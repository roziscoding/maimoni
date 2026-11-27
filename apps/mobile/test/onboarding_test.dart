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
import 'package:maimoni/main.dart';
import 'package:maimoni/routes.dart';
import 'package:maimoni/screens/home_shell.dart';
import 'package:maimoni/screens/onboarding_screen.dart';
import 'package:maimoni/screens/welcome_screen.dart';
import 'package:maimoni/state/currencies_store.dart';
import 'package:maimoni/state/months_store.dart';
import 'package:maimoni/state/session.dart';

http.Response json(Object? body, {int status = 200}) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// A server that keeps what the setup saves: the currencies, the template's items and the months.
class FakeServer {
  FakeServer({List<Map<String, dynamic>>? currencies}) : currencies = currencies ?? [];

  List<Map<String, dynamic>> currencies;
  final items = <Map<String, dynamic>>[];
  final months = <Map<String, dynamic>>[];

  /// Every request, as `METHOD /path`.
  final requests = <String>[];

  /// The body of the request that marked the user as onboarded, once it was made.
  Object? updateUser;

  Future<http.Response> serve(http.Request request) async {
    final path = request.url.path.replaceFirst('/api', '');
    final body = request.body.isEmpty ? null : jsonDecode(request.body);
    requests.add('${request.method} $path');
    switch ((request.method, path)) {
      case ('GET', '/settings/currencies'):
        return json(currencies);
      case ('PUT', '/settings/currencies'):
        currencies = [
          for (final entry in (body['currencies'] as List).cast<Map<String, dynamic>>())
            {'currency': entry['currency'], 'enabled': entry['enabled'], 'main': entry['currency'] == body['main'], 'inUse': false},
        ];
        return json(currencies);
      case ('GET', '/template'):
        return json({'items': items});
      case ('POST', '/template/items'):
        items.add({'id': 'i${items.length}', 'variable': false, 'position': items.length, ...(body as Map<String, dynamic>)});
        return json(items.last, status: 201);
      case ('GET', '/rates/live'):
        return json({'base': 'BRL', 'rates': <String, double>{}, 'source': 'frankfurter', 'fetchedAt': '2026-11-01T00:00:00.000Z', 'stale': false});
      case ('GET', '/months'):
        return json(months);
      case ('POST', '/months'):
        return json({}, status: 201);
      case ('POST', '/auth/update-user'):
        updateUser = body;
        return json({'status': true});
      default:
        return json({'error': 'Not found'}, status: 404);
    }
  }
}

void main() {
  /// This month's name as the setup writes it, known once the date formats are loaded.
  late final String month;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('pt_BR');
    month = monthName(DateTime.now().month).toLowerCase();
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Session.instance.clear();
    MonthsStore.instance.reset();
    CurrenciesStore.instance.reset();
    shellTab.value = AppTab.today;
    spendRequested.value = false;
  });

  Future<FakeServer> open(WidgetTester tester, {bool onboarded = false, FakeServer? server}) async {
    // The region the device is set to, which the setup suggests a currency from.
    tester.platformDispatcher.localeTestValue = const Locale('pt', 'BR');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final fake = server ?? FakeServer();
    Api.instance.httpClient = MockClient(fake.serve);
    Session.instance.setToken('t');
    Session.instance.setUser(SessionUser(name: 'Ana Souza', email: 'ana@example.com', onboarded: onboarded));
    await tester.pumpWidget(const MaimoniApp());
    await tester.pump(const Duration(seconds: 1));
    return fake;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  test('a user from a server without the field counts as onboarded', () {
    expect(SessionUser.fromJson({'name': 'A', 'email': 'a@b.c'}).onboarded, isTrue);
    expect(SessionUser.fromJson({'name': 'A', 'email': 'a@b.c', 'onboarded': false}).onboarded, isFalse);
  });

  testWidgets('a user who is onboarded opens the app, and one who is not opens the setup', (tester) async {
    await open(tester, onboarded: true);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);

    // The session check comes back saying the user still has the setup to go through.
    Session.instance.setUser(const SessionUser(name: 'Ana Souza', email: 'ana@example.com', onboarded: false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
    expect(find.text('Boas-vindas ao maimoni'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the setup saves the currencies and the items, creates the month and opens the app from its last screen', (tester) async {
    final server = await open(tester);
    await tap(tester, 'Começar');

    // The currency of the device's region comes marked, so the question is answered as it opens.
    expect(find.text('Quais moedas você usa?'), findsOneWidget);
    expect(find.text('A moeda da região do seu aparelho'), findsOneWidget);
    await tap(tester, 'Continuar');
    // With a single currency there is no main one to ask about.
    expect(find.text('Qual delas é a principal?'), findsNothing);
    expect(server.currencies, [
      {'currency': 'BRL', 'enabled': true, 'main': true, 'inUse': false},
    ]);

    expect(find.text('O que entra todo mês?'), findsOneWidget);
    await tap(tester, 'Salário');
    await tester.enterText(find.byType(TextField).last, '5000');
    await tap(tester, 'Adicionar');
    expect(server.items.single, containsPair('name', 'Salário'));
    expect(server.items.single, containsPair('kind', 'income'));
    expect(server.items.single, containsPair('amount', 5000));
    expect(server.items.single, containsPair('currency', 'BRL'));
    // A name already on the list isn't offered again.
    expect(find.widgetWithText(ActionChip, 'Salário'), findsNothing);
    await tap(tester, 'Continuar');

    expect(find.text('E o que sai todo mês?'), findsOneWidget);
    await tap(tester, 'Pular');

    expect(find.text('Em $month, você pode gastar'), findsOneWidget);
    expect(find.text('por dia'), findsOneWidget);
    await tap(tester, 'Criar $month');
    expect(server.requests, containsAllInOrder(['POST /months', 'POST /auth/update-user']));
    expect(server.updateUser, {'onboarded': true});
    expect(Session.instance.onboarded, isTrue);

    // Recorded as finished, and still on the setup: leaving it is the button's doing.
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Tudo pronto, Ana'), findsOneWidget);
    await tap(tester, 'Registrar um gasto');
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with two currencies the setup asks which is the main one', (tester) async {
    final server = await open(tester);
    await tap(tester, 'Começar');
    await tap(tester, 'Euro');
    await tap(tester, 'Continuar');

    expect(find.text('Qual delas é a principal?'), findsOneWidget);
    await tap(tester, 'Euro');
    await tap(tester, 'Continuar');
    expect(server.currencies, [
      {'currency': 'BRL', 'enabled': true, 'main': false, 'inUse': false},
      {'currency': 'EUR', 'enabled': true, 'main': true, 'inUse': false},
    ]);
    expect(find.text('O que entra todo mês?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a user who left after the currencies comes back to the question after them', (tester) async {
    await open(
      tester,
      server: FakeServer(currencies: [
        {'currency': 'BRL', 'enabled': true, 'main': true, 'inUse': false},
      ]),
    );
    expect(find.text('O que entra todo mês?'), findsOneWidget);
    expect(find.text('Boas-vindas ao maimoni'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('finishing without the month leaves it for later', (tester) async {
    final server = await open(
      tester,
      server: FakeServer(currencies: [
        {'currency': 'BRL', 'enabled': true, 'main': true, 'inUse': false},
      ]),
    );
    await tap(tester, 'Pular');
    await tap(tester, 'Pular');
    expect(find.text('Criar o mês de $month?'), findsOneWidget);
    await tap(tester, 'Agora não');
    expect(server.requests, isNot(contains('POST /months')));
    expect(server.updateUser, {'onboarded': true});
    await tap(tester, 'Abrir o maimoni');
    expect(find.byType(HomeShell), findsOneWidget);
    expect(spendRequested.value, isFalse);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('signing out from the setup goes to the welcome screen', (tester) async {
    await open(tester);
    await tap(tester, 'Sair');
    expect(Session.instance.signedIn, isFalse);
    expect(find.byType(WelcomeScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
