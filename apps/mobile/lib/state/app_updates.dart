import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import '../api/models.dart';

enum UpdateChannel {
  stable('Estável'),
  beta('Beta');

  const UpdateChannel(this.label);
  final String label;
}

/// Android updates outside Obtainium: asks the server for the newest release of the chosen channel
/// and, when it's newer than this build, downloads the APK and opens the system installer. iOS
/// updates come from TestFlight.
class AppUpdates extends ChangeNotifier {
  AppUpdates._();

  static final instance = AppUpdates._();
  static const _channelKey = 'update_channel';

  /// Version and build number of the installed app.
  String? version;
  int? build;
  UpdateChannel channel = UpdateChannel.stable;

  /// A release newer than the installed build, if the last check found one.
  AppRelease? available;
  bool checking = false;
  String? error;

  /// Download progress from 0 to 1 while installing; `null` otherwise.
  double? progress;

  bool get supported => Platform.isAndroid;
  bool get installing => progress != null;

  Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      build = int.tryParse(info.buildNumber);
    } catch (_) {
      // Without the build number there's nothing to compare releases with.
    }
    // Betas (build numbers not ending in 99) follow the beta channel until the person picks one.
    final isBeta = build != null && build! % 100 != 99;
    try {
      final stored = (await SharedPreferences.getInstance()).getString(_channelKey);
      channel = stored == null ? (isBeta ? UpdateChannel.beta : UpdateChannel.stable) : UpdateChannel.values.byName(stored);
    } catch (_) {
      channel = isBeta ? UpdateChannel.beta : UpdateChannel.stable;
    }
    notifyListeners();
  }

  Future<void> setChannel(UpdateChannel value) async {
    channel = value;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_channelKey, value.name);
    } catch (_) {
      // Not persisted; applies to this session.
    }
    await check();
  }

  /// Looks for a newer release; returns it when there is one.
  Future<AppRelease?> check() async {
    if (!supported || checking) return available;
    if (build == null) {
      error = 'Não foi possível ler a versão instalada para comparar.';
      notifyListeners();
      return null;
    }
    checking = true;
    error = null;
    notifyListeners();
    final requested = channel;
    try {
      final release = await Api.instance.latestAndroidRelease(requested.name);
      if (channel == requested) available = release != null && release.versionCode > build! ? release : null;
    } catch (err) {
      if (channel == requested) error = errorMessage(err);
    } finally {
      checking = false;
      notifyListeners();
    }
    // The channel changed while this check ran: its answer was for the previous one.
    return channel == requested ? available : check();
  }

  /// Downloads the available release and opens the installer. Completes when the installer is up
  /// or the attempt failed (see [error]).
  Future<void> install() async {
    final release = available;
    if (release == null || installing) return;
    error = null;
    progress = 0;
    notifyListeners();
    final done = Completer<void>();
    // A new instance per attempt: OtaUpdate keeps the first stream it returned.
    OtaUpdate()
        .execute(
          Api.instance.resolve(release.url).toString(),
          destinationFilename: 'maimoni-${release.version}.apk',
          sha256checksum: release.sha256,
        )
        .listen(
          (event) {
            switch (event.status) {
              case OtaStatus.DOWNLOADING:
                progress = (double.tryParse(event.value ?? '') ?? 0) / 100;
              case OtaStatus.INSTALLING || OtaStatus.INSTALLATION_DONE:
                progress = null;
                if (!done.isCompleted) done.complete();
              case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                _fail('Permita instalar apps do maimoni nas configurações do Android e tente de novo.', done);
              case OtaStatus.CHECKSUM_ERROR:
                _fail('O arquivo baixado não confere com a release. Tente de novo.', done);
              case OtaStatus.CANCELED:
                _fail(null, done);
              default:
                _fail('Não foi possível instalar: ${event.value ?? event.status.name}', done);
            }
            notifyListeners();
          },
          onError: (Object err) {
            _fail('Não foi possível baixar a atualização.', done);
            notifyListeners();
          },
          onDone: () {
            progress = null;
            if (!done.isCompleted) done.complete();
            notifyListeners();
          },
        );
    return done.future;
  }

  void _fail(String? message, Completer<void> done) {
    error = message;
    progress = null;
    if (!done.isCompleted) done.complete();
  }
}
