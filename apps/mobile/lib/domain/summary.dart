import '../api/models.dart';
import 'expression.dart';

/// Port of `packages/shared/src/summary.ts`. Keep both in sync: the app recomputes the summary
/// locally so optimistic edits update every figure instantly, exactly like the web.

double _d(Object? value) => (value as num).toDouble();
double? _dn(Object? value) => value == null ? null : (value as num).toDouble();

class CurrencyTotals {
  const CurrencyTotals({
    required this.income,
    required this.expenses,
    required this.net,
    required this.paid,
    required this.pending,
    required this.unresolved,
  });

  factory CurrencyTotals.fromJson(Json json) => CurrencyTotals(
        income: _d(json['income']),
        expenses: _d(json['expenses']),
        net: _d(json['net']),
        paid: _d(json['paid']),
        pending: _d(json['pending']),
        unresolved: json['unresolved'] as int,
      );

  /// A currency with no item in it.
  static const empty = CurrencyTotals(income: 0, expenses: 0, net: 0, paid: 0, pending: 0, unresolved: 0);

  final double income;
  final double expenses;
  final double net;
  final double paid;
  final double pending;

  /// Items still missing a value or flagged for review.
  final int unresolved;
}

/// How what is left in a currency other than the month's main one becomes main currency.
class CurrencyConversion {
  CurrencyConversion({
    required this.currency,
    required this.rate,
    required this.rateLocked,
    required this.net,
    required this.converted,
  });

  factory CurrencyConversion.fromJson(Json json) => CurrencyConversion(
        currency: Currency.parse(json['currency'] as String),
        rate: _dn(json['rate']),
        rateLocked: json['rateLocked'] as bool,
        net: _d(json['net']),
        converted: _dn(json['converted']),
      );

  final Currency currency;

  /// How many units of the currency one unit of the main currency is worth; `null` when there is no rate for it.
  final double? rate;

  /// Whether the rate is the one the month locked, rather than the live one.
  final bool rateLocked;

  /// The currency's own net: its income minus its expenses.
  final double net;

  /// That net in the main currency, with no fee taken off; `null` when it isn't zero and there is no rate.
  final double? converted;
}

/// Daily spending, all in the month's main currency.
class Allowance {
  Allowance({
    required this.activeDay,
    required this.days,
    required this.spentBefore,
    required this.spentToday,
    required this.spentTotal,
    required this.amount,
    required this.remaining,
  });

  factory Allowance.fromJson(Json json) => Allowance(
        activeDay: json['activeDay'] as int?,
        days: json['days'] as int,
        spentBefore: _d(json['spentBefore']),
        spentToday: _d(json['spentToday']),
        spentTotal: _d(json['spentTotal']),
        amount: _dn(json['amount']),
        remaining: _dn(json['remaining']),
      );

  /// Day of the month open for daily spending; `null` for past months and once every day was closed.
  final int? activeDay;

  /// Days the budget is spread over: from the open day to the end of the month.
  final int days;

  /// Daily spending on days other than the open day; it already came out of the budget being spread.
  final double spentBefore;

  /// Daily spending on the open day (spends in other currencies converted with [spendInMain]).
  final double spentToday;

  /// All daily spending of the month.
  final double spentTotal;

  /// Budget for the open day: (net − spentBefore) ÷ days.
  final double? amount;

  /// What is left of the open day's budget after its spending.
  final double? remaining;
}

class MonthSummary {
  MonthSummary({
    required this.main,
    required this.totals,
    required this.rates,
    required this.conversions,
    required this.converted,
    required this.net,
    required this.allowance,
  });

  factory MonthSummary.fromJson(Json json) => MonthSummary(
        main: Currency.parse(json['main'] as String),
        totals: {
          for (final MapEntry(:key, :value) in (json['totals'] as Json).entries)
            Currency.parse(key): CurrencyTotals.fromJson(value as Json),
        },
        rates: ratesFromJson(json['rates']),
        conversions: [for (final row in json['conversions'] as List) CurrencyConversion.fromJson(row as Json)],
        converted: _dn(json['converted']),
        net: _dn(json['net']),
        allowance: Allowance.fromJson(json['allowance'] as Json),
      );

  /// The currency the month is worked out in.
  final Currency main;

  /// Totals of each currency's own items: the main currency, and every other one with an item.
  final Map<Currency, CurrencyTotals> totals;

  /// The rate in use for each currency: the month's locked one, or the live one.
  final Rates rates;

  /// One entry per other currency the month has items or spends in, in the app's order.
  final List<CurrencyConversion> conversions;

  /// What the other currencies add up to in the main one; `null` while any of them can't be converted.
  final double? converted;

  /// The main currency's own net plus [converted]; `null` while [converted] is.
  final double? net;
  final Allowance allowance;

  /// What [spend] costs the allowance, in the main currency.
  double? cost(DailySpend spend) => spendInMain(spend, main: main, rates: rates);
}

enum MonthPhase { past, current, future }

int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

MonthPhase monthPhase(int year, int month, [DateTime? today]) {
  final now = today ?? DateTime.now();
  final current = now.year * 12 + now.month - 1;
  final target = year * 12 + month - 1;
  if (target < current) return MonthPhase.past;
  return target == current ? MonthPhase.current : MonthPhase.future;
}

/// Days from [today] through the end of the requested month. Past months have none, while a future
/// month has all of its days. Mirrors `remainingDays` in `packages/shared/src/summary.ts`.
int remainingDays(int year, int month, [DateTime? today]) {
  final now = today ?? DateTime.now();
  return switch (monthPhase(year, month, now)) {
    MonthPhase.past => 0,
    MonthPhase.current => daysInMonth(year, month) - now.day + 1,
    MonthPhase.future => daysInMonth(year, month),
  };
}

/// Day open for daily spending. Until a day is closed it follows the calendar (today, or the 1st
/// of a future month); after that it only moves when the day is closed.
int? openDay(Month month, [DateTime? today]) {
  final now = today ?? DateTime.now();
  final phase = monthPhase(month.year, month.month, now);
  if (phase == MonthPhase.past) return null;
  final day = month.activeDay ?? (phase == MonthPhase.current ? now.day : 1);
  return day > daysInMonth(month.year, month.month) ? null : day;
}

/// Where "close day" moves the open day: to today when earlier days were left open, otherwise to
/// the next day. Past the last day means the month is done.
int? nextActiveDay(Month month, [DateTime? today]) {
  final now = today ?? DateTime.now();
  final current = openDay(month, now);
  if (current == null) return null;
  final calendarDay = monthPhase(month.year, month.month, now) == MonthPhase.current ? now.day : 0;
  final next = calendarDay > current + 1 ? calendarDay : current + 1;
  final last = daysInMonth(month.year, month.month) + 1;
  return next < last ? next : last;
}

CurrencyTotals _totals(List<MonthItem> items, Currency currency) {
  var income = 0.0, expenses = 0.0, paid = 0.0, pending = 0.0;
  var unresolved = 0;
  for (final item in items) {
    if (item.currency != currency) continue;
    if (item.amount == null || item.needsReview) unresolved++;
    final value = item.amount ?? 0;
    if (item.kind == EntryKind.income) {
      income += value;
      continue;
    }
    expenses += value;
    if (item.paid) {
      paid += value;
    } else {
      pending += value;
    }
  }
  income = round2(income);
  expenses = round2(expenses);
  return CurrencyTotals(
    income: income,
    expenses: expenses,
    net: round2(income - expenses),
    paid: round2(paid),
    pending: round2(pending),
    unresolved: unresolved,
  );
}

/// What a daily spend costs the allowance, in the month's main currency. Money spent in another
/// currency is money that won't become main currency, so it is worth what it would have become at
/// the rate: amount ÷ rate. `null` when its currency has no rate.
double? spendInMain(DailySpend spend, {required Currency main, required Rates rates}) {
  if (spend.currency == main) return spend.amount;
  final rate = rates[spend.currency];
  return rate != null && rate != 0 ? round2(spend.amount / rate) : null;
}

/// Computes the month's result and allowance, in the month's main currency. What is left in every
/// other currency, above or below zero, is converted into it at that currency's rate, with no fee
/// taken off. The result is then split across the open days.
///
/// [rates] are the live ones quoted against the month's main currency, used for the currencies the
/// month didn't lock.
MonthSummary summarizeMonth(
  Month month,
  List<MonthItem> items, {
  required Rates? rates,
  List<DailySpend> spends = const [],
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final main = month.mainCurrency;
  final effective = <Currency, double>{...?rates, ...month.lockedRates}..remove(main);

  final used = Currency.sorted([main, for (final item in items) item.currency]);
  final totals = {for (final currency in used) currency: _totals(items, currency)};

  final converting = Currency.sorted([...used, for (final spend in spends) spend.currency])..remove(main);
  final conversions = <CurrencyConversion>[];
  for (final currency in converting) {
    final rate = effective[currency];
    final net = totals[currency]?.net ?? 0;
    conversions.add(CurrencyConversion(
      currency: currency,
      rate: rate,
      rateLocked: month.lockedRates.containsKey(currency),
      net: net,
      converted: net == 0 ? 0 : (rate != null && rate != 0 ? round2(net / rate) : null),
    ));
  }
  final double? converted = conversions.any((conversion) => conversion.converted == null)
      ? null
      : round2(conversions.fold<double>(0, (sum, conversion) => sum + conversion.converted!));
  final net = converted == null ? null : round2(totals[main]!.net + converted);

  // Daily spending is kept out of the net: days before the open day reduce what gets spread over
  // the remaining days, while the open day's spending only eats into that day's budget.
  final activeDay = openDay(month, now);
  final days = activeDay == null ? 0 : daysInMonth(month.year, month.month) - activeDay + 1;
  var spentBefore = 0.0, spentToday = 0.0, spentTotal = 0.0;
  for (final spend in spends) {
    // Without a rate a spend in another currency can't be converted; it counts once a rate is available.
    final value = spendInMain(spend, main: main, rates: effective) ?? 0;
    spentTotal += value;
    // Spends on later days only exist after undoing a close; they are still money already gone.
    if (spend.day == activeDay) {
      spentToday += value;
    } else {
      spentBefore += value;
    }
  }
  final amount = days > 0 && net != null ? round2((net - spentBefore) / days) : null;

  return MonthSummary(
    main: main,
    totals: totals,
    rates: effective,
    conversions: conversions,
    converted: converted,
    net: net,
    allowance: Allowance(
      activeDay: activeDay,
      days: days,
      spentBefore: round2(spentBefore),
      spentToday: round2(spentToday),
      spentTotal: round2(spentTotal),
      amount: amount,
      remaining: amount == null ? null : round2(amount - spentToday),
    ),
  );
}

enum DayState { closed, open, upcoming }

class DayResult {
  DayResult({required this.day, required this.state, required this.budget, required this.spent, required this.result});

  final int day;
  final DayState state;

  /// The day's budget, in the main currency; for upcoming days, what they'd get if the open day closed now.
  final double? budget;

  /// Daily spending on the day, in the main currency.
  final double spent;

  /// budget − spent: what was left (or, negative, what went over); for the open day, what's still left.
  final double? result;
}

/// Per-day budgets and results for a month's calendar, rebuilt by replaying the month as if each
/// day had been closed in order. The open day uses the summary's own figures, so it matches Hoje.
List<DayResult> dayResults(Month month, MonthSummary summary, List<DailySpend> spends) {
  final total = daysInMonth(month.year, month.month);
  final open = summary.allowance.activeDay;
  final net = summary.net;
  final spentOn = List<double>.filled(total + 2, 0);
  for (final spend in spends) {
    if (spend.day >= 0 && spend.day < spentOn.length) spentOn[spend.day] += summary.cost(spend) ?? 0;
  }
  final spentAll = spentOn.fold<double>(0, (sum, value) => sum + value);
  // Upcoming days: what the open day's close would leave for each of the days after it.
  final upcomingDays = open == null ? 0 : total - open;
  final projected = net != null && upcomingDays > 0 ? round2((net - spentAll) / upcomingDays) : null;

  final results = <DayResult>[];
  var spentBefore = 0.0;
  for (var day = 1; day <= total; day++) {
    final spent = round2(spentOn[day]);
    if (open != null && day == open) {
      results.add(DayResult(
        day: day,
        state: DayState.open,
        budget: summary.allowance.amount,
        spent: summary.allowance.spentToday,
        result: summary.allowance.remaining,
      ));
    } else if (open != null && day > open) {
      results.add(DayResult(day: day, state: DayState.upcoming, budget: projected, spent: spent, result: projected));
    } else {
      final budget = net == null ? null : round2((net - spentBefore) / (total - day + 1));
      results.add(DayResult(
        day: day,
        state: DayState.closed,
        budget: budget,
        spent: spent,
        result: budget == null ? null : round2(budget - spent),
      ));
    }
    spentBefore += spentOn[day];
  }
  return results;
}

/// Spends grouped by day, newest day first, each day in the order it was recorded.
List<({int day, List<DailySpend> spends})> groupDailySpends(List<DailySpend> spends) {
  final ordered = [...spends]..sort((a, b) {
      final byDay = b.day.compareTo(a.day);
      return byDay != 0 ? byDay : a.createdAt.compareTo(b.createdAt);
    });
  final groups = <({int day, List<DailySpend> spends})>[];
  for (final spend in ordered) {
    if (groups.isEmpty || groups.last.day != spend.day) groups.add((day: spend.day, spends: []));
    groups.last.spends.add(spend);
  }
  return groups;
}
