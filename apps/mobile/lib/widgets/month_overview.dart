import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../theme.dart';
import 'common.dart';

/// Port of `AllowanceHero.vue`: the daily budget (or the final result of a past month) and one
/// tick per day of the month.
class AllowanceHero extends StatelessWidget {
  const AllowanceHero({super.key, required this.year, required this.month, required this.summary, required this.exchange});

  final int year;
  final int month;
  final MonthSummary summary;

  /// Whether the month has more than one currency, and so equivalents in the others to show.
  final bool exchange;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final today = DateTime.now();
    final phase = monthPhase(year, month, today);
    final total = daysInMonth(year, month);
    final todayNumber = phase == MonthPhase.current ? today.day : null;
    final allowance = summary.allowance;
    final amount = allowance.amount;
    // Past months show what was left over; open months show the daily budget.
    final headline = phase == MonthPhase.past ? summary.net : amount;

    final List<Widget> details;
    if (phase == MonthPhase.past) {
      details = [
        Text(
          exchange ? 'Líquido final em ${currencyPlural(summary.main).toLowerCase()}' : 'Líquido final',
          style: TextStyle(fontSize: 14, color: palette.muted),
        ),
      ];
    } else if (amount == null) {
      details = [Text('Sem cotação, não dá para calcular o valor por dia.', style: TextStyle(fontSize: 14, color: palette.muted))];
    } else {
      details = [
        // The daily budget in each other currency of the month that has a rate.
        if (exchange)
          for (final conversion in summary.conversions)
            if (conversion.rate != null)
              Text('≈ ${formatMoney(amount * conversion.rate!, conversion.currency)} por dia', style: money(fontSize: 16, color: palette.text)),
        Text(
          phase == MonthPhase.current
              ? (allowance.days == 1 ? 'Último dia do mês' : '${allowance.days} dias restantes, contando hoje')
              : 'Mês futuro, dividido pelos ${allowance.days} dias',
          style: TextStyle(fontSize: 14, color: palette.muted),
        ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          phase == MonthPhase.past ? 'Mês encerrado, sobrou' : 'Por dia',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.muted),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMoney(headline, summary.main),
            style: money(fontSize: 48, fontWeight: FontWeight.w600, height: 1.1, color: (headline ?? 0) < 0 ? palette.error : palette.highlighted),
          ),
        ),
        const SizedBox(height: 12),
        ...details,
        const SizedBox(height: 20),
        // One tick per day: spent days fade, today stands out, weekends are shorter so the weeks read at a glance.
        SizedBox(
          height: 36,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var day = 1; day <= total; day++) ...[
                if (day > 1) const SizedBox(width: 3),
                Expanded(child: _tick(palette, day, phase, todayNumber)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 16,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final style = money(fontSize: 12, color: palette.dimmed);
              return Stack(
                children: [
                  Positioned(left: 0, child: Text('1', style: style)),
                  Positioned(right: 0, child: Text('$total', style: style)),
                  if (todayNumber != null)
                    Positioned(
                      left: ((todayNumber - 0.5) / total * constraints.maxWidth - 16).clamp(0, constraints.maxWidth - 32),
                      width: 32,
                      child: Text('hoje', textAlign: TextAlign.center, style: style.copyWith(color: palette.highlighted, fontWeight: FontWeight.w500)),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tick(Palette palette, int day, MonthPhase phase, int? todayNumber) {
    final weekday = DateTime(year, month, day).weekday;
    final weekend = weekday == DateTime.saturday || weekday == DateTime.sunday;
    final isToday = day == todayNumber;
    final spent = phase == MonthPhase.past || (todayNumber != null && day < todayNumber);
    return Container(
      height: isToday ? 36 : (weekend ? 20 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: isToday ? palette.bgInverted : (spent ? palette.bgAccented : palette.bgInverted.withValues(alpha: 0.55)),
      ),
    );
  }
}

class _Cell {
  const _Cell(this.op, this.label, this.value, {this.tone});

  final String op;
  final String label;
  final double? value;

  /// `result` or `final`.
  final String? tone;
}

/// The month as a receipt: one block per other currency, each ending in what is left in it and
/// how that becomes main currency, then the main currency's block, which takes those in.
class FlowStrip extends StatelessWidget {
  const FlowStrip({super.key, required this.summary, required this.currencies});

  final MonthSummary summary;

  /// The currencies to show a block for. The month's main one is always shown, last.
  final List<Currency> currencies;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final main = summary.main;
    final others = currencies.where((currency) => currency != main).toList();
    final own = summary.totals[main] ?? CurrencyTotals.empty;

    Color valueColor(_Cell cell) {
      final value = cell.value;
      if (value != null && value < 0) return palette.error;
      if (cell.tone == 'final' && value != null && value > 0) return palette.success;
      return cell.tone != null ? palette.highlighted : palette.text;
    }

    Widget lane(Currency currency, List<_Cell> cells) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              for (final cell in cells)
                Container(
                  margin: EdgeInsets.only(top: cell.tone != null ? 4 : 0),
                  padding: EdgeInsets.only(top: cell.tone != null ? 8 : 4, bottom: 4),
                  decoration: cell.tone != null ? BoxDecoration(border: Border(top: BorderSide(color: palette.border))) : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      SizedBox(width: 16, child: Text(cell.op, style: money(fontSize: 14, color: palette.muted))),
                      Expanded(child: Text(cell.label, style: TextStyle(fontSize: 14, color: palette.muted))),
                      Text(
                        formatMoney(cell.value, currency),
                        style: money(fontSize: 18, fontWeight: cell.tone != null ? FontWeight.w600 : FontWeight.w400, color: valueColor(cell)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

    final secondary = money(fontSize: 13, color: palette.toned);
    final strong = money(fontSize: 13, fontWeight: FontWeight.w500, color: palette.highlighted);

    /// What is left in [currency], on its way to the main one.
    Widget conversion(CurrencyConversion entry) {
      final currency = entry.currency;
      final Widget content;
      if (entry.net == 0) {
        content = Row(children: [
          Icon(LucideIcons.arrowDown, size: 16, color: palette.muted),
          const SizedBox(width: 8),
          Text('Nada a converter', style: TextStyle(fontSize: 13, color: palette.muted)),
        ]);
      } else {
        content = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 1, right: 8), child: Icon(LucideIcons.arrowDown, size: 16, color: palette.muted)),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(formatMoney(entry.net, currency), style: secondary),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('÷ ${formatRate(entry.rate, currency)}', style: secondary),
                    if (entry.rateLocked)
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Icon(LucideIcons.lock, size: 12, color: palette.muted, semanticLabel: 'cotação travada'),
                      ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('= ${formatMoney(entry.converted, main)}', style: strong),
          ],
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: palette.bgAccented,
        ),
        child: content,
      );
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final currency in others) ...[
            lane(currency, [
              _Cell('', 'Entrada', (summary.totals[currency] ?? CurrencyTotals.empty).income),
              _Cell('−', 'Saída', (summary.totals[currency] ?? CurrencyTotals.empty).expenses),
              _Cell('=', 'Em ${currencyPlural(currency).toLowerCase()}', (summary.totals[currency] ?? CurrencyTotals.empty).net, tone: 'result'),
            ]),
            if (summary.conversions.where((entry) => entry.currency == currency).firstOrNull case final entry?) conversion(entry),
          ],
          lane(main, [
            _Cell('', 'Entrada', own.income),
            // Only where there is another currency to convert from.
            if (others.isNotEmpty) _Cell('+', 'Convertido', summary.converted),
            _Cell('−', 'Saída', own.expenses),
            _Cell('=', 'Líquido', summary.net, tone: 'final'),
          ]),
        ],
      ),
    );
  }
}

/// The rate of each currency the month converts from: one row per currency, with a button that
/// freezes it at the live value or sends it back to live.
class RatePanel extends StatelessWidget {
  const RatePanel({
    super.key,
    required this.rates,
    required this.error,
    required this.summary,
    required this.refreshing,
    required this.onLock,
    required this.onUnlock,
    required this.onRetry,
  });

  /// Live rates quoted against the month's main currency.
  final LiveRates? rates;
  final String? error;
  final MonthSummary summary;
  final bool refreshing;
  final void Function(Currency currency, double rate) onLock;
  final ValueChanged<Currency> onUnlock;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final live = rates;
    final small = TextStyle(fontSize: 12, color: palette.muted);

    Widget row(CurrencyConversion conversion) {
      final liveRate = live?.rates[conversion.currency];
      final name = currencyName(conversion.currency);

      final Widget status;
      if (conversion.rateLocked) {
        status = Text(liveRate == null ? 'Travada' : 'Travada · ao vivo ${formatRate(liveRate, conversion.currency)}', style: small);
      } else if (conversion.rate == null) {
        status = Text('Sem cotação agora', style: small.copyWith(color: palette.warning));
      } else if (live?.stale ?? false) {
        status = Text('Desatualizada', style: small.copyWith(color: palette.warning));
      } else {
        status = Text('Ao vivo', style: small);
      }

      final Widget action;
      if (conversion.rateLocked) {
        action = IconButton.filledTonal(
          tooltip: 'Usar cotação ao vivo de $name',
          icon: const Icon(LucideIcons.lock, size: 18),
          onPressed: () => onUnlock(conversion.currency),
        );
      } else if (liveRate != null) {
        action = IconButton(
          tooltip: 'Travar $name em ${formatRate(liveRate, conversion.currency)}',
          icon: Icon(LucideIcons.lockOpen, size: 18, color: palette.muted),
          onPressed: () => onLock(conversion.currency, liveRate),
        );
      } else {
        action = IconButton(
          tooltip: 'Tentar novamente',
          icon: refreshing
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(LucideIcons.refreshCw, size: 18, color: palette.muted),
          onPressed: refreshing ? null : onRetry,
        );
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.border))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.highlighted)),
                  const SizedBox(height: 2),
                  status,
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(formatRate(conversion.rate, conversion.currency), style: money(fontSize: 18, fontWeight: FontWeight.w600, color: palette.highlighted)),
            const SizedBox(width: 4),
            action,
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Cotações'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Text('Quanto vale ${formatMoney(1, summary.main)} em cada moeda do mês.', style: small),
              ),
              ...summary.conversions.map(row),
          if (live != null || error != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.border))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (live != null) Text('Fonte: ${live.source.label}, ${formatDateTime(live.fetchedAt)}.', style: small),
                  if (error != null)
                    Text('${live != null ? 'Falha ao atualizar' : 'Motivo'}: $error', style: small.copyWith(color: palette.error)),
                ],
              ),
            ),
            ],
          ),
        ),
      ],
    );
  }
}
