import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:maimoni/api/client.dart';
import 'package:maimoni/main.dart';
import 'package:maimoni/routes.dart';
import 'package:maimoni/screens/login_screen.dart';
import 'package:maimoni/screens/month_screen.dart';
import 'package:maimoni/screens/months_screen.dart';
import 'package:maimoni/screens/settings_screen.dart';
import 'package:maimoni/screens/today_screen.dart';
import 'package:maimoni/state/months_store.dart';
import 'package:maimoni/state/session.dart';

http.Response json(Object? body, {int status = 200, Map<String, String> headers = const {}}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('pt_BR');
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Session.instance.clear();
    MonthsStore.instance.reset();
    shellTab.value = AppTab.today;
  });

  Future<List<String>> open(WidgetTester tester) async {
    final requests = <String>[];
    Api.instance.httpClient = MockClient((request) async {
      requests.add(request.url.path);
      if (request.url.path == '/api/months') return json([]);
      if (request.url.path == '/api/sessions/current') return json({'success': true});
      return json({'error': 'Not found'}, status: 404);
    });
    Session.instance.setToken('t');
    Session.instance.setUser(const SessionUser(name: 'A', email: 'a@b.c'));
    // What `main` does before the first frame of a session it found stored.
    MonthsStore.instance.refresh();
    await tester.pumpWidget(const MaimoniApp());
    await tester.pump(const Duration(seconds: 1));
    return requests;
  }

  testWidgets('the bottom bar switches between the tabs and keeps Hoje alive', (tester) async {
    await open(tester);
    expect(find.byType(TodayScreen), findsOneWidget);
    // A tab is only built once it is visited.
    expect(find.byType(MonthsScreen, skipOffstage: false), findsNothing);

    await tester.tap(find.text('Meses'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MonthsScreen), findsOneWidget);
    expect(find.text('Nenhum mês ainda'), findsOneWidget);
    expect(find.byType(TodayScreen, skipOffstage: false), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a month opens above the shell and back returns to the tab it was opened from', (tester) async {
    await open(tester);
    await tester.tap(find.text('Meses'));
    await tester.pump(const Duration(seconds: 1));

    openMonthWith(navigatorKey.currentState!, 2026, 11);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MonthScreen), findsOneWidget);
    // The server has no such month, so the screen offers to create it.
    expect(find.text('Novembro 2026 ainda não existe'), findsOneWidget);

    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MonthScreen), findsNothing);
    expect(find.byType(MonthsScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Ajustes shows the account and signs out', (tester) async {
    final requests = await open(tester);
    await tester.tap(find.text('Ajustes'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('a@b.c'), findsOneWidget);

    await tester.tap(find.text('Sair'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(Session.instance.signedIn, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sua sessão expirou'), findsNothing);
    expect(requests, contains('/api/sessions/current'));

    await tester.pumpWidget(const SizedBox());
  });
}
