import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:maimoni/data/local_rates.dart';
import 'package:maimoni/data/local_repository.dart';
import 'package:maimoni/main.dart';
import 'package:maimoni/routes.dart';
import 'package:maimoni/screens/login_screen.dart';
import 'package:maimoni/screens/onboarding_screen.dart';
import 'package:maimoni/screens/welcome_screen.dart';
import 'package:maimoni/state/currencies_store.dart';
import 'package:maimoni/state/local_mode.dart';
import 'package:maimoni/state/months_store.dart';
import 'package:maimoni/state/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_repository_test.dart' show frankfurter, memoryDatabase;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('pt_BR');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    Session.instance.clear();
    MonthsStore.instance.reset();
    CurrenciesStore.instance.reset();
    shellTab.value = AppTab.today;
    await LocalMode.instance.reset();
    LocalMode.instance.createRepository = () {
      final db = memoryDatabase();
      return LocalRepository(db, rates: LocalRates(db, client: MockClient((request) async => frankfurter(request.url, 6))));
    };
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('using the app without an account starts the setup, and going back drops it', (tester) async {
    await tester.pumpWidget(const MaimoniApp());
    await settle(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Usar sem conta'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
    expect(LocalMode.instance.active, isTrue);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Voltar ao início'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
    expect(LocalMode.instance.active, isFalse);
    expect(find.byType(WelcomeScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('signing in from the local mode warns that the data is deleted', (tester) async {
    final fixture = jsonDecode(File('../../packages/shared/src/export.fixture.json').readAsStringSync());
    await tester.runAsync(() => LocalMode.instance.start(data: fixture));
    await tester.pumpWidget(const MaimoniApp());
    await settle(tester);
    await tester.tap(find.text('Ajustes'));
    await settle(tester);

    await tester.tap(find.text('Entrar numa conta'));
    await settle(tester);
    expect(find.textContaining('eles são apagados daqui e não dá para recuperar'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Apagar dados e entrar'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
    expect(LocalMode.instance.active, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await tester.runAsync(() => LocalMode.instance.repository.months()), isEmpty);

    await tester.pumpWidget(const SizedBox());
  });
}
