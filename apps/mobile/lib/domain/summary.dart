import '../api/models.dart';
import 'expression.dart';

/// Port of `packages/shared/src/summary.ts`. Keep both in sync: the app recomputes the summary
/// locally so optimistic edits update every figure instantly, exactly like the web.

double _d(Object? value) => (value as num).toDouble();
double? _dn(Object? value) => value == null ? null : (value as num).toDouble();

class CurrencyTotals {
  CurrencyTotals({
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

  final double income;
  final double expenses;
  final double net;
  final double paid;
  final double pending;

  /// Items still missing a value or flagged for review.
  final int unresolved;

  CurrencyTotals copyWith({double? income, double? net}) => CurrencyTotals(
        income: income ?? this.income,
        expenses: expenses,
        net: net ?? this.net,
        paid: paid,
        pending: pending,
        unresolved: unresolved,
      );
}

enum FeeSource { manual, wise, fallback }

class Realized {
  Realized({required this.sentBrl, required this.convertedBrl, required this.feeBrl, required this.receivedEur});

  factory Realized.fromJson(Json json) => Realized(
        sentBrl: _d(json['sentBrl']),
        convertedBrl: _d(json['convertedBrl']),
        feeBrl: _d(json['feeBrl']),
        receivedEur: _d(json['receivedEur']),
      );

  /// Total BRL debited by completed conversions, fees included.
  final double sentBrl;
  final double convertedBrl;
  final double feeBrl;
  final double receivedEur;
}

class Projected {
  Projected({required this.sentBrl, required this.feeBrl, required this.eur});

  factory Projected.fromJson(Json json) =>
      Projected(sentBrl: _d(json['sentBrl']), feeBrl: _d(json['feeBrl']), eur: _dn(json['eur']));

  /// Positive BRL balance still expected to be converted.
  final double sentBrl;
  final double feeBrl;

  /// Expected EUR for the remaining BRL; `null` without a rate.
  final double? eur;
}

class Transfer {
  Transfer({
    required this.rate,
    required this.rateLocked,
    required this.wiseFee,
    required this.feeSource,
    required this.remainingBrl,
    required this.realized,
    required this.projected,
    required this.eur,
  });

  factory Transfer.fromJson(Json json) => Transfer(
        rate: _dn(json['rate']),
        rateLocked: json['rateLocked'] as bool,
        wiseFee: _d(json['wiseFee']),
        feeSource: FeeSource.values.byName(json['feeSource'] as String),
        remainingBrl: _d(json['remainingBrl']),
        realized: Realized.fromJson(json['realized'] as Json),
        projected: Projected.fromJson(json['projected'] as Json),
        eur: _dn(json['eur']),
      );

  /// EUR→BRL rate used for the conversion.
  final double? rate;
  final bool rateLocked;

  /// Effective fee as a fraction of sentBrl.
  final double wiseFee;
  final FeeSource feeSource;

  /// BRL left after completed conversions; negative when they exceeded this month's net.
  final double remainingBrl;
  final Realized realized;
  final Projected projected;

  /// Completed EUR plus the projection for the remaining BRL.
  final double? eur;
}

class Allowance {
  Allowance({
    required this.activeDay,
    required this.days,
    required this.spentBefore,
    required this.spentToday,
    required this.spentTotal,
    required this.eur,
    required this.remainingEur,
    required this.brl,
  });

  factory Allowance.fromJson(Json json) => Allowance(
        activeDay: json['activeDay'] as int?,
        days: json['days'] as int,
        spentBefore: _d(json['spentBefore']),
        spentToday: _d(json['spentToday']),
        spentTotal: _d(json['spentTotal']),
        eur: _dn(json['eur']),
        remainingEur: _dn(json['remainingEur']),
        brl: _dn(json['brl']),
      );

  /// Day of the month open for daily spending; `null` for past months and once every day was closed.
  final int? activeDay;

  /// Days the budget is spread over: from the open day to the end of the month.
  final int days;

  /// Daily spending on days other than the open day; it already came out of the budget being spread.
  final double spentBefore;

  /// Daily spending on the open day, in EUR.
  final double spentToday;

  /// All daily spending of the month, in EUR.
  final double spentTotal;

  /// Budget for the open day: (EUR net − spentBefore) ÷ days.
  final double? eur;

  /// What is left of the open day's budget after its spending.
  final double? remainingEur;
  final double? brl;
}

class MonthSummary {
  MonthSummary({required this.brl, required this.eur, required this.transfer, required this.allowance});

  factory MonthSummary.fromJson(Json json) => MonthSummary(
        brl: CurrencyTotals.fromJson(json['brl'] as Json),
        eur: CurrencyTotals.fromJson(json['eur'] as Json),
        transfer: Transfer.fromJson(json['transfer'] as Json),
        allowance: Allowance.fromJson(json['allowance'] as Json),
      );

  final CurrencyTotals brl;
  final CurrencyTotals eur;
  final Transfer transfer;
  final Allowance allowance;
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

/// What a daily spend costs the EUR allowance. A BRL spend is worth what it would have become
/// through Wise: amount × (1 − fee) ÷ rate. `null` when a BRL spend has no rate to convert with.
double? spendInEur(DailySpend spend, {required double? rate, required double wiseFee}) {
  if (spend.currency == Currency.eur) return spend.amount;
  return rate != null && rate != 0 ? round2((spend.amount * (1 - wiseFee)) / rate) : null;
}

double? spendInEurFor(DailySpend spend, Transfer transfer) =>
    spendInEur(spend, rate: transfer.rate, wiseFee: transfer.wiseFee);

({double feeBrl, double fraction, FeeSource source}) _wiseFee(
  Month month,
  double sentBrl,
  WiseQuote? quote,
  double fallbackFee,
) {
  final manual = month.wiseFee;
  if (manual != null) return (feeBrl: sentBrl * manual, fraction: manual, source: FeeSource.manual);
  if (quote != null && quote.sendAmount > 0) {
    final fraction = quote.fee / quote.sendAmount;
    return (
      feeBrl: quote.sendAmount == sentBrl ? quote.fee : sentBrl * fraction,
      fraction: fraction,
      source: FeeSource.wise,
    );
  }
  return (feeBrl: sentBrl * fallbackFee, fraction: fallbackFee, source: FeeSource.fallback);
}

/// Computes the month's result and allowance. Completed conversions use their actual amounts; only
/// the BRL left after them is projected through Wise. EUR expenses are paid from actual plus
/// projected EUR, and the remainder is split across the open days.
MonthSummary summarizeMonth(
  Month month,
  List<MonthItem> items, {
  required double? rate,
  WiseQuote? quote,
  required double fallbackFee,
  List<DailySpend> spends = const [],
  List<Conversion> conversions = const [],
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final brl = _totals(items, Currency.brl);
  final eurOwn = _totals(items, Currency.eur);
  final effectiveRate = month.exchangeRate ?? rate;

  var sentBrl = 0.0, convertedBrl = 0.0, realizedFee = 0.0, receivedEur = 0.0;
  for (final conversion in conversions) {
    sentBrl += conversion.sentBrl;
    convertedBrl += conversion.sentBrl - conversion.feeBrl;
    realizedFee += conversion.feeBrl;
    receivedEur += conversion.receivedEur;
  }
  final remainingBrl = round2(brl.net - sentBrl);
  final projectedBrl = remainingBrl > 0 ? remainingBrl : 0.0;
  final fee = _wiseFee(month, projectedBrl, quote, fallbackFee);
  final double? projectedEur = projectedBrl == 0
      ? 0
      : effectiveRate != null && effectiveRate != 0
          ? round2((projectedBrl - fee.feeBrl) / effectiveRate)
          : null;
  final transferEur = projectedEur == null ? null : round2(receivedEur + projectedEur);

  final eurIncome = round2(eurOwn.income + receivedEur + (projectedEur ?? 0));
  final eur = eurOwn.copyWith(income: eurIncome, net: round2(eurIncome - eurOwn.expenses));

  // Daily spending is kept out of the EUR totals: days before the open day reduce what gets spread
  // over the remaining days, while the open day's spending only eats into that day's budget.
  final activeDay = openDay(month, now);
  final days = activeDay == null ? 0 : daysInMonth(month.year, month.month) - activeDay + 1;
  var spentBefore = 0.0, spentToday = 0.0, spentTotal = 0.0;
  for (final spend in spends) {
    // Without a rate a BRL spend can't be converted; it counts once a rate is available.
    final value = spendInEur(spend, rate: effectiveRate, wiseFee: fee.fraction) ?? 0;
    spentTotal += value;
    if (spend.day == activeDay) {
      spentToday += value;
    } else {
      spentBefore += value;
    }
  }
  final allowanceEur = days > 0 && transferEur != null ? round2((eur.net - spentBefore) / days) : null;

  return MonthSummary(
    brl: brl,
    eur: eur,
    transfer: Transfer(
      rate: effectiveRate,
      rateLocked: month.exchangeRate != null,
      wiseFee: fee.fraction,
      feeSource: fee.source,
      remainingBrl: remainingBrl,
      realized: Realized(
        sentBrl: round2(sentBrl),
        convertedBrl: round2(convertedBrl),
        feeBrl: round2(realizedFee),
        receivedEur: round2(receivedEur),
      ),
      projected: Projected(sentBrl: round2(projectedBrl), feeBrl: round2(fee.feeBrl), eur: projectedEur),
      eur: transferEur,
    ),
    allowance: Allowance(
      activeDay: activeDay,
      days: days,
      spentBefore: round2(spentBefore),
      spentToday: round2(spentToday),
      spentTotal: round2(spentTotal),
      eur: allowanceEur,
      remainingEur: allowanceEur == null ? null : round2(allowanceEur - spentToday),
      brl: allowanceEur != null && effectiveRate != null ? round2(allowanceEur * effectiveRate) : null,
    ),
  );
}

enum DayState { closed, open, upcoming }

class DayResult {
  DayResult({required this.day, required this.state, required this.budget, required this.spent, required this.result});

  final int day;
  final DayState state;

  /// The day's budget in EUR; for upcoming days, what they'd get if the open day closed now.
  final double? budget;

  /// Daily spending on the day, in EUR.
  final double spent;

  /// budget − spent: what was left (or, negative, what went over); for the open day, what's still left.
  final double? result;
}

/// Per-day budgets and results for a month's calendar, rebuilt by replaying the month as if each
/// day had been closed in order. The open day uses the summary's own figures, so it matches Hoje.
List<DayResult> dayResults(Month month, MonthSummary summary, List<DailySpend> spends) {
  final total = daysInMonth(month.year, month.month);
  final open = summary.allowance.activeDay;
  final hasBudget = summary.transfer.eur != null;
  final spentOn = List<double>.filled(total + 2, 0);
  for (final spend in spends) {
    if (spend.day >= 0 && spend.day < spentOn.length) spentOn[spend.day] += spendInEurFor(spend, summary.transfer) ?? 0;
  }
  final spentAll = spentOn.fold<double>(0, (sum, value) => sum + value);
  final upcomingDays = open == null ? 0 : total - open;
  final projected = hasBudget && upcomingDays > 0 ? round2((summary.eur.net - spentAll) / upcomingDays) : null;

  final results = <DayResult>[];
  var spentBefore = 0.0;
  for (var day = 1; day <= total; day++) {
    final spent = round2(spentOn[day]);
    if (open != null && day == open) {
      results.add(DayResult(
        day: day,
        state: DayState.open,
        budget: summary.allowance.eur,
        spent: summary.allowance.spentToday,
        result: summary.allowance.remainingEur,
      ));
    } else if (open != null && day > open) {
      results.add(DayResult(day: day, state: DayState.upcoming, budget: projected, spent: spent, result: projected));
    } else {
      final budget = hasBudget ? round2((summary.eur.net - spentBefore) / (total - day + 1)) : null;
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
