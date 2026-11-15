import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../domain/expression.dart';
import '../format.dart';
import '../state/toast.dart';
import '../theme.dart';

/// Borderless, unfilled decoration for inline editing (`variant="ghost"`).
InputDecoration ghostDecoration(BuildContext context, {String? hint, Widget? suffix, bool highlight = false}) {
  final palette = context.palette;
  final radius = BorderRadius.circular(6);
  final highlightBorder = OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: palette.warning));
  return InputDecoration(
    hintText: hint,
    filled: false,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    border: highlight ? highlightBorder : OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    enabledBorder: highlight ? highlightBorder : OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: highlight ? palette.warning : Theme.of(context).colorScheme.primary, width: 1.5),
    ),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 20),
  );
}

/// Text edited in place: commits when focus leaves or on submit, if it changed.
class InlineTextField extends StatefulWidget {
  const InlineTextField({super.key, required this.value, required this.onCommit, this.hint, this.style, this.allowEmpty = false});

  final String value;
  final ValueChanged<String> onCommit;
  final String? hint;
  final TextStyle? style;

  /// When false an emptied field reverts to [value] instead of committing.
  final bool allowEmpty;

  @override
  State<InlineTextField> createState() => _InlineTextFieldState();
}

class _InlineTextFieldState extends State<InlineTextField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(InlineTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.value != _controller.text) _controller.text = widget.value;
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text.isEmpty && !widget.allowEmpty) {
      _controller.text = widget.value;
      return;
    }
    if (text != widget.value.trim()) widget.onCommit(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      style: widget.style ?? const TextStyle(fontSize: 14),
      decoration: ghostDecoration(context, hint: widget.hint),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _focus.unfocus(),
      onTapOutside: (_) => _focus.unfocus(),
    );
  }
}

/// Port of `AmountInput.vue`: shows the formatted amount, switches to what was typed (the
/// expression or the plain number) while focused, and commits `{amount, expression}` on blur.
class AmountField extends StatefulWidget {
  const AmountField({
    super.key,
    required this.amount,
    required this.expression,
    required this.currency,
    required this.onCommit,
    this.placeholder = 'preencher',
    this.highlight = false,
  });

  final double? amount;
  final String? expression;
  final Currency currency;
  final void Function(double? amount, String? expression) onCommit;
  final String placeholder;
  final bool highlight;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  String get _raw => widget.expression ?? (widget.amount == null ? '' : formatPlain(widget.amount!));
  String get _display => widget.amount == null ? '' : formatMoney(widget.amount, widget.currency);

  @override
  void initState() {
    super.initState();
    _controller.text = _display;
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus) _controller.text = _display;
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      // Select once the raw value replaced the formatted one, so typing overwrites it.
      _controller
        ..text = _raw
        ..selection = TextSelection(baseOffset: 0, extentOffset: _raw.length);
    } else {
      _commit();
      _controller.text = _display;
    }
    setState(() {});
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text == _raw) return;
    if (text.isEmpty) {
      widget.onCommit(null, null);
      return;
    }
    final amount = evaluateExpression(text);
    if (amount == null) {
      toast('Valor inválido', description: '"$text" não é um número nem uma conta como 11,99+2,99.', tone: ToastTone.error);
      return;
    }
    widget.onCommit(amount, expressionOf(text));
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final showSigma = widget.expression != null && !_focus.hasFocus;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: money(fontSize: 14, color: palette.text),
      decoration: ghostDecoration(
        context,
        hint: widget.placeholder,
        highlight: widget.highlight,
        suffix: showSigma
            ? Tooltip(
                message: '= ${widget.expression}',
                triggerMode: TooltipTriggerMode.tap,
                child: Padding(padding: const EdgeInsets.only(right: 6), child: Icon(LucideIcons.sigma, size: 14, color: palette.dimmed)),
              )
            : null,
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _focus.unfocus(),
      onTapOutside: (_) => _focus.unfocus(),
    );
  }
}

/// Percent edited as `3,9` and stored as the fraction `0.039`; commits on blur within 0–99%.
class PercentField extends StatefulWidget {
  const PercentField({super.key, required this.value, required this.onCommit});

  final double? value;
  final ValueChanged<double> onCommit;

  @override
  State<PercentField> createState() => _PercentFieldState();
}

class _PercentFieldState extends State<PercentField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  String _text(double? value) => value == null ? '' : formatPercent(value);

  @override
  void initState() {
    super.initState();
    _controller.text = _text(widget.value);
    _focus.addListener(() {
      if (_focus.hasFocus) {
        final raw = widget.value == null ? '' : formatPlain(widget.value! * 100);
        _controller
          ..text = raw
          ..selection = TextSelection(baseOffset: 0, extentOffset: raw.length);
      } else {
        _commit();
        _controller.text = _text(widget.value);
      }
    });
  }

  @override
  void didUpdateWidget(PercentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus) _controller.text = _text(widget.value);
  }

  void _commit() {
    final parsed = evaluateExpression(_controller.text.replaceAll('%', ''));
    if (parsed == null) return;
    final fraction = (parsed / 100).clamp(0, 0.99).toDouble();
    final rounded = (fraction * 1e5).round() / 1e5;
    if (rounded != widget.value) widget.onCommit(rounded);
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: money(fontSize: 15),
      decoration: const InputDecoration(suffixText: '%'),
      onSubmitted: (_) => _focus.unfocus(),
      onTapOutside: (_) => _focus.unfocus(),
    );
  }
}

/// Plain money input for forms (sheets): parses expressions, reports `null` while invalid.
class MoneyFormField extends StatelessWidget {
  const MoneyFormField({super.key, required this.controller, required this.label, this.highlight = false, this.onChanged, this.errorText, this.prefix});

  final TextEditingController controller;
  final String label;
  final bool highlight;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: money(fontSize: 15),
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixText: prefix == null ? null : '$prefix ',
            prefixStyle: money(fontSize: 15, color: palette.muted),
            errorText: errorText,
            enabledBorder: highlight
                ? OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary))
                : null,
          ),
        ),
      ],
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key, this.hint});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.text))),
          if (hint != null) Text(hint!, style: TextStyle(fontSize: 12, color: palette.muted)),
        ],
      ),
    );
  }
}
