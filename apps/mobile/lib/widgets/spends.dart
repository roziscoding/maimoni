import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../domain/expression.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../state/currencies_store.dart';
import '../state/toast.dart';
import '../theme.dart';
import 'common.dart';
import 'fields.dart';

/// How much is still left to spend on the open day, with each spend as a slice of the budget.
class DayHero extends StatelessWidget {
  const DayHero({super.key, required this.summary, required this.spends, required this.exchange});

  /// The month's summary: the allowance, and the rates that size a spend in another currency by its cost.
  final MonthSummary summary;

  /// The open day's spending, in the order it was recorded.
  final List<DailySpend> spends;

  /// Whether the month has more than one currency, and so equivalents in the others to show.
  final bool exchange;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final allowance = summary.allowance;
    final main = summary.main;
    final budget = allowance.amount ?? 0;
    final remaining = allowance.remaining ?? 0;
    final over = remaining < 0;

    // Each spend is a slice of the day's budget; past the budget the bar is full and turns red.
    final segments = <double>[];
    if (budget > 0) {
      var used = 0.0;
      for (final spend in spends) {
        final value = summary.cost(spend) ?? 0;
        final width = (value.clamp(0, (budget - used).clamp(0, double.infinity)) / budget).toDouble();
        used += value > 0 ? value : 0;
        if (width > 0) segments.add(width);
      }
    }

    final String caption;
    if (over) {
      caption = 'Passou ${formatMoney(-remaining, main)} do valor de hoje.';
    } else if (allowance.spentToday > 0) {
      caption = 'Sobrando de ${formatMoney(budget, main)} para hoje.';
    } else {
      caption = 'Para gastar hoje.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMoney(remaining, main),
            style: money(fontSize: 60, fontWeight: FontWeight.w600, height: 1, color: over ? palette.error : palette.highlighted),
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: caption),
            // What is left today in each other currency of the month that has a rate.
            if (exchange)
              for (final conversion in summary.conversions)
                if (conversion.rate != null)
                  TextSpan(text: ' ≈ ${formatMoney(remaining * conversion.rate!, conversion.currency)}', style: money(fontSize: 14)),
          ]),
          style: TextStyle(fontSize: 14, color: palette.muted),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: over
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: palette.error.withValues(alpha: 0.6), width: 2),
                )
              : null,
          padding: over ? const EdgeInsets.all(2) : EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 12,
              color: palette.bgAccented,
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    for (final (index, width) in segments.indexed)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: (constraints.maxWidth * width - (index < segments.length - 1 ? 1 : 0)).clamp(0, constraints.maxWidth),
                        margin: EdgeInsets.only(right: index < segments.length - 1 ? 1 : 0),
                        color: over ? palette.error : palette.bgInverted,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Enters a spend: currency (when there is more than one to pick from), amount (number or
/// expression), description, submit.
class SpendForm extends StatefulWidget {
  const SpendForm({
    super.key,
    required this.day,
    required this.create,
    this.autofocus = false,
    this.currency,
    this.onCurrencyPicked,
    this.onCreated,
  });

  final int day;
  final Future<DailySpend?> Function(Json body) create;
  final bool autofocus;

  /// The currency the form starts in, when it is still offered. The main one otherwise.
  final Currency? currency;

  /// Tells the caller which currency was picked, so the next form can start in it: a run of spends
  /// usually happens in the same one.
  final ValueChanged<Currency>? onCurrencyPicked;

  /// Called once a spend was saved. Without it the form clears and waits for the next one.
  final VoidCallback? onCreated;

  @override
  State<SpendForm> createState() => _SpendFormState();
}

class _SpendFormState extends State<SpendForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _amountFocus = FocusNode();

  late Currency? _picked = widget.currency;
  bool _saving = false;

  void _pick(Currency currency) {
    setState(() => _picked = currency);
    widget.onCurrencyPicked?.call(currency);
  }

  /// The currency the spend goes in: the picked one while it is still offered, otherwise the main one.
  Currency? get _currency {
    final store = CurrenciesStore.instance;
    return _picked != null && store.offered.contains(_picked) ? _picked : store.main;
  }

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  Future<void> _submit() async {
    final currency = _currency;
    if (currency == null) return;
    final text = _amount.text.trim();
    final amount = evaluateExpression(text);
    if (amount == null) {
      toast('Valor inválido', description: '"$text" não é um número nem uma conta como 4,50+2.', tone: ToastTone.error);
      return;
    }
    setState(() => _saving = true);
    final note = _note.text.trim();
    final created = await widget.create({
      'day': widget.day,
      'currency': currency.code,
      'amount': amount,
      'expression': expressionOf(text),
      'note': note.isEmpty ? null : note,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (created == null) return;
    if (widget.onCreated != null) {
      widget.onCreated!();
      return;
    }
    _amount.clear();
    _note.clear();
    _amountFocus.requestFocus();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: CurrenciesStore.instance, builder: (context, _) => _build(context));
  }

  /// The button that says which currency the spend goes in. With two currencies a tap swaps them;
  /// with more it opens the list.
  Widget _currencyButton(BuildContext context, Currency currency, List<Currency> offered) {
    final palette = context.palette;
    final style = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minimumSize: const Size(56, 52),
      backgroundColor: palette.bgAccented,
      foregroundColor: palette.text,
    );
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(currencySymbol(currency), style: money(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        // Says the button changes something: two currencies swap, more open a list.
        Icon(offered.length == 2 ? LucideIcons.arrowLeftRight : LucideIcons.chevronDown, size: 14, color: palette.muted),
      ],
    );
    final hint = 'Gasto em ${currencyPlural(currency).toLowerCase()} (trocar a moeda)';
    if (offered.length == 2) {
      return Tooltip(
        message: hint,
        child: FilledButton(
          style: style,
          onPressed: () => _pick(offered.firstWhere((other) => other != currency)),
          child: label,
        ),
      );
    }
    return MenuAnchor(
      menuChildren: [
        for (final option in offered)
          MenuItemButton(
            leadingIcon: SizedBox(width: 40, child: Text(currencySymbol(option), style: money(fontSize: 14, color: palette.muted))),
            trailingIcon: option == currency ? Icon(LucideIcons.check, size: 16, color: palette.highlighted) : null,
            onPressed: () => _pick(option),
            child: Text(currencyName(option)),
          ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: hint,
        child: FilledButton(
          style: style,
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          child: label,
        ),
      ),
    );
  }

  Widget _build(BuildContext context) {
    final currency = _currency;
    // Nothing can be entered without a currency to enter it in; the screen says so above the form.
    if (currency == null) return const SizedBox();
    final offered = CurrenciesStore.instance.offered;
    final canSubmit = _amount.text.trim().isNotEmpty && !_saving;
    return Column(
      children: [
        Row(
          children: [
            if (offered.length > 1) ...[
              _currencyButton(context, currency, offered),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TextField(
                controller: _amount,
                focusNode: _amountFocus,
                autofocus: widget.autofocus,
                keyboardType: amountKeyboard,
                style: money(fontSize: 20),
                decoration: const InputDecoration(hintText: '0,00'),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: canSubmit ? _submit : null,
                child: _saving
                    ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                    : const Text('Lançar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Com o quê?'),
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => canSubmit ? _submit() : null,
        ),
      ],
    );
  }
}

/// Opens the sheet that enters a spend on [day]. It closes once the spend is saved.
Future<void> showSpendSheet(
  BuildContext context, {
  required int day,
  required Future<DailySpend?> Function(Json body) create,
  Currency? currency,
  ValueChanged<Currency>? onCurrencyPicked,
}) {
  return showSheet<void>(
    context,
    title: 'Lançar gasto',
    body: (context) => SpendForm(
      day: day,
      create: create,
      autofocus: true,
      currency: currency,
      onCurrencyPicked: onCurrencyPicked,
      onCreated: () => Navigator.of(context).pop(),
    ),
  );
}

/// One spend: what it was and how much, with its cost under a spend in another currency. A tap
/// opens it for editing; swiping it away deletes it.
class SpendRow extends StatelessWidget {
  const SpendRow({super.key, required this.spend, required this.main, required this.cost, required this.onUpdate, required this.onRemove});

  final DailySpend spend;

  /// The currency the month is worked out in.
  final Currency main;

  /// What the spend costs the allowance, in the main currency; shown under spends in another one.
  final double? cost;
  final ValueChanged<Json> onUpdate;
  final VoidCallback onRemove;

  void _open(BuildContext context) {
    showSheet<void>(
      context,
      title: 'Gasto',
      body: (context) => _SpendEditForm(spend: spend, onUpdate: onUpdate, onRemove: onRemove),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final note = spend.note;
    return Dismissible(
      key: ValueKey('spend-${spend.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: palette.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(LucideIcons.trash2, size: 20, color: Colors.white),
      ),
      onDismissed: (_) => onRemove(),
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  note ?? 'Gasto',
                  style: TextStyle(fontSize: 16, color: note == null ? palette.muted : palette.highlighted),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatMoney(spend.amount, spend.currency), style: money(fontSize: 15, color: palette.text)),
                  if (spend.currency != main) Text('≈ ${formatMoney(cost, main)}', style: money(fontSize: 12, color: palette.dimmed)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A divided list of [SpendRow]s.
class SpendList extends StatelessWidget {
  const SpendList({super.key, required this.spends, required this.summary, required this.onUpdate, required this.onRemove, this.onRestore});

  final List<DailySpend> spends;

  /// The month's summary: its main currency, and the rates a spend in another one is costed with.
  final MonthSummary summary;
  final void Function(String id, Json patch) onUpdate;
  final void Function(String id) onRemove;

  /// Enters a spend again. With it, deleting one offers to undo.
  final Future<DailySpend?> Function(Json body)? onRestore;

  void _remove(DailySpend spend) {
    onRemove(spend.id);
    final restore = onRestore;
    if (restore == null) return;
    toast(
      'Gasto apagado',
      description: spend.note,
      icon: LucideIcons.trash2,
      duration: const Duration(seconds: 6),
      actionLabel: 'Desfazer',
      onAction: () => restore({
        'day': spend.day,
        'currency': spend.currency.code,
        'amount': spend.amount,
        'expression': spend.expression,
        'note': spend.note,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (index, spend) in spends.indexed) ...[
          if (index > 0) const RowDivider(),
          SpendRow(
            key: ValueKey(spend.id),
            spend: spend,
            main: summary.main,
            cost: summary.cost(spend),
            onUpdate: (patch) => onUpdate(spend.id, patch),
            onRemove: () => _remove(spend),
          ),
        ],
      ],
    );
  }
}

/// Changes a spend's description and amount, or deletes it.
class _SpendEditForm extends StatefulWidget {
  const _SpendEditForm({required this.spend, required this.onUpdate, required this.onRemove});

  final DailySpend spend;
  final ValueChanged<Json> onUpdate;
  final VoidCallback onRemove;

  @override
  State<_SpendEditForm> createState() => _SpendEditFormState();
}

class _SpendEditFormState extends State<_SpendEditForm> {
  late final _note = TextEditingController(text: widget.spend.note ?? '');
  late final _amount = TextEditingController(text: _initialAmount);
  String? _amountError;

  String get _initialAmount => amountText(widget.spend.amount, widget.spend.expression);

  void _submit() {
    final note = _note.text.trim();
    final text = _amount.text.trim();
    final amount = evaluateExpression(text);
    setState(() => _amountError = amount == null ? 'Número ou conta, ex.: 4,50+2' : null);
    if (amount == null) return;
    final patch = <String, dynamic>{
      if (note != (widget.spend.note ?? '')) 'note': note.isEmpty ? null : note,
      if (text != _initialAmount) ...{'amount': amount, 'expression': expressionOf(text)},
    };
    Navigator.of(context).pop();
    if (patch.isNotEmpty) widget.onUpdate(patch);
  }

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Valor'),
        TextField(
          controller: _amount,
          keyboardType: amountKeyboard,
          style: money(fontSize: 20),
          textInputAction: TextInputAction.next,
          decoration: amountDecoration(context, widget.spend.currency, fontSize: 20, errorText: _amountError),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Com o quê?'),
        TextField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _submit, child: const Text('Salvar')),
        const SizedBox(height: 8),
        ActionButton(
          label: 'Apagar gasto',
          icon: LucideIcons.trash2,
          style: ActionStyle.subtle,
          danger: true,
          onPressed: () {
            Navigator.of(context).pop();
            widget.onRemove();
          },
        ),
      ],
    );
  }
}
