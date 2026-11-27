import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../domain/summary.dart';
import 'database.dart';
import 'local_rates.dart';
import 'repository.dart';

final _random = Random.secure();

/// A random (version 4) UUID, the same kind of id the server makes.
String newId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Rounds to cents, as the server does with every amount it receives.
double? _cents(Object? value) => value == null ? null : ((value as num) * 100).round() / 100;

String? _trimmed(Object? value) {
  final text = (value as String?)?.trim();
  return text == null || text.isEmpty ? null : text;
}

ApiException _notFound(String message) => ApiException(message, status: 404);
ApiException _refused(String message) => ApiException(message, status: 409);
ApiException _invalid(String message) => ApiException(message, status: 400);

/// The local storage mode: the user's data in a SQLite database on the device.
///
/// It keeps the server's rules (apps/backend/src/routes), so the screens can't tell the two apart.
class LocalRepository implements Repository {
  LocalRepository(this.db, {LocalRates? rates}) : _rates = rates ?? LocalRates(db);

  final LocalDatabase db;
  final LocalRates _rates;

  String _now() => DateTime.now().toUtc().toIso8601String();

  /* --------------------------------- Mappers ------------------------------- */

  Month _month(MonthRow row) => Month(
        id: row.id,
        year: row.year,
        month: row.month,
        mainCurrency: Currency.parse(row.mainCurrency),
        lockedRates: ratesFromJson(jsonDecode(row.lockedRates)),
        activeDay: row.activeDay,
        note: row.note,
        createdAt: row.createdAt,
      );

  MonthItem _item(MonthItemRow row) => MonthItem(
        id: row.id,
        monthId: row.monthId,
        templateItemId: row.templateItemId,
        name: row.name,
        currency: Currency.parse(row.currency),
        kind: EntryKind.parse(row.kind),
        amount: row.amount,
        expression: row.expression,
        paid: row.paid,
        needsReview: row.needsReview,
        position: row.position,
      );

  TemplateItem _templateItem(TemplateItemRow row) => TemplateItem(
        id: row.id,
        name: row.name,
        currency: Currency.parse(row.currency),
        kind: EntryKind.parse(row.kind),
        amount: row.amount,
        expression: row.expression,
        variable: row.variable,
        position: row.position,
      );

  DailySpend _spend(DailySpendRow row) => DailySpend(
        id: row.id,
        monthId: row.monthId,
        day: row.day,
        currency: Currency.parse(row.currency),
        amount: row.amount,
        expression: row.expression,
        note: row.note,
        createdAt: row.createdAt,
      );

  /* --------------------------------- Lookups ------------------------------- */

  Future<MonthRow?> _findMonth(int year, int month) =>
      (db.select(db.months)..where((row) => row.year.equals(year) & row.month.equals(month))).getSingleOrNull();

  Future<MonthRow> _requireMonth(int year, int month) async =>
      await _findMonth(year, month) ?? (throw _notFound('Mês não encontrado'));

  Future<List<MonthItemRow>> _items(String monthId) => (db.select(db.monthItems)
        ..where((row) => row.monthId.equals(monthId))
        ..orderBy([(row) => OrderingTerm.asc(row.position), (row) => OrderingTerm.asc(row.createdAt)]))
      .get();

  Future<List<DailySpendRow>> _spends(String monthId) => (db.select(db.dailySpends)
        ..where((row) => row.monthId.equals(monthId))
        ..orderBy([(row) => OrderingTerm.asc(row.day), (row) => OrderingTerm.asc(row.createdAt)]))
      .get();

  Future<List<TemplateItemRow>> _templateRows() => (db.select(db.templateItems)
        ..orderBy([(row) => OrderingTerm.asc(row.position), (row) => OrderingTerm.asc(row.createdAt)]))
      .get();

  Future<Currency?> _mainCurrency() async {
    final row = await (db.select(db.currencies)..where((row) => row.main.equals(true))).getSingleOrNull();
    return row == null ? null : Currency.parse(row.code);
  }

  Future<void> _requireCurrency(Object? code) async {
    if (code == null) return;
    final row = await (db.select(db.currencies)..where((row) => row.code.equals(code as String))).getSingleOrNull();
    if (row == null) throw _invalid('Essa moeda não está entre as suas');
  }

  Future<int> _nextPosition<T extends Table, R>(TableInfo<T, R> table, Expression<int> position, [Expression<bool>? where]) async {
    final max = position.max();
    final query = db.selectOnly(table)..addColumns([max]);
    if (where != null) query.where(where);
    final value = await query.map((row) => row.read(max)).getSingleOrNull();
    return (value ?? -1) + 1;
  }

  /// Rates against [base], or the reason there are none.
  Future<({LiveRates? rates, String? error})> _ratesFor(Currency base) async {
    try {
      return (rates: await _rates.get(base), error: null);
    } on ApiException catch (error) {
      return (rates: null, error: error.message);
    }
  }

  Future<MonthDetail> _detail(MonthRow row) async {
    final month = _month(row);
    final (items, spends, rates) = await (_items(row.id), _spends(row.id), _ratesFor(month.mainCurrency)).wait;
    return MonthDetail(
      month: month,
      items: items.map(_item).toList(),
      spends: spends.map(_spend).toList(),
      rates: rates.rates,
      rateError: rates.error,
    );
  }

  /* --------------------------------- Months -------------------------------- */

  @override
  Future<List<MonthListEntry>> months() async {
    final rows = await (db.select(db.months)..orderBy([(row) => OrderingTerm.desc(row.year), (row) => OrderingTerm.desc(row.month)])).get();
    final rates = <Currency, Rates?>{};
    for (final base in {for (final row in rows) Currency.parse(row.mainCurrency)}) {
      rates[base] = (await _ratesFor(base)).rates?.rates;
    }
    return [
      for (final row in rows)
        await () async {
          final month = _month(row);
          final items = (await _items(row.id)).map(_item).toList();
          final spends = (await _spends(row.id)).map(_spend).toList();
          return MonthListEntry(month: month, summary: summarizeMonth(month, items, rates: rates[month.mainCurrency], spends: spends));
        }(),
    ];
  }

  @override
  Future<MonthDetail> month(int year, int month) async => _detail(await _requireMonth(year, month));

  @override
  Future<void> createMonth(int year, int month, String source, {Currency? mainCurrency}) async {
    if (await _findMonth(year, month) != null) throw _refused('Esse mês já existe');
    if (mainCurrency != null) await _requireCurrency(mainCurrency.code);
    final template = await _templateRows();
    final List<MonthItemsCompanion Function(String monthId)> items;
    if (source == 'template') {
      items = [
        for (final item in template)
          (monthId) => MonthItemsCompanion.insert(
                id: newId(),
                monthId: monthId,
                templateItemId: Value(item.id),
                name: item.name,
                currency: item.currency,
                kind: item.kind,
                amount: Value(item.amount),
                expression: Value(item.expression),
                needsReview: Value(item.variable),
                position: item.position,
                createdAt: _now(),
              ),
      ];
    } else {
      final previous = await (db.select(db.months)
            ..where((row) => row.year.isSmallerThanValue(year) | (row.year.equals(year) & row.month.isSmallerThanValue(month)))
            ..orderBy([(row) => OrderingTerm.desc(row.year), (row) => OrderingTerm.desc(row.month)])
            ..limit(1))
          .getSingleOrNull();
      if (previous == null) throw _invalid('Não há um mês anterior para copiar');
      final variable = {for (final item in template) if (item.variable) item.id};
      items = [
        for (final item in await _items(previous.id))
          (monthId) => MonthItemsCompanion.insert(
                id: newId(),
                monthId: monthId,
                templateItemId: Value(item.templateItemId),
                name: item.name,
                currency: item.currency,
                kind: item.kind,
                amount: Value(item.amount),
                expression: Value(item.expression),
                needsReview: Value(item.templateItemId != null && variable.contains(item.templateItemId)),
                position: item.position,
                createdAt: _now(),
              ),
      ];
    }
    // The month keeps this currency: changing the main one later doesn't move it.
    final currency = mainCurrency ?? await _mainCurrency() ?? (throw _refused('Adicione uma moeda antes de criar um mês'));
    await db.transaction(() async {
      final id = newId();
      await db.into(db.months).insert(MonthsCompanion.insert(id: id, year: year, month: month, mainCurrency: currency.code, createdAt: _now()));
      await db.batch((batch) => batch.insertAll(db.monthItems, [for (final item in items) item(id)]));
    });
  }

  @override
  Future<MonthDetail> updateMonth(int year, int month, Json patch) async {
    final row = await _requireMonth(year, month);
    if (patch.isEmpty) return _detail(row);
    await (db.update(db.months)..where((month) => month.id.equals(row.id))).write(MonthsCompanion(
      lockedRates: patch.containsKey('lockedRates') ? Value(jsonEncode(patch['lockedRates'])) : const Value.absent(),
      activeDay: patch.containsKey('activeDay') ? Value(patch['activeDay'] as int?) : const Value.absent(),
      note: patch.containsKey('note') ? Value(_trimmed(patch['note'])) : const Value.absent(),
    ));
    return _detail(await _requireMonth(year, month));
  }

  @override
  Future<void> deleteMonth(int year, int month) async {
    final row = await _requireMonth(year, month);
    await (db.delete(db.months)..where((month) => month.id.equals(row.id))).go();
  }

  /* ------------------------------- Month items ----------------------------- */

  @override
  Future<MonthItem> addItem(int year, int month, Json body) async {
    final row = await _requireMonth(year, month);
    await _requireCurrency(body['currency']);
    final position = await _nextPosition(db.monthItems, db.monthItems.position, db.monthItems.monthId.equals(row.id));
    final item = await db.into(db.monthItems).insertReturning(MonthItemsCompanion.insert(
          id: newId(),
          monthId: row.id,
          name: (body['name'] as String).trim(),
          currency: body['currency'] as String,
          kind: body['kind'] as String? ?? EntryKind.expense.name,
          amount: Value(_cents(body['amount'])),
          expression: Value(_trimmed(body['expression'])),
          paid: Value(body['paid'] as bool? ?? false),
          position: position,
          createdAt: _now(),
        ));
    return _item(item);
  }

  @override
  Future<MonthItem> updateItem(int year, int month, String id, Json patch) async {
    final row = await _requireMonth(year, month);
    await _requireCurrency(patch['currency']);
    final amountChanged = patch.containsKey('amount');
    final updated = await (db.update(db.monthItems)..where((item) => item.id.equals(id) & item.monthId.equals(row.id))).writeReturning(MonthItemsCompanion(
      name: patch.containsKey('name') ? Value((patch['name'] as String).trim()) : const Value.absent(),
      currency: patch.containsKey('currency') ? Value(patch['currency'] as String) : const Value.absent(),
      kind: patch.containsKey('kind') ? Value(patch['kind'] as String) : const Value.absent(),
      amount: amountChanged ? Value(_cents(patch['amount'])) : const Value.absent(),
      paid: patch.containsKey('paid') ? Value(patch['paid'] as bool) : const Value.absent(),
      // Typing a value confirms it, and a plain amount replaces any previous expression.
      needsReview: patch.containsKey('needsReview') ? Value(patch['needsReview'] as bool) : (amountChanged ? const Value(false) : const Value.absent()),
      expression: patch.containsKey('expression') ? Value(_trimmed(patch['expression'])) : (amountChanged ? const Value(null) : const Value.absent()),
    ));
    if (updated.isEmpty) throw _notFound('Item não encontrado');
    return _item(updated.single);
  }

  @override
  Future<void> deleteItem(int year, int month, String id) async {
    final row = await _requireMonth(year, month);
    final deleted = await (db.delete(db.monthItems)..where((item) => item.id.equals(id) & item.monthId.equals(row.id))).go();
    if (deleted == 0) throw _notFound('Item não encontrado');
  }

  @override
  Future<TemplateItem> promoteItem(int year, int month, String id) async {
    final row = await _requireMonth(year, month);
    return db.transaction(() async {
      final item = await (db.select(db.monthItems)..where((item) => item.id.equals(id) & item.monthId.equals(row.id))).getSingleOrNull();
      if (item == null) throw _notFound('Item não encontrado');
      final values = TemplateItemsCompanion(
        name: Value(item.name),
        currency: Value(item.currency),
        kind: Value(item.kind),
        amount: Value(item.amount),
        expression: Value(item.expression),
      );
      if (item.templateItemId != null) {
        final updated = await (db.update(db.templateItems)..where((template) => template.id.equals(item.templateItemId!))).writeReturning(values);
        if (updated.isNotEmpty) return _templateItem(updated.single);
      }
      final created = await db.into(db.templateItems).insertReturning(values.copyWith(
            id: Value(newId()),
            position: Value(await _nextPosition(db.templateItems, db.templateItems.position)),
            createdAt: Value(_now()),
          ));
      await (db.update(db.monthItems)..where((month) => month.id.equals(item.id))).write(MonthItemsCompanion(templateItemId: Value(created.id)));
      return _templateItem(created);
    });
  }

  /* ------------------------------- Daily spends ---------------------------- */

  void _requireDay(int? day, MonthRow month) {
    if (day != null && (day < 1 || day > daysInMonth(month.year, month.month))) throw _invalid('Esse dia não está no mês');
  }

  @override
  Future<DailySpend> addSpend(int year, int month, Json body) async {
    final row = await _requireMonth(year, month);
    _requireDay(body['day'] as int, row);
    final currency = body['currency'] as String? ?? row.mainCurrency;
    await _requireCurrency(currency);
    final spend = await db.into(db.dailySpends).insertReturning(DailySpendsCompanion.insert(
          id: newId(),
          monthId: row.id,
          day: body['day'] as int,
          currency: currency,
          amount: _cents(body['amount'])!,
          expression: Value(_trimmed(body['expression'])),
          note: Value(_trimmed(body['note'])),
          createdAt: _now(),
        ));
    return _spend(spend);
  }

  @override
  Future<DailySpend> updateSpend(int year, int month, String id, Json patch) async {
    final row = await _requireMonth(year, month);
    _requireDay(patch['day'] as int?, row);
    await _requireCurrency(patch['currency']);
    final amountChanged = patch.containsKey('amount');
    final updated = await (db.update(db.dailySpends)..where((spend) => spend.id.equals(id) & spend.monthId.equals(row.id))).writeReturning(DailySpendsCompanion(
      day: patch.containsKey('day') ? Value(patch['day'] as int) : const Value.absent(),
      currency: patch.containsKey('currency') ? Value(patch['currency'] as String) : const Value.absent(),
      amount: amountChanged ? Value(_cents(patch['amount'])!) : const Value.absent(),
      expression: patch.containsKey('expression') ? Value(_trimmed(patch['expression'])) : (amountChanged ? const Value(null) : const Value.absent()),
      note: patch.containsKey('note') ? Value(_trimmed(patch['note'])) : const Value.absent(),
    ));
    if (updated.isEmpty) throw _notFound('Gasto não encontrado');
    return _spend(updated.single);
  }

  @override
  Future<void> deleteSpend(int year, int month, String id) async {
    final row = await _requireMonth(year, month);
    final deleted = await (db.delete(db.dailySpends)..where((spend) => spend.id.equals(id) & spend.monthId.equals(row.id))).go();
    if (deleted == 0) throw _notFound('Gasto não encontrado');
  }

  /* ---------------------------------- Rates -------------------------------- */

  @override
  Future<LiveRates> liveRates({Currency? base}) async =>
      _rates.get(base ?? await _mainCurrency() ?? (throw _refused('Nenhuma moeda principal')));

  /* -------------------------------- Currencies ----------------------------- */

  /// The currencies any template item, month item or daily spend is in, and the ones months are worked out in.
  Future<Set<String>> _usedCurrencies() async {
    final rows = await db.customSelect(
      'SELECT currency AS code FROM template_items UNION SELECT currency FROM month_items '
      'UNION SELECT currency FROM daily_spends UNION SELECT main_currency FROM months',
      readsFrom: {db.templateItems, db.monthItems, db.dailySpends, db.months},
    ).get();
    return {for (final row in rows) row.read<String>('code')};
  }

  @override
  Future<List<UserCurrency>> currencies() async {
    final rows = await (db.select(db.currencies)..orderBy([(row) => OrderingTerm.desc(row.main), (row) => OrderingTerm.asc(row.code)])).get();
    final used = await _usedCurrencies();
    return [
      for (final row in rows) UserCurrency(currency: Currency.parse(row.code), enabled: row.enabled, main: row.main, inUse: used.contains(row.code)),
    ];
  }

  Future<CurrencyRow?> _currency(Currency currency) => (db.select(db.currencies)..where((row) => row.code.equals(currency.code))).getSingleOrNull();

  Future<void> _demoteMain() => (db.update(db.currencies)..where((row) => row.main.equals(true))).write(const CurrenciesCompanion(main: Value(false)));

  @override
  Future<void> addCurrency(Currency currency) => db.transaction(() async {
        if (await _currency(currency) != null) throw _refused('Essa moeda já foi adicionada');
        // The first currency is the main one.
        final first = await _mainCurrency() == null;
        await db.into(db.currencies).insert(CurrenciesCompanion.insert(code: currency.code, main: Value(first)));
      });

  @override
  Future<List<UserCurrency>> updateCurrency(Currency currency, Json patch) async {
    await db.transaction(() async {
      final row = await _currency(currency) ?? (throw _notFound('Moeda não encontrada'));
      final enabled = patch['enabled'] as bool? ?? row.enabled;
      final main = patch['main'] as bool? ?? row.main;
      if (row.main && !main) throw _refused('Escolha outra moeda principal');
      if (row.main && !enabled) throw _refused('Escolha outra moeda principal antes de desativar esta');
      if (main && !enabled) throw _refused('Uma moeda desativada não pode ser a principal');
      if (main && !row.main) await _demoteMain();
      await (db.update(db.currencies)..where((r) => r.code.equals(currency.code))).write(CurrenciesCompanion(enabled: Value(enabled), main: Value(main)));
    });
    return currencies();
  }

  @override
  Future<List<UserCurrency>> replaceCurrencies({required List<Currency> enabled, List<Currency> disabled = const [], required Currency main}) async {
    if (!enabled.contains(main)) throw _invalid('A moeda principal precisa estar ativa');
    await db.transaction(() async {
      final kept = {for (final currency in [...enabled, ...disabled]) currency.code};
      final existing = await db.select(db.currencies).get();
      final removed = [for (final row in existing) if (!kept.contains(row.code)) row.code];
      final used = await _usedCurrencies();
      final inUse = [for (final code in removed) if (used.contains(code)) code];
      if (inUse.isNotEmpty) throw _refused('Em uso: ${inUse.join(', ')}');
      await (db.delete(db.currencies)..where((row) => row.code.isIn(removed))).go();
      await db.batch((batch) => batch.insertAllOnConflictUpdate(db.currencies, [
            for (final currency in enabled) CurrenciesCompanion.insert(code: currency.code, enabled: const Value(true), main: Value(currency == main)),
            for (final currency in disabled) CurrenciesCompanion.insert(code: currency.code, enabled: const Value(false), main: const Value(false)),
          ]));
    });
    return currencies();
  }

  @override
  Future<void> deleteCurrency(Currency currency) => db.transaction(() async {
        final row = await _currency(currency) ?? (throw _notFound('Moeda não encontrada'));
        if (row.main) throw _refused('A moeda principal não pode ser removida');
        if ((await _usedCurrencies()).contains(row.code)) throw _refused('Essa moeda está em uso');
        await (db.delete(db.currencies)..where((r) => r.code.equals(row.code))).go();
      });

  /* --------------------------------- Template ------------------------------ */

  @override
  Future<TemplateDetail> template() async => TemplateDetail(items: (await _templateRows()).map(_templateItem).toList());

  @override
  Future<TemplateItem> addTemplateItem(Json body) async {
    await _requireCurrency(body['currency']);
    final item = await db.into(db.templateItems).insertReturning(TemplateItemsCompanion.insert(
          id: newId(),
          name: (body['name'] as String).trim(),
          currency: body['currency'] as String,
          kind: body['kind'] as String? ?? EntryKind.expense.name,
          amount: Value(_cents(body['amount'])),
          expression: Value(_trimmed(body['expression'])),
          variable: Value(body['variable'] as bool? ?? false),
          position: await _nextPosition(db.templateItems, db.templateItems.position),
          createdAt: _now(),
        ));
    return _templateItem(item);
  }

  @override
  Future<TemplateItem> updateTemplateItem(String id, Json patch) async {
    await _requireCurrency(patch['currency']);
    final amountChanged = patch.containsKey('amount');
    final updated = await (db.update(db.templateItems)..where((item) => item.id.equals(id))).writeReturning(TemplateItemsCompanion(
      name: patch.containsKey('name') ? Value((patch['name'] as String).trim()) : const Value.absent(),
      currency: patch.containsKey('currency') ? Value(patch['currency'] as String) : const Value.absent(),
      kind: patch.containsKey('kind') ? Value(patch['kind'] as String) : const Value.absent(),
      amount: amountChanged ? Value(_cents(patch['amount'])) : const Value.absent(),
      expression: patch.containsKey('expression') ? Value(_trimmed(patch['expression'])) : (amountChanged ? const Value(null) : const Value.absent()),
      variable: patch.containsKey('variable') ? Value(patch['variable'] as bool) : const Value.absent(),
    ));
    if (updated.isEmpty) throw _notFound('Item do template não encontrado');
    return _templateItem(updated.single);
  }

  @override
  Future<void> deleteTemplateItem(String id) async {
    final deleted = await (db.delete(db.templateItems)..where((item) => item.id.equals(id))).go();
    if (deleted == 0) throw _notFound('Item do template não encontrado');
  }

  @override
  Future<List<TemplateItem>> reorderTemplate(List<String> ids) async {
    await db.transaction(() async {
      final existing = await (db.select(db.templateItems)..where((item) => item.id.isIn(ids))).get();
      if (existing.length != ids.toSet().length) throw _invalid('Item desconhecido na ordem');
      for (final (position, id) in ids.indexed) {
        await (db.update(db.templateItems)..where((item) => item.id.equals(id))).write(TemplateItemsCompanion(position: Value(position)));
      }
    });
    return (await _templateRows()).map(_templateItem).toList();
  }

  /* ----------------------------------- Data -------------------------------- */

  @override
  Future<void> clearData() => db.transaction(() async {
        await db.delete(db.months).go();
        await db.delete(db.templateItems).go();
      });

  /* ---------------------------- Export and import -------------------------- */

  /// Everything on the device, in the file format of `packages/shared/src/export.ts`.
  Future<Json> export() async {
    final currencies = await (db.select(db.currencies)..orderBy([(row) => OrderingTerm.desc(row.main), (row) => OrderingTerm.asc(row.code)])).get();
    final months = await (db.select(db.months)..orderBy([(row) => OrderingTerm.desc(row.year), (row) => OrderingTerm.desc(row.month)])).get();
    return {
      'format': exportFormat,
      'version': exportVersion,
      'exportedAt': _now(),
      'currencies': [
        for (final row in currencies) {'currency': row.code, 'enabled': row.enabled, 'main': row.main},
      ],
      'template': [for (final row in await _templateRows()) _templateItem(row).toJson()],
      'months': [
        for (final row in months)
          {
            ..._month(row).toJson(),
            'items': [for (final item in await _items(row.id)) _item(item).toJson()],
            'spends': [for (final spend in await _spends(row.id)) _spend(spend).toJson()],
          },
      ],
    };
  }

  /// Replaces everything on the device with an export, from this app or from the server. Nothing
  /// changes when the export can't be read.
  Future<void> replaceAll(Object? data) async {
    final ({List<CurrencyRow> currencies, List<TemplateItem> template, List<(Month, List<MonthItem>, List<DailySpend>)> months}) parsed;
    try {
      final json = data as Map;
      if (json['format'] != exportFormat) throw const FormatException();
      if (json['version'] != exportVersion) throw _invalid('Esse arquivo é de uma versão mais nova do maimoni. Atualize o app e tente de novo.');
      parsed = (
        currencies: [
          for (final row in json['currencies'] as List)
            CurrencyRow(code: Currency.parse((row as Map)['currency'] as String).code, enabled: row['enabled'] as bool, main: row['main'] as bool),
        ],
        template: [for (final item in json['template'] as List) TemplateItem.fromJson((item as Map).cast())],
        months: [
          for (final month in json['months'] as List)
            (
              Month.fromJson((month as Map).cast()),
              [for (final item in month['items'] as List) MonthItem.fromJson((item as Map).cast())],
              [for (final spend in month['spends'] as List) DailySpend.fromJson((spend as Map).cast())],
            ),
        ],
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw _invalid('Esse arquivo não é um export do maimoni');
    }
    final mains = parsed.currencies.where((currency) => currency.main).toList();
    if (parsed.currencies.isNotEmpty && (mains.length != 1 || !mains.single.enabled)) {
      throw _invalid('Esse arquivo precisa ter exatamente uma moeda principal ativa');
    }
    try {
      await _replace(parsed);
    } catch (_) {
      // Such as an item pointing at a month or template item the file doesn't have.
      throw _invalid('Esse arquivo não é um export do maimoni');
    }
  }

  Future<void> _replace(({List<CurrencyRow> currencies, List<TemplateItem> template, List<(Month, List<MonthItem>, List<DailySpend>)> months}) parsed) async {
    await db.transaction(() async {
      // Rates stay: they aren't the person's data.
      for (final TableInfo table in [db.dailySpends, db.monthItems, db.months, db.templateItems, db.currencies]) {
        await db.delete(table).go();
      }
      final created = _now();
      await db.batch((batch) {
        batch.insertAll(db.currencies, parsed.currencies);
        batch.insertAll(db.templateItems, [
          for (final item in parsed.template)
            TemplateItemRow(
              id: item.id,
              name: item.name,
              currency: item.currency.code,
              kind: item.kind.name,
              amount: item.amount,
              expression: item.expression,
              variable: item.variable,
              position: item.position,
              createdAt: created,
            ),
        ]);
        for (final (month, items, spends) in parsed.months) {
          batch.insert(
            db.months,
            MonthRow(
              id: month.id,
              year: month.year,
              month: month.month,
              mainCurrency: month.mainCurrency.code,
              lockedRates: jsonEncode(ratesToJson(month.lockedRates)),
              activeDay: month.activeDay,
              note: month.note,
              createdAt: month.createdAt,
            ),
          );
          batch.insertAll(db.monthItems, [
            for (final item in items)
              MonthItemRow(
                id: item.id,
                monthId: month.id,
                templateItemId: item.templateItemId,
                name: item.name,
                currency: item.currency.code,
                kind: item.kind.name,
                amount: item.amount,
                expression: item.expression,
                paid: item.paid,
                needsReview: item.needsReview,
                position: item.position,
                createdAt: created,
              ),
          ]);
          batch.insertAll(db.dailySpends, [
            for (final spend in spends)
              DailySpendRow(
                id: spend.id,
                monthId: month.id,
                day: spend.day,
                currency: spend.currency.code,
                amount: spend.amount,
                expression: spend.expression,
                note: spend.note,
                createdAt: spend.createdAt,
              ),
          ]);
        }
      });
    });
  }
}

const exportFormat = 'maimoni-export';
const exportVersion = 1;
