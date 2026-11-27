import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/*
 * The local database lives in one of two folders under the app's support folder: `local`, which the
 * system backs up (Android: res/xml/data_extraction_rules.xml and backup_rules.xml), or
 * `local-nobackup`, which it doesn't (iOS: marked excluded through the `maimoni/backup` channel in
 * AppDelegate.swift). Turning the backup on or off moves the file. Where it is says whether the
 * backup is on, so a restore brings that answer along.
 */

const _name = 'maimoni.sqlite';
const _channel = MethodChannel('maimoni/backup');

/// The files SQLite keeps next to the database.
const _suffixes = ['', '-wal', '-shm', '-journal'];

Future<Directory> _folder({required bool backup}) async {
  final support = await getApplicationSupportDirectory();
  final folder = Directory('${support.path}/${backup ? 'local' : 'local-nobackup'}');
  await folder.create(recursive: true);
  if (!backup && Platform.isIOS) {
    try {
      await _channel.invokeMethod<void>('excludeFromBackup', folder.path);
    } on PlatformException {
      // Left in the backup until the next start tries again.
    }
  }
  return folder;
}

/// Whether the system backs up the database.
Future<bool> backupEnabled() async => File('${(await _folder(backup: true)).path}/$_name').exists();

/// The folder the database is in: the one the system backs up only when the backup is on.
Future<Directory> databaseFolder() async => _folder(backup: await backupEnabled());

/// Moves the database into the folder that matches [backup]. It must be closed.
Future<void> moveDatabase({required bool backup}) async {
  final from = await _folder(backup: !backup);
  final to = await _folder(backup: backup);
  for (final suffix in _suffixes) {
    final file = File('${from.path}/$_name$suffix');
    if (await file.exists()) await file.rename('${to.path}/$_name$suffix');
  }
}
