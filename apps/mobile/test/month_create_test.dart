import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:maimoni/api/client.dart';
import 'package:maimoni/api/models.dart';
import 'package:maimoni/state/currencies_store.dart';
import 'package:maimoni/state/months_store.dart';
import 'package:maimoni/theme.dart';
import 'package:maimoni/widgets/month_create.dart';

http.Response json(Object? body, {int status = 200}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

UserCurrency currency(String code, {bool main = false}) =>
    UserCurrency(currency: Currency.parse(code), enabled: true, main: main, inUse: false);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('pt_BR');
  });

  setUp(() {
    MonthsStore.instance.reset();
    CurrenciesStore.instance.reset();
  });

  /// Opens the new month sheet and answers what it sends to `POST /months`.
  Future<List<Map<String, dynamic>>> openSheet(WidgetTester tester) async {
    final created = <Map<String, dynamic>>[];
    Api.instance.httpClient = MockClient((request) async {
      if (request.url.path == '/api/months' && request.method == 'POST') {
        created.add(jsonDecode(request.body) as Map<String, dynamic>);
        return json({}, status: 201);
      }
      if (request.url.path == '/api/months') return json([]);
      return json({'error': 'Not found'}, status: 404);
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(body: TextButton(onPressed: () => showNewMonthSheet(context), child: const Text('Abrir'))),
      ),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    return created;
  }

  testWidgets('the new month goes in the main currency until another is picked by name', (tester) async {
    CurrenciesStore.instance.replace([currency('EUR', main: true), currency('BRL')]);
    final created = await openSheet(tester);

    expect(find.text('Moeda do mês'), findsOneWidget);
    expect(find.text('Sua moeda principal'), findsOneWidget);
    await tester.tap(find.text('Real brasileiro'));
    await tester.pump();
    await tester.tap(find.text('Criar do template'));
    await tester.pump(const Duration(seconds: 1));

    expect(created.single, containsPair('mainCurrency', 'BRL'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with a single currency there is nothing to choose', (tester) async {
    CurrenciesStore.instance.replace([currency('BRL', main: true)]);
    final created = await openSheet(tester);

    expect(find.text('Moeda do mês'), findsNothing);
    await tester.tap(find.text('Criar do template'));
    await tester.pump(const Duration(seconds: 1));

    expect(created.single, containsPair('mainCurrency', 'BRL'));
    await tester.pumpWidget(const SizedBox());
  });
}
