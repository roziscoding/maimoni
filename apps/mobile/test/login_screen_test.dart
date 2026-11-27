import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maimoni/api/client.dart';
import 'package:maimoni/main.dart';
import 'package:maimoni/screens/login_screen.dart';
import 'package:maimoni/screens/today_screen.dart';
import 'package:maimoni/screens/welcome_screen.dart';
import 'package:maimoni/state/months_store.dart';
import 'package:maimoni/state/session.dart';
import 'package:maimoni/theme.dart';
import 'package:maimoni/widgets/common.dart';

http.Response json(Object? body, {int status = 200, Map<String, String> headers = const {}}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});

Widget _login() => MaterialApp(theme: buildTheme(Brightness.light), home: const LoginScreen());

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Session.instance.clear();
    MonthsStore.instance.reset();
  });

  testWidgets('an empty email is rejected without a request', (tester) async {
    var calls = 0;
    Api.instance.httpClient = MockClient((request) async {
      // The screen asks for the sign in providers when it opens.
      if (request.url.path != '/api/sign-in-providers') calls++;
      return json(null);
    });
    await tester.pumpWidget(_login());
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Informe um e-mail válido'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('rejected credentials show a callout', (tester) async {
    Api.instance.httpClient =
        MockClient((request) async => json({'message': 'Invalid email or password', 'code': 'INVALID_EMAIL_OR_PASSWORD'}, status: 401));
    await tester.pumpWidget(_login());
    await tester.enterText(find.byType(TextField).first, 'ana@example.com');
    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Callout, 'E-mail ou senha incorretos.'), findsOneWidget);
  });

  testWidgets('starting and ending a session swaps the navigation stack', (tester) async {
    var monthRequests = 0;
    Api.instance.httpClient = MockClient((request) async {
      if (request.url.path == '/api/months') {
        monthRequests++;
        return json([]);
      }
      return json({'error': 'Not found'}, status: 404);
    });
    await tester.pumpWidget(const MaimoniApp());
    await tester.pump();
    expect(find.byType(WelcomeScreen), findsOneWidget);

    Session.instance.setToken('t');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(monthRequests, greaterThan(0));
    expect(MonthsStore.instance.loaded, isTrue);

    Session.instance.clear();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(TodayScreen, skipOffstage: false), findsNothing);
    expect(MonthsStore.instance.months, isEmpty);
    expect(MonthsStore.instance.loaded, isFalse);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an expired session shows the welcome screen and says so', (tester) async {
    Api.instance.httpClient = MockClient(
      (request) async => request.url.path == '/api/months' ? json([]) : json({'error': 'Not found'}, status: 404),
    );
    Session.instance.setToken('t');
    await tester.pumpWidget(const MaimoniApp());
    await tester.pump(const Duration(seconds: 1));

    Session.instance.clear(ifToken: 't', expired: true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Sua sessão expirou'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
