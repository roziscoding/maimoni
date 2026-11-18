import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../domain/expression.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../theme.dart';
import 'common.dart';
import 'fields.dart';

/// Port of `ItemSection.vue`: one currency's incomes and expenses with paid/pending totals.
class ItemSection extends StatelessWidget {
  const ItemSection({
    super.key,
    required this.currency,
    required this.items,
    required this.totals,
    required this.onUpdate,
    required this.onRemove,
    required this.onPromote,
    required this.onAdd,
  });

  final Currency currency;
  final List<MonthItem> items;
  final CurrencyTotals totals;
  final void Function(String id, Json patch) onUpdate;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onPromote;
  final ValueChanged<Json> onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = currency == Currency.brl ? 'Reais' : 'Euros';
    final incomes = items.where((item) => item.kind == EntryKind.income).toList();
    final expenses = items.where((item) => item.kind == EntryKind.expense).toList();
    // Sum of the listed incomes only: for EUR, `totals.income` also includes the converted BRL.
    final incomeTotal = incomes.fold<double>(0, (sum, item) => sum + (item.amount ?? 0));
    final paidShare = totals.expenses > 0 ? (totals.paid / totals.expenses).clamp(0, 1).toDouble() : 0.0;

    Widget row(MonthItem item) => ItemRow(
          key: ValueKey(item.id),
          item: item,
          onUpdate: (patch) => onUpdate(item.id, patch),
          onRemove: () => onRemove(item.id),
          onPromote: () => onPromote(item.id),
        );

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            title: title,
            tag: currency.code,
            trailing: totals.unresolved > 0
                ? Pill(
                    label: totals.unresolved == 1 ? '1 valor a confirmar' : '${totals.unresolved} valores a confirmar',
                    icon: LucideIcons.circleDot,
                    tone: Tone.warning,
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (incomes.isNotEmpty) ...[
                  GroupLabel('Entradas', trailing: formatMoney(incomeTotal, currency)),
                  ...incomes.map(row),
                  const SizedBox(height: 8),
                  const GroupLabel('Saídas'),
                ],
                if (expenses.isNotEmpty)
                  ...expenses.map(row)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: Text('Nenhuma saída em ${title.toLowerCase()} ainda.', style: TextStyle(fontSize: 14, color: palette.muted)),
                  ),
                AddItemForm(currency: currency, onAdd: onAdd),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.border))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: Text('Saída total', style: TextStyle(fontSize: 14, color: palette.muted))),
                  Text(formatMoney(totals.expenses, currency), style: money(fontSize: 16, fontWeight: FontWeight.w600, color: palette.highlighted)),
                ]),
                if (totals.expenses > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: paidShare, minHeight: 6, color: palette.bgInverted),
                  ),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Pago', style: TextStyle(fontSize: 14, color: palette.muted)),
                      Text(formatMoney(totals.paid, currency), style: money(fontSize: 14, color: palette.text)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Falta pagar', style: TextStyle(fontSize: 14, color: palette.muted)),
                    Text(formatMoney(totals.pending, currency), style: money(fontSize: 14, color: palette.text)),
                  ]),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Port of `ItemRow.vue`: paid checkbox, name and amount edited in place, actions menu.
class ItemRow extends StatelessWidget {
  const ItemRow({super.key, required this.item, required this.onUpdate, required this.onRemove, required this.onPromote});

  final MonthItem item;
  final ValueChanged<Json> onUpdate;
  final VoidCallback onRemove;
  final VoidCallback onPromote;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isIncome = item.kind == EntryKind.income;
    return Opacity(
      opacity: item.paid ? 0.6 : 1,
      child: Row(
        children: [
          Checkbox(
            value: item.paid,
            visualDensity: VisualDensity.compact,
            semanticLabel: '${isIncome ? 'Recebido' : 'Pago'}: ${item.name}',
            onChanged: (value) => onUpdate({'paid': value == true}),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: InlineTextField(
                    value: item.name,
                    style: TextStyle(
                      fontSize: 14,
                      decoration: item.paid ? TextDecoration.lineThrough : null,
                      decorationColor: palette.muted,
                    ),
                    onCommit: (name) => onUpdate({'name': name}),
                  ),
                ),
                if (item.needsReview)
                  Tooltip(
                    message: 'Valor estimado a partir do template. Confirme ou edite para este mês.',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => onUpdate({'needsReview': false}),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: palette.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(LucideIcons.circleDot, size: 12, color: palette.warning),
                          const SizedBox(width: 4),
                          Text('confirmar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: palette.warning)),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 136,
            child: AmountField(
              amount: item.amount,
              expression: item.expression,
              currency: item.currency,
              highlight: item.amount == null,
              onCommit: (amount, expression) => onUpdate({'amount': amount, 'expression': expression}),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(LucideIcons.ellipsis, size: 18, color: palette.muted),
            tooltip: 'Ações de ${item.name}',
            onSelected: (action) => switch (action) {
              'confirm' => onUpdate({'needsReview': false}),
              'promote' => onPromote(),
              'kind' => onUpdate({'kind': isIncome ? 'expense' : 'income'}),
              'remove' => onRemove(),
              _ => null,
            },
            itemBuilder: (context) => [
              if (item.needsReview) menuItem(context, 'confirm', LucideIcons.check, 'Confirmar valor'),
              menuItem(context, 'promote', LucideIcons.layoutTemplate, item.templateItemId != null ? 'Atualizar no template' : 'Salvar no template'),
              menuItem(
                context,
                'kind',
                isIncome ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
                isIncome ? 'Mover para saídas' : 'Mover para entradas',
              ),
              const PopupMenuDivider(),
              menuItem(context, 'remove', LucideIcons.trash2, 'Excluir', danger: true),
            ],
          ),
        ],
      ),
    );
  }
}

PopupMenuItem<String> menuItem(BuildContext context, String value, IconData icon, String label, {bool danger = false}) {
  final palette = context.palette;
  final color = danger ? palette.error : palette.text;
  return PopupMenuItem(
    value: value,
    height: 40,
    child: Row(children: [
      Icon(icon, size: 16, color: danger ? palette.error : palette.muted),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 14, color: color)),
    ]),
  );
}

/// Port of `AddItemForm.vue`: kind toggle, name and optional amount for a new row.
class AddItemForm extends StatefulWidget {
  const AddItemForm({super.key, required this.currency, required this.onAdd});

  final Currency currency;
  final ValueChanged<Json> onAdd;

  @override
  State<AddItemForm> createState() => _AddItemFormState();
}

class _AddItemFormState extends State<AddItemForm> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _nameFocus = FocusNode();
  EntryKind _kind = EntryKind.expense;
  String? _nameError;
  String? _amountError;

  void _submit() {
    final name = _name.text.trim();
    final amountText = _amount.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Dê um nome' : null;
      _amountError = amountText.isNotEmpty && evaluateExpression(amountText) == null ? 'Número ou conta, ex.: 11,99+2,99' : null;
    });
    if (_nameError != null || _amountError != null) return;
    widget.onAdd({
      'name': name,
      'currency': widget.currency.code,
      'kind': _kind.name,
      'amount': amountText.isEmpty ? null : evaluateExpression(amountText),
      'expression': amountText.isEmpty ? null : expressionOf(amountText),
    });
    _name.clear();
    _amount.clear();
    _nameFocus.requestFocus();
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final income = _kind == EntryKind.income;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: income ? 'Entrada (toque para mudar para saída)' : 'Saída (toque para mudar para entrada)',
            icon: Icon(income ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight, size: 18, color: palette.text),
            onPressed: () => setState(() => _kind = income ? EntryKind.expense : EntryKind.income),
          ),
          Expanded(
            child: TextField(
              controller: _name,
              focusNode: _nameFocus,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: income ? 'Nova entrada' : 'Nova saída', errorText: _nameError),
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 112,
            child: TextField(
              controller: _amount,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: money(fontSize: 14),
              decoration: InputDecoration(hintText: '0,00', errorText: _amountError, errorMaxLines: 3),
              onSubmitted: (_) => _submit(),
            ),
          ),
          IconButton(tooltip: 'Adicionar', icon: Icon(LucideIcons.plus, size: 18, color: palette.text), onPressed: _submit),
        ],
      ),
    );
  }
}
