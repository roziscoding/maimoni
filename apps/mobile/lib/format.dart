import 'package:intl/intl.dart';

import 'api/models.dart';

final _money = {
  Currency.brl: NumberFormat.currency(locale: 'pt_BR', name: 'BRL', symbol: r'R$'),
  Currency.eur: NumberFormat.currency(locale: 'pt_BR', name: 'EUR', symbol: '€'),
};
final _rate = NumberFormat('0.0000', 'pt_BR');
final _percent = NumberFormat('#,##0.##', 'pt_BR');
final _plain = NumberFormat('0.##', 'pt_BR');

/// Every currency figure in pt-BR: `R$ 1.250,99` / `€ 45,00`. Missing values render as an em dash.
String formatMoney(double? value, Currency currency) => value == null ? '—' : _money[currency]!.format(value);

/// EUR→BRL rate with 4 decimals.
String formatRate(double? value) => value == null ? '—' : 'R\$ ${_rate.format(value)}';

/// Fraction to percent: `0.039` → `3,9%`.
String formatPercent(double value) => '${_percent.format(value * 100)}%';

/// Plain number with a pt-BR comma, for editing: `1250.5` → `1250,5`.
String formatPlain(double value) => _plain.format(value);

String formatDateTime(String iso) => DateFormat('dd/MM/yyyy, HH:mm', 'pt_BR').format(DateTime.parse(iso).toLocal());

/// `+€ 12,00` / `−€ 8,00`.
String signedMoney(double value) => '${value >= 0 ? '+' : '−'}${formatMoney(value.abs(), Currency.eur)}';

/// Compact form for narrow cells: `+12` / `−8`.
String compactSigned(double value) => '${value >= 0 ? '+' : '−'}${value.abs().round()}';

String _capitalize(String value) => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// Capitalized pt-BR month name: `Outubro`.
String monthName(int month) => _capitalize(DateFormat.MMMM('pt_BR').format(DateTime(2000, month)));

String monthLabel(int year, int month) => '${monthName(month)} $year';

/// Capitalized pt-BR day: `Sábado, 3 de outubro`.
String dayLabel(int year, int month, int day) =>
    _capitalize(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime(year, month, day)));

String plural(int count, String one, String many) => count == 1 ? one : many;
