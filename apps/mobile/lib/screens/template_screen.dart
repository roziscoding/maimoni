import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../routes.dart';
import '../state/currencies_store.dart';
import '../state/toast.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/items.dart';
import '../widgets/month_overview.dart';

/// The items every new month starts with, plus a preview of the month they make.
class TemplateScreen extends StatefulWidget {
  const TemplateScreen({super.key});

  @override
  State<TemplateScreen> createState() => _TemplateScreenState();
}

class _TemplateScreenState extends State<TemplateScreen> {
  final _api = Api.instance;
  TemplateDetail? _data;

  /// Quoted against the user's main currency, which a new month would be worked out in.
  LiveRates? _rates;
  ApiException? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    shellTab.addListener(_onTab);
    _load();
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTab);
    super.dispose();
  }

  /// Back on the template from another tab: a month may have saved an item into it meanwhile.
  void _onTab() {
    if (shellTab.value == AppTab.template) _load();
  }

  Future<void> _load() async {
    try {
      // The preview does without rates, and the sections without the list, when either can't be loaded.
      final rates = _api.liveRates().then<LiveRates?>((rates) => rates).catchError((_) => null);
      final currencies = CurrenciesStore.instance.ensureLoaded();
      _data = await _api.template();
      _rates = await rates;
      await currencies;
      _error = null;
    } on ApiException catch (err) {
      _error = err;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  List<TemplateItem> get _items => [...?_data?.items]..sort((a, b) => a.position.compareTo(b.position));

  List<TemplateItem> _group(Currency currency, EntryKind kind) =>
      _items.where((item) => item.currency == currency && item.kind == kind).toList();

  /// What a month created today from this template would look like, using next month's calendar.
  MonthSummary? get _preview {
    final data = _data;
    final currencies = CurrenciesStore.instance;
    // Without the list, the store's main is only a fallback; the live rates are quoted against the
    // user's real main currency, so their base is the one to use. With neither, there is no preview.
    final mainCurrency = currencies.list != null ? currencies.main : _rates?.base;
    if (data == null || mainCurrency == null) return null;
    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1);
    final monthItems = [
      for (final item in _items)
        MonthItem(
          id: item.id,
          monthId: '',
          templateItemId: item.id,
          name: item.name,
          currency: item.currency,
          kind: item.kind,
          amount: item.amount,
          expression: item.expression,
          paid: false,
          needsReview: item.variable,
          position: item.position,
        ),
    ];
    final month = Month(
      id: '',
      year: next.year,
      month: next.month,
      mainCurrency: mainCurrency,
      lockedRates: const {},
      activeDay: null,
      note: null,
      createdAt: '',
    );
    // Rates quoted against another currency (the main one changed since they were loaded) don't apply.
    return summarizeMonth(month, monthItems, rates: _rates?.base == mainCurrency ? _rates!.rates : null, today: now);
  }

  void _setItems(List<TemplateItem> Function(List<TemplateItem>) update) {
    if (_data == null || !mounted) return;
    setState(() => _data!.items = update(_data!.items));
  }

  Future<T?> _persist<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (err) {
      toast('Não foi possível salvar', description: errorMessage(err), tone: ToastTone.error);
      await _load();
      return null;
    }
  }

  Future<void> _update(String id, Json patch) async {
    _setItems((list) => [for (final item in list) item.id == id ? item.patch(patch) : item]);
    final saved = await _persist(() => _api.updateTemplateItem(id, patch));
    if (saved != null) _setItems((list) => [for (final item in list) item.id == id ? saved : item]);
  }

  Future<void> _add(Json body) async {
    final created = await _persist(() => _api.addTemplateItem(body));
    if (created != null) _setItems((list) => [...list, created]);
  }

  Future<void> _remove(String id) async {
    _setItems((list) => list.where((item) => item.id != id).toList());
    await _persist(() => _api.deleteTemplateItem(id));
  }

  /// Moves an item inside its currency/kind group, then saves the full order: the group's items
  /// keep the slots they had among all the others, in their new order.
  Future<void> _reorder(Currency currency, EntryKind kind, int from, int to) async {
    final siblings = _group(currency, kind);
    if (from == to || from < 0 || from >= siblings.length) return;
    siblings.insert(to.clamp(0, siblings.length - 1), siblings.removeAt(from));
    final next = siblings.iterator;
    final ids = [
      for (final entry in _items)
        if (entry.currency == currency && entry.kind == kind) (next..moveNext()).current.id else entry.id,
    ];
    _setItems((list) => [for (final entry in list) entry.patch({'position': ids.indexOf(entry.id)})]);
    final saved = await _persist(() => _api.reorderTemplate(ids));
    if (saved != null) _setItems((_) => saved);
  }

  void _addItem() {
    final currencies = CurrenciesStore.instance;
    showSheet<void>(
      context,
      title: 'Novo item do template',
      body: (context) => ItemForm(
        currency: currencies.main,
        currencies: currencies.offered,
        variable: false,
        submitLabel: 'Adicionar',
        onSubmit: _add,
      ),
    );
  }

  void _edit(TemplateItem item) {
    showSheet<void>(
      context,
      title: item.kind == EntryKind.income ? 'Entrada do template' : 'Saída do template',
      body: (context) => ItemForm(
        editing: true,
        name: item.name,
        amount: item.amount,
        expression: item.expression,
        kind: item.kind,
        currency: item.currency,
        variable: item.variable,
        submitLabel: 'Salvar',
        onSubmit: (patch) => _update(item.id, patch),
        actions: [
          SheetAction(
            icon: LucideIcons.trash2,
            label: 'Excluir',
            subtitle: 'Os meses que já existem não mudam.',
            danger: true,
            onTap: () {
              Navigator.of(context).pop();
              _remove(item.id);
            },
          ),
        ],
      ),
    );
  }

  void _explain() {
    showSheet<void>(
      context,
      title: 'O ponto de partida de todo mês',
      description: 'Cada mês novo começa com estes itens. Os fixos entram com o valor daqui. Os marcados como "varia" mudam todo mês '
          '(fatura do cartão, energia) e chegam pedindo confirmação, com o valor daqui como estimativa ou em branco.',
      body: (context) => FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CurrenciesStore.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Template'),
          actions: [
            IconButton(tooltip: 'Como funciona', icon: const Icon(LucideIcons.circleQuestionMark, size: 22), onPressed: _explain),
            const SizedBox(width: 4),
          ],
        ),
        floatingActionButton: _data != null && !CurrenciesStore.instance.none
            ? AppFab(label: 'Novo item', icon: LucideIcons.plus, onPressed: _addItem)
            : null,
        body: RefreshIndicator(
          onRefresh: () => Future.wait([_load(), CurrenciesStore.instance.refresh()]),
          child: _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final palette = context.palette;
    final data = _data;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (data == null) {
      return ListView(children: [
        EmptyState(
          icon: LucideIcons.cloudOff,
          title: 'Não foi possível carregar o template',
          description: _error?.message,
          actions: [ActionButton(label: 'Tentar de novo', icon: LucideIcons.refreshCw, style: ActionStyle.subtle, onPressed: _load)],
        ),
      ]);
    }
    final preview = _preview;
    final currencies = CurrenciesStore.instance;
    // A section per offered currency, and per any other the template still has items in.
    final sections = currencies.shown(_items.map((item) => item.currency));
    // With a single currency the items need no heading saying which, and the preview has no rate.
    final exchange = sections.length > 1;

    return ListView(
      // Room under the last row for the floating button.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
      children: [
        if (currencies.none) ...[const NoCurrenciesCallout(), const SizedBox(height: 24)],
        for (final currency in sections) ...[
          if (exchange) SectionHeader(currencyPlural(currency), tag: currency.code),
          Panel(
            key: ValueKey(currency.code),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final kind in [EntryKind.income, EntryKind.expense]) ...[
                  GroupLabel(kind == EntryKind.income ? 'Entradas' : 'Saídas'),
                  _rows(context, currency, kind),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (preview != null) ...[
          const SizedBox(height: 8),
          const SectionHeader('Prévia de um mês novo'),
          FlowStrip(summary: preview, currencies: sections),
          const SizedBox(height: 12),
          Panel(
            child: FigureRow(
              label: 'Por dia, em ${preview.allowance.days} dias',
              value: formatMoney(preview.allowance.amount, preview.main),
              strong: true,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              [
                if (preview.conversions.isNotEmpty)
                  'Com a cotação de agora (${preview.conversions.map((conversion) => formatRate(conversion.rate, conversion.currency)).join(', ')}).',
                'Itens que variam e estão em branco contam como zero.',
              ].join(' '),
              style: TextStyle(fontSize: 13, height: 1.4, color: palette.muted),
            ),
          ),
        ],
      ],
    );
  }

  /// One currency/kind group: rows that open for editing on a tap and move by their handle.
  Widget _rows(BuildContext context, Currency currency, EntryKind kind) {
    final palette = context.palette;
    final group = _group(currency, kind);
    if (group.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: Text('Nada aqui.', style: TextStyle(fontSize: 15, color: palette.dimmed)),
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: group.length,
      onReorderItem: (from, to) => _reorder(currency, kind, from, to),
      proxyDecorator: (child, _, _) => Material(color: palette.bgAccented, elevation: 6, borderRadius: BorderRadius.circular(12), child: child),
      itemBuilder: (context, index) => _TemplateRow(
        key: ValueKey(group[index].id),
        item: group[index],
        index: index,
        movable: group.length > 1,
        onTap: () => _edit(group[index]),
      ),
    );
  }
}

/// One item of the template: its name, whether it changes every month, its amount, and the handle
/// that drags it to another place in its group.
class _TemplateRow extends StatelessWidget {
  const _TemplateRow({super.key, required this.item, required this.index, required this.movable, required this.onTap});

  final TemplateItem item;
  final int index;

  /// Whether there is another item in the group to trade places with.
  final bool movable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: movable ? 0 : 16),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(item.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, color: palette.highlighted)),
                    ),
                    if (item.variable) ...[const SizedBox(width: 8), const Pill(label: 'varia', tone: Tone.warning)],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              item.amount == null ? (item.variable ? 'em branco' : 'sem valor') : formatMoney(item.amount, item.currency),
              style: money(fontSize: 15, color: item.amount == null ? palette.dimmed : palette.text),
            ),
            if (movable)
              ReorderableDragStartListener(
                index: index,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(LucideIcons.gripVertical, size: 18, color: palette.dimmed, semanticLabel: 'Arrastar ${item.name}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
