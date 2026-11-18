import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../domain/expression.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../state/month_controller.dart';
import '../theme.dart';
import 'common.dart';
import 'fields.dart';

/// Port of `ConversionSection.vue`: completed BRL→EUR conversions, with a form that pre-fills
/// from a Wise quote.
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
    description: 'A cotação da Wise é só uma ajuda. Ajuste os valores para o que aconteceu de fato.',
    body: (context) => _ConversionForm(controller: controller, editing: editing),
  );
}

enum _QuoteMode { eur, brl }

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
  final _fee = TextEditingController();
  final _note = TextEditingController();
  _QuoteMode _mode = _QuoteMode.eur;
  bool _saving = false;
  bool _quoting = false;
  String? _quoteError;
  Map<String, String> _errors = {};
  int _quoteVersion = 0;

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
      _fee.text = formatPlain(conversion.feeBrl);
      _note.text = conversion.note ?? '';
    }
  }

  double? _value(TextEditingController controller) => evaluateExpression(controller.text);

  String _quoteKey() {
    final amount = _mode == _QuoteMode.eur ? _value(_received) : _value(_sent);
    return amount != null && amount > 0 ? '${_mode.name}:$amount' : '';
  }

  /// Fills the other amount and the fee from Wise. Only on request: the form never asks Wise by itself.
  Future<void> _requestQuote() async {
    final key = _quoteKey();
    if (key.isEmpty) return;
    final version = ++_quoteVersion;
    setState(() {
      _quoteError = null;
      _quoting = true;
    });
    try {
      final quote = _mode == _QuoteMode.eur
          ? await Api.instance.quote(recipientGetsAmount: _value(_received))
          : await Api.instance.quote(sendAmount: _value(_sent));
      if (!mounted || version != _quoteVersion || key != _quoteKey()) return;
      setState(() {
        _sent.text = formatPlain(quote.sendAmount);
        _fee.text = formatPlain(quote.fee);
        _received.text = formatPlain(quote.receivedAmount);
      });
    } catch (err) {
      if (mounted && version == _quoteVersion) setState(() => _quoteError = errorMessage(err));
    } finally {
      if (mounted && version == _quoteVersion) setState(() => _quoting = false);
    }
  }

  Future<void> _submit() async {
    final received = _value(_received);
    final sent = _value(_sent);
    final fee = _value(_fee);
    final errors = <String, String>{};
    if (received == null || received <= 0) errors['receivedEur'] = 'Informe um valor maior que zero';
    if (sent == null || sent <= 0) errors['sentBrl'] = 'Informe um valor maior que zero';
    if (fee == null || fee < 0) {
      errors['feeBrl'] = 'Informe um valor';
    } else if (sent != null && fee > sent) {
      errors['feeBrl'] = 'A taxa não pode passar do total enviado';
    }
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _saving = true);
    final note = _note.text.trim();
    final body = {'day': _day, 'sentBrl': sent, 'feeBrl': fee, 'receivedEur': received, 'note': note.isEmpty ? null : note};
    final saved = widget.editing != null
        ? await widget.controller.updateConversion(widget.editing!.id, body)
        : await widget.controller.addConversion(body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved != null) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _quoteVersion++;
    _received.dispose();
    _sent.dispose();
    _fee.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
        const FieldLabel('Cotação a partir de'),
        Segmented<_QuoteMode>(
          value: _mode,
          expand: true,
          options: const [(value: _QuoteMode.eur, label: 'EUR recebido', icon: null), (value: _QuoteMode.brl, label: 'BRL enviado', icon: null)],
          onChanged: (mode) => setState(() => _mode = mode),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MoneyFormField(
                controller: _received,
                label: 'EUR recebido',
                prefix: '€',
                highlight: _mode == _QuoteMode.eur,
                errorText: _errors['receivedEur'],
                // Rebuilds so the Wise button follows whether there is an amount to quote.
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MoneyFormField(
                controller: _sent,
                label: 'BRL enviado',
                prefix: r'R$',
                highlight: _mode == _QuoteMode.brl,
                errorText: _errors['sentBrl'],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionButton(
            label: 'Calcular com a Wise',
            icon: LucideIcons.sparkles,
            style: ActionStyle.subtle,
            loading: _quoting,
            onPressed: _quoteKey().isEmpty ? null : _requestQuote,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Preenche o outro valor e a taxa a partir do ${_mode == _QuoteMode.eur ? 'EUR recebido' : 'BRL enviado'}. Os três continuam editáveis.',
          style: TextStyle(fontSize: 12, color: palette.muted),
        ),
        if (_quoteError != null) ...[
          const SizedBox(height: 12),
          Callout(
            icon: LucideIcons.circleAlert,
            tone: Tone.error,
            title: 'Não foi possível consultar a Wise',
            description: _quoteError,
            action: OutlinedButton.icon(
              onPressed: _requestQuote,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Tentar novamente'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        MoneyFormField(controller: _fee, label: 'Taxa Wise em BRL', prefix: r'R$', errorText: _errors['feeBrl']),
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
