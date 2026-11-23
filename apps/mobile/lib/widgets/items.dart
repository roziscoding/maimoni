import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../domain/expression.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../theme.dart';
import 'common.dart';
import 'fields.dart';

/// One currency's incomes and expenses in a month, with the paid and pending totals under them.
class ItemSection extends StatelessWidget {
  const ItemSection({
    super.key,
    required this.currency,
    required this.items,
    required this.totals,
    required this.alone,
    required this.onUpdate,
    required this.onRemove,
    required this.onPromote,
  });

  final Currency currency;
  final List<MonthItem> items;
  final CurrencyTotals totals;

  /// Whether this is the month's only section, which then needs no currency in its title.
  final bool alone;
  final void Function(String id, Json patch) onUpdate;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onPromote;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = alone ? 'Entradas e saídas' : currencyPlural(currency);
    final incomes = items.where((item) => item.kind == EntryKind.income).toList();
    final expenses = items.where((item) => item.kind == EntryKind.expense).toList();
    final paidShare = totals.expenses > 0 ? (totals.paid / totals.expenses).clamp(0, 1).toDouble() : 0.0;

    List<Widget> rows(List<MonthItem> group) => [
          for (final (index, item) in group.indexed) ...[
            if (index > 0) const RowDivider(indent: 52),
            ItemRow(
              key: ValueKey(item.id),
              item: item,
              onUpdate: (patch) => onUpdate(item.id, patch),
              onRemove: () => onRemove(item.id),
              onPromote: () => onPromote(item.id),
            ),
          ],
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title,
          tag: alone ? null : currency.code,
          trailing: totals.unresolved > 0
              ? Pill(
                  label: totals.unresolved == 1 ? '1 a confirmar' : '${totals.unresolved} a confirmar',
                  icon: LucideIcons.circleDot,
                  tone: Tone.warning,
                )
              : null,
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (incomes.isNotEmpty) ...[
                GroupLabel('Entradas', trailing: formatMoney(totals.income, currency)),
                ...rows(incomes),
              ],
              GroupLabel('Saídas', trailing: expenses.isEmpty ? null : formatMoney(totals.expenses, currency)),
              if (expenses.isNotEmpty)
                ...rows(expenses)
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Text(
                    alone ? 'Nenhuma saída ainda.' : 'Nenhuma saída em ${title.toLowerCase()} ainda.',
                    style: TextStyle(fontSize: 15, color: palette.dimmed),
                  ),
                ),
              if (totals.expenses > 0) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(value: paidShare, minHeight: 6, color: palette.bgInverted),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Pago', style: TextStyle(fontSize: 13, color: palette.muted)),
                            Text(formatMoney(totals.paid, currency), style: money(fontSize: 15, color: palette.text)),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('Falta pagar', style: TextStyle(fontSize: 13, color: palette.muted)),
                          Text(formatMoney(totals.pending, currency), style: money(fontSize: 15, fontWeight: FontWeight.w600, color: palette.highlighted)),
                        ]),
                      ]),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One item of a month: a box to tick it paid, its name and its amount. A tap opens it for editing.
class ItemRow extends StatelessWidget {
  const ItemRow({super.key, required this.item, required this.onUpdate, required this.onRemove, required this.onPromote});

  final MonthItem item;
  final ValueChanged<Json> onUpdate;
  final VoidCallback onRemove;
  final VoidCallback onPromote;

  void _open(BuildContext context) {
    showSheet<void>(
      context,
      title: item.kind == EntryKind.income ? 'Entrada' : 'Saída',
      body: (context) => ItemForm(
        editing: true,
        name: item.name,
        amount: item.amount,
        expression: item.expression,
        kind: item.kind,
        currency: item.currency,
        submitLabel: 'Salvar',
        onSubmit: onUpdate,
        actions: [
          if (item.needsReview)
            SheetAction(
              icon: LucideIcons.check,
              label: 'Confirmar valor',
              subtitle: 'O valor veio do template como estimativa.',
              onTap: () {
                Navigator.of(context).pop();
                onUpdate({'needsReview': false});
              },
            ),
          SheetAction(
            icon: LucideIcons.layoutTemplate,
            label: item.templateItemId != null ? 'Atualizar no template' : 'Salvar no template',
            subtitle: 'Os próximos meses começam com este item como está aqui.',
            onTap: () {
              Navigator.of(context).pop();
              onPromote();
            },
          ),
          SheetAction(
            icon: LucideIcons.trash2,
            label: 'Excluir',
            danger: true,
            onTap: () {
              Navigator.of(context).pop();
              onRemove();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isIncome = item.kind == EntryKind.income;
    final pending = item.amount == null || item.needsReview;
    return InkWell(
      onTap: () => _open(context),
      child: Opacity(
        opacity: item.paid ? 0.55 : 1,
        child: Row(
          children: [
            const SizedBox(width: 4),
            Checkbox(
              value: item.paid,
              semanticLabel: '${isIncome ? 'Recebido' : 'Pago'}: ${item.name}',
              onChanged: (value) {
                HapticFeedback.selectionClick();
                onUpdate({'paid': value == true});
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 16,
                        color: palette.highlighted,
                        decoration: item.paid ? TextDecoration.lineThrough : null,
                        decorationColor: palette.muted,
                      ),
                    ),
                    if (pending)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.amount == null ? 'Falta o valor deste mês' : 'Estimativa, toque para confirmar',
                          style: TextStyle(fontSize: 13, color: palette.warning),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              item.amount == null ? 'preencher' : formatMoney(item.amount, item.currency),
              style: money(fontSize: 15, color: pending ? palette.warning : palette.text),
            ),
            if (item.expression != null) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(LucideIcons.sigma, size: 14, color: palette.dimmed)),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

PopupMenuItem<String> menuItem(BuildContext context, String value, IconData icon, String label, {bool danger = false}) {
  final palette = context.palette;
  final color = danger ? palette.error : palette.text;
  return PopupMenuItem(
    value: value,
    child: Row(children: [
      Icon(icon, size: 18, color: danger ? palette.error : palette.muted),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(fontSize: 15, color: color)),
    ]),
  );
}

/// The form behind every item sheet, for a month's item or a template's, new or existing: kind,
/// name, amount, and what else the caller asks for.
class ItemForm extends StatefulWidget {
  const ItemForm({
    super.key,
    this.editing = false,
    this.name = '',
    this.amount,
    this.expression,
    this.kind = EntryKind.expense,
    this.currency,
    this.currencies = const [],
    this.variable,
    required this.submitLabel,
    required this.onSubmit,
    this.actions = const [],
  });

  /// Whether the form changes an existing item. It then submits only the fields that changed, and
  /// nothing at all when none did.
  final bool editing;
  final String name;
  final double? amount;
  final String? expression;
  final EntryKind kind;

  /// The currency the item is in, or the one a new item starts in.
  final Currency? currency;

  /// The currencies a new item can be in. With more than one the form asks which.
  final List<Currency> currencies;

  /// The template's "changes every month" switch. Null leaves it out of the form.
  final bool? variable;
  final String submitLabel;
  final ValueChanged<Json> onSubmit;

  /// Rows under the submit button for what else can be done with the item.
  final List<Widget> actions;

  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  late final _name = TextEditingController(text: widget.name);
  late final _amount = TextEditingController(text: _initialAmount);
  late EntryKind _kind = widget.kind;
  late Currency? _currency = widget.currency ?? widget.currencies.firstOrNull;
  late bool? _variable = widget.variable;
  String? _nameError;
  String? _amountError;

  String get _initialAmount => amountText(widget.amount, widget.expression);

  void _submit() {
    final name = _name.text.trim();
    final amountText = _amount.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Dê um nome' : null;
      _amountError = amountText.isNotEmpty && evaluateExpression(amountText) == null ? 'Número ou conta, ex.: 11,99+2,99' : null;
    });
    if (_nameError != null || _amountError != null) return;
    final amount = {
      'amount': amountText.isEmpty ? null : evaluateExpression(amountText),
      'expression': amountText.isEmpty ? null : expressionOf(amountText),
    };
    final Json values;
    if (widget.editing) {
      values = {
        if (name != widget.name) 'name': name,
        if (_kind != widget.kind) 'kind': _kind.name,
        if (amountText != _initialAmount) ...amount,
        if (_variable != widget.variable) 'variable': _variable,
      };
    } else {
      values = {
        'name': name,
        'currency': _currency?.code,
        'kind': _kind.name,
        ...amount,
        if (_variable != null) 'variable': _variable,
      };
    }
    Navigator.of(context).pop();
    if (values.isNotEmpty) widget.onSubmit(values);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = _currency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Segmented<EntryKind>(
          value: _kind,
          options: const [
            (value: EntryKind.expense, label: 'Saída', icon: LucideIcons.arrowUpRight),
            (value: EntryKind.income, label: 'Entrada', icon: LucideIcons.arrowDownLeft),
          ],
          onChanged: (kind) => setState(() => _kind = kind),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Nome'),
        TextField(
          controller: _name,
          autofocus: !widget.editing,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(hintText: _kind == EntryKind.income ? 'Salário' : 'Aluguel', errorText: _nameError),
        ),
        const SizedBox(height: 16),
        FieldLabel('Valor', hint: _variable == true ? 'estimativa, pode ficar em branco' : 'aceita contas: 11,99+2,99'),
        TextField(
          controller: _amount,
          keyboardType: amountKeyboard,
          style: money(fontSize: 17),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: amountDecoration(context, currency, errorText: _amountError),
        ),
        if (!widget.editing && widget.currencies.length > 1) ...[
          const SizedBox(height: 16),
          const FieldLabel('Moeda'),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final option in widget.currencies)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(option.code, style: money(fontSize: 14)),
                      tooltip: currencyName(option),
                      selected: option == currency,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _currency = option),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (_variable != null) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Varia todo mês'),
            subtitle: const Text('Como a fatura do cartão: o mês novo pede para confirmar o valor.'),
            value: _variable!,
            onChanged: (value) => setState(() => _variable = value),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
        if (widget.actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 4),
          ...widget.actions,
        ],
      ],
    );
  }
}
