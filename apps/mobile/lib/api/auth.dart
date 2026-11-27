import 'dart:async';

import 'package:http/http.dart' show HeadersWithSplitValues;

import '../config.dart';
import '../state/local_mode.dart';
import '../state/session.dart';
import 'client.dart';
import 'providers.dart';

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

const _socialFallback = 'Não foi possível entrar com essa conta.';

/// Social providers the server has credentials for; empty when it can't be asked.
Future<List<String>> signInProviders() async {
  try {
    final data = (await Api.instance.request('GET', '/sign-in-providers')).data;
    return data is List ? data.whereType<String>().toList() : const [];
  } catch (_) {
    return const [];
  }
}

/// Signs in with an ID token the provider's SDK issued on this device.
/// Returns an error message in Portuguese, or `null` once signed in.
Future<String?> signInSocial(String provider, {required String token, String? nonce}) async {
  try {
    final result = await Api.instance.request('POST', '/auth/sign-in/social', body: {
      'provider': provider,
      'idToken': {'token': token, 'nonce': ?nonce},
    });
    return _started(result.data);
  } catch (error) {
    // Sign up is off and no user has this email. Better Auth shares the code with other link failures.
    if (error is ApiException && error.code == 'OAUTH_LINK_ERROR' && error.message == 'signup disabled') {
      return 'Não existe uma conta do maimoni para o e-mail dessa conta.';
    }
    return signInError(error, fallback: _socialFallback);
  }
}

const _passkeyFallback = 'Não foi possível entrar com a passkey.';

/// Signs in with a passkey: the server issues a challenge, the device signs it, the server checks it.
/// Returns an error message in Portuguese, or `null` when signed in or when the person gave up.
Future<String?> signInPasskey() async {
  try {
    final options = await Api.instance.request('GET', '/auth/passkey/generate-authenticate-options');
    if (options.data is! Map) return _passkeyFallback;
    // The server keeps the challenge under a signed cookie and wants it back unchanged with the answer.
    final cookie = (options.response.headersSplitValues['set-cookie'] ?? const []).map((value) => value.split(';').first.trim()).join('; ');
    final assertion = await passkeyAssertion(Map<String, dynamic>.from(options.data as Map));
    if (assertion == null) return null;
    final result = await Api.instance.request(
      'POST',
      '/auth/passkey/verify-authentication',
      body: {'response': assertion},
      // Better Auth refuses a request that has a cookie and no Origin; the server's own origin is trusted.
      headers: {'cookie': cookie, 'origin': Uri.parse(serverUrl).origin},
    );
    return _started(result.data);
  } catch (error) {
    if (error is ApiException && error.code == 'PASSKEY_NOT_FOUND') return 'Essa passkey não pertence a uma conta do maimoni.';
    return passkeyError(error) ?? signInError(error, fallback: _passkeyFallback);
  }
}

/// Asks for a password reset link. The server answers the same whether or not the email has an
/// account. Returns an error message in Portuguese, or `null` once the request was accepted.
Future<String?> requestPasswordReset(String email) async {
  try {
    await Api.instance.request('POST', '/password-reset', body: {'email': email});
    return null;
  } catch (error) {
    if (error is ApiException && error.status == 400) return 'Informe um e-mail válido';
    return error is ApiException && error.status == null ? error.message : 'Não foi possível enviar o link.';
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

/// Records that the first-run setup was finished or skipped: on the device in the local mode, on
/// the server otherwise, so neither this app nor the web shows it again. Throws when that failed.
Future<void> finishOnboarding() async {
  if (LocalMode.instance.active) return LocalMode.instance.setOnboarded();
  await Api.instance.request('POST', '/auth/update-user', body: {'onboarded': true});
  Session.instance.setOnboarded();
}

/// Ends the session here at once and tells the server in the background. Until the server answers,
/// the token is kept aside and [confirmSignOuts] tries again when the app starts.
void signOut() {
  Session.instance.signOut();
  unawaited(confirmSignOuts());
}

/// Tells the server to end the sessions signed out here that it may still accept, such as one
/// signed out while offline. A token stays for the next try when the server couldn't be asked.
Future<void> confirmSignOuts() async {
  final session = Session.instance;
  for (final token in session.pendingSignOuts) {
    try {
      // Not Better Auth's `sign-out`: it answers 200 even when it fails to delete the session.
      await Api.instance.request('DELETE', '/sessions/current', bearer: token);
    } catch (error) {
      // Only a 401 also settles it: the server no longer accepts the token. Anything else (no
      // answer, a server error, a server too old to have the route) leaves it for the next try.
      if (error is! ApiException || error.status != 401) continue;
    }
    session.signOutConfirmed(token);
  }
}
