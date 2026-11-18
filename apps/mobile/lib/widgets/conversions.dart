import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../domain/expression.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../state/month_controller.dart';
import '../theme.dart';
import 'common.dart';
import 'fields.dart';

/// Port of `ConversionSection.vue`: completed BRL→EUR conversions, with a form that takes what was
/// sent and what arrived.
class ConversionSection extends StatelessWidget {
  const ConversionSection({super.key, required this.controller, required this.conversions});

  final MonthController controller;
  final List<Conversion> conversions;

  Future<void> _confirmDelete(BuildContext context, Conversion conversion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conversão?'),
        content: const Text('O saldo e a projeção do mês serão recalculados sem ela.'),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ActionButton(label: 'Excluir', icon: LucideIcons.trash2, danger: true, onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (confirmed == true) await controller.removeConversion(conversion.id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sorted = [...conversions]..sort((a, b) {
        final byDay = b.day.compareTo(a.day);
        return byDay != 0 ? byDay : b.createdAt.compareTo(a.createdAt);
      });

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            title: 'Conversões',
            subtitle: 'Reais enviados e euros que já chegaram.',
            trailing: ActionButton(
              label: 'Lançar',
              icon: LucideIcons.arrowRightLeft,
              style: ActionStyle.subtle,
              onPressed: () => showConversionSheet(context, controller),
            ),
          ),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Text('Nenhuma conversão lançada neste mês.', style: TextStyle(fontSize: 14, color: palette.muted)),
            )
          else
            for (final (index, conversion) in sorted.indexed) ...[
              if (index > 0) const Divider(indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayLabel(controller.year, controller.month, conversion.day),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.highlighted),
                          ),
                          if (conversion.note != null)
                            Text(conversion.note!, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: palette.muted)),
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: formatMoney(conversion.sentBrl, Currency.brl)),
                              TextSpan(text: ' → ', style: TextStyle(color: palette.muted)),
                              TextSpan(
                                text: formatMoney(conversion.receivedEur, Currency.eur),
                                style: TextStyle(fontWeight: FontWeight.w500, color: palette.highlighted),
                              ),
                            ]),
                            style: money(fontSize: 14, color: palette.toned),
                          ),
                          Text('${formatMoney(conversion.feeBrl, Currency.brl)} de taxa', style: money(fontSize: 12, color: palette.muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar conversão',
                      icon: const Icon(LucideIcons.pencil, size: 16),
                      onPressed: () => showConversionSheet(context, controller, editing: conversion),
                    ),
                    IconButton(
                      tooltip: 'Excluir conversão',
                      icon: Icon(LucideIcons.trash2, size: 16, color: palette.error),
                      onPressed: () => _confirmDelete(context, conversion),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

Future<void> showConversionSheet(BuildContext context, MonthController controller, {Conversion? editing}) {
  return showSheet(
    context,
    title: editing != null ? 'Editar conversão' : 'Lançar conversão',
    description: 'Informe quanto saiu em reais e quanto chegou em euros. A taxa é o que sobra da conta com o câmbio.',
    body: (context) => _ConversionForm(controller: controller, editing: editing),
  );
}

class _ConversionForm extends StatefulWidget {
  const _ConversionForm({required this.controller, this.editing});

  final MonthController controller;
  final Conversion? editing;

  @override
  State<_ConversionForm> createState() => _ConversionFormState();
}

class _ConversionFormState extends State<_ConversionForm> {
  late int _day;
  final _received = TextEditingController();
  final _sent = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  Map<String, String> _errors = {};

  int get _maxDay => daysInMonth(widget.controller.year, widget.controller.month);

  @override
  void initState() {
    super.initState();
    final conversion = widget.editing;
    final now = DateTime.now();
    final currentMonth = now.year == widget.controller.year && now.month == widget.controller.month;
    _day = conversion?.day ?? (currentMonth ? now.day : 1);
    if (conversion != null) {
      _received.text = formatPlain(conversion.receivedEur);
      _sent.text = formatPlain(conversion.sentBrl);
      _note.text = conversion.note ?? '';
    }
  }

  double? _value(TextEditingController controller) => evaluateExpression(controller.text);

  /// EUR→BRL rate the month is using, which the fee of a new conversion is worked out from.
  double? get _rate => widget.controller.summary?.transfer.rate;

  /// The fee isn't typed in. The server works it out from the rate when the amounts are saved; this
  /// previews it. A conversion being edited keeps its fee while its amounts stay the same.
  ({double? fee, bool kept}) _fee() {
    final sent = _value(_sent);
    final received = _value(_received);
    final editing = widget.editing;
    if (editing != null && sent == editing.sentBrl && received == editing.receivedEur) return (fee: editing.feeBrl, kept: true);
    if (sent == null || sent <= 0 || received == null || received <= 0 || _rate == null) return (fee: null, kept: false);
    return (fee: conversionFee(sentBrl: sent, receivedEur: received, rate: _rate), kept: false);
  }

  Future<void> _submit() async {
    final received = _value(_received);
    final sent = _value(_sent);
    final errors = <String, String>{};
    if (received == null || received <= 0) errors['receivedEur'] = 'Informe um valor maior que zero';
    if (sent == null || sent <= 0) errors['sentBrl'] = 'Informe um valor maior que zero';
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _saving = true);
    final note = _note.text.trim();
    final body = {'day': _day, 'sentBrl': sent, 'receivedEur': received, 'note': note.isEmpty ? null : note};
    final saved = widget.editing != null
        ? await widget.controller.updateConversion(widget.editing!.id, body)
        : await widget.controller.addConversion(body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved != null) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _received.dispose();
    _sent.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fee = _fee();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Dia'),
        DropdownButtonFormField<int>(
          initialValue: _day.clamp(1, _maxDay),
          menuMaxHeight: 320,
          items: [for (var day = 1; day <= _maxDay; day++) DropdownMenuItem(value: day, child: Text('$day'))],
          onChanged: (value) => setState(() => _day = value ?? _day),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MoneyFormField(
                controller: _sent,
                label: 'BRL enviado',
                prefix: r'R$',
                errorText: _errors['sentBrl'],
                // Rebuilds so the fee below follows the amounts.
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MoneyFormField(
                controller: _received,
                label: 'EUR recebido',
                prefix: '€',
                errorText: _errors['receivedEur'],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (fee.fee != null)
          Text(
            fee.kept
                ? 'Taxa: ${formatMoney(fee.fee, Currency.brl)}, calculada quando a conversão foi lançada.'
                : 'Taxa: ${formatMoney(fee.fee, Currency.brl)}, com o euro a ${formatRate(_rate)}.',
            style: TextStyle(fontSize: 14, color: palette.muted),
          )
        else if (_rate == null)
          Text('Sem cotação do euro agora, a taxa desta conversão fica em zero.', style: TextStyle(fontSize: 14, color: palette.warning)),
        const SizedBox(height: 16),
        const FieldLabel('Anotação', hint: 'Opcional'),
        TextField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ex.: dinheiro para aluguel'),
        ),
        SheetActions(
          primary: ActionButton(
            label: widget.editing != null ? 'Salvar' : 'Lançar',
            icon: LucideIcons.check,
            loading: _saving,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}
