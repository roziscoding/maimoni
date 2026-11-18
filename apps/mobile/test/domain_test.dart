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

Month month({double? exchangeRate, int? activeDay}) => Month(
      id: 'month',
      year: 2026,
      month: 10,
      exchangeRate: exchangeRate,
      activeDay: activeDay,
      note: null,
      createdAt: '',
    );

// A made-up October
final october = [
  item(Currency.brl, 20000.5, kind: EntryKind.income),
  for (final amount in [1250.99, 800, 2000, 0, 360, 1200.5, 3000, 650.49]) item(Currency.brl, amount.toDouble()),
  for (final amount in [50, 75.5, 90, 1000, 45, 7.99, 4.99, 20.99, 14.98, 60.55]) item(Currency.eur, amount.toDouble()),
];

final oct3 = DateTime(2026, 10, 3);
const rate = 5.868553;

void main() {
  group('summarizeMonth', () {
    test('computes the month totals', () {
      final summary = summarizeMonth(month(), october, rate: rate, today: oct3);
      expect(summary.brl.expenses, 9261.98);
      expect(summary.brl.net, 10738.52);
      // Everything left is converted at the rate, with no fee: 10738.52 ÷ 5.868553.
      expect(summary.transfer.eur, closeTo(1829.84, 0.005));
      expect(summary.eur.expenses, 1370);
      expect(summary.eur.net, closeTo(459.84, 0.005));
      expect(summary.allowance.days, 29);
      expect(summary.allowance.eur, closeTo(15.86, 0.005));
      expect(summary.allowance.brl, closeTo(93.06, 0.05));
    });

    test('locked rate overrides the live value', () {
      final summary = summarizeMonth(month(exchangeRate: 6), october, rate: rate, today: oct3);
      expect(summary.transfer.rate, 6);
      expect(summary.transfer.rateLocked, isTrue);
      expect(summary.transfer.projected.eur, closeTo(10738.52 / 6, 0.005));
    });

    test('counts empty and review items as unresolved, splits paid/pending', () {
      final summary = summarizeMonth(
        month(),
        [item(Currency.brl, null), item(Currency.brl, 10, paid: true), item(Currency.brl, 5, needsReview: true)],
        rate: 5,
        today: oct3,
      );
      expect(summary.brl.unresolved, 2);
      expect(summary.brl.paid, 10);
      expect(summary.brl.pending, 5);
    });

    test('no allowance without a rate or for past months', () {
      expect(summarizeMonth(month(), october, rate: null, today: oct3).allowance.eur, isNull);
      expect(summarizeMonth(month(), october, rate: 5.8, today: DateTime(2026, 11, 3)).allowance.eur, isNull);
    });
  });

  group('daily allowance', () {
    final base = summarizeMonth(month(), october, rate: rate, today: oct3).allowance;

    test('spending on the open day only reduces that day', () {
      final allowance =
          summarizeMonth(month(), october, rate: rate, spends: [spend(3, 20), spend(3, 5.5)], today: oct3).allowance;
      expect(allowance.activeDay, 3);
      expect(allowance.eur, base.eur);
      expect(allowance.spentToday, 25.5);
      expect(allowance.spentBefore, 0);
      expect(allowance.remainingEur, closeTo(base.eur! - 25.5, 0.005));
    });

    test('closing spreads the leftover over the remaining days', () {
      final allowance = summarizeMonth(month(activeDay: 5), october,
              rate: rate, spends: [spend(3, 80)], today: DateTime(2026, 10, 5))
          .allowance;
      expect(allowance.days, 27);
      expect(allowance.spentBefore, 80);
      expect(allowance.eur, closeTo((459.84 - 80) / 27, 0.05));
    });

    test('a BRL spend costs what those reais would have become at the rate', () {
      const inEur = 100 / rate;
      final allowance = summarizeMonth(month(), october,
              rate: rate, spends: [spend(3, 100, Currency.brl), spend(3, 10)], today: oct3)
          .allowance;
      expect(allowance.spentToday, closeTo(inEur + 10, 0.005));
      expect(spendInEur(spend(1, 100, Currency.brl), rate: null), isNull);
      expect(spendInEur(spend(1, 12.5), rate: null), 12.5);
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
    const net = 459.84;

    test('replays closed days, matches the open day and projects upcoming ones', () {
      final spends = [spend(1, 30), spend(2, 100), spend(3, 10)];
      final summary = summarizeMonth(month(activeDay: 3), october, rate: rate, spends: spends, today: oct3);
      final days = dayResults(month(), summary, spends);
      expect(days, hasLength(31));
      expect(days[0].state, DayState.closed);
      expect(days[0].budget, closeTo(net / 31, 0.05));
      expect(days[1].result, lessThan(0));
      expect(days[2].state, DayState.open);
      expect(days[2].result, summary.allowance.remainingEur);
      expect(days[3].state, DayState.upcoming);
      expect(days[3].budget, closeTo((net - 140) / 28, 0.05));
    });
  });

  group('conversions', () {
    test('the fee is what was sent beyond what the received EUR are worth at the rate', () {
      expect(conversionFee(sentBrl: 3000, receivedEur: 480, rate: 6), 120);
      expect(conversionFee(sentBrl: 1000, receivedEur: 163.31, rate: rate), 41.61);
      // The rate moved in the sender's favour, or there is none: no fee rather than a negative one.
      expect(conversionFee(sentBrl: 3000, receivedEur: 520, rate: 6), 0);
      expect(conversionFee(sentBrl: 3000, receivedEur: 480, rate: null), 0);
    });

    test('completed conversions count as they happened, and the rest is projected without a fee', () {
      final conversion =
          Conversion(id: 'c', monthId: 'month', day: 2, sentBrl: 3000, feeBrl: 120, receivedEur: 480, note: null, createdAt: '');
      final transfer = summarizeMonth(month(), october, rate: 6, conversions: [conversion], today: oct3).transfer;
      expect(transfer.realized.convertedBrl, 2880);
      expect(transfer.realized.feeBrl, 120);
      expect(transfer.remainingBrl, 7738.52);
      expect(transfer.projected.eur, 1289.75);
      expect(transfer.eur, 1769.75);
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
      expect(evaluateExpression('10.5'), 10.5);
      expect(evaluateExpression('€ 45'), 45);
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
