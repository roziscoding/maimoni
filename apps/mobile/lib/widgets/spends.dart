import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../domain/expression.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../state/toast.dart';
import '../theme.dart';
import 'fields.dart';

/// How much is still left to spend on the open day, with each spend as a slice of the budget.
class DayHero extends StatelessWidget {
  const DayHero({super.key, required this.allowance, required this.spends, required this.transfer});

  final Allowance allowance;

  /// The open day's spending, in the order it was recorded.
  final List<DailySpend> spends;
  final Transfer transfer;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final budget = allowance.eur ?? 0;
    final remaining = allowance.remainingEur ?? 0;
    final over = remaining < 0;
    final rate = transfer.rate;

    // Each spend is a slice of the day's budget; past the budget the bar is full and turns red.
    final segments = <double>[];
    if (budget > 0) {
      var used = 0.0;
      for (final spend in spends) {
        final value = spendInEurFor(spend, transfer) ?? 0;
        final width = (value.clamp(0, (budget - used).clamp(0, double.infinity)) / budget).toDouble();
        used += value > 0 ? value : 0;
        if (width > 0) segments.add(width);
      }
    }

    final String caption;
    if (over) {
      caption = 'Passou ${formatMoney(-remaining, Currency.eur)} do valor de hoje.';
    } else if (allowance.spentToday > 0) {
      caption = 'Sobrando de ${formatMoney(budget, Currency.eur)} para hoje.';
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
            formatMoney(remaining, Currency.eur),
            style: money(fontSize: 60, fontWeight: FontWeight.w600, height: 1, color: over ? palette.error : palette.highlighted),
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: caption),
            if (rate != null) TextSpan(text: ' ≈ ${formatMoney(remaining * rate, Currency.brl)}', style: money(fontSize: 14)),
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

/// Port of `SpendForm.vue`: currency toggle, amount (number or expression), description, submit.
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
  Currency _currency = Currency.eur;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  Future<void> _submit() async {
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
      'currency': _currency.code,
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
    final palette = context.palette;
    final canSubmit = _amount.text.trim().isNotEmpty && !_saving;
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 52,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: palette.bgElevated,
                  foregroundColor: palette.text,
                  side: BorderSide(color: palette.borderAccented),
                ),
                onPressed: () => setState(() => _currency = _currency == Currency.eur ? Currency.brl : Currency.eur),
                child: Text(_currency == Currency.eur ? '€' : r'R$', style: money(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(width: 8),
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

/// One spend: description and amount edited in place, the EUR cost under BRL spends, delete.
class SpendRow extends StatelessWidget {
  const SpendRow({super.key, required this.spend, required this.eur, required this.onUpdate, required this.onRemove});

  final DailySpend spend;

  /// What the spend costs the EUR allowance; shown under BRL spends.
  final double? eur;
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
                if (spend.currency == Currency.brl)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('≈ ${formatMoney(eur, Currency.eur)}', style: money(fontSize: 12, color: palette.dimmed)),
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
  const SpendList({super.key, required this.spends, required this.inEur, required this.onUpdate, required this.onRemove});

  final List<DailySpend> spends;
  final double? Function(DailySpend) inEur;
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
            eur: inEur(spend),
            onUpdate: (patch) => onUpdate(spend.id, patch),
            onRemove: () => onRemove(spend.id),
          ),
        ],
      ],
    );
  }
}
