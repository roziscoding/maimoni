import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maimoni/api/client.dart';
import 'package:maimoni/routes.dart';
import 'package:maimoni/screens/template_screen.dart';
import 'package:maimoni/state/currencies_store.dart';
import 'package:maimoni/state/session.dart';
import 'package:maimoni/theme.dart';

http.Response json(Object? body, {int status = 200}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, Object?> _item(String name) =>
    {'id': 'i1', 'name': name, 'currency': 'EUR', 'kind': 'expense', 'amount': 950, 'expression': null, 'variable': false, 'position': 0};

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Session.instance.clear();
    CurrenciesStore.instance.reset();
    shellTab.value = AppTab.template;
  });

  testWidgets('a reload that started before a save does not put the old item back', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The first read answers at once; the ones after it wait to be answered by the test.
    final reads = <Completer<http.Response>>[];
    var first = true;
    Api.instance.httpClient = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/template') {
        if (first) {
          first = false;
          return json({
            'items': [_item('Aluguel')],
          });
        }
        reads.add(Completer());
        return reads.last.future;
      }
      if (path == '/api/template/items/i1') return json(_item('Aluguel novo'));
      if (path == '/api/settings/currencies') {
        return json([
          {'currency': 'EUR', 'enabled': true, 'main': true, 'inUse': true},
        ]);
      }
      return json({'error': 'Not found'}, status: 404);
    });
    Session.instance.setToken('t');
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const TemplateScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Aluguel'), findsOneWidget);

    // Coming back to the tab starts a reload, which stays in flight.
    shellTab.value = AppTab.months;
    shellTab.value = AppTab.template;
    await tester.pump();
    expect(reads, hasLength(1));

    await tester.tap(find.text('Aluguel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Aluguel'), 'Aluguel novo');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Aluguel novo'), findsOneWidget);

    // The reload answers with what the server had before the save.
    reads.single.complete(json({
      'items': [_item('Aluguel')],
    }));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Aluguel novo'), findsOneWidget);
    expect(find.text('Aluguel'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
