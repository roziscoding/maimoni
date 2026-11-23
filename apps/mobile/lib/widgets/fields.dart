import 'package:flutter/material.dart';

import '../api/models.dart';
import '../format.dart';
import '../theme.dart';

/// What an amount field starts with: the expression it was typed as, or the plain number.
String amountText(double? amount, String? expression) => expression ?? (amount == null ? '' : formatPlain(amount));

/// The keyboard for an amount: digits, the comma, and the signs an expression like `11,99+2,99` needs.
const amountKeyboard = TextInputType.numberWithOptions(decimal: true, signed: true);

/// The decoration of an amount field: the currency's sign ahead of the number, there even while the
/// field is empty.
InputDecoration amountDecoration(BuildContext context, Currency? currency, {double fontSize = 17, String? errorText}) {
  return InputDecoration(
    hintText: '0,00',
    errorText: errorText,
    prefixIcon: currency == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Text(currencySymbol(currency), style: money(fontSize: fontSize, color: context.palette.muted)),
          ),
    prefixIconConstraints: const BoxConstraints(),
  );
}

/// The label over a field of a form.
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
