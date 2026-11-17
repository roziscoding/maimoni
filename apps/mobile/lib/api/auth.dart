import '../state/session.dart';
import 'client.dart';

const _signInErrors = {
  'INVALID_EMAIL_OR_PASSWORD': 'E-mail ou senha incorretos.',
  'INVALID_EMAIL': 'E-mail inválido.',
};

const _fallback = 'Não foi possível entrar.';

/// Message in Portuguese for a failed sign in.
String signInError(Object error, {String fallback = _fallback}) {
  if (error is! ApiException) return fallback;
  if (error.status == 429) return 'Muitas tentativas. Espere um pouco e tente de novo.';
  // No status: the request never got an answer, and the message already says why.
  if (error.status == null) return error.message;
  return _signInErrors[error.code] ?? fallback;
}

/// Finishes a sign in: the token normally arrived in `set-auth-token` and [Api] stored it; the body
/// carries the user, and the token as a fallback.
String? _started(Object? data) {
  final session = Session.instance;
  if (data is! Map) return session.signedIn ? null : _fallback;
  if (!session.signedIn) {
    final nested = data['session'];
    final token = data['token'] ?? (nested is Map ? nested['token'] : null);
    if (token is! String || token.isEmpty) return _fallback;
    session.setToken(token);
  }
  final user = data['user'];
  if (user is Map) session.setUser(SessionUser.fromJson(Map<String, dynamic>.from(user)));
  return null;
}

/// Returns an error message in Portuguese, or `null` once signed in.
Future<String?> signInEmail(String email, String password) async {
  try {
    final result = await Api.instance.request('POST', '/auth/sign-in/email', body: {'email': email, 'password': password});
    return _started(result.data);
  } catch (error) {
    return signInError(error);
  }
}

/// Asks the server who the stored token belongs to. The server answers `null` for a token it no
/// longer accepts, which ends the session here; a failed request leaves it alone.
Future<void> checkSession() async {
  final session = Session.instance;
  final token = session.token;
  if (token == null) return;
  try {
    final data = (await Api.instance.request('GET', '/auth/get-session')).data;
    final user = data is Map ? data['user'] : null;
    if (user is Map) {
      // Another session may have started while the request was in flight; this user isn't theirs.
      if (session.token == token) session.setUser(SessionUser.fromJson(Map<String, dynamic>.from(user)));
    } else {
      session.clear(ifToken: token, expired: true);
    }
  } catch (_) {
    // Offline or the server is down: a data route's 401 ends the session if it has to.
  }
}

/// Ends the session here at once and tells the server in the background.
void signOut() {
  final token = Session.instance.token;
  if (token == null) return;
  Session.instance.clear();
  Api.instance.request('POST', '/auth/sign-out', headers: {'authorization': 'Bearer $token'}).then((_) {}, onError: (_) {});
}
