import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:maimoni/api/client.dart';
import 'package:maimoni/api/models.dart';
import 'package:maimoni/domain/expression.dart';
import 'package:maimoni/domain/summary.dart';
import 'package:maimoni/format.dart';
import 'package:maimoni/screens/settings_screen.dart';
import 'package:maimoni/screens/template_screen.dart';
import 'package:maimoni/state/currencies_store.dart';
import 'package:maimoni/state/month_controller.dart';
import 'package:maimoni/state/session.dart';
import 'package:maimoni/theme.dart';
import 'package:maimoni/widgets/spends.dart';

http.Response json(Object? body, {int status = 200}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, Object?> _currency(String code, {bool enabled = true, bool main = false, bool inUse = false}) =>
    {'currency': code, 'enabled': enabled, 'main': main, 'inUse': inUse};

/// `formatMoney` without the non-breaking space `intl` puts after the symbol.
String _money(double? value, Currency currency) => formatMoney(value, currency).replaceAll(' ', ' ');

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('pt_BR');
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Session.instance.clear();
    CurrenciesStore.instance.reset();
  });

  group('models', () {
    test('reads a month in the shape the server answers with', () {
      final detail = MonthDetail.fromJson({
        'month': {
          'id': 'm1',
          'year': 2026,
          'month': 10,
          'mainCurrency': 'EUR',
          'lockedRates': {'BRL': 6},
          'activeDay': null,
          'note': null,
          'createdAt': '2026-10-01T00:00:00.000Z',
        },
        'items': [],
        'spends': [],
        'summary': {},
        'rates': {
          'base': 'EUR',
          'rates': {'BRL': 5.868553, 'USD': 1.1},
          'source': 'frankfurter',
          'fetchedAt': '2026-10-01T00:00:00.000Z',
          'stale': false,
        },
        'rateError': null,
      });
      expect(detail.month.mainCurrency, Currency.eur);
      expect(detail.month.lockedRates, {Currency.brl: 6});
      expect(detail.rates!.rates[const Currency('USD')], 1.1);
      // A patch replaces the whole map, the way the server does.
      expect(detail.month.patch({'lockedRates': <String, double>{}}).lockedRates, isEmpty);
    });

    test('a currency the app does not know still parses, and sorts last', () {
      final unknown = Currency.parse('XTS');
      expect(unknown.code, 'XTS');
      expect(Currency.sorted([unknown, const Currency('USD'), Currency.brl, Currency.brl]), [Currency.brl, const Currency('USD'), unknown]);
      expect(_money(10, unknown), 'XTS 10,00');
      expect(currencyName(unknown), 'XTS');
    });
  });

  group('format', () {
    test('writes each currency the way pt-BR does', () {
      expect(_money(1250.99, Currency.brl), r'R$ 1.250,99');
      expect(_money(45, Currency.eur), '€ 45,00');
      expect(_money(10, const Currency('USD')), r'US$ 10,00');
      expect(_money(10, const Currency('CHF')), 'CHF 10,00');
      expect(_money(null, Currency.eur), '—');
      expect(signedMoney(-8, Currency.brl).replaceAll(' ', ' '), r'−R$ 8,00');
    });

    test('a currency without minor units shows no decimals', () {
      expect(_money(1234.5, const Currency('JPY')), 'JP¥ 1.235');
      expect(_money(1000, const Currency('KRW')), '₩ 1.000');
    });

    test('a rate has 4 decimals, or 4 significant digits below one', () {
      expect(formatRate(5.868553, Currency.brl), r'R$ 5,8686');
      expect(formatRate(0.17, Currency.eur), '€ 0,1700');
      expect(formatRate(0.00005512, Currency.eur), '€ 0,00005512');
      expect(formatRate(null, Currency.eur), '—');
    });

    test('names the currencies', () {
      expect(currencyName(Currency.brl), 'Real brasileiro');
      expect(currencyPlural(Currency.brl), 'Reais brasileiros');
      expect(currencySymbol(Currency.eur), '€');
      // Every currency the server offers has a name here.
      expect(Currency.all.where((currency) => currencyName(currency) == currency.code), isEmpty);
    });
  });

  group('CurrenciesStore', () {
    test('offers the enabled ones and keeps showing the ones with history', () async {
      Api.instance.httpClient = MockClient((request) async => json([
            _currency('EUR', main: true),
            _currency('USD', enabled: false, inUse: true),
            _currency('BRL'),
          ]));
      final store = CurrenciesStore.instance;
      await store.refresh();
      expect(store.offered, [Currency.brl, Currency.eur]);
      expect(store.main, Currency.eur);
      expect(store.none, isFalse);
      expect(store.shown([const Currency('USD')]), [Currency.brl, Currency.eur, const Currency('USD')]);
    });

    test('offers every currency when the list could not be loaded', () async {
      Api.instance.httpClient = MockClient((request) async => json({'error': 'boom'}, status: 500));
      final store = CurrenciesStore.instance;
      await store.refresh();
      expect(store.loaded, isTrue);
      expect(store.list, isNull);
      expect(store.offered, Currency.all);
    });

    test('a read that started before a change does not overwrite it', () async {
      final answer = Completer<http.Response>();
      Api.instance.httpClient = MockClient((request) => answer.future);
      final store = CurrenciesStore.instance;
      final stale = store.refresh();
      store.replace([UserCurrency.fromJson(_currency('BRL', main: true))]);
      answer.complete(json([_currency('EUR', main: true)]));
      await stale;
      expect(store.main, Currency.brl);
    });

    test('a reload after a change does not reuse a read from before it', () async {
      final answers = <Completer<http.Response>>[];
      Api.instance.httpClient = MockClient((request) {
        answers.add(Completer());
        return answers.last.future;
      });
      final store = CurrenciesStore.instance;
      final stale = store.refresh();
      final fresh = store.reload();
      await Future<void>.delayed(Duration.zero);
      expect(answers, hasLength(2));
      // The dropped read ending first leaves the new one as the read to share.
      answers.first.complete(json([_currency('EUR', main: true)]));
      await stale;
      final shared = store.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(answers, hasLength(2));
      answers.last.complete(json([_currency('EUR', main: true), _currency('JPY')]));
      await fresh;
      await shared;
      expect(store.offered, [Currency.eur, const Currency('JPY')]);
    });

    test('a user without currencies has nothing to offer', () async {
      Api.instance.httpClient = MockClient((request) async => json([]));
      final store = CurrenciesStore.instance;
      await store.refresh();
      expect(store.none, isTrue);
      expect(store.main, isNull);
    });
  });

  group('spend form', () {
    Future<List<Map<String, dynamic>>> pump(WidgetTester tester, List<Map<String, Object?>> currencies) async {
      CurrenciesStore.instance.replace([for (final row in currencies) UserCurrency.fromJson(row)]);
      final sent = <Map<String, dynamic>>[];
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SpendForm(
            day: 3,
            create: (body) async {
              sent.add(body);
              return null;
            },
          ),
        ),
      ));
      return sent;
    }

    testWidgets('with one currency there is nothing to pick', (tester) async {
      final sent = await pump(tester, [_currency('EUR', main: true)]);
      expect(find.text('€'), findsNothing);
      await tester.enterText(find.byType(TextField).first, '4,50');
      await tester.pump();
      await tester.tap(find.text('Lançar'));
      await tester.pump();
      expect(sent.single['currency'], 'EUR');
      expect(sent.single['amount'], 4.5);
    });

    testWidgets('with two currencies a tap swaps them', (tester) async {
      final sent = await pump(tester, [_currency('EUR', main: true), _currency('BRL')]);
      // Starts in the main one.
      expect(find.text('€'), findsOneWidget);
      await tester.tap(find.text('€'));
      await tester.pump();
      expect(find.text(r'R$'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '10');
      await tester.pump();
      await tester.tap(find.text('Lançar'));
      await tester.pump();
      expect(sent.single['currency'], 'BRL');
    });

    testWidgets('with more it opens the list', (tester) async {
      final sent = await pump(tester, [_currency('EUR', main: true), _currency('BRL'), _currency('USD')]);
      await tester.tap(find.text('€'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dólar americano'));
      await tester.pumpAndSettle();
      expect(find.text(r'US$'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '10');
      await tester.pump();
      await tester.tap(find.text('Lançar'));
      await tester.pump();
      expect(sent.single['currency'], 'USD');
    });
  });

  group('rate locks', () {
    /// Serves one month. A PATCH applies at once and answers with the month as it was then, but only
    /// when the test completes its entry in the returned list.
    ({List<Map<String, dynamic>> patches, List<Completer<void>> answers}) serve() {
      final month = <String, Object?>{
        'id': 'm1',
        'year': 2026,
        'month': 10,
        'mainCurrency': 'EUR',
        'lockedRates': <String, Object?>{},
        'activeDay': null,
        'note': null,
        'createdAt': '2026-10-01T00:00:00.000Z',
      };
      Map<String, Object?> detail() =>
          {'month': Map.of(month), 'items': [], 'spends': [], 'summary': {}, 'rates': null, 'rateError': null};
      final patches = <Map<String, dynamic>>[];
      final answers = <Completer<void>>[];
      Api.instance.httpClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/settings/currencies') return json([_currency('EUR', main: true), _currency('BRL'), _currency('USD')]);
        if (path == '/api/months/2026/10' && request.method == 'GET') return json(detail());
        if (path == '/api/months/2026/10' && request.method == 'PATCH') {
          final patch = jsonDecode(request.body) as Map<String, dynamic>;
          patches.add(patch);
          month.addAll(patch);
          final answer = detail();
          final gate = Completer<void>();
          answers.add(gate);
          await gate.future;
          return json(answer);
        }
        return json({'error': 'Not found'}, status: 404);
      });
      return (patches: patches, answers: answers);
    }

    Future<MonthController> open(WidgetTester tester) async {
      Session.instance.setToken('t');
      final controller = MonthController(2026, 10);
      await tester.pump();
      await tester.pump();
      expect(controller.data, isNotNull);
      return controller;
    }

    testWidgets('overlapping locks are saved one after another, each keeping the other', (tester) async {
      final (:patches, :answers) = serve();
      final controller = await open(tester);

      final first = controller.lockRate(Currency.brl, 6);
      final second = controller.lockRate(const Currency('USD'), 1.1);
      await tester.pump();
      // The second waits for the first to be saved.
      expect(patches, [
        {'lockedRates': {'BRL': 6.0}},
      ]);
      answers.first.complete();
      await tester.pump();
      await tester.pump();
      expect(patches.last, {
        'lockedRates': {'BRL': 6.0, 'USD': 1.1},
      });
      answers.last.complete();
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(controller.data!.month.lockedRates, {Currency.brl: 6, const Currency('USD'): 1.1});
      // Before the test ends, which fails on the controller's pending rate timer.
      controller.dispose();
    });

    testWidgets('a note answered after a lock does not put back the old locked rates', (tester) async {
      final (:patches, :answers) = serve();
      final controller = await open(tester);

      final note = controller.updateMonth({'note': 'trip'});
      await tester.pump();
      final lock = controller.lockRate(Currency.brl, 6);
      await tester.pump();
      expect(patches, hasLength(2));
      answers.last.complete();
      expect(await lock, isTrue);
      // The note's answer was made before the lock, so its locked rates are empty.
      answers.first.complete();
      expect(await note, isTrue);
      expect(controller.data!.month.note, 'trip');
      expect(controller.data!.month.lockedRates, {Currency.brl: 6});
      controller.dispose();
    });
  });

  group('template preview', () {
    Future<void> open(WidgetTester tester, {required bool rates}) async {
      tester.view.physicalSize = const Size(1200, 40000); // Tall enough for a section per known currency.
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Session.instance.setToken('t');
      Api.instance.httpClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/template') {
          return json({
            'items': [
              {'id': 'i1', 'name': 'Salary', 'currency': 'USD', 'kind': 'income', 'amount': 3000, 'expression': null, 'variable': false, 'position': 0},
            ],
          });
        }
        if (path == '/api/rates/live' && rates) {
          return json({'base': 'USD', 'rates': {'EUR': 0.9}, 'source': 'frankfurter', 'fetchedAt': '2026-10-01T00:00:00.000Z', 'stale': false});
        }
        return json({'error': 'boom'}, status: 500);
      });
      await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const TemplateScreen()));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('without the currency list it is worked out in the base of the live rates', (tester) async {
      await open(tester, rates: true);
      final next = DateTime(DateTime.now().year, DateTime.now().month + 1);
      final days = daysInMonth(next.year, next.month);
      expect(find.text('Por dia, em $days dias'), findsOneWidget);
      expect(find.text(formatMoney(round2(3000 / days), const Currency('USD'))), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('without the list or the rates there is no preview', (tester) async {
      await open(tester, rates: false);
      expect(find.text('O ponto de partida de todo mês'), findsOneWidget);
      expect(find.text('Prévia de um mês novo'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('settings', () {
    /// Serves the currency routes over [currencies], and `/flags` with [purge].
    List<String> serve(List<Map<String, Object?>> currencies, {bool purge = false}) {
      final calls = <String>[];
      Api.instance.httpClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/flags') return json({'purge': purge});
        if (path == '/api/sessions') return json([]);
        if (path == '/api/settings/currencies' && request.method == 'GET') return json(currencies);
        if (path == '/api/settings/currencies' && request.method == 'POST') {
          final code = (jsonDecode(request.body) as Map)['currency'] as String;
          calls.add('POST $code');
          currencies.add(_currency(code));
          return json(currencies.last, status: 201);
        }
        if (path.startsWith('/api/settings/currencies/')) {
          final code = path.split('/').last;
          final row = currencies.firstWhere((row) => row['currency'] == code);
          if (request.method == 'DELETE') {
            calls.add('DELETE $code');
            currencies.remove(row);
            return http.Response('', 204);
          }
          final patch = jsonDecode(request.body) as Map<String, dynamic>;
          calls.add('PATCH $code ${request.body}');
          if (patch['main'] == true) {
            for (final other in currencies) {
              other['main'] = false;
            }
          }
          row.addAll(patch);
          return json(currencies);
        }
        return json({'error': 'Not found'}, status: 404);
      });
      return calls;
    }

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Session.instance.setToken('t');
      await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const SettingsScreen()));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('the main currency cannot be disabled or removed, and says why', (tester) async {
      final calls = serve([_currency('EUR', main: true), _currency('BRL', inUse: true)]);
      await open(tester);
      expect(find.text('Euro'), findsOneWidget);
      expect(find.text('Principal'), findsOneWidget);

      await tester.tap(find.text('Euro'));
      await tester.pumpAndSettle();
      expect(find.text('A moeda principal não pode ser desativada.'), findsOneWidget);
      expect(find.text('A moeda principal não pode ser removida.'), findsOneWidget);
      expect(find.text('Definir como principal'), findsNothing);
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();
      expect(find.text('Remover Euro?'), findsNothing);
      expect(calls, isEmpty);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a currency in use can be disabled, not removed', (tester) async {
      final calls = serve([_currency('EUR', main: true), _currency('BRL', inUse: true)]);
      await open(tester);

      await tester.tap(find.text('Real brasileiro'));
      await tester.pumpAndSettle();
      expect(find.text('Real brasileiro possui itens ou gastos registrados.'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(calls, ['PATCH BRL {"enabled":false}']);
      // The list behind the sheet follows.
      expect(find.text('Desativada'), findsOneWidget);
      // Disabled, it can't become the main one.
      expect(find.text('Definir como principal'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('makes another currency the main one, removes one and adds one', (tester) async {
      final calls = serve([_currency('EUR', main: true), _currency('BRL'), _currency('USD')]);
      await open(tester);

      await tester.tap(find.text('Real brasileiro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Definir como principal'));
      await tester.pumpAndSettle();
      expect(calls, ['PATCH BRL {"main":true}']);
      expect(find.text('Moeda principal'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dólar americano'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover moeda'));
      await tester.pumpAndSettle();
      expect(calls.last, 'DELETE USD');
      expect(find.text('Dólar americano'), findsNothing);

      await tester.tap(find.text('Adicionar moeda'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'iene');
      await tester.pumpAndSettle();
      expect(find.text('Dólar americano'), findsNothing);
      await tester.tap(find.text('Iene japonês'));
      await tester.pumpAndSettle();
      expect(calls.last, 'POST JPY');
      expect(find.text('Iene japonês'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the danger zone only shows when the server serves the purge', (tester) async {
      serve([_currency('EUR', main: true)]);
      await open(tester);
      expect(find.text('Zona de perigo'), findsNothing);

      serve([_currency('EUR', main: true)], purge: true);
      await tester.pumpWidget(const SizedBox());
      await open(tester);
      expect(find.text('Zona de perigo'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
