import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionUser {
  const SessionUser({required this.name, required this.email, this.onboarded = true});

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        onboarded: json['onboarded'] as bool? ?? true,
      );

  final String name;
  final String email;

  /// Whether the user went through the first-run setup, here or on the web. A server too old to
  /// have the field doesn't send it, and its users aren't asked to set anything up.
  final bool onboarded;
}

/// Who is signed in. The token is kept in the platform's secure storage and sent as a bearer by
/// [Api]; the user arrives with the sign in response or the session check after start.
class Session extends ChangeNotifier {
  Session._();

  static final instance = Session._();
  static const _key = 'session_token';
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static const _pendingKey = 'pending_sign_outs';
  static const _onboardedKey = 'session_onboarded';

  String? _token;
  List<String> _pendingSignOuts = [];
  SessionUser? _user;
  bool _expired = false;

  /// What the server last said about the user's setup; `null` until it says anything.
  bool? _onboarded;

  /// Whether the user went through the first-run setup. Kept on the device with the token, so the
  /// app knows what to open before the server answers, or when it can't be reached. Taken as done
  /// while nothing is known.
  bool get onboarded => _onboarded ?? true;

  String? get token => _token;
  SessionUser? get user => _user;
  bool get signedIn => _token != null;

  /// Whether the last session ended on its own (the server stopped accepting it) rather than by signing out.
  bool get expired => _expired;

  /// Tokens of sessions signed out here that the server hasn't confirmed ending yet.
  List<String> get pendingSignOuts => List.unmodifiable(_pendingSignOuts);

  Future<void> load() async {
    try {
      _token = await _storage.read(key: _key);
      final onboarded = await _storage.read(key: _onboardedKey);
      _onboarded = onboarded == null ? null : onboarded == 'true';
      final pending = await _storage.read(key: _pendingKey);
      _pendingSignOuts = pending == null ? [] : (jsonDecode(pending) as List).whereType<String>().toList();
    } catch (_) {
      // Storage unavailable: start signed out.
    }
  }

  /// Ends the session on this device and keeps its token in [pendingSignOuts], since the server
  /// still accepts it until it is told otherwise.
  void signOut() {
    final token = _token;
    if (token == null) return;
    _pendingSignOuts = [..._pendingSignOuts, token];
    unawaited(_persistPending());
    clear();
  }

  /// Forgets a token the server has stopped accepting.
  void signOutConfirmed(String token) {
    if (!_pendingSignOuts.contains(token)) return;
    _pendingSignOuts = _pendingSignOuts.where((pending) => pending != token).toList();
    unawaited(_persistPending());
  }

  Future<void> _persistPending() async {
    try {
      await _storage.write(key: _pendingKey, value: _pendingSignOuts.isEmpty ? null : jsonEncode(_pendingSignOuts));
    } catch (_) {
      // Not persisted; the retry still happens until the app closes.
    }
  }

  /// Starts a session, or replaces the token of the current one.
  void setToken(String token) {
    if (token == _token) return;
    _token = token;
    _expired = false;
    unawaited(_persist());
    notifyListeners();
  }

  void setUser(SessionUser? user) {
    _user = user;
    if (user != null) _rememberOnboarded(user.onboarded);
    notifyListeners();
  }

  /// Takes the first-run setup as done, once the server recorded it.
  void setOnboarded() {
    final user = _user;
    if (user != null) _user = SessionUser(name: user.name, email: user.email);
    _rememberOnboarded(true);
    notifyListeners();
  }

  void _rememberOnboarded(bool? value) {
    if (value == _onboarded) return;
    _onboarded = value;
    unawaited(_persistOnboarded());
  }

  Future<void> _persistOnboarded() async {
    try {
      await _storage.write(key: _onboardedKey, value: _onboarded?.toString());
    } catch (_) {
      // Not persisted; the server says it again on the next session check.
    }
  }

  /// Ends the session on this device. With [ifToken], only when that is still the current token, so
  /// a late answer to a request made by an earlier session can't end the new one.
  void clear({String? ifToken, bool expired = false}) {
    if (_token == null || (ifToken != null && ifToken != _token)) return;
    _token = null;
    _user = null;
    _expired = expired;
    _rememberOnboarded(null);
    unawaited(_persist());
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _storage.write(key: _key, value: _token);
    } catch (_) {
      // Not persisted; the session still holds until the app closes.
    }
  }
}
