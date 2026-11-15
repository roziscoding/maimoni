import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../state/month_controller.dart';
import '../state/months_store.dart';
import '../theme.dart';
import 'common.dart';
import 'spends.dart';

enum HistoryView { calendar, spends }

/// Port of `DailySpendHistory.vue`: a month's days as a calendar (budget vs. spent per day) or as
/// a statement of every spend, with a month picker.
class DailySpendHistory extends StatefulWidget {
  const DailySpendHistory({
    super.key,
    required this.controller,
    required this.view,
    required this.onViewChanged,
    required this.onMonthChanged,
    required this.onOpenToday,
  });

  final MonthController controller;
  final HistoryView view;
  final ValueChanged<HistoryView> onViewChanged;
  final void Function(int year, int month) onMonthChanged;
  final VoidCallback onOpenToday;

  @override
  State<DailySpendHistory> createState() => _DailySpendHistoryState();
}

class _DailySpendHistoryState extends State<DailySpendHistory> {
  int? _selected;

  /// Monday first, like Spanish calendars.
  static const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

  @override
  void didUpdateWidget(DailySpendHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, MonthsStore.instance]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final palette = context.palette;
    final controller = widget.controller;
    final year = controller.year;
    final month = controller.month;
    final data = controller.data;
    final summary = controller.summary;
    final months = MonthsStore.instance.months;

    final header = Row(
      children: [
        Segmented<HistoryView>(
          value: widget.view,
          small: true,
          options: const [
            (value: HistoryView.calendar, label: 'Calendário', icon: LucideIcons.calendarDays),
            (value: HistoryView.spends, label: 'Extrato', icon: LucideIcons.list),
          ],
          onChanged: widget.onViewChanged,
        ),
        const Spacer(),
        if (months.isNotEmpty)
          DropdownButton<String>(
            value: months.any((entry) => entry.year == year && entry.monthNumber == month) ? '$year-$month' : null,
            underline: const SizedBox(),
            isDense: true,
            borderRadius: BorderRadius.circular(8),
            style: TextStyle(fontSize: 14, color: palette.text),
            items: [
              for (final entry in months)
                DropdownMenuItem(value: '${entry.year}-${entry.monthNumber}', child: Text(monthLabel(entry.year, entry.monthNumber))),
            ],
            onChanged: (value) {
              if (value == null) return;
              final [y, m] = value.split('-').map(int.parse).toList();
              widget.onMonthChanged(y, m);
            },
          ),
      ],
    );

    Widget body;
    if (controller.loading) {
      body = const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
    } else if (data == null || summary == null) {
      final notFound = controller.error?.notFound ?? false;
      body = EmptyState(
        icon: LucideIcons.calendarX,
        title: notFound ? '${monthLabel(year, month)} não existe' : 'Não foi possível carregar o mês',
        description: notFound ? null : controller.error?.message,
      );
    } else if (data.spends.isEmpty && summary.allowance.activeDay == null) {
      // Months before daily tracking existed have nothing to show day by day.
      body = EmptyState(
        icon: LucideIcons.calendarOff,
        title: 'Nenhum gasto do dia a dia em ${monthName(month).toLowerCase()}',
        description: 'O calendário mostra os dias de meses em que os gastos foram lançados em Hoje.',
      );
    } else {
      body = _content(context, data, summary);
    }

    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.only(top: 32),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, const SizedBox(height: 24), body]),
    );
  }

  Widget _content(BuildContext context, MonthDetail data, MonthSummary summary) {
    final palette = context.palette;
    final controller = widget.controller;
    final year = controller.year;
    final month = controller.month;
    final days = dayResults(data.month, summary, data.spends);
    final closed = days.where((day) => day.state == DayState.closed && day.result != null).toList();
    final withinBudget = closed.where((day) => day.result! >= 0).length;
    // Closed days against the month's original plan (net ÷ days in month each). Summing the daily
    // results would double count: what's left on one day rolls into the next days' budgets.
    final balance = days.isEmpty
        ? 0.0
        : closed.length * summary.eur.net / days.length - closed.fold<double>(0, (sum, day) => sum + day.spent);

    final heading = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 8,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(monthLabel(year, month), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: palette.highlighted)),
            Text(
              closed.isEmpty
                  ? 'Nenhum dia fechado ainda.'
                  : '$withinBudget de ${closed.length} ${plural(closed.length, 'dia fechado', 'dias fechados')} dentro do valor do dia.',
              style: TextStyle(fontSize: 14, color: palette.muted),
            ),
          ],
        ),
        if (closed.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                signedMoney(balance),
                style: money(fontSize: 24, fontWeight: FontWeight.w600, color: balance >= 0 ? palette.success : palette.error),
              ),
              Text('${balance >= 0 ? 'sobrou' : 'passou'} nos dias fechados', style: TextStyle(fontSize: 14, color: palette.muted)),
            ],
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        const SizedBox(height: 24),
        if (widget.view == HistoryView.calendar)
          ..._calendar(context, data, summary, days)
        else
          ..._statement(context, data, summary),
      ],
    );
  }

  List<Widget> _calendar(BuildContext context, MonthDetail data, MonthSummary summary, List<DayResult> days) {
    final palette = context.palette;
    final controller = widget.controller;
    final year = controller.year;
    final month = controller.month;
    final selected = _selected ?? summary.allowance.activeDay ?? (data.spends.isEmpty ? 1 : data.spends.last.day);
    final selectedDay = days.where((day) => day.day == selected).firstOrNull;
    final selectedSpends = data.spends.where((spend) => spend.day == selected).toList();
    final leadingBlanks = (DateTime(year, month, 1).weekday + 6) % 7;
    const gap = 4.0;

    final grid = LayoutBuilder(builder: (context, constraints) {
      final size = (constraints.maxWidth - gap * 6) / 7;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final weekday in _weekdays)
            SizedBox(
              width: size,
              child: Text(weekday, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: palette.muted)),
            ),
          for (var blank = 0; blank < leadingBlanks; blank++) SizedBox(width: size, height: size),
          for (final day in days)
            _DayCell(day: day, size: size, selected: selected == day.day, onTap: () => setState(() => _selected = day.day)),
        ],
      );
    });

    return [
      grid,
      if (selectedDay != null) ...[
        const SizedBox(height: 24),
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(dayLabel(year, month, selectedDay.day), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: palette.highlighted)),
              if (selectedDay.state != DayState.upcoming && selectedDay.result != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Stat(label: 'Valor do dia', value: formatMoney(selectedDay.budget, Currency.eur)),
                    const SizedBox(width: 20),
                    _Stat(label: 'Gasto', value: formatMoney(selectedDay.spent, Currency.eur)),
                    const SizedBox(width: 20),
                    _Stat(
                      label: selectedDay.state == DayState.open ? 'Restam' : 'Resultado',
                      value: selectedDay.state == DayState.open ? formatMoney(selectedDay.result, Currency.eur) : signedMoney(selectedDay.result!),
                      color: selectedDay.result! >= 0 ? palette.success : palette.error,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (selectedDay.state == DayState.closed) ...[
                SpendForm(key: ValueKey('form-${controller.year}-${controller.month}-${selectedDay.day}'), day: selectedDay.day, create: controller.addSpend),
                const SizedBox(height: 8),
              ],
              if (selectedSpends.isNotEmpty)
                SpendList(
                  spends: selectedSpends,
                  inEur: (spend) => spendInEurFor(spend, summary.transfer),
                  onUpdate: controller.updateSpend,
                  onRemove: controller.removeSpend,
                )
              else if (selectedDay.state == DayState.upcoming)
                Text(
                  'Ainda não chegou.${selectedDay.budget == null ? '' : ' Se o dia aberto fechasse agora, este dia teria ${formatMoney(selectedDay.budget, Currency.eur)}.'}',
                  style: TextStyle(fontSize: 14, color: palette.muted),
                )
              else
                Text('Nenhum gasto neste dia.', style: TextStyle(fontSize: 14, color: palette.muted)),
              if (selectedDay.state == DayState.open)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: widget.onOpenToday,
                    icon: const Icon(LucideIcons.wallet, size: 16),
                    label: const Text('Lançar gastos em Hoje'),
                  ),
                ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _statement(BuildContext context, MonthDetail data, MonthSummary summary) {
    final palette = context.palette;
    final controller = widget.controller;
    final groups = groupDailySpends(data.spends);
    if (groups.isEmpty) {
      return const [
        EmptyState(
          icon: LucideIcons.receiptText,
          title: 'Nenhum gasto neste mês',
          description: 'Os gastos lançados no dia a dia aparecerão aqui.',
        ),
      ];
    }
    return [
      for (final group in groups)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Panel(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dayLabel(controller.year, controller.month, group.day),
                        style: TextStyle(fontWeight: FontWeight.w600, color: palette.highlighted),
                      ),
                    ),
                    Text(
                      '${group.spends.length} ${plural(group.spends.length, 'gasto', 'gastos')}',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 4),
                SpendList(
                  spends: group.spends,
                  inEur: (spend) => spendInEurFor(spend, summary.transfer),
                  onUpdate: controller.updateSpend,
                  onRemove: controller.removeSpend,
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: palette.muted)),
        Text(value, style: money(fontSize: 14, fontWeight: color == null ? null : FontWeight.w600, color: color ?? palette.text)),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.size, required this.selected, required this.onTap});

  final DayResult day;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final open = day.state == DayState.open;
    final upcoming = day.state == DayState.upcoming;
    final result = day.result;

    Widget? value;
    if (day.state == DayState.closed && result != null) {
      value = Text(
        compactSigned(result),
        style: money(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2, color: result >= 0 ? palette.success : palette.error),
      );
    } else if (open && result != null) {
      value = Text(
        compactSigned(result).replaceFirst('+', ''),
        style: money(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2, color: result >= 0 ? palette.highlighted : palette.error),
      );
    }

    // The result as a bar: what was left fills from the left (full when nothing was spent), what
    // went over fills red from the right (full at a whole day's budget over).
    Widget? bar;
    if (!upcoming && result != null && day.budget != null && day.budget != 0) {
      final over = result < 0;
      final fraction = (result.abs() / day.budget!).clamp(0, 1).toDouble();
      bar = Container(
        height: 4,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(color: palette.bgAccented, borderRadius: BorderRadius.circular(999)),
        child: FractionallySizedBox(
          alignment: over ? Alignment.centerRight : Alignment.centerLeft,
          widthFactor: fraction,
          child: Container(
            decoration: BoxDecoration(
              color: over ? palette.error : (open ? palette.bgInverted : palette.success),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: upcoming ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected || open ? palette.bgInverted : palette.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: open ? FontWeight.w600 : FontWeight.normal,
                  color: open ? palette.highlighted : palette.muted,
                ),
              ),
              const Spacer(),
              ?value,
              ?bar,
            ],
          ),
        ),
      ),
    );
  }
}
