import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionUser {
  const SessionUser({required this.name, required this.email});

  factory SessionUser.fromJson(Map<String, dynamic> json) =>
      SessionUser(name: json['name'] as String? ?? '', email: json['email'] as String? ?? '');

  final String name;
  final String email;
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

  String? _token;
  SessionUser? _user;
  bool _expired = false;

  String? get token => _token;
  SessionUser? get user => _user;
  bool get signedIn => _token != null;

  /// Whether the last session ended on its own (the server stopped accepting it) rather than by signing out.
  bool get expired => _expired;

  Future<void> load() async {
    try {
      _token = await _storage.read(key: _key);
    } catch (_) {
      // Storage unavailable: start signed out.
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
    notifyListeners();
  }

  /// Ends the session on this device. With [ifToken], only when that is still the current token, so
  /// a late answer to a request made by an earlier session can't end the new one.
  void clear({String? ifToken, bool expired = false}) {
    if (_token == null || (ifToken != null && ifToken != _token)) return;
    _token = null;
    _user = null;
    _expired = expired;
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
