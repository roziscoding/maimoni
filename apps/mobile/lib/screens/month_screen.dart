import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../routes.dart';
import '../state/currencies_store.dart';
import '../state/month_controller.dart';
import '../state/toast.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common.dart';
import '../widgets/items.dart';
import '../widgets/month_create.dart';
import '../widgets/month_overview.dart';

/// Port of `pages/months/[year]/[month].vue`.
class MonthScreen extends StatefulWidget {
  const MonthScreen({super.key, required this.year, required this.month});

  final int year;
  final int month;

  @override
  State<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends State<MonthScreen> {
  late final _controller = MonthController(widget.year, widget.month);
  final _note = TextEditingController();
  final _noteFocus = FocusNode();

  String get _title => monthLabel(widget.year, widget.month);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncNote);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteMonthDialog(title: _title, controller: _controller),
    );
    if (confirmed != true || !mounted) return;
    toast('$_title excluído', icon: LucideIcons.trash2);
    navigate(context, todayRoute);
  }

  @override
  void dispose() {
    _controller.dispose();
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
        final phaseLabel = switch (monthPhase(widget.year, widget.month)) {
          MonthPhase.past => 'encerrado',
          MonthPhase.current => 'mês atual',
          MonthPhase.future => 'futuro',
        };

        return Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(
            title: Row(
              children: [
                Flexible(child: Text(_title, overflow: TextOverflow.ellipsis)),
                if (data != null) ...[const SizedBox(width: 8), Pill(label: phaseLabel)],
              ],
            ),
            actions: [
              if (data != null)
                PopupMenuButton<String>(
                  icon: Icon(LucideIcons.ellipsisVertical, size: 20, color: palette.muted),
                  tooltip: 'Ações do mês',
                  onSelected: (_) => _confirmDelete(),
                  itemBuilder: (context) => [menuItem(context, 'delete', LucideIcons.trash2, 'Excluir mês', danger: true)],
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _controller.load,
            child: _body(context, data, summary),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, MonthDetail? data, MonthSummary? summary) {
    final palette = context.palette;
    if (_controller.loading) return const Center(child: CircularProgressIndicator());
    if (data == null || summary == null) {
      return ListView(
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

    final items = [...data.items]..sort((a, b) => a.position.compareTo(b.position));
    final currencies = CurrenciesStore.instance;
    // A section per currency the month shows: the offered ones, and any other it already has items or spends in.
    final sections = currencies.shownInMonth(data);
    // With a single currency there is nothing to convert, and so no rate.
    final exchange = sections.length > 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
      children: [
        AllowanceHero(year: widget.year, month: widget.month, summary: summary, exchange: exchange),
        const SizedBox(height: 32),
        FlowStrip(summary: summary, currencies: sections),
        if (currencies.none) ...[const SizedBox(height: 24), const NoCurrenciesCallout()],
        for (final currency in sections) ...[
          const SizedBox(height: 24),
          ItemSection(
            currency: currency,
            items: items.where((item) => item.currency == currency).toList(),
            // A currency the month only offers, with no item in it yet, has nothing to total.
            totals: summary.totals[currency] ?? CurrencyTotals.empty,
            offered: currencies.offered.contains(currency),
            alone: !exchange,
            onUpdate: _controller.updateItem,
            onRemove: _controller.removeItem,
            onPromote: _controller.promoteItem,
            onAdd: (body) => _controller.addItem(body),
          ),
        ],
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
        Text('Anotações', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.muted)),
        const SizedBox(height: 6),
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
}

class _DeleteMonthDialog extends StatefulWidget {
  const _DeleteMonthDialog({required this.title, required this.controller});

  final String title;
  final MonthController controller;

  @override
  State<_DeleteMonthDialog> createState() => _DeleteMonthDialogState();
}

class _DeleteMonthDialogState extends State<_DeleteMonthDialog> {
  bool _deleting = false;

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await widget.controller.removeMonth();
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      toast('Não foi possível excluir o mês', description: errorMessage(err), tone: ToastTone.error);
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Excluir ${widget.title}?'),
      content: const Text('Todos os itens, valores e anotações deste mês serão apagados. O template não muda.'),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        ActionButton(label: 'Excluir mês', icon: LucideIcons.trash2, danger: true, loading: _deleting, onPressed: _delete),
      ],
    );
  }
}
