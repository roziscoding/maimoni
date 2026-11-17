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
import 'package:maimoni/screens/login_screen.dart';
import 'package:maimoni/state/session.dart';
import 'package:maimoni/theme.dart';
import 'package:maimoni/widgets/common.dart';

http.Response json(Object? body, {int status = 200, Map<String, String> headers = const {}}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});

const _user = {'id': 'u1', 'name': 'Ana', 'email': 'ana@example.com'};

Widget _login() => MaterialApp(theme: buildTheme(Brightness.light), home: const LoginScreen());

/// Answers the providers list with [providers], or a 500 when it is `null`, and counts social sign ins.
MockClient _server(List<String>? providers, {void Function(http.Request request)? onSocial}) => MockClient((request) async {
      if (request.url.path == '/api/sign-in-providers') return providers == null ? json({'error': 'boom'}, status: 500) : json(providers);
      if (request.url.path == '/api/auth/sign-in/social') {
        onSocial?.call(request);
        return json({'redirect': false, 'token': 'tok', 'user': _user}, headers: {'set-auth-token': 'tok'});
      }
      if (request.url.path == '/api/auth/sign-in/email') {
        return json({'message': 'Invalid email or password', 'code': 'INVALID_EMAIL_OR_PASSWORD'}, status: 401);
      }
      return json({'error': 'Not found'}, status: 404);
    });

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final originalGoogle = googleIdToken;
  final originalApple = appleIdToken;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Session.instance.clear();
  });

  tearDown(() {
    googleIdToken = originalGoogle;
    appleIdToken = originalApple;
  });

  group('signInSocial', () {
    test('posts the Google ID token without a cookie and starts the session', () async {
      String? path;
      Map<String, dynamic>? sent;
      Map<String, String>? headers;
      Api.instance.httpClient = MockClient((request) async {
        path = request.url.path;
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        headers = request.headers;
        return json({'redirect': false, 'token': 'tok', 'user': _user}, headers: {'set-auth-token': 'tok'});
      });
      expect(await signInSocial('google', token: 't'), isNull);
      expect(path, '/api/auth/sign-in/social');
      expect(sent, {
        'provider': 'google',
        'idToken': {'token': 't'},
      });
      expect(headers?.containsKey('cookie'), isFalse);
      expect(Session.instance.token, 'tok');
      expect(Session.instance.user?.email, 'ana@example.com');
    });

    test('sends the Apple nonce', () async {
      Map<String, dynamic>? sent;
      Api.instance.httpClient = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return json({'redirect': false, 'token': 'tok', 'user': _user}, headers: {'set-auth-token': 'tok'});
      });
      expect(await signInSocial('apple', token: 't', nonce: 'n'), isNull);
      expect(sent, {
        'provider': 'apple',
        'idToken': {'token': 't', 'nonce': 'n'},
      });
    });

    test('explains a missing account', () async {
      Api.instance.httpClient = MockClient((request) async => json({'message': 'signup disabled', 'code': 'OAUTH_LINK_ERROR'}, status: 401));
      expect(await signInSocial('google', token: 't'), 'Não existe uma conta do maimoni para o e-mail dessa conta.');
      expect(Session.instance.signedIn, isFalse);
    });

    test('falls back for other errors', () async {
      Api.instance.httpClient = MockClient((request) async => json({'message': 'Invalid token', 'code': 'INVALID_TOKEN'}, status: 401));
      expect(await signInSocial('google', token: 't'), 'Não foi possível entrar com essa conta.');
      Api.instance.httpClient = MockClient((request) async => json({'message': 'account not linked', 'code': 'OAUTH_LINK_ERROR'}, status: 401));
      expect(await signInSocial('google', token: 't'), 'Não foi possível entrar com essa conta.');
    });
  });

  group('signInProviders', () {
    test('lists the providers', () async {
      Api.instance.httpClient = _server(['google', 'apple']);
      expect(await signInProviders(), ['google', 'apple']);
    });

    test('is empty when the request fails', () async {
      Api.instance.httpClient = _server(null);
      expect(await signInProviders(), isEmpty);
    });
  });

  group('login screen', () {
    testWidgets('Android shows Google only', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      Api.instance.httpClient = _server(['google', 'apple']);
      await tester.pumpWidget(_login());
      await tester.pumpAndSettle();
      expect(find.text('Continuar com o Google'), findsOneWidget);
      expect(find.text('Continuar com a Apple'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('iOS shows Google and Apple', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      Api.instance.httpClient = _server(['google', 'apple']);
      await tester.pumpWidget(_login());
      await tester.pumpAndSettle();
      expect(find.text('Continuar com o Google'), findsOneWidget);
      expect(find.text('Continuar com a Apple'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a failed providers request leaves only the email form', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      Api.instance.httpClient = _server(null);
      await tester.pumpWidget(_login());
      await tester.pumpAndSettle();
      expect(find.text('Continuar com o Google'), findsNothing);
      expect(find.text('Continuar com a Apple'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'ana@example.com');
      await tester.enterText(find.byType(TextField).last, 'wrong');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Callout, 'E-mail ou senha incorretos.'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a closed Google sheet sends nothing and shows no error', (tester) async {
      var socialRequests = 0;
      googleIdToken = () async => null;
      Api.instance.httpClient = _server(['google'], onSocial: (_) => socialRequests++);
      await tester.pumpWidget(_login());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar com o Google'));
      await tester.pumpAndSettle();
      expect(socialRequests, 0);
      expect(find.byType(Callout), findsNothing);
      expect(Session.instance.signedIn, isFalse);
    });

    testWidgets('a closed Apple sheet sends nothing and shows no error', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var socialRequests = 0;
      appleIdToken = () async => null;
      Api.instance.httpClient = _server(['apple'], onSocial: (_) => socialRequests++);
      await tester.pumpWidget(_login());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar com a Apple'));
      await tester.pumpAndSettle();
      expect(socialRequests, 0);
      expect(find.byType(Callout), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a Google token signs in', (tester) async {
      Map<String, dynamic>? sent;
      googleIdToken = () async => (token: 'g', nonce: null);
      Api.instance.httpClient = _server(['google'], onSocial: (request) => sent = jsonDecode(request.body) as Map<String, dynamic>);
      await tester.pumpWidget(_login());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar com o Google'));
      await tester.pumpAndSettle();
      expect(sent, {
        'provider': 'google',
        'idToken': {'token': 'g'},
      });
      expect(Session.instance.token, 'tok');
    });

    testWidgets('a provider SDK failure shows the fallback', (tester) async {
      googleIdToken = () async => throw StateError('Google returned no ID token');
      Api.instance.httpClient = _server(['google']);
      await tester.pumpWidget(_login());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar com o Google'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Callout, 'Não foi possível entrar com essa conta.'), findsOneWidget);
    });
  });
}
