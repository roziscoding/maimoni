import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config.dart';

typedef ProviderToken = ({String token, String? nonce});

/// Asks Google for an ID token; `null` when the person closed the sheet. Replaceable in tests.
Future<ProviderToken?> Function() googleIdToken = _googleIdToken;

/// Asks Apple for an identity token; `null` when the person closed the sheet. Replaceable in tests.
Future<ProviderToken?> Function() appleIdToken = _appleIdToken;

Future<void>? _googleReady;

Future<ProviderToken?> _googleIdToken() async {
  // `initialize` may only run once per process.
  try {
    await (_googleReady ??= GoogleSignIn.instance.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS ? googleIosClientId : null,
      serverClientId: googleWebClientId,
    ));
  } catch (_) {
    // It didn't run: let the next tap try again.
    _googleReady = null;
    rethrow;
  }
  try {
    final token = (await GoogleSignIn.instance.authenticate()).authentication.idToken;
    if (token == null) throw StateError('Google returned no ID token');
    return (token: token, nonce: null);
  } on GoogleSignInException catch (error) {
    // Android also reports a client that isn't set up for this package and signing key as a cancel.
    if (error.code == GoogleSignInExceptionCode.canceled) return null;
    rethrow;
  }
}

Future<ProviderToken?> _appleIdToken() async {
  // Apple gets the hash and puts it in the token; the server gets the raw value and hashes it to compare.
  final nonce = generateNonce();
  try {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      nonce: sha256.convert(utf8.encode(nonce)).toString(),
    );
    final token = credential.identityToken;
    if (token == null) throw StateError('Apple returned no identity token');
    return (token: token, nonce: nonce);
  } on SignInWithAppleAuthorizationException catch (error) {
    if (error.code == AuthorizationErrorCode.canceled) return null;
    rethrow;
  }
}
