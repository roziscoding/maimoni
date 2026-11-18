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
  const AllowanceHero({super.key, required this.year, required this.month, required this.summary});

  final int year;
  final int month;
  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final today = DateTime.now();
    final phase = monthPhase(year, month, today);
    final total = daysInMonth(year, month);
    final todayNumber = phase == MonthPhase.current ? today.day : null;
    final allowance = summary.allowance;
    final net = summary.transfer.eur == null ? null : summary.eur.net;
    // Past months show what was left over; open months show the daily budget.
    final headline = phase == MonthPhase.past ? net : allowance.eur;

    final List<Widget> details;
    if (phase == MonthPhase.past) {
      details = [Text('Líquido final em euros', style: TextStyle(fontSize: 14, color: palette.muted))];
    } else if (allowance.eur == null) {
      details = [Text('Sem cotação do euro, não dá para calcular o valor por dia.', style: TextStyle(fontSize: 14, color: palette.muted))];
    } else {
      details = [
        Text('≈ ${formatMoney(allowance.brl, Currency.brl)} por dia', style: money(fontSize: 16, color: palette.text)),
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
            formatMoney(headline, Currency.eur),
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

/// Port of `FlowStrip.vue`, stacked like a receipt: reais, the conversion, then euros.
class FlowStrip extends StatelessWidget {
  const FlowStrip({super.key, required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final transfer = summary.transfer;
    final lanes = [
      (
        currency: Currency.brl,
        cells: [
          _Cell('', 'Entrada', summary.brl.income),
          _Cell('−', 'Despesas', summary.brl.expenses),
          _Cell('−', 'Conversão', transfer.realized.convertedBrl),
          _Cell('−', 'Taxa', transfer.realized.feeBrl),
          _Cell('=', 'Em reais', transfer.remainingBrl, tone: 'result'),
        ],
      ),
      (
        currency: Currency.eur,
        cells: [
          _Cell('', 'Entrada', transfer.eur == null ? null : summary.eur.income),
          _Cell('−', 'Saída', summary.eur.expenses),
          _Cell('=', 'Líquido', transfer.eur == null ? null : summary.eur.net, tone: 'final'),
        ],
      ),
    ];

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
    final label = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: palette.highlighted);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          lane(lanes[0].currency, lanes[0].cells),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: palette.bgMuted,
              border: Border.symmetric(horizontal: BorderSide(color: palette.borderAccented)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (transfer.realized.sentBrl > 0)
                  _TransferRow(
                    icon: Icon(LucideIcons.circleCheck, size: 16, color: palette.success),
                    parts: [
                      Text('Realizado', style: label),
                      Text(formatMoney(transfer.realized.sentBrl, Currency.brl), style: secondary),
                      Text('incluindo ${formatMoney(transfer.realized.feeBrl, Currency.brl)} de taxa', style: TextStyle(fontSize: 13, color: palette.muted)),
                    ],
                    result: Text('= ${formatMoney(transfer.realized.receivedEur, Currency.eur)}', style: strong),
                  ),
                if (transfer.realized.sentBrl > 0 && transfer.projected.sentBrl > 0) const SizedBox(height: 6),
                if (transfer.projected.sentBrl > 0)
                  _TransferRow(
                    icon: Icon(LucideIcons.sparkles, size: 16, color: palette.muted),
                    parts: [
                      Text('Projetado', style: label),
                      Text(formatMoney(transfer.projected.sentBrl, Currency.brl), style: secondary),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('÷ ${formatRate(transfer.rate)}', style: secondary),
                        if (transfer.rateLocked)
                          Padding(padding: const EdgeInsets.only(left: 3), child: Icon(LucideIcons.lock, size: 12, color: palette.muted)),
                      ]),
                    ],
                    result: Text('= ${formatMoney(transfer.projected.eur, Currency.eur)}', style: strong),
                  ),
                if (transfer.realized.sentBrl == 0 && transfer.projected.sentBrl == 0)
                  Row(children: [
                    Icon(LucideIcons.arrowDown, size: 16, color: palette.muted),
                    const SizedBox(width: 8),
                    Text('Nada a converter', style: TextStyle(fontSize: 13, color: palette.muted)),
                  ]),
              ],
            ),
          ),
          lane(lanes[1].currency, lanes[1].cells),
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({required this.icon, required this.parts, required this.result});

  final Widget icon;
  final List<Widget> parts;
  final Widget result;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1, right: 8), child: icon),
        Expanded(child: Wrap(spacing: 8, runSpacing: 2, children: parts)),
        const SizedBox(width: 8),
        result,
      ],
    );
  }
}

/// Port of `RatePanel.vue`: the euro rate (live or locked) and the fee used by the projection.
class RatePanel extends StatelessWidget {
  const RatePanel({
    super.key,
    required this.month,
    required this.rate,
    required this.error,
    required this.summary,
    required this.refreshing,
    required this.onUpdate,
    required this.onRetry,
  });

  final Month month;
  final LiveRate? rate;
  final String? error;
  final MonthSummary summary;
  final bool refreshing;
  final ValueChanged<Json> onUpdate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final locked = month.exchangeRate != null;
    final transfer = summary.transfer;
    final live = rate;
    final small = TextStyle(fontSize: 12, color: palette.muted);

    final Widget badge;
    if (locked) {
      badge = const Pill(label: 'travado', icon: LucideIcons.lock);
    } else if (live?.stale ?? false) {
      badge = const Pill(label: 'desatualizado', icon: LucideIcons.clockAlert, tone: Tone.warning);
    } else if (live != null) {
      badge = const Pill(label: 'ao vivo', icon: LucideIcons.radio, outline: true);
    } else {
      badge = const SizedBox();
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: Text('Preço do euro', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.muted))),
                  badge,
                ]),
                const SizedBox(height: 12),
                Text(formatRate(transfer.rate), style: money(fontSize: 30, fontWeight: FontWeight.w600, color: palette.highlighted)),
                const SizedBox(height: 12),
                if (live != null)
                  Text.rich(
                    TextSpan(children: [
                      if (locked) ...[
                        const TextSpan(text: 'Ao vivo agora: '),
                        TextSpan(text: formatRate(live.rate), style: money(fontSize: 12, color: palette.toned)),
                        const TextSpan(text: '. '),
                      ],
                      TextSpan(text: 'Fonte: ${live.source.label}, ${formatDateTime(live.fetchedAt)}.'),
                    ]),
                    style: small,
                  )
                else
                  Text('Nenhuma cotação disponível agora. Trave um valor para calcular o mês.', style: small.copyWith(color: palette.warning)),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${live != null ? 'Falha ao atualizar' : 'Motivo'}: $error', style: small.copyWith(color: palette.error)),
                  ),
                const SizedBox(height: 12),
                if (locked)
                  ActionButton(
                    label: 'Usar cotação ao vivo',
                    icon: LucideIcons.lockOpen,
                    style: ActionStyle.subtle,
                    onPressed: () => onUpdate({'exchangeRate': null}),
                  )
                else if (live != null)
                  ActionButton(
                    label: 'Travar em ${formatRate(live.rate)}',
                    icon: LucideIcons.lock,
                    style: ActionStyle.subtle,
                    onPressed: () => onUpdate({'exchangeRate': live.rate}),
                  )
                else
                  ActionButton(
                    label: 'Tentar novamente',
                    icon: LucideIcons.refreshCw,
                    style: ActionStyle.subtle,
                    loading: refreshing,
                    onPressed: onRetry,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
