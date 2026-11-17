import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maimoni/api/auth.dart';
import 'package:maimoni/api/client.dart';
import 'package:maimoni/api/providers.dart';
import 'package:maimoni/config.dart';
import 'package:maimoni/screens/login_screen.dart';
import 'package:maimoni/state/session.dart';
import 'package:maimoni/theme.dart';
import 'package:maimoni/widgets/common.dart';
import 'package:passkeys/exceptions.dart';

http.Response json(Object? body, {int status = 200, Map<String, String> headers = const {}}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});

const _user = {'id': 'u1', 'name': 'Ana', 'email': 'ana@example.com'};
const _options = {'challenge': 'Y2hhbGxlbmdl', 'rpId': 'maimoni.roz.ninja', 'userVerification': 'preferred'};
const _assertion = {
  'id': 'cred',
  'rawId': 'cred',
  'type': 'public-key',
  'response': {'clientDataJSON': 'cd', 'authenticatorData': 'ad', 'signature': 'sig'},
};

Widget _login() => MaterialApp(theme: buildTheme(Brightness.light), home: const LoginScreen());

/// Answers the two passkey steps; [verify] answers the second one and sees its request.
MockClient _server({http.Response Function(http.Request request)? verify, void Function(http.Request request)? onVerify}) => MockClient((request) async {
      switch (request.url.path) {
        case '/api/sign-in-providers':
          return json({'error': 'boom'}, status: 500);
        case '/api/auth/passkey/generate-authenticate-options':
          return json(_options, headers: {'set-cookie': '__Secure-better-auth.better-auth-passkey=v%2B1.sig; Max-Age=300; Path=/; HttpOnly'});
        case '/api/auth/passkey/verify-authentication':
          onVerify?.call(request);
          return verify?.call(request) ??
              json({
                'session': {'token': 'raw'},
                'user': _user,
              }, headers: {'set-auth-token': 'tok'});
      }
      return json({'error': 'Not found'}, status: 404);
    });

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final originalAssertion = passkeyAssertion;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Session.instance.clear();
  });

  tearDown(() => passkeyAssertion = originalAssertion);

  group('signInPasskey', () {
    test('sends the assertion with the challenge cookie and an Origin, and starts the session', () async {
      Map<String, dynamic>? asked;
      http.Request? verify;
      passkeyAssertion = (options) async {
        asked = options;
        return _assertion;
      };
      Api.instance.httpClient = _server(onVerify: (request) => verify = request);
      expect(await signInPasskey(), isNull);
      expect(asked, _options);
      expect(verify?.method, 'POST');
      expect(verify?.headers['cookie'], '__Secure-better-auth.better-auth-passkey=v%2B1.sig');
      expect(verify?.headers['origin'], Uri.parse(serverUrl).origin);
      expect(jsonDecode(verify!.body), {'response': _assertion});
      expect(Session.instance.token, 'tok');
      expect(Session.instance.user?.email, 'ana@example.com');
    });

    test('a closed sheet sends nothing and stays signed out', () async {
      var verifies = 0;
      passkeyAssertion = (_) async => null;
      Api.instance.httpClient = _server(onVerify: (_) => verifies++);
      expect(await signInPasskey(), isNull);
      expect(verifies, 0);
      expect(Session.instance.signedIn, isFalse);
    });

    test('explains a device without passkeys for the domain', () async {
      passkeyAssertion = (_) async => throw NoCredentialsAvailableException();
      Api.instance.httpClient = _server();
      expect(await signInPasskey(), 'Nenhuma passkey encontrada neste aparelho.');
    });

    test('explains a device that does not support passkeys', () async {
      Api.instance.httpClient = _server();
      passkeyAssertion = (_) async => throw PasskeyUnsupportedException();
      expect(await signInPasskey(), 'Este aparelho não suporta passkeys.');
      passkeyAssertion = (_) async => throw DeviceNotSupportedException();
      expect(await signInPasskey(), 'Este aparelho não suporta passkeys.');
    });

    test('explains a passkey that belongs to no account', () async {
      passkeyAssertion = (_) async => _assertion;
      Api.instance.httpClient = _server(verify: (_) => json({'message': 'Passkey not found', 'code': 'PASSKEY_NOT_FOUND'}, status: 401));
      expect(await signInPasskey(), 'Essa passkey não pertence a uma conta do maimoni.');
      expect(Session.instance.signedIn, isFalse);
    });

    test('falls back for other failures', () async {
      passkeyAssertion = (_) async => _assertion;
      Api.instance.httpClient = _server(verify: (_) => json({'message': 'Authentication failed', 'code': 'AUTHENTICATION_FAILED'}, status: 400));
      expect(await signInPasskey(), 'Não foi possível entrar com a passkey.');
    });
  });

  group('login screen', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('${platform.name} shows the passkey button when the providers request failed', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        Api.instance.httpClient = _server();
        await tester.pumpWidget(_login());
        await tester.pumpAndSettle();
        expect(find.text('Entrar com passkey'), findsOneWidget);
        expect(find.text('ou'), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('a passkey failure is shown', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      passkeyAssertion = (_) async => throw NoCredentialsAvailableException();
      Api.instance.httpClient = _server();
      await tester.pumpWidget(_login());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrar com passkey'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Callout, 'Nenhuma passkey encontrada neste aparelho.'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
