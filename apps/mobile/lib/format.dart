import 'dart:math';

import 'package:intl/intl.dart';

import 'api/models.dart';

/// How each currency is written in pt-BR: what the web gets from the browser's `Intl` (symbol,
/// name, plural name and decimal places), which Dart's `intl` doesn't carry in full.
const _currencies = <String, ({String symbol, String name, String plural, int digits})>{
  'AUD': (symbol: r'AU$', name: 'Dólar australiano', plural: 'Dólares australianos', digits: 2),
  'BRL': (symbol: r'R$', name: 'Real brasileiro', plural: 'Reais brasileiros', digits: 2),
  'CAD': (symbol: r'CA$', name: 'Dólar canadense', plural: 'Dólares canadenses', digits: 2),
  'CHF': (symbol: 'CHF', name: 'Franco suíço', plural: 'Francos suíços', digits: 2),
  'CNY': (symbol: 'CN¥', name: 'Yuan chinês', plural: 'Yuans chineses', digits: 2),
  'CZK': (symbol: 'CZK', name: 'Coroa tcheca', plural: 'Coroas tchecas', digits: 2),
  'DKK': (symbol: 'DKK', name: 'Coroa dinamarquesa', plural: 'Coroas dinamarquesas', digits: 2),
  'EUR': (symbol: '€', name: 'Euro', plural: 'Euros', digits: 2),
  'GBP': (symbol: '£', name: 'Libra esterlina', plural: 'Libras esterlinas', digits: 2),
  'HKD': (symbol: r'HK$', name: 'Dólar de Hong Kong', plural: 'Dólares de Hong Kong', digits: 2),
  'HUF': (symbol: 'HUF', name: 'Florim húngaro', plural: 'Florins húngaros', digits: 2),
  'IDR': (symbol: 'IDR', name: 'Rupia indonésia', plural: 'Rupias indonésias', digits: 2),
  'ILS': (symbol: '₪', name: 'Novo shekel israelense', plural: 'Novos shekels israelenses', digits: 2),
  'INR': (symbol: '₹', name: 'Rupia indiana', plural: 'Rupias indianas', digits: 2),
  'ISK': (symbol: 'ISK', name: 'Coroa islandesa', plural: 'Coroas islandesas', digits: 0),
  'JPY': (symbol: 'JP¥', name: 'Iene japonês', plural: 'Ienes japoneses', digits: 0),
  'KRW': (symbol: '₩', name: 'Won sul-coreano', plural: 'Wons sul-coreanos', digits: 0),
  'MXN': (symbol: r'MX$', name: 'Peso mexicano', plural: 'Pesos mexicanos', digits: 2),
  'MYR': (symbol: 'MYR', name: 'Ringgit malaio', plural: 'Ringgits malaios', digits: 2),
  'NOK': (symbol: 'NOK', name: 'Coroa norueguesa', plural: 'Coroas norueguesas', digits: 2),
  'NZD': (symbol: r'NZ$', name: 'Dólar neozelandês', plural: 'Dólares neozelandeses', digits: 2),
  'PHP': (symbol: 'PHP', name: 'Peso filipino', plural: 'Pesos filipinos', digits: 2),
  'PLN': (symbol: 'PLN', name: 'Zloty polonês', plural: 'Zlotys poloneses', digits: 2),
  'RON': (symbol: 'RON', name: 'Leu romeno', plural: 'Leus romenos', digits: 2),
  'SEK': (symbol: 'SEK', name: 'Coroa sueca', plural: 'Coroas suecas', digits: 2),
  'SGD': (symbol: 'SGD', name: 'Dólar singapuriano', plural: 'Dólares singapurianos', digits: 2),
  'THB': (symbol: '฿', name: 'Baht tailandês', plural: 'Bahts tailandeses', digits: 2),
  'TRY': (symbol: 'TRY', name: 'Lira turca', plural: 'Liras turcas', digits: 2),
  'USD': (symbol: r'US$', name: 'Dólar americano', plural: 'Dólares americanos', digits: 2),
  'ZAR': (symbol: 'ZAR', name: 'Rand sul-africano', plural: 'Rands sul-africanos', digits: 2),
};

/// One formatter per currency, made the first time it is asked for.
final _money = <Currency, NumberFormat>{};
final _rate = NumberFormat('0.0000', 'pt_BR');
final _plain = NumberFormat('0.##', 'pt_BR');

/// Every currency figure in pt-BR: `R$ 1.250,99` / `€ 45,00` / `JP¥ 1.235`. A currency without
/// minor units shows no decimals. Missing values render as an em dash.
String formatMoney(double? value, Currency currency) {
  if (value == null) return '—';
  final formatter = _money[currency] ??= NumberFormat.currency(
    locale: 'pt_BR',
    name: currency.code,
    symbol: currencySymbol(currency),
    decimalDigits: _currencies[currency.code]?.digits ?? 2,
  );
  return formatter.format(value);
}

/// The sign a currency's amounts are written with: `R$`, `€`. Its code when the app doesn't know it.
String currencySymbol(Currency currency) => _currencies[currency.code]?.symbol ?? currency.code;

/// pt-BR name of a currency: `Real brasileiro`, `Euro`.
String currencyName(Currency currency) => _currencies[currency.code]?.name ?? currency.code;

/// pt-BR plural name of a currency, for a heading over amounts in it: `Reais brasileiros`, `Euros`.
String currencyPlural(Currency currency) => _currencies[currency.code]?.plural ?? currency.code;

/// A rate: how much of [currency] one unit of a month's main currency is worth, with 4 decimals:
/// `R$ 5,8686`. Below one, 4 decimals can be all zeros (a rupiah in euros), so it shows 4
/// significant digits instead: `€ 0,00005512`.
String formatRate(double? value, Currency currency) {
  if (value == null) return '—';
  final magnitude = value.abs();
  final String number;
  if (magnitude >= 1 || magnitude == 0) {
    number = _rate.format(value);
  } else {
    final decimals = (3 - (log(magnitude) / ln10).floor()).clamp(4, 20);
    number = value.toStringAsFixed(decimals).replaceFirst('.', ',');
  }
  return '${currencySymbol(currency)} $number';
}

/// Plain number with a pt-BR comma, for editing: `1250.5` → `1250,5`.
String formatPlain(double value) => _plain.format(value);

String formatDateTime(String iso) => DateFormat('dd/MM/yyyy, HH:mm', 'pt_BR').format(DateTime.parse(iso).toLocal());

/// `+€ 12,00` / `−€ 8,00`.
String signedMoney(double value, Currency currency) => '${value >= 0 ? '+' : '−'}${formatMoney(value.abs(), currency)}';

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

final _browsers = {RegExp('Edg/'): 'Edge', RegExp('OPR/'): 'Opera', RegExp('Firefox/'): 'Firefox', RegExp('Chrome/'): 'Chrome', RegExp('Safari/'): 'Safari'};
final _systems = {
  RegExp('Android', caseSensitive: false): 'Android',
  RegExp('iPhone|iPad|iOS', caseSensitive: false): 'iPhone',
  RegExp('Mac OS X|macOS', caseSensitive: false): 'macOS',
  RegExp('Windows', caseSensitive: false): 'Windows',
  RegExp('Linux', caseSensitive: false): 'Linux',
};

String? _match(Map<RegExp, String> names, String value) {
  for (final MapEntry(key: pattern, value: name) in names.entries) {
    if (pattern.hasMatch(value)) return name;
  }
  return null;
}

/// Names the device behind a session's `User-Agent`: `Chrome no Linux`, `App maimoni no Android`.
String deviceLabel(String? userAgent) {
  if (userAgent == null || userAgent.isEmpty) return 'Dispositivo desconhecido';
  // This app sends `maimoni-app (<system>)`; builds before that sent Dart's default.
  final app = userAgent.startsWith('maimoni-app') || userAgent.startsWith('Dart/');
  final name = app ? 'App maimoni' : _match(_browsers, userAgent);
  final system = _match(_systems, userAgent);
  if (name == null) return system ?? 'Dispositivo desconhecido';
  return system == null ? name : '$name no $system';
}
