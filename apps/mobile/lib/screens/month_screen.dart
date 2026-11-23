import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../state/currencies_store.dart';
import '../state/month_controller.dart';
import '../state/toast.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/items.dart';
import '../widgets/month_create.dart';
import '../widgets/month_overview.dart';

/// One month, in two tabs: the summary (daily budget, how the net is reached, rates, notes) and
/// the items (incomes and expenses per currency).
class MonthScreen extends StatefulWidget {
  const MonthScreen({super.key, required this.year, required this.month});

  final int year;
  final int month;

  @override
  State<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends State<MonthScreen> with SingleTickerProviderStateMixin {
  static const _itemsTab = 1;

  late final _controller = MonthController(widget.year, widget.month);
  late final _tabs = TabController(length: 2, vsync: this);
  final _note = TextEditingController();
  final _noteFocus = FocusNode();

  String get _title => monthLabel(widget.year, widget.month);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncNote);
    // The button that adds an item only shows over the items.
    _tabs.addListener(() => setState(() {}));
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) _saveNote();
    });
  }

  void _syncNote() {
    final value = _controller.data?.month.note ?? '';
    if (!_noteFocus.hasFocus && _note.text != value) _note.text = value;
  }

  void _saveNote() {
    final data = _controller.data;
    if (data == null) return;
    final value = _note.text.trim();
    final note = value.isEmpty ? null : value;
    if (note != data.month.note) _controller.updateMonth({'note': note});
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Excluir $_title?',
      message: 'Todos os itens, valores e anotações deste mês serão apagados. O template não muda.',
      confirmLabel: 'Excluir mês',
      icon: LucideIcons.trash2,
      danger: true,
    );
    if (!confirmed) return;
    try {
      await _controller.removeMonth();
    } catch (err) {
      toast('Não foi possível excluir o mês', description: errorMessage(err), tone: ToastTone.error);
      return;
    }
    toast('$_title excluído', icon: LucideIcons.trash2);
    if (mounted) Navigator.of(context).pop();
  }

  void _addItem() {
    final currencies = CurrenciesStore.instance;
    showSheet<void>(
      context,
      title: 'Novo item',
      body: (context) => ItemForm(
        currency: currencies.main,
        currencies: currencies.offered,
        submitLabel: 'Adicionar',
        onSubmit: _controller.addItem,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabs.dispose();
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, CurrenciesStore.instance]),
      builder: (context, _) {
        final palette = context.palette;
        final data = _controller.data;
        final summary = _controller.summary;
        final ready = data != null && summary != null;
        final unresolved = summary == null ? 0 : summary.totals.values.fold<int>(0, (sum, totals) => sum + totals.unresolved);

        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: [
              if (ready)
                PopupMenuButton<String>(
                  icon: Icon(LucideIcons.ellipsisVertical, size: 22, color: palette.muted),
                  tooltip: 'Ações do mês',
                  onSelected: (_) => _confirmDelete(),
                  itemBuilder: (context) => [menuItem(context, 'delete', LucideIcons.trash2, 'Excluir mês', danger: true)],
                ),
            ],
            bottom: ready
                ? TabBar(
                    controller: _tabs,
                    tabs: [
                      const Tab(text: 'Resumo'),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Itens'),
                            if (unresolved > 0) ...[const SizedBox(width: 8), Pill(label: '$unresolved', tone: Tone.warning)],
                          ],
                        ),
                      ),
                    ],
                  )
                : null,
          ),
          floatingActionButton: ready && _tabs.index == _itemsTab && !CurrenciesStore.instance.none
              ? AppFab(label: 'Novo item', icon: LucideIcons.plus, onPressed: _addItem)
              : null,
          body: ready
              ? TabBarView(
                  controller: _tabs,
                  children: [
                    RefreshIndicator(onRefresh: _controller.load, child: _overview(context, data, summary)),
                    RefreshIndicator(onRefresh: _controller.load, child: _items(context, data, summary)),
                  ],
                )
              : RefreshIndicator(onRefresh: _controller.load, child: _missing(context)),
        );
      },
    );
  }

  Widget _missing(BuildContext context) {
    if (_controller.loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      // A short list still takes the pull that reloads it.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (_controller.error?.notFound ?? false)
          MonthCreate(year: widget.year, month: widget.month)
        else
          EmptyState(
            icon: LucideIcons.cloudOff,
            title: 'Não foi possível carregar o mês',
            description: _controller.error?.message,
            actions: [
              ActionButton(label: 'Tentar de novo', icon: LucideIcons.refreshCw, style: ActionStyle.subtle, onPressed: _controller.load),
            ],
          ),
      ],
    );
  }

  Widget _overview(BuildContext context, MonthDetail data, MonthSummary summary) {
    final sections = CurrenciesStore.instance.shownInMonth(data);
    // With a single currency there is nothing to convert, and so no rate.
    final exchange = sections.length > 1;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        AllowanceHero(year: widget.year, month: widget.month, summary: summary, exchange: exchange),
        const SizedBox(height: 32),
        const SectionHeader('Como o mês fecha'),
        FlowStrip(summary: summary, currencies: sections),
        if (exchange) ...[
          const SizedBox(height: 24),
          RatePanel(
            rates: data.rates,
            error: data.rateError,
            summary: summary,
            refreshing: _controller.refreshingRate,
            onLock: _controller.lockRate,
            onUnlock: _controller.unlockRate,
            onRetry: _controller.refreshRate,
          ),
        ],
        const SizedBox(height: 24),
        const SectionHeader('Anotações'),
        TextField(
          controller: _note,
          focusNode: _noteFocus,
          minLines: 3,
          maxLines: 12,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Algo para lembrar deste mês'),
          onTapOutside: (_) => _noteFocus.unfocus(),
        ),
      ],
    );
  }

  Widget _items(BuildContext context, MonthDetail data, MonthSummary summary) {
    final items = [...data.items]..sort((a, b) => a.position.compareTo(b.position));
    final currencies = CurrenciesStore.instance;
    // A section per currency the month shows: the offered ones, and any other it already has items or spends in.
    final sections = currencies.shownInMonth(data);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Room under the last row for the floating button.
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 104),
      children: [
        if (currencies.none) ...[const NoCurrenciesCallout(), const SizedBox(height: 24)],
        for (final currency in sections) ...[
          ItemSection(
            key: ValueKey(currency.code),
            currency: currency,
            items: items.where((item) => item.currency == currency).toList(),
            // A currency the month only offers, with no item in it yet, has nothing to total.
            totals: summary.totals[currency] ?? CurrencyTotals.empty,
            alone: sections.length == 1,
            onUpdate: _controller.updateItem,
            onRemove: _controller.removeItem,
            onPromote: _controller.promoteItem,
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}
