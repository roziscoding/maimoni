import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../state/month_controller.dart';
import '../state/months_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/spends.dart';

enum HistoryView { calendar, spends }

/// A month's days as a calendar (budget against spent per day) or as a statement of every spend.
/// The title picks the month.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.year, required this.month});

  final int year;
  final int month;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late MonthController _controller = MonthController(widget.year, widget.month);
  HistoryView _view = HistoryView.calendar;

  /// Monday first, like Spanish calendars.
  static const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

  void _show(int year, int month) {
    if (year == _controller.year && month == _controller.month) return;
    final previous = _controller;
    setState(() => _controller = MonthController(year, month));
    previous.dispose();
  }

  void _pickMonth() {
    final months = MonthsStore.instance.months;
    showSheet<void>(
      context,
      title: 'Histórico de',
      body: (context) => Column(
        children: [
          for (final entry in months)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(monthLabel(entry.year, entry.monthNumber)),
              trailing: entry.year == _controller.year && entry.monthNumber == _controller.month
                  ? Icon(LucideIcons.check, size: 20, color: context.palette.highlighted)
                  : null,
              onTap: () {
                Navigator.of(context).pop();
                _show(entry.year, entry.monthNumber);
              },
            ),
        ],
      ),
    );
  }

  void _openDay(int day) {
    final controller = _controller;
    showSheet<void>(
      context,
      title: dayLabel(controller.year, controller.month, day),
      body: (context) => _DayDetail(controller: controller, day: day),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, MonthsStore.instance]),
      builder: (context, _) {
        final canPick = MonthsStore.instance.months.length > 1;
        final title = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(monthLabel(_controller.year, _controller.month), overflow: TextOverflow.ellipsis)),
            if (canPick) ...[const SizedBox(width: 6), Icon(LucideIcons.chevronDown, size: 18, color: palette.muted)],
          ],
        );
        return Scaffold(
          appBar: AppBar(
            title: canPick
                ? InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _pickMonth,
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: title),
                  )
                : title,
          ),
          body: RefreshIndicator(
            onRefresh: _controller.load,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: _content(context)),
          ),
        );
      },
    );
  }

  List<Widget> _content(BuildContext context) {
    final controller = _controller;
    final data = controller.data;
    final summary = controller.summary;
    if (controller.loading) {
      return const [Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))];
    }
    if (data == null || summary == null) {
      final notFound = controller.error?.notFound ?? false;
      return [
        EmptyState(
          icon: LucideIcons.calendarX,
          title: notFound ? '${monthLabel(controller.year, controller.month)} não existe' : 'Não foi possível carregar o mês',
          description: notFound ? null : controller.error?.message,
        ),
      ];
    }
    if (data.spends.isEmpty && summary.allowance.activeDay == null) {
      // Months before daily tracking existed have nothing to show day by day.
      return [
        EmptyState(
          icon: LucideIcons.calendarOff,
          title: 'Nenhum gasto do dia a dia em ${monthName(controller.month).toLowerCase()}',
          description: 'O histórico mostra os dias de meses em que os gastos foram lançados em Hoje.',
        ),
      ];
    }

    final palette = context.palette;
    final days = dayResults(data.month, summary, data.spends);
    final closed = days.where((day) => day.state == DayState.closed && day.result != null).toList();
    final withinBudget = closed.where((day) => day.result! >= 0).length;
    // Closed days against the month's original plan (net ÷ days in month each). Summing the daily
    // results would double count: what's left on one day rolls into the next days' budgets.
    final balance = days.isEmpty
        ? 0.0
        : closed.length * (summary.net ?? 0) / days.length - closed.fold<double>(0, (sum, day) => sum + day.spent);

    return [
      if (closed.isEmpty)
        Text('Nenhum dia fechado ainda.', style: TextStyle(fontSize: 15, color: palette.muted))
      else ...[
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            signedMoney(balance, summary.main),
            style: money(fontSize: 40, fontWeight: FontWeight.w600, height: 1.1, color: balance >= 0 ? palette.success : palette.error),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${balance >= 0 ? 'Sobrou' : 'Passou'} nos dias fechados. $withinBudget de ${closed.length} ${plural(closed.length, 'ficou', 'ficaram')} dentro do valor do dia.',
          style: TextStyle(fontSize: 15, height: 1.4, color: palette.muted),
        ),
      ],
      const SizedBox(height: 24),
      Segmented<HistoryView>(
        value: _view,
        options: const [
          (value: HistoryView.calendar, label: 'Calendário', icon: LucideIcons.calendarDays),
          (value: HistoryView.spends, label: 'Extrato', icon: LucideIcons.list),
        ],
        onChanged: (view) => setState(() => _view = view),
      ),
      const SizedBox(height: 24),
      if (_view == HistoryView.calendar) _calendar(context, days) else ..._statement(context, data, summary),
    ];
  }

  Widget _calendar(BuildContext context, List<DayResult> days) {
    final palette = context.palette;
    final leadingBlanks = (DateTime(_controller.year, _controller.month, 1).weekday + 6) % 7;
    const gap = 6.0;
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - gap * 6) / 7;
      // Taller than wide: the day, its result and the bar each get a line.
      final height = width * 1.3;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final weekday in _weekdays)
            SizedBox(
              width: width,
              height: 24,
              child: Text(weekday, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: palette.muted)),
            ),
          for (var blank = 0; blank < leadingBlanks; blank++) SizedBox(width: width, height: height),
          for (final day in days) _DayCell(day: day, width: width, height: height, onTap: () => _openDay(day.day)),
        ],
      );
    });
  }

  List<Widget> _statement(BuildContext context, MonthDetail data, MonthSummary summary) {
    final palette = context.palette;
    final controller = _controller;
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
      for (final group in groups) ...[
        SectionHeader(
          dayLabel(controller.year, controller.month, group.day),
          trailing: Text(
            formatMoney(group.spends.fold<double>(0, (sum, spend) => sum + (summary.cost(spend) ?? 0)), summary.main),
            style: money(fontSize: 14, color: palette.muted),
          ),
        ),
        Panel(
          child: SpendList(
            spends: group.spends,
            summary: summary,
            onUpdate: controller.updateSpend,
            onRemove: controller.removeSpend,
            onRestore: controller.addSpend,
          ),
        ),
        const SizedBox(height: 24),
      ],
    ];
  }
}

/// One day in a sheet: its budget against what was spent, its spends, and on a closed day the form
/// to enter one that was left out. Follows the month, so it shows each change as it is made.
class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.controller, required this.day});

  final MonthController controller;
  final int day;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final palette = context.palette;
        final data = controller.data;
        final summary = controller.summary;
        final muted = TextStyle(fontSize: 15, height: 1.4, color: palette.muted);
        final result = data == null || summary == null
            ? null
            : dayResults(data.month, summary, data.spends).where((entry) => entry.day == day).firstOrNull;
        if (data == null || summary == null || result == null) return Text('Não foi possível carregar o dia.', style: muted);

        final spends = data.spends.where((spend) => spend.day == day).toList();
        final open = result.state == DayState.open;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result.state != DayState.upcoming && result.result != null) ...[
              Row(
                children: [
                  Expanded(child: _Stat(label: 'Valor do dia', value: formatMoney(result.budget, summary.main))),
                  Expanded(child: _Stat(label: 'Gasto', value: formatMoney(result.spent, summary.main))),
                  Expanded(
                    child: _Stat(
                      label: open ? 'Restam' : 'Resultado',
                      value: open ? formatMoney(result.result, summary.main) : signedMoney(result.result!, summary.main),
                      color: result.result! >= 0 ? palette.success : palette.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            if (spends.isNotEmpty)
              Panel(
                child: SpendList(
                  spends: spends,
                  summary: summary,
                  onUpdate: controller.updateSpend,
                  onRemove: controller.removeSpend,
                  onRestore: controller.addSpend,
                ),
              )
            else if (result.state == DayState.upcoming)
              Text(
                'Ainda não chegou.${result.budget == null ? '' : ' Se o dia aberto fechasse agora, este dia teria ${formatMoney(result.budget, summary.main)}.'}',
                style: muted,
              )
            else
              Text('Nenhum gasto neste dia.', style: muted),
            // The open day's spends are entered on Hoje; a closed day takes the ones that were left out.
            if (result.state == DayState.closed) ...[
              const SizedBox(height: 24),
              const SectionHeader('Lançar um gasto que faltou'),
              SpendForm(key: ValueKey('form-${controller.year}-${controller.month}-$day'), day: day, create: controller.addSpend),
            ],
          ],
        );
      },
    );
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
        Text(label, style: TextStyle(fontSize: 13, color: palette.muted)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: money(fontSize: 16, fontWeight: color == null ? null : FontWeight.w600, color: color ?? palette.text)),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.width, required this.height, required this.onTap});

  final DayResult day;
  final double width;
  final double height;
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
        style: money(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2, color: result >= 0 ? palette.success : palette.error),
      );
    } else if (open && result != null) {
      value = Text(
        compactSigned(result).replaceFirst('+', ''),
        style: money(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2, color: result >= 0 ? palette.highlighted : palette.error),
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
      child: Material(
        color: palette.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: open ? BorderSide(color: palette.bgInverted, width: 2) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: width,
            height: height,
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: open ? FontWeight.w700 : FontWeight.w500,
                    color: open ? palette.highlighted : palette.muted,
                  ),
                ),
                const Spacer(),
                if (value != null) FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value),
                ?bar,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
