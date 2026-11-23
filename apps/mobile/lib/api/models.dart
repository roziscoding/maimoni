import '../domain/summary.dart';

/// Mirrors the shapes in `@maimoni/shared` (schemas.ts and api.ts). Optimistic updates apply a
/// JSON patch on top of `toJson()` and parse the result back, like the web's `{ ...item, ...patch }`.

/// A currency code. The server picks from a fixed list ([Currency.all], the `currencies` array in
/// `@maimoni/shared`); a code outside it still parses, so a newer server doesn't break the app.
///
/// An extension type over the code, so two of the same code are equal and work as `const` map keys.
extension type const Currency(String code) {
  static const brl = Currency('BRL');
  static const eur = Currency('EUR');

  /// The currencies a user can pick from, in the order the app lists them.
  static const all = [
    Currency('AUD'),
    brl,
    Currency('CAD'),
    Currency('CHF'),
    Currency('CNY'),
    Currency('CZK'),
    Currency('DKK'),
    eur,
    Currency('GBP'),
    Currency('HKD'),
    Currency('HUF'),
    Currency('IDR'),
    Currency('ILS'),
    Currency('INR'),
    Currency('ISK'),
    Currency('JPY'),
    Currency('KRW'),
    Currency('MXN'),
    Currency('MYR'),
    Currency('NOK'),
    Currency('NZD'),
    Currency('PHP'),
    Currency('PLN'),
    Currency('RON'),
    Currency('SEK'),
    Currency('SGD'),
    Currency('THB'),
    Currency('TRY'),
    Currency('USD'),
    Currency('ZAR'),
  ];

  static Currency parse(String value) => Currency(value);

  /// [currencies] without repeats, in the app's order; codes outside [all] come last, by code.
  static List<Currency> sorted(Iterable<Currency> currencies) {
    int position(Currency currency) {
      final index = all.indexOf(currency);
      return index < 0 ? all.length : index;
    }

    return currencies.toSet().toList()
      ..sort((a, b) {
        final byPosition = position(a).compareTo(position(b));
        return byPosition != 0 ? byPosition : a.code.compareTo(b.code);
      });
  }
}

/// Exchange rates by currency, all quoted against one other currency (a month's main one): how
/// many units of the key that one is worth. A currency left out has no rate.
typedef Rates = Map<Currency, double>;

Rates ratesFromJson(Object? json) =>
    {for (final MapEntry(:key, :value) in (json as Map).entries) Currency.parse(key as String): (value as num).toDouble()};

Map<String, double> ratesToJson(Rates rates) => {for (final MapEntry(:key, :value) in rates.entries) key.code: value};

enum EntryKind {
  income,
  expense;

  static EntryKind parse(String value) => values.byName(value);
}

typedef Json = Map<String, dynamic>;

double _num(Object? value) => (value as num).toDouble();
double? _numOrNull(Object? value) => value == null ? null : (value as num).toDouble();

class Month {
  Month({
    required this.id,
    required this.year,
    required this.month,
    required this.mainCurrency,
    required this.lockedRates,
    required this.activeDay,
    required this.note,
    required this.createdAt,
  });

  factory Month.fromJson(Json json) => Month(
        id: json['id'] as String,
        year: json['year'] as int,
        month: json['month'] as int,
        mainCurrency: Currency.parse(json['mainCurrency'] as String),
        lockedRates: ratesFromJson(json['lockedRates']),
        activeDay: json['activeDay'] as int?,
        note: json['note'] as String?,
        createdAt: json['createdAt'] as String,
      );

  final String id;
  final int year;
  final int month;

  /// The currency the month is worked out in: the user's main currency when it was created.
  final Currency mainCurrency;

  /// Rates the month froze, by currency. A currency left out follows the live rate.
  final Rates lockedRates;

  /// Day open for daily spending. `null` means no day was closed yet, so the open day is today.
  final int? activeDay;
  final String? note;
  final String createdAt;

  Json toJson() => {
        'id': id,
        'year': year,
        'month': month,
        'mainCurrency': mainCurrency.code,
        'lockedRates': ratesToJson(lockedRates),
        'activeDay': activeDay,
        'note': note,
        'createdAt': createdAt,
      };

  Month patch(Json patch) => Month.fromJson({...toJson(), ...patch});
}

class MonthItem {
  MonthItem({
    required this.id,
    required this.monthId,
    required this.templateItemId,
    required this.name,
    required this.currency,
    required this.kind,
    required this.amount,
    required this.expression,
    required this.paid,
    required this.needsReview,
    required this.position,
  });

  factory MonthItem.fromJson(Json json) => MonthItem(
        id: json['id'] as String,
        monthId: json['monthId'] as String,
        templateItemId: json['templateItemId'] as String?,
        name: json['name'] as String,
        currency: Currency.parse(json['currency'] as String),
        kind: EntryKind.parse(json['kind'] as String),
        amount: _numOrNull(json['amount']),
        expression: json['expression'] as String?,
        paid: json['paid'] as bool,
        needsReview: json['needsReview'] as bool,
        position: json['position'] as int,
      );

  final String id;
  final String monthId;
  final String? templateItemId;
  final String name;
  final Currency currency;
  final EntryKind kind;
  final double? amount;
  final String? expression;
  final bool paid;

  /// True while a variable value copied from the template hasn't been confirmed for this month.
  final bool needsReview;
  final int position;

  Json toJson() => {
        'id': id,
        'monthId': monthId,
        'templateItemId': templateItemId,
        'name': name,
        'currency': currency.code,
        'kind': kind.name,
        'amount': amount,
        'expression': expression,
        'paid': paid,
        'needsReview': needsReview,
        'position': position,
      };

  MonthItem patch(Json patch) => MonthItem.fromJson({...toJson(), ...patch});
}

class TemplateItem {
  TemplateItem({
    required this.id,
    required this.name,
    required this.currency,
    required this.kind,
    required this.amount,
    required this.expression,
    required this.variable,
    required this.position,
  });

  factory TemplateItem.fromJson(Json json) => TemplateItem(
        id: json['id'] as String,
        name: json['name'] as String,
        currency: Currency.parse(json['currency'] as String),
        kind: EntryKind.parse(json['kind'] as String),
        amount: _numOrNull(json['amount']),
        expression: json['expression'] as String?,
        variable: json['variable'] as bool,
        position: json['position'] as int,
      );

  final String id;
  final String name;
  final Currency currency;
  final EntryKind kind;
  final double? amount;
  final String? expression;

  /// Variable items change every month: their value is only an estimate when a month is created.
  final bool variable;
  final int position;

  Json toJson() => {
        'id': id,
        'name': name,
        'currency': currency.code,
        'kind': kind.name,
        'amount': amount,
        'expression': expression,
        'variable': variable,
        'position': position,
      };

  TemplateItem patch(Json patch) => TemplateItem.fromJson({...toJson(), ...patch});
}

class DailySpend {
  DailySpend({
    required this.id,
    required this.monthId,
    required this.day,
    required this.currency,
    required this.amount,
    required this.expression,
    required this.note,
    required this.createdAt,
  });

  factory DailySpend.fromJson(Json json) => DailySpend(
        id: json['id'] as String,
        monthId: json['monthId'] as String,
        day: json['day'] as int,
        currency: Currency.parse(json['currency'] as String),
        amount: _num(json['amount']),
        expression: json['expression'] as String?,
        note: json['note'] as String?,
        createdAt: json['createdAt'] as String,
      );

  final String id;
  final String monthId;
  final int day;
  final Currency currency;
  final double amount;
  final String? expression;
  final String? note;
  final String createdAt;

  Json toJson() => {
        'id': id,
        'monthId': monthId,
        'day': day,
        'currency': currency.code,
        'amount': amount,
        'expression': expression,
        'note': note,
        'createdAt': createdAt,
      };

  DailySpend patch(Json patch) => DailySpend.fromJson({...toJson(), ...patch});
}

enum RateSource {
  frankfurter('frankfurter', 'Frankfurter (BCE)'),
  openErApi('open-er-api', 'Open Exchange Rates'),
  cache('cache', 'último valor salvo');

  const RateSource(this.code, this.label);
  final String code;
  final String label;

  static RateSource parse(String value) => values.firstWhere((source) => source.code == value);
}

/// `GET /api/rates/live`, and `MonthDetail.rates`.
class LiveRates {
  LiveRates({required this.base, required this.rates, required this.source, required this.fetchedAt, required this.stale});

  factory LiveRates.fromJson(Json json) => LiveRates(
        base: Currency.parse(json['base'] as String),
        rates: ratesFromJson(json['rates']),
        source: RateSource.parse(json['source'] as String),
        fetchedAt: json['fetchedAt'] as String,
        stale: json['stale'] as bool,
      );

  /// The currency the rates are quoted against.
  final Currency base;

  /// How many units of each other currency one unit of [base] costs.
  final Rates rates;
  final RateSource source;
  final String fetchedAt;

  /// True when every provider failed and the last stored rates are being served.
  final bool stale;
}

/// `GET /api/settings/currencies` row: a currency the user works with. Exactly one is the main one.
class UserCurrency {
  UserCurrency({required this.currency, required this.enabled, required this.main, required this.inUse});

  factory UserCurrency.fromJson(Json json) => UserCurrency(
        currency: Currency.parse(json['currency'] as String),
        enabled: json['enabled'] as bool,
        main: json['main'] as bool,
        inUse: json['inUse'] as bool,
      );

  final Currency currency;

  /// Whether the app offers it for new items and spends. A disabled one keeps showing where it has history.
  final bool enabled;
  final bool main;

  /// Whether a template item, month item or daily spend is in it. One in use can be disabled, not removed.
  final bool inUse;
}

/// `GET /api/flags`: what the server has switched on, so the app knows what to offer.
class Flags {
  Flags({required this.purge});

  factory Flags.fromJson(Json json) => Flags(purge: json['purge'] as bool);

  /// Whether `DELETE /api/data` is served.
  final bool purge;
}

/// `GET /api/sessions` row: one sign in to the account that is still valid.
class SessionEntry {
  SessionEntry({required this.id, required this.current, required this.userAgent, required this.ipAddress, required this.createdAt});

  factory SessionEntry.fromJson(Json json) => SessionEntry(
        id: json['id'] as String,
        current: json['current'] as bool,
        userAgent: json['userAgent'] as String?,
        ipAddress: json['ipAddress'] as String?,
        createdAt: json['createdAt'] as String,
      );

  final String id;

  /// Whether this is the session the app is using.
  final bool current;
  final String? userAgent;
  final String? ipAddress;
  final String createdAt;
}

/// `GET /api/months` row.
class MonthListEntry {
  MonthListEntry({required this.month, required this.summary});

  factory MonthListEntry.fromJson(Json json) =>
      MonthListEntry(month: Month.fromJson(json), summary: MonthSummary.fromJson(json['summary'] as Json));

  final Month month;
  final MonthSummary summary;

  int get year => month.year;
  int get monthNumber => month.month;
}

/// `GET /api/months/:year/:month`
class MonthDetail {
  MonthDetail({
    required this.month,
    required this.items,
    required this.spends,
    required this.rates,
    required this.rateError,
  });

  factory MonthDetail.fromJson(Json json) => MonthDetail(
        month: Month.fromJson(json['month'] as Json),
        items: [for (final item in json['items'] as List) MonthItem.fromJson(item as Json)],
        spends: [for (final spend in json['spends'] as List) DailySpend.fromJson(spend as Json)],
        rates: json['rates'] == null ? null : LiveRates.fromJson(json['rates'] as Json),
        rateError: json['rateError'] as String?,
      );

  Month month;
  List<MonthItem> items;

  /// Day-to-day spending, oldest first.
  List<DailySpend> spends;

  /// Live rates quoted against the month's main currency.
  LiveRates? rates;

  /// Why the live providers failed; present with missing or stale rates.
  String? rateError;
}

/// `GET /api/app/android/latest`: the newest Android release of a channel.
class AppRelease {
  AppRelease({required this.version, required this.versionCode, required this.prerelease, required this.notes, required this.url, required this.sha256});

  factory AppRelease.fromJson(Json json) => AppRelease(
        version: json['version'] as String,
        versionCode: json['versionCode'] as int,
        prerelease: json['prerelease'] as bool,
        notes: json['notes'] as String?,
        url: json['url'] as String,
        sha256: json['sha256'] as String?,
      );

  final String version;
  final int versionCode;
  final bool prerelease;

  /// Release notes (Markdown).
  final String? notes;

  /// APK download, relative to the server (`/api/app/android/releases/<tag>/apk`).
  final String url;
  final String? sha256;
}

/// `GET /api/template`
class TemplateDetail {
  TemplateDetail({required this.items});

  factory TemplateDetail.fromJson(Json json) =>
      TemplateDetail(items: [for (final item in json['items'] as List) TemplateItem.fromJson(item as Json)]);

  List<TemplateItem> items;
}
