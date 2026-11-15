import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../routes.dart';
import '../state/month_controller.dart';
import '../state/months_store.dart';
import '../state/toast.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common.dart';
import '../widgets/daily_spend_history.dart';
import '../widgets/month_create.dart';
import '../widgets/spends.dart';

/// Port of `pages/index.vue`: the open day's budget, spending entry, and the month's history.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with WidgetsBindingObserver, RouteAware {
  DateTime _now = DateTime.now();
  final _scroll = ScrollController();
  late MonthController _today = MonthController(_now.year, _now.month);

  /// The month shown in the history; the same controller as [_today] for the current month.
  late MonthController _history = _today;
  HistoryView _view = HistoryView.calendar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _followCalendar();
  }

  /// Back on Hoje from another page, where the month may have been created, edited or deleted.
  @override
  void didPopNext() {
    _today.load();
    if (_history != _today) _history.load();
  }

  /// Hoje lives as long as the app: after midnight it reloads, and in a new month it switches to it.
  void _followCalendar() {
    final now = DateTime.now();
    if (now.year == _now.year && now.month == _now.month && now.day == _now.day) return;
    final previous = _today;
    setState(() {
      _now = now;
      if (previous.year == now.year && previous.month == now.month) return;
      // The history may already show the new month: reuse its controller instead of loading it twice.
      _today = _history.year == now.year && _history.month == now.month ? _history : MonthController(now.year, now.month);
      if (_history == previous) _history = _today;
      previous.dispose();
    });
    if (_today == previous) previous.load();
  }

  void _showHistoryMonth(int year, int month) {
    if (year == _history.year && month == _history.month) return;
    setState(() {
      if (_history != _today) _history.dispose();
      _history = year == _today.year && month == _today.month ? _today : MonthController(year, month);
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      _today.load(),
      if (_history != _today) _history.load(),
      MonthsStore.instance.refresh(),
    ]);
  }

  Future<void> _confirmClose(MonthDetail data, Allowance allowance) async {
    final next = nextActiveDay(data.month);
    if (next == null) return;
    final afterClose = summarizeMonth(
      data.month.patch({'activeDay': next}),
      data.items,
      rate: data.rate?.rate,
      quote: data.quote,
      fallbackFee: data.fallbackFee,
      spends: data.spends,
      conversions: data.conversions,
    ).allowance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _CloseDayDialog(day: allowance.activeDay!, allowance: allowance, afterClose: afterClose, today: _now.day),
    );
    if (confirmed != true) return;
    final closedDay = allowance.activeDay;
    final result = await _today.closeDay();
    if (result == null || closedDay == null) return;
    final eur = _today.summary?.allowance.eur;
    toast(
      'Dia $closedDay fechado',
      description: eur == null ? null : 'Novo valor diário: ${formatMoney(eur, Currency.eur)}.',
      icon: LucideIcons.calendarCheck,
      // Long enough to notice a misclick and undo it.
      duration: const Duration(seconds: 10),
      actionLabel: 'Desfazer',
      onAction: () => _today.updateMonth({'activeDay': result.previous}),
    );
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    if (_history != _today) _history.dispose();
    _today.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_today, MonthsStore.instance]),
      builder: (context, _) {
        final data = _today.data;
        final summary = _today.summary;
        final allowance = summary?.allowance;
        final activeDay = allowance?.activeDay;
        final canClose = data != null && activeDay != null && nextActiveDay(data.month) != null;
        /// Days before today that were never closed: their budget hasn't been spread yet.
        final lagging = activeDay != null && activeDay < _now.day;

        return Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(
            title: Text(activeDay == null ? 'Hoje' : dayLabel(_now.year, _now.month, activeDay)),
            actions: [
              if (canClose)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ActionButton(
                    label: 'Fechar o dia',
                    icon: LucideIcons.calendarCheck,
                    style: lagging ? ActionStyle.solid : ActionStyle.outline,
                    onPressed: () => _confirmClose(data, allowance!),
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              children: [
                ..._main(context, data, summary),
                DailySpendHistory(
                  controller: _history,
                  view: _view,
                  onViewChanged: (view) => setState(() => _view = view),
                  onMonthChanged: _showHistoryMonth,
                  onOpenToday: () => _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _main(BuildContext context, MonthDetail? data, MonthSummary? summary) {
    final palette = context.palette;
    if (_today.loading) {
      return const [Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))];
    }
    if (data == null || summary == null) {
      if (_today.error?.notFound ?? false) {
        return [MonthCreate(year: _now.year, month: _now.month, onCreated: _today.load)];
      }
      return [
        EmptyState(
          icon: LucideIcons.cloudOff,
          title: 'Não foi possível carregar o mês',
          description: _today.error?.message,
          actions: [
            ActionButton(label: 'Tentar de novo', icon: LucideIcons.refreshCw, style: ActionStyle.subtle, onPressed: _today.load),
          ],
        ),
      ];
    }

    final allowance = summary.allowance;
    final activeDay = allowance.activeDay;
    final lagging = activeDay != null && activeDay < _now.day;

    if (activeDay == null) {
      return [
        EmptyState(
          icon: LucideIcons.flag,
          title: 'Todos os dias de ${monthName(_now.month).toLowerCase()} foram fechados',
          description: 'No mês, os gastos do dia a dia somaram ${formatMoney(allowance.spentTotal, Currency.eur)}.',
        ),
      ];
    }
    if (allowance.eur == null) {
      return [
        EmptyState(
          icon: LucideIcons.hourglass,
          title: 'Ainda não dá para calcular o dia',
          description: data.rateError != null ? 'A cotação do euro falhou: ${data.rateError}' : 'Falta a cotação do euro.',
          actions: [
            ActionButton(
              label: 'Tentar novamente',
              icon: LucideIcons.refreshCw,
              style: ActionStyle.subtle,
              loading: _today.refreshingRate,
              onPressed: _today.refreshRate,
            ),
          ],
        ),
      ];
    }

    final spendsToday = data.spends.where((spend) => spend.day == activeDay).toList();
    final spentBefore = allowance.spentBefore;
    final toned = money(fontSize: 14, color: palette.toned);

    return [
      if (lagging) ...[
        Callout(
          icon: LucideIcons.calendarClock,
          title: 'O dia $activeDay ainda está aberto',
          description: 'Gastos novos entram nele. Feche o dia para levar a sobra (ou o que passou) para os dias que faltam.',
        ),
        const SizedBox(height: 32),
      ],
      DayHero(allowance: allowance, spends: spendsToday, transfer: summary.transfer),
      const SizedBox(height: 32),
      SpendForm(day: activeDay, create: _today.addSpend),
      if (spendsToday.isNotEmpty) ...[
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: Text('Gastos do dia', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.muted))),
            Text(formatMoney(allowance.spentToday, Currency.eur), style: money(fontSize: 14, color: palette.muted)),
          ],
        ),
        const SizedBox(height: 4),
        SpendList(
          spends: spendsToday,
          inEur: (spend) => spendInEurFor(spend, summary.transfer),
          onUpdate: _today.updateSpend,
          onRemove: _today.removeSpend,
        ),
      ],
      const SizedBox(height: 32),
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'O mês tem '),
          TextSpan(text: formatMoney(summary.eur.net, Currency.eur), style: toned),
          const TextSpan(text: ' livres depois das contas. '),
          if (spentBefore != 0) ...[
            const TextSpan(text: 'Já foram '),
            TextSpan(text: formatMoney(spentBefore, Currency.eur), style: toned),
            const TextSpan(text: ' nos dias anteriores, '),
          ] else
            const TextSpan(text: 'Isso '),
          TextSpan(text: 'dividido por ${allowance.days} ${plural(allowance.days, 'dia', 'dias')} dá '),
          TextSpan(text: formatMoney(allowance.eur, Currency.eur), style: toned),
          const TextSpan(text: ' por dia.'),
        ]),
        style: TextStyle(fontSize: 14, color: palette.muted, height: 1.5),
      ),
    ];
  }
}

class _CloseDayDialog extends StatefulWidget {
  const _CloseDayDialog({required this.day, required this.allowance, required this.afterClose, required this.today});

  final int day;
  final Allowance allowance;
  final Allowance afterClose;
  final int today;

  @override
  State<_CloseDayDialog> createState() => _CloseDayDialogState();
}

class _CloseDayDialogState extends State<_CloseDayDialog> {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final remaining = widget.allowance.remainingEur ?? 0;
    final after = widget.afterClose;
    final strong = money(fontSize: 14, fontWeight: FontWeight.w600, color: palette.highlighted);
    return AlertDialog(
      title: Text('Fechar o dia ${widget.day}?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: palette.highlighted)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            remaining >= 0
                ? TextSpan(children: [
                    const TextSpan(text: 'Sobraram '),
                    TextSpan(text: formatMoney(remaining, Currency.eur), style: strong),
                    const TextSpan(text: '. Eles vão para os dias que faltam.'),
                  ])
                : TextSpan(children: [
                    const TextSpan(text: 'O dia passou '),
                    TextSpan(text: formatMoney(-remaining, Currency.eur), style: strong.copyWith(color: palette.error)),
                    const TextSpan(text: '. Isso sai dos dias que faltam.'),
                  ]),
            style: TextStyle(fontSize: 14, color: palette.text),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: palette.bgElevated, borderRadius: BorderRadius.circular(8)),
            child: after.activeDay != null && after.eur != null
                ? Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'A partir ${after.activeDay == widget.today ? 'de hoje' : 'do dia ${after.activeDay}'}: '),
                      TextSpan(text: formatMoney(after.eur, Currency.eur), style: strong.copyWith(fontSize: 16)),
                      TextSpan(text: ' por dia, por ${after.days} ${plural(after.days, 'dia', 'dias')}.'),
                    ]),
                    style: TextStyle(fontSize: 14, color: palette.text),
                  )
                : Text('Era o último dia do mês.', style: TextStyle(fontSize: 14, color: palette.text)),
          ),
        ],
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        ActionButton(label: 'Fechar o dia', icon: LucideIcons.calendarCheck, onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
  }
}
