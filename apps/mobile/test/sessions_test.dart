import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:maimoni/api/client.dart';
import 'package:maimoni/format.dart';
import 'package:maimoni/screens/settings_screen.dart';
import 'package:maimoni/state/session.dart';
import 'package:maimoni/theme.dart';

http.Response json(Object? body, {int status = 200}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, Object?> _session(String id, String userAgent, {bool current = false}) =>
    {'id': id, 'current': current, 'userAgent': userAgent, 'ipAddress': '203.0.113.7', 'createdAt': '2026-11-01T10:00:00.000Z'};

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('pt_BR');
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Session.instance.clear();
  });

  test('names the device behind a user agent', () {
    expect(deviceLabel('maimoni-app (android)'), 'App maimoni no Android');
    expect(deviceLabel('maimoni-app (iOS)'), 'App maimoni no iPhone');
    expect(deviceLabel('Dart/3.9 (dart:io)'), 'App maimoni');
    expect(
      deviceLabel('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36'),
      'Chrome no Linux',
    );
    expect(
      deviceLabel('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/19.0 Safari/605.1.15'),
      'Safari no macOS',
    );
    expect(deviceLabel(null), 'Dispositivo desconhecido');
  });

  test('requests name the app in the user agent', () async {
    String? userAgent;
    Api.instance.httpClient = MockClient((request) async {
      userAgent = request.headers['user-agent'];
      return json([]);
    });
    await Api.instance.sessions();
    expect(userAgent, startsWith('maimoni-app ('));
  });

  testWidgets('settings lists the sessions and ends another one', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final ended = <String>[];
    Api.instance.httpClient = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/template') return json({'items': [], 'settings': {'wiseFee': 0.039}});
      if (path == '/api/sessions' && request.method == 'GET') {
        return json([
          _session('s1', 'maimoni-app (android)', current: true),
          if (!ended.contains('s2')) _session('s2', 'Mozilla/5.0 (X11; Linux x86_64) Chrome/142.0.0.0 Safari/537.36'),
        ]);
      }
      if (path.startsWith('/api/sessions/') && request.method == 'DELETE') {
        ended.add(path.split('/').last);
        return http.Response('', 204);
      }
      return json({'error': 'Not found'}, status: 404);
    });
    Session.instance.setToken('t');
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const SettingsScreen()));
    // The section appears with the settings, then loads its own list.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('App maimoni no Android · esta sessão'), findsOneWidget);
    expect(find.text('Chrome no Linux'), findsOneWidget);
    // Only the other session can be ended from here.
    expect(find.text('Encerrar'), findsOneWidget);

    await tester.tap(find.text('Encerrar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(ended, ['s2']);
    expect(find.text('Chrome no Linux'), findsNothing);
    expect(find.text('Encerrar todas as outras'), findsNothing);

    // Lets the toast's timer run out.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox());
  });
}
