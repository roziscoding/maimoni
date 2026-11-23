import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../state/currencies_store.dart';
import '../state/toast.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';
import '../widgets/items.dart';
import '../widgets/month_overview.dart';

/// Port of `pages/template.vue`: the items every new month starts with, plus a preview.
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
    _load();
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

  /// Swaps an item with its neighbour inside the same currency/kind group, then saves the full order.
  Future<void> _move(TemplateItem item, int offset) async {
    final siblings = _group(item.currency, item.kind);
    final index = siblings.indexWhere((entry) => entry.id == item.id) + offset;
    if (index < 0 || index >= siblings.length) return;
    final neighbour = siblings[index];
    final ids = [
      for (final entry in _items) entry.id == item.id ? neighbour.id : (entry.id == neighbour.id ? item.id : entry.id),
    ];
    _setItems((list) => [for (final entry in list) entry.patch({'position': ids.indexOf(entry.id)})]);
    final saved = await _persist(() => _api.reorderTemplate(ids));
    if (saved != null) _setItems((_) => saved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Template')),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([_load(), CurrenciesStore.instance.refresh()]),
        child: ListenableBuilder(listenable: CurrenciesStore.instance, builder: (context, _) => _body(context)),
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
    final groups = {
      for (final currency in sections)
        for (final kind in EntryKind.values) (currency, kind): _group(currency, kind),
    };
    final muted = TextStyle(fontSize: 14, color: palette.muted, height: 1.45);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
      children: [
        Text('O ponto de partida de todo mês', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: palette.highlighted)),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Cada mês novo começa com estes itens. Os fixos entram com o valor daqui; os marcados como '),
            TextSpan(text: 'varia', style: TextStyle(fontWeight: FontWeight.w500, color: palette.text)),
            const TextSpan(
              text: ' mudam todo mês (fatura do cartão, energia) e chegam pedindo confirmação, com o valor daqui como estimativa ou em branco.',
            ),
          ]),
          style: muted,
        ),
        if (currencies.none) ...[const SizedBox(height: 24), const NoCurrenciesCallout()],
        for (final currency in sections) ...[
          const SizedBox(height: 24),
          Panel(
            // Keeps each section's add form with its currency when the shown currencies change.
            key: ValueKey(currency.code),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (exchange) PanelHeader(title: currencyPlural(currency), tag: currency.code),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final kind in [EntryKind.income, EntryKind.expense]) ...[
                        GroupLabel(kind == EntryKind.income ? 'Entradas' : 'Saídas'),
                        if (groups[(currency, kind)]!.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Text('Nada aqui.', style: TextStyle(fontSize: 14, color: palette.dimmed)),
                          )
                        else
                          for (final (index, item) in groups[(currency, kind)]!.indexed)
                            _TemplateRow(
                              key: ValueKey(item.id),
                              item: item,
                              first: index == 0,
                              last: index == groups[(currency, kind)]!.length - 1,
                              onUpdate: (patch) => _update(item.id, patch),
                              onMove: (offset) => _move(item, offset),
                              onRemove: () => _remove(item.id),
                            ),
                        const SizedBox(height: 8),
                      ],
                      if (currencies.offered.contains(currency)) AddItemForm(currency: currency, onAdd: _add),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (preview != null) ...[
          const SizedBox(height: 32),
          Text('Prévia de um mês novo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.highlighted)),
          const SizedBox(height: 4),
          Text(
            [
              if (preview.conversions.isNotEmpty)
                'Com a cotação de agora (${preview.conversions.map((conversion) => formatRate(conversion.rate, conversion.currency)).join(', ')}).',
              'Itens variáveis em branco contam como zero.',
            ].join(' '),
            style: muted,
          ),
          const SizedBox(height: 16),
          FlowStrip(summary: preview, currencies: sections),
          const SizedBox(height: 16),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(child: Text('Por dia, em ${preview.allowance.days} dias', style: TextStyle(fontSize: 14, color: palette.muted))),
              Text(formatMoney(preview.allowance.amount, preview.main), style: money(fontSize: 20, fontWeight: FontWeight.w600, color: palette.highlighted)),
            ]),
          ),
        ],
      ],
    );
  }
}

/// Port of `TemplateRow.vue`: reorder, name, amount, the "varia" switch and the actions menu.
class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    super.key,
    required this.item,
    required this.first,
    required this.last,
    required this.onUpdate,
    required this.onMove,
    required this.onRemove,
  });

  final TemplateItem item;
  final bool first;
  final bool last;
  final ValueChanged<Json> onUpdate;
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final income = item.kind == EntryKind.income;
    Widget arrow(IconData icon, bool disabled, int offset, String label) => SizedBox(
          width: 28,
          height: 20,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 16,
            tooltip: label,
            icon: Icon(icon, color: disabled ? palette.dimmed.withValues(alpha: 0.4) : palette.muted),
            onPressed: disabled ? null : () => onMove(offset),
          ),
        );

    return Row(
      children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          arrow(LucideIcons.chevronUp, first, -1, 'Subir ${item.name}'),
          arrow(LucideIcons.chevronDown, last, 1, 'Descer ${item.name}'),
        ]),
        Expanded(child: InlineTextField(value: item.name, onCommit: (name) => onUpdate({'name': name}))),
        SizedBox(
          width: 128,
          child: AmountField(
            amount: item.amount,
            expression: item.expression,
            currency: item.currency,
            placeholder: item.variable ? 'varia' : 'sem valor',
            onCommit: (amount, expression) => onUpdate({'amount': amount, 'expression': expression}),
          ),
        ),
        Tooltip(
          message: item.variable ? 'Muda todo mês: o mês novo pede confirmação' : 'Fixo: entra no mês novo como está',
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 28,
              child: FittedBox(child: Switch(value: item.variable, onChanged: (value) => onUpdate({'variable': value}))),
            ),
            Text('varia', style: TextStyle(fontSize: 10, color: palette.muted)),
          ]),
        ),
        PopupMenuButton<String>(
          icon: Icon(LucideIcons.ellipsis, size: 18, color: palette.muted),
          tooltip: 'Ações de ${item.name}',
          onSelected: (action) => action == 'remove' ? onRemove() : onUpdate({'kind': income ? 'expense' : 'income'}),
          itemBuilder: (context) => [
            menuItem(
              context,
              'kind',
              income ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
              income ? 'Mover para saídas' : 'Mover para entradas',
            ),
            const PopupMenuDivider(),
            menuItem(context, 'remove', LucideIcons.trash2, 'Excluir', danger: true),
          ],
        ),
      ],
    );
  }
}
