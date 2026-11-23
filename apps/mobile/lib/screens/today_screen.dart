import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../routes.dart';
import '../state/currencies_store.dart';
import '../state/month_controller.dart';
import '../state/months_store.dart';
import '../state/toast.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/month_create.dart';
import '../widgets/spends.dart';
import 'history_screen.dart';

/// The open day: what is left to spend, the day's spends, and the way to close it.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with WidgetsBindingObserver, RouteAware {
  DateTime _now = DateTime.now();
  late MonthController _today = MonthController(_now.year, _now.month);

  /// The currency the last spend was entered in, which the next one starts in.
  Currency? _spendCurrency;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    shellTab.addListener(_onTab);
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

  /// Back on Hoje from a page above the shell, where the month may have been created, edited or deleted.
  @override
  void didPopNext() => _today.load();

  /// Back on Hoje from another tab, where the data it shows may have been cleared.
  void _onTab() {
    if (shellTab.value == AppTab.today) _today.load();
  }

  /// Hoje lives as long as the app: after midnight it reloads, and in a new month it switches to it.
  void _followCalendar() {
    final now = DateTime.now();
    if (now.year == _now.year && now.month == _now.month && now.day == _now.day) return;
    final previous = _today;
    final sameMonth = previous.year == now.year && previous.month == now.month;
    setState(() {
      _now = now;
      if (sameMonth) return;
      _today = MonthController(now.year, now.month);
      previous.dispose();
    });
    if (sameMonth) previous.load();
  }

  Future<void> _refresh() => Future.wait([_today.load(), MonthsStore.instance.refresh()]);

  Future<void> _confirmClose(MonthDetail data, Allowance allowance) async {
    final next = nextActiveDay(data.month);
    if (next == null) return;
    final main = data.month.mainCurrency;
    // The allowance as it will look once the day is closed: same data, open day moved forward.
    final afterClose =
        summarizeMonth(data.month.patch({'activeDay': next}), data.items, rates: data.rates?.rates, spends: data.spends).allowance;
    final confirmed = await showConfirmSheet(
      context,
      title: 'Fechar o dia ${allowance.activeDay}?',
      body: _CloseDaySummary(allowance: allowance, afterClose: afterClose, main: main, today: _now.day),
      confirmLabel: 'Fechar o dia',
      icon: LucideIcons.calendarCheck,
    );
    if (!confirmed) return;
    final closedDay = allowance.activeDay;
    final result = await _today.closeDay();
    if (result == null || closedDay == null) return;
    HapticFeedback.mediumImpact();
    final amount = _today.summary?.allowance.amount;
    toast(
      'Dia $closedDay fechado',
      description: amount == null ? null : 'Novo valor diário: ${formatMoney(amount, main)}.',
      icon: LucideIcons.calendarCheck,
      // Long enough to notice a misclick and undo it.
      duration: const Duration(seconds: 10),
      actionLabel: 'Desfazer',
      onAction: () => _today.updateMonth({'activeDay': result.previous}),
    );
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTab);
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _today.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_today, MonthsStore.instance, CurrenciesStore.instance]),
      builder: (context, _) {
        final data = _today.data;
        final allowance = _today.summary?.allowance;
        final activeDay = allowance?.activeDay;
        // A spend goes into the open day, in a currency, against a budget that could be worked out.
        final canSpend = activeDay != null && allowance?.amount != null && !CurrenciesStore.instance.none;

        return Scaffold(
          appBar: AppBar(
            title: Text(activeDay == null ? 'Hoje' : dayLabel(_now.year, _now.month, activeDay)),
            actions: [
              IconButton(
                tooltip: 'Histórico',
                icon: const Icon(LucideIcons.calendarDays, size: 22),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => HistoryScreen(year: _now.year, month: _now.month)),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          floatingActionButton: canSpend
              ? AppFab(
                  label: 'Lançar gasto',
                  icon: LucideIcons.plus,
                  onPressed: () => showSpendSheet(
                    context,
                    day: activeDay,
                    create: _today.addSpend,
                    currency: _spendCurrency,
                    onCurrencyPicked: (currency) => _spendCurrency = currency,
                  ),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              // A short list still takes the pull that reloads it.
              physics: const AlwaysScrollableScrollPhysics(),
              // Room under the last row for the floating button.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
              children: _content(context, data, _today.summary),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _content(BuildContext context, MonthDetail? data, MonthSummary? summary) {
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
    // The currency the month is worked out in; every figure here is in it.
    final main = summary.main;
    final currencies = CurrenciesStore.instance;
    // With a single currency in the month there is no equivalent in another one to show.
    final exchange = currencies.shownInMonth(data).length > 1;

    if (activeDay == null) {
      return [
        EmptyState(
          icon: LucideIcons.flag,
          title: 'Todos os dias de ${monthName(_now.month).toLowerCase()} foram fechados',
          description: 'No mês, os gastos do dia a dia somaram ${formatMoney(allowance.spentTotal, main)}.',
        ),
      ];
    }
    if (allowance.amount == null) {
      return [
        EmptyState(
          icon: LucideIcons.hourglass,
          title: 'Ainda não dá para calcular o dia',
          description: data.rateError != null ? 'A cotação falhou: ${data.rateError}' : 'Falta a cotação de uma das moedas do mês.',
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

    /// Days before today that were never closed: their budget hasn't been spread yet.
    final lagging = activeDay < _now.day;
    final canClose = nextActiveDay(data.month) != null;
    final spendsToday = data.spends.where((spend) => spend.day == activeDay).toList();
    void close() => _confirmClose(data, allowance);

    return [
      if (lagging) ...[
        Callout(
          icon: LucideIcons.calendarClock,
          title: 'O dia $activeDay ainda está aberto',
          description: 'Gastos novos entram nele. Feche o dia para levar a sobra (ou o que passou) para os dias que faltam.',
          action: canClose ? ActionButton(label: 'Fechar o dia $activeDay', icon: LucideIcons.calendarCheck, onPressed: close) : null,
        ),
        const SizedBox(height: 24),
      ],
      const SizedBox(height: 8),
      DayHero(summary: summary, spends: spendsToday, exchange: exchange),
      const SizedBox(height: 32),
      if (currencies.none) ...[const NoCurrenciesCallout(), const SizedBox(height: 32)],
      SectionHeader(
        'Gastos do dia',
        trailing: spendsToday.isEmpty ? null : Text(formatMoney(allowance.spentToday, main), style: money(fontSize: 14, color: palette.muted)),
      ),
      Panel(
        child: spendsToday.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Nada lançado ainda.', style: TextStyle(fontSize: 15, color: palette.dimmed)),
              )
            : SpendList(
                spends: spendsToday,
                summary: summary,
                onUpdate: _today.updateSpend,
                onRemove: _today.removeSpend,
                onRestore: _today.addSpend,
              ),
      ),
      if (canClose && !lagging) ...[
        const SizedBox(height: 12),
        ActionButton(label: 'Fechar o dia', icon: LucideIcons.calendarCheck, style: ActionStyle.outline, onPressed: close),
      ],
      const SizedBox(height: 32),
      const SectionHeader('De onde vem o valor do dia'),
      Panel(
        child: Column(
          children: [
            FigureRow(label: 'Livre no mês, depois das contas', value: formatMoney(summary.net, main)),
            if (allowance.spentBefore != 0) ...[
              const RowDivider(),
              FigureRow(label: 'Gasto nos dias anteriores', value: formatMoney(allowance.spentBefore, main)),
            ],
            const RowDivider(),
            FigureRow(label: 'Dias que faltam, contando hoje', value: '${allowance.days}'),
            const RowDivider(),
            FigureRow(label: 'Por dia', value: formatMoney(allowance.amount, main), strong: true),
          ],
        ),
      ),
    ];
  }
}

/// What closing the open day does: where what is left goes, and the daily amount from then on.
class _CloseDaySummary extends StatelessWidget {
  const _CloseDaySummary({required this.allowance, required this.afterClose, required this.main, required this.today});

  final Allowance allowance;
  final Allowance afterClose;

  /// The currency the month is worked out in.
  final Currency main;
  final int today;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final remaining = allowance.remaining ?? 0;
    final after = afterClose;
    final strong = money(fontSize: 15, fontWeight: FontWeight.w600, color: palette.highlighted);
    final body = TextStyle(fontSize: 15, height: 1.4, color: palette.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          remaining >= 0
              ? TextSpan(children: [
                  const TextSpan(text: 'Sobraram '),
                  TextSpan(text: formatMoney(remaining, main), style: strong),
                  const TextSpan(text: '. Eles vão para os dias que faltam.'),
                ])
              : TextSpan(children: [
                  const TextSpan(text: 'O dia passou '),
                  TextSpan(text: formatMoney(-remaining, main), style: strong.copyWith(color: palette.error)),
                  const TextSpan(text: '. Isso sai dos dias que faltam.'),
                ]),
          style: body,
        ),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.all(16),
          child: after.activeDay != null && after.amount != null
              ? Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'A partir ${after.activeDay == today ? 'de hoje' : 'do dia ${after.activeDay}'}: '),
                    TextSpan(text: formatMoney(after.amount, main), style: strong.copyWith(fontSize: 17)),
                    TextSpan(text: ' por dia, por ${after.days} ${plural(after.days, 'dia', 'dias')}.'),
                  ]),
                  style: body,
                )
              : Text('Era o último dia do mês.', style: body),
        ),
      ],
    );
  }
}
