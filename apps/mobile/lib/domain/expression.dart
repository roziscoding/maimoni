/// Rounds to cents the way JavaScript's `Math.round(value * 100) / 100` does (halves go up).
double round2(double value) => (value * 100 + 0.5).floorToDouble() / 100;

final _prefix = RegExp(r'^=');
final _ignored = RegExp(r'R\$|€|\s+');
final _numberToken = RegExp(r'^(?:\d+(?:[.,]\d+)*|[.,]\d+)');
final _thousands = RegExp(r'^\d{1,3}(?:\.\d{3})+$');

/// Evaluates the small arithmetic expressions the spreadsheet used inside value cells
/// (e.g. `=11.99+2.99` or `20000.5+509.54`). Supports + - * / and parentheses. Numbers can be
/// written as `1250.99`, `1250,99`, `2.500` or pt-BR style `1.250,99`; currency symbols are ignored.
/// Returns `null` for anything else.
double? evaluateExpression(String input) {
  final source = input.trim().replaceFirst(_prefix, '').replaceAll(_ignored, '');
  if (source.isEmpty) return null;
  final parser = _Parser(source);
  final result = parser.sum();
  if (result == null || parser.index != source.length || !result.isFinite) return null;
  return round2(result);
}

/// True when the input is more than a plain number, i.e. worth keeping as an expression.
bool isExpression(String input) =>
    RegExp(r'\d\s*[-+*/]|[()]').hasMatch(input.trim().replaceFirst(RegExp(r'^[=+-]'), ''));

/// The expression to store for [text]: the text itself (without a leading `=`) when it's more than a number.
String? expressionOf(String text) => isExpression(text) ? text.replaceFirst(_prefix, '') : null;

class _Parser {
  _Parser(this.source);

  final String source;
  int index = 0;

  String? peek() => index < source.length ? source[index] : null;

  double? number() {
    final match = _numberToken.firstMatch(source.substring(index));
    if (match == null) return null;
    final token = match.group(0)!;
    index += token.length;
    // With a comma, dots group thousands (pt-BR). Without one, dots followed by groups of exactly
    // three digits are thousands too (`2.500`, `1.000.000`): money never has three decimals.
    if (token.contains(',')) {
      if (token.split(',').length != 2) return double.nan;
      return double.tryParse(token.replaceAll('.', '').replaceFirst(',', '.')) ?? double.nan;
    }
    return double.tryParse(_thousands.hasMatch(token) ? token.replaceAll('.', '') : token) ?? double.nan;
  }

  double? factor() {
    final char = peek();
    if (char == '-' || char == '+') {
      index++;
      final value = factor();
      return value == null ? null : (char == '-' ? -value : value);
    }
    if (char == '(') {
      index++;
      final value = sum();
      if (value == null || peek() != ')') return null;
      index++;
      return value;
    }
    return number();
  }

  double? product() {
    var value = factor();
    while (value != null && (peek() == '*' || peek() == '/')) {
      final operator = source[index++];
      final right = factor();
      if (right == null) return null;
      value = operator == '*' ? value * right : value / right;
    }
    return value;
  }

  double? sum() {
    var value = product();
    while (value != null && (peek() == '+' || peek() == '-')) {
      final operator = source[index++];
      final right = product();
      if (right == null) return null;
      value = operator == '+' ? value + right : value - right;
    }
    return value;
  }
}
