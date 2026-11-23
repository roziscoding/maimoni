import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../domain/expression.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../state/currencies_store.dart';
import '../state/toast.dart';
import '../theme.dart';
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
  const SpendForm({super.key, required this.day, required this.create, this.autofocus = false});

  final int day;
  final Future<DailySpend?> Function(Json body) create;
  final bool autofocus;

  @override
  State<SpendForm> createState() => _SpendFormState();
}

class _SpendFormState extends State<SpendForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _amountFocus = FocusNode();

  // Kept between entries: a run of spends usually happens in the same currency.
  Currency? _picked;
  bool _saving = false;

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
    if (created != null) {
      _amount.clear();
      _note.clear();
      _amountFocus.requestFocus();
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(52, 48),
      backgroundColor: palette.bgElevated,
      foregroundColor: palette.text,
      side: BorderSide(color: palette.borderAccented),
    );
    final label = Text(currencySymbol(currency), style: money(fontSize: 16, fontWeight: FontWeight.w500));
    final hint = 'Gasto em ${currencyPlural(currency).toLowerCase()} (trocar a moeda)';
    if (offered.length == 2) {
      return Tooltip(
        message: hint,
        child: FilledButton(
          style: style,
          onPressed: () => setState(() => _picked = offered.firstWhere((other) => other != currency)),
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
            onPressed: () => setState(() => _picked = option),
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: money(fontSize: 17),
                decoration: const InputDecoration(hintText: '0,00', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
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
          decoration: const InputDecoration(hintText: 'Com o quê?', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => canSubmit ? _submit() : null,
        ),
      ],
    );
  }
}

/// One spend: description and amount edited in place, its cost under a spend in another currency, delete.
class SpendRow extends StatelessWidget {
  const SpendRow({super.key, required this.spend, required this.main, required this.cost, required this.onUpdate, required this.onRemove});

  final DailySpend spend;

  /// The currency the month is worked out in.
  final Currency main;

  /// What the spend costs the allowance, in the main currency; shown under spends in another one.
  final double? cost;
  final ValueChanged<Json> onUpdate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: InlineTextField(
              value: spend.note ?? '',
              hint: 'Gasto',
              allowEmpty: true,
              onCommit: (value) => onUpdate({'note': value.isEmpty ? null : value}),
            ),
          ),
          SizedBox(
            width: 128,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountField(
                  amount: spend.amount,
                  expression: spend.expression,
                  currency: spend.currency,
                  onCommit: (amount, expression) {
                    if (amount != null) onUpdate({'amount': amount, 'expression': expression});
                  },
                ),
                if (spend.currency != main)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('≈ ${formatMoney(cost, main)}', style: money(fontSize: 12, color: palette.dimmed)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 16),
            visualDensity: VisualDensity.compact,
            tooltip: 'Apagar ${spend.note ?? 'gasto'}',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// A divided list of [SpendRow]s.
class SpendList extends StatelessWidget {
  const SpendList({super.key, required this.spends, required this.summary, required this.onUpdate, required this.onRemove});

  final List<DailySpend> spends;

  /// The month's summary: its main currency, and the rates a spend in another one is costed with.
  final MonthSummary summary;
  final void Function(String id, Json patch) onUpdate;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (index, spend) in spends.indexed) ...[
          if (index > 0) const Divider(),
          SpendRow(
            key: ValueKey(spend.id),
            spend: spend,
            main: summary.main,
            cost: summary.cost(spend),
            onUpdate: (patch) => onUpdate(spend.id, patch),
            onRemove: () => onRemove(spend.id),
          ),
        ],
      ],
    );
  }
}
