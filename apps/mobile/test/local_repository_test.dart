import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maimoni/api/client.dart';
import 'package:maimoni/api/models.dart';
import 'package:maimoni/data/database.dart';
import 'package:maimoni/data/local_rates.dart';
import 'package:maimoni/data/local_repository.dart';

const eur = Currency('EUR');
const brl = Currency('BRL');

LocalDatabase memoryDatabase() => LocalDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

http.Response json(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// Frankfurter's answer quoting every currency at [rate].
http.Response frankfurter(Uri url, double rate) =>
    json({'rates': {for (final code in url.queryParameters['symbols']!.split(',')) code: rate}});

void main() {
  late LocalDatabase db;
  late LocalRepository repository;
  var offline = false;

  setUp(() {
    offline = false;
    db = memoryDatabase();
    final client = MockClient((request) async {
      if (offline) throw const SocketException('offline');
      return frankfurter(request.url, 6);
    });
    repository = LocalRepository(db, rates: LocalRates(db, client: client));
  });
  tearDown(() => db.close());

  group('export', () {
    // The same file the shared schema test and the server's export are held to.
    final fixture = jsonDecode(File('../../packages/shared/src/export.fixture.json').readAsStringSync()) as Map<String, dynamic>;

    test('importing the fixture and exporting it again gives the same file', () async {
      await repository.replaceAll(fixture);

      final exported = await repository.export();

      expect({...exported, 'exportedAt': fixture['exportedAt']}, fixture);
    });

    test('a file that is not an export is refused and leaves the data as it was', () async {
      await repository.addCurrency(eur);

      await expectLater(repository.replaceAll({'format': 'something-else'}), throwsA(isA<ApiException>()));
      await expectLater(repository.replaceAll({...fixture, 'months': 'nope'}), throwsA(isA<ApiException>()));

      expect((await repository.currencies()).map((row) => row.currency), [eur]);
    });
  });

  test('the first currency is the main one, and one in use cannot be removed', () async {
    await repository.addCurrency(eur);
    await repository.addCurrency(brl);
    await repository.addTemplateItem({'name': 'Aluguel', 'currency': 'BRL', 'amount': 1000});

    final currencies = await repository.currencies();
    expect([for (final row in currencies) (row.currency, row.main, row.inUse)], [(eur, true, false), (brl, false, true)]);
    await expectLater(repository.deleteCurrency(brl), throwsA(isA<ApiException>()));
    await expectLater(repository.deleteCurrency(eur), throwsA(isA<ApiException>()));
  });

  test('a month copied from the previous one resets paid and flags variable items again', () async {
    await repository.addCurrency(eur);
    final rent = await repository.addTemplateItem({'name': 'Aluguel', 'currency': 'EUR', 'amount': 900});
    final power = await repository.addTemplateItem({'name': 'Luz', 'currency': 'EUR', 'variable': true});
    await repository.createMonth(2026, 10, 'template');
    final october = await repository.month(2026, 10);
    expect([for (final item in october.items) (item.templateItemId, item.needsReview)], [(rent.id, false), (power.id, true)]);
    for (final item in october.items) {
      await repository.updateItem(2026, 10, item.id, {'amount': 50, 'paid': true});
    }

    await repository.createMonth(2026, 11, 'previous');

    final november = await repository.month(2026, 11);
    expect([for (final item in november.items) (item.name, item.amount, item.paid, item.needsReview)], [('Aluguel', 50, false, false), ('Luz', 50, false, true)]);
    expect(november.rates?.rates[const Currency('BRL')], 6);
  });

  test('typing an amount confirms the item and drops its expression', () async {
    await repository.addCurrency(eur);
    await repository.addTemplateItem({'name': 'Luz', 'currency': 'EUR', 'amount': 3, 'expression': '1+2', 'variable': true});
    await repository.createMonth(2026, 10, 'template');
    final item = (await repository.month(2026, 10)).items.single;

    final saved = await repository.updateItem(2026, 10, item.id, {'amount': 80.456});

    expect((saved.amount, saved.expression, saved.needsReview), (80.46, null, false));
  });

  test('without a connection, the last rates are served as stale', () async {
    await repository.addCurrency(eur);
    final fresh = await repository.liveRates();
    expect((fresh.stale, fresh.source), (false, RateSource.frankfurter));

    offline = true;
    final now = DateTime.now().add(const Duration(days: 1));
    final client = MockClient((_) async => throw const SocketException('offline'));
    final rates = await LocalRates(db, client: client, now: () => now).get(eur);

    expect((rates.stale, rates.source, rates.rates[brl]), (true, RateSource.cache, 6));
  });
}
