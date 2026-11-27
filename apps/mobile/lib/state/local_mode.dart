import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/backup.dart';
import '../data/database.dart';
import '../data/local_repository.dart';

/// Whether the app keeps the data on the device, with no account, instead of on the server.
///
/// Signing in is the cloud mode, so the two never hold at once: [Session] says who is signed in,
/// this says whether the person chose to go without an account.
class LocalMode extends ChangeNotifier {
  LocalMode._();

  static final instance = LocalMode._();
  static const _key = 'local_mode';
  static const _onboardedKey = 'onboarded';

  /// How the repository is made; tests swap in one kept in memory.
  @visibleForTesting
  LocalRepository Function() createRepository = () => LocalRepository(openLocalDatabase());

  bool _active = false;
  bool _onboarded = false;
  bool _backup = false;
  LocalRepository? _repository;

  bool get active => _active;

  /// Whether the system's backup (Google or iCloud) keeps a copy of the database.
  bool get backup => _backup;

  /// Whether the first-run setup is done. It lives in the database, so a backup or an import carries it.
  bool get onboarded => _onboarded;

  LocalRepository get repository => _repository ??= createRepository();

  Future<void> load() async {
    bool? chosen;
    try {
      chosen = (await SharedPreferences.getInstance()).getBool(_key);
    } catch (_) {
      chosen = null;
    }
    await _readBackup();
    // The preferences aren't in the backup: a database restored from it is a choice made on the old device.
    _active = chosen ?? _backup;
    if (!_active) return;
    if (chosen == null) await _persist(true);
    await _readOnboarded();
  }

  Future<void> _readBackup() async {
    try {
      _backup = await backupEnabled();
    } catch (_) {
      _backup = false;
    }
  }

  /// Moves the database in or out of the system's backup.
  Future<void> setBackup(bool value) async {
    if (value == _backup) return;
    await _repository?.db.close();
    _repository = null;
    await moveDatabase(backup: value);
    _backup = value;
    notifyListeners();
  }

  Future<void> _readOnboarded() async {
    final db = repository.db;
    final row = await (db.select(db.meta)..where((row) => row.key.equals(_onboardedKey))).getSingleOrNull();
    _onboarded = row?.value == 'true';
  }

  /// Starts using the app without an account, with [data] (an export) when there is one.
  Future<void> start({Object? data}) async {
    await _readBackup();
    if (data != null) await _import(data);
    await _persist(true);
    await _readOnboarded();
    _active = true;
    notifyListeners();
  }

  /// Replaces the data on the device with an export, which also takes the setup as done.
  Future<void> import(Object? data) async {
    await _import(data);
    notifyListeners();
  }

  Future<void> _import(Object? data) async {
    await repository.replaceAll(data);
    final db = repository.db;
    await db.into(db.meta).insertOnConflictUpdate(MetaRow(key: _onboardedKey, value: 'true'));
    _onboarded = true;
  }

  /// Takes the first-run setup as done.
  Future<void> setOnboarded() async {
    final db = repository.db;
    await db.into(db.meta).insertOnConflictUpdate(MetaRow(key: _onboardedKey, value: 'true'));
    _onboarded = true;
    notifyListeners();
  }

  /// Stops using the app without an account and deletes everything stored on the device.
  Future<void> leave() async {
    final db = repository.db;
    await db.transaction(() async {
      for (final table in db.allTables) {
        await db.delete(table).go();
      }
    });
    _onboarded = false;
    _active = false;
    await _persist(false);
    // An empty database has nothing to back up, and the next start asks again.
    try {
      await setBackup(false);
    } finally {
      notifyListeners();
    }
  }

  Future<void> _persist(bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, value);
    } catch (_) {
      // Not persisted; the choice holds until the app closes.
    }
  }

  /// Forgets the state between tests.
  @visibleForTesting
  Future<void> reset() async {
    await _repository?.db.close();
    _repository = null;
    _active = false;
    _onboarded = false;
    _backup = false;
  }
}
