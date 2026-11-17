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
import 'package:maimoni/state/session.dart';

http.Response json(Object? body, {int status = 200, Map<String, String> headers = const {}}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Session.instance.clear();
  });

  testWidgets('the drawer shows the email and signs out', (tester) async {
    final requests = <String>[];
    Api.instance.httpClient = MockClient((request) async {
      requests.add(request.url.path);
      if (request.url.path == '/api/months') return json([]);
      if (request.url.path == '/api/auth/sign-out') return json({'success': true});
      return json({'error': 'Not found'}, status: 404);
    });
    Session.instance.setToken('t');
    Session.instance.setUser(const SessionUser(name: 'A', email: 'a@b.c'));
    await tester.pumpWidget(const MaimoniApp());
    await tester.pump(const Duration(seconds: 1));

    tester.firstState<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('a@b.c'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);

    await tester.tap(find.text('Sair'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(Session.instance.signedIn, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sua sessão expirou'), findsNothing);
    expect(requests, contains('/api/auth/sign-out'));

    await tester.pumpWidget(const SizedBox());
  });
}
