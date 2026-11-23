import 'package:flutter_test/flutter_test.dart';
import 'package:maimoni/api/models.dart';
import 'package:maimoni/domain/expression.dart';
import 'package:maimoni/domain/summary.dart';

// Mirrors packages/shared/src/summary.test.ts, so the Dart port stays faithful to the TypeScript.

var _counter = 0;

MonthItem item(Currency currency, double? amount, {EntryKind kind = EntryKind.expense, bool paid = false, bool needsReview = false}) =>
    MonthItem(
      id: 'item-${_counter++}',
      monthId: 'month',
      templateItemId: null,
      name: 'item $_counter',
      currency: currency,
      kind: kind,
      amount: amount,
      expression: null,
      paid: paid,
      needsReview: needsReview,
      position: _counter,
    );

DailySpend spend(int day, double amount, [Currency currency = Currency.eur]) => DailySpend(
      id: 'spend-${_counter++}',
      monthId: 'month',
      day: day,
      currency: currency,
      amount: amount,
      expression: null,
      note: null,
      createdAt: '2026-10-0${_counter % 9 + 1}T00:00:00Z',
    );

Month month({Currency mainCurrency = Currency.eur, Rates lockedRates = const {}, int? activeDay}) => Month(
      id: 'month',
      year: 2026,
      month: 10,
      mainCurrency: mainCurrency,
      lockedRates: lockedRates,
      activeDay: activeDay,
      note: null,
      createdAt: '',
    );

// A made-up October: income in reais, bills in both currencies, worked out in euros.
final october = [
  item(Currency.brl, 20000.5, kind: EntryKind.income),
  for (final amount in [1250.99, 800, 2000, 0, 360, 1200.5, 3000, 650.49]) item(Currency.brl, amount.toDouble()),
  for (final amount in [50, 75.5, 90, 1000, 45, 7.99, 4.99, 20.99, 14.98, 60.55]) item(Currency.eur, amount.toDouble()),
];
final euros = october.where((entry) => entry.currency == Currency.eur).toList();

final oct3 = DateTime(2026, 10, 3);

/// Reais per euro.
const rates = {Currency.brl: 5.868553};

void main() {
  group('summarizeMonth', () {
    test('computes the month totals in the main currency', () {
      final summary = summarizeMonth(month(), october, rates: rates, today: oct3);
      expect(summary.main, Currency.eur);
      expect(summary.totals[Currency.brl]!.expenses, 9261.98);
      expect(summary.totals[Currency.brl]!.net, 10738.52);
      expect(summary.totals[Currency.eur]!.income, 0);
      expect(summary.totals[Currency.eur]!.expenses, 1370);
      expect(summary.totals[Currency.eur]!.net, -1370);
      // Everything left in reais is converted at the rate, with no fee: 10738.52 ÷ 5.868553.
      expect(summary.conversions, hasLength(1));
      final conversion = summary.conversions.single;
      expect(conversion.currency, Currency.brl);
      expect(conversion.rate, 5.868553);
      expect(conversion.rateLocked, isFalse);
      expect(conversion.net, 10738.52);
      expect(conversion.converted, 1829.84);
      expect(summary.converted, 1829.84);
      expect(summary.net, 459.84);
      expect(summary.allowance.days, 29);
      expect(summary.allowance.amount, closeTo(15.86, 0.005));
    });

    test('the same month worked out in the other currency', () {
      // Euros per real.
      final summary = summarizeMonth(month(mainCurrency: Currency.brl), october, rates: {Currency.eur: 0.17}, today: oct3);
      expect(summary.main, Currency.brl);
      // What is left in euros is a deficit, and it comes out of the reais: −1370 ÷ 0.17.
      final conversion = summary.conversions.single;
      expect(conversion.currency, Currency.eur);
      expect(conversion.rate, 0.17);
      expect(conversion.net, -1370);
      expect(conversion.converted, -8058.82);
      expect(summary.net, 2679.7);
      expect(summary.allowance.amount, closeTo(2679.7 / 29, 0.005));
    });

    test('a single currency needs no rate', () {
      final summary = summarizeMonth(month(), euros, rates: null, today: oct3);
      expect(summary.totals.keys, [Currency.eur]);
      expect(summary.totals[Currency.eur]!.net, -1370);
      expect(summary.conversions, isEmpty);
      expect(summary.net, -1370);
    });

    test('a locked rate overrides the live value, per currency', () {
      final summary = summarizeMonth(month(lockedRates: {Currency.brl: 6}), october, rates: rates, today: oct3);
      expect(summary.rates, {Currency.brl: 6});
      expect(summary.conversions.first.rate, 6);
      expect(summary.conversions.first.rateLocked, isTrue);
      expect(summary.conversions.first.converted, closeTo(10738.52 / 6, 0.005));
    });

    test('counts empty and review items as unresolved, splits paid/pending', () {
      final summary = summarizeMonth(
        month(),
        [item(Currency.brl, null), item(Currency.brl, 10, paid: true), item(Currency.brl, 5, needsReview: true)],
        rates: {Currency.brl: 5},
        today: oct3,
      );
      expect(summary.totals[Currency.brl]!.unresolved, 2);
      expect(summary.totals[Currency.brl]!.paid, 10);
      expect(summary.totals[Currency.brl]!.pending, 5);
      // The main currency is always there, even without items.
      expect(summary.totals[Currency.eur]!.net, 0);
    });

    test('no result or allowance without a rate, and no allowance for past months', () {
      final missing = summarizeMonth(month(), october, rates: null, today: oct3);
      expect(missing.conversions.first.rate, isNull);
      expect(missing.conversions.first.converted, isNull);
      expect(missing.converted, isNull);
      expect(missing.net, isNull);
      expect(missing.allowance.amount, isNull);
      expect(missing.allowance.remaining, isNull);
      expect(summarizeMonth(month(), october, rates: rates, today: DateTime(2026, 11, 3)).allowance.amount, isNull);
    });

    test("a currency with nothing left doesn't wait for a rate", () {
      final balanced = [
        item(Currency.brl, 100, kind: EntryKind.income),
        item(Currency.brl, 100),
        item(Currency.eur, 50, kind: EntryKind.income),
      ];
      final summary = summarizeMonth(month(), balanced, rates: null, today: oct3);
      expect(summary.converted, 0);
      expect(summary.net, 50);
    });

    test('lists the currencies in the order of the app, whatever the order of the items', () {
      const usd = Currency('USD');
      final summary = summarizeMonth(
        month(),
        [item(usd, 10), item(Currency.brl, 10), item(Currency.eur, 10)],
        rates: {usd: 1.1, Currency.brl: 5},
        today: oct3,
      );
      expect(summary.totals.keys, [Currency.brl, Currency.eur, usd]);
      expect(summary.conversions.map((conversion) => conversion.currency), [Currency.brl, usd]);
    });
  });

  group('daily allowance', () {
    // Net 459.84 over 29 days (3rd to 31st) = 15.86 a day
    final base = summarizeMonth(month(), october, rates: rates, today: oct3).allowance;

    test('spending on the open day only reduces that day', () {
      final allowance = summarizeMonth(month(), october, rates: rates, spends: [spend(3, 20), spend(3, 5.5)], today: oct3).allowance;
      expect(allowance.activeDay, 3);
      expect(allowance.days, 29);
      expect(allowance.amount, base.amount);
      expect(allowance.spentToday, 25.5);
      expect(allowance.spentBefore, 0);
      expect(allowance.spentTotal, 25.5);
      expect(allowance.remaining, closeTo(base.amount! - 25.5, 0.005));
    });

    test('an unclosed day keeps its budget even after the calendar moves on', () {
      final allowance =
          summarizeMonth(month(activeDay: 3), october, rates: rates, spends: [spend(3, 80)], today: DateTime(2026, 10, 5)).allowance;
      expect(allowance.activeDay, 3);
      expect(allowance.days, 29);
      expect(allowance.amount, base.amount);
      expect(allowance.remaining, closeTo(base.amount! - 80, 0.005));
    });

    test('closing spreads the leftover (or the overspend) over the remaining days', () {
      final allowance =
          summarizeMonth(month(activeDay: 5), october, rates: rates, spends: [spend(3, 80)], today: DateTime(2026, 10, 5)).allowance;
      expect(allowance.activeDay, 5);
      expect(allowance.days, 27);
      expect(allowance.spentBefore, 80);
      expect(allowance.spentToday, 0);
      expect(allowance.amount, closeTo((459.84 - 80) / 27, 0.05));
    });

    test('spends on a later day (left by undoing a close) still come out of the budget', () {
      final allowance = summarizeMonth(month(activeDay: 3), october, rates: rates, spends: [spend(4, 29)], today: oct3).allowance;
      expect(allowance.spentBefore, 29);
      expect(allowance.spentToday, 0);
      expect(allowance.amount, closeTo((459.84 - 29) / 29, 0.05));
    });

    test('a spend in another currency costs what it would have become at the rate', () {
      const inEur = 100 / 5.868553;
      final summary =
          summarizeMonth(month(), october, rates: rates, spends: [spend(3, 100, Currency.brl), spend(3, 10)], today: oct3);
      expect(summary.allowance.spentToday, closeTo(inEur + 10, 0.005));
      expect(summary.cost(spend(3, 100, Currency.brl)), closeTo(inEur, 0.005));
      expect(spendInMain(spend(3, 100, Currency.brl), main: Currency.eur, rates: const {}), isNull);
      expect(spendInMain(spend(3, 12.5), main: Currency.eur, rates: const {}), 12.5);
    });

    test('a currency only spends are in is converted too', () {
      final summary = summarizeMonth(month(), euros, rates: rates, spends: [spend(3, 100, Currency.brl)], today: oct3);
      final conversion = summary.conversions.single;
      expect(conversion.currency, Currency.brl);
      expect(conversion.rate, 5.868553);
      expect(conversion.net, 0);
      expect(conversion.converted, 0);
      expect(summary.allowance.spentToday, 17.04);
    });

    test('nextActiveDay jumps to today, or to tomorrow when today is the open day', () {
      expect(nextActiveDay(month(activeDay: 3), DateTime(2026, 10, 5)), 5);
      expect(nextActiveDay(month(), oct3), 4);
      expect(nextActiveDay(month(activeDay: 31), DateTime(2026, 10, 31)), 32);
      expect(openDay(month(activeDay: 32), DateTime(2026, 10, 31)), isNull);
      expect(nextActiveDay(month(), DateTime(2026, 11, 2)), isNull);
    });
  });

  group('dayResults', () {
    const net = 459.84; // October's net (see 'computes the month totals in the main currency')

    test('replays closed days, matches the open day and projects upcoming ones', () {
      final spends = [spend(1, 30), spend(2, 100), spend(3, 10)];
      final summary = summarizeMonth(month(activeDay: 3), october, rates: rates, spends: spends, today: oct3);
      final days = dayResults(month(), summary, spends);
      expect(days, hasLength(31));

      expect(days[0].state, DayState.closed);
      expect(days[0].spent, 30);
      expect(days[0].budget, closeTo(net / 31, 0.05));
      expect(days[0].result, closeTo(net / 31 - 30, 0.05));
      expect(days[1].budget, closeTo((net - 30) / 30, 0.05));
      expect(days[1].result, lessThan(0));

      expect(days[2].state, DayState.open);
      expect(days[2].budget, summary.allowance.amount);
      expect(days[2].spent, 10);
      expect(days[2].result, summary.allowance.remaining);
      expect(days[3].state, DayState.upcoming);
      expect(days[3].budget, closeTo((net - 140) / 28, 0.05));
    });

    test('every day of a past month is closed', () {
      final summary = summarizeMonth(month(), october, rates: rates, today: DateTime(2026, 11, 5));
      final days = dayResults(month(), summary, []);
      expect(days.every((day) => day.state == DayState.closed), isTrue);
      expect(days.last.budget, closeTo(net, 0.05));
    });
  });

  group('remainingDays', () {
    test('current, past and future months', () {
      expect(remainingDays(2026, 10, DateTime(2026, 10, 31)), 1);
      expect(remainingDays(2026, 9, DateTime(2026, 10, 3)), 0);
      expect(remainingDays(2027, 2, DateTime(2026, 10, 3)), 28);
    });
  });

  group('evaluateExpression', () {
    test('evaluates arithmetic', () {
      expect(evaluateExpression('=11.99+2.99'), 14.98);
      expect(evaluateExpression('20000.5 + 509.54'), 20510.04);
      expect(evaluateExpression('(10 - 2) * 3 / 4'), 6);
      expect(evaluateExpression('-1250,4'), -1250.4);
    });

    test('accepts pt-BR formatting and currency symbols', () {
      expect(evaluateExpression('1.250,99'), 1250.99);
      expect(evaluateExpression(r'R$ 20.000,50 + 509,54'), 20510.04);
      expect(evaluateExpression('1.000.000'), 1000000);
      expect(evaluateExpression('2.500'), 2500);
      expect(evaluateExpression('1250.99'), 1250.99);
      expect(evaluateExpression('10.5'), 10.5);
      expect(evaluateExpression('€ 45'), 45);
      expect(evaluateExpression(r'US$ 45'), isNull);
      expect(evaluateExpression('£ 45 + ¥ 5'), 50);
      expect(evaluateExpression('1,2,3'), isNull);
    });

    test('rejects garbage', () {
      expect(evaluateExpression('abc'), isNull);
      expect(evaluateExpression('1+'), isNull);
      expect(evaluateExpression(''), isNull);
    });

    test('detects expressions', () {
      expect(isExpression('11.99+2.99'), isTrue);
      expect(isExpression('-12'), isFalse);
      expect(isExpression('12.5'), isFalse);
    });
  });

  test('groupDailySpends orders days newest first', () {
    final groups = groupDailySpends([spend(1, 1), spend(3, 1), spend(1, 2)]);
    expect(groups.map((group) => group.day), [3, 1]);
    expect(groups.last.spends, hasLength(2));
  });
}
