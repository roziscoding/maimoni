import '../domain/summary.dart';

/// Mirrors the shapes in `@maimoni/shared` (schemas.ts and api.ts). Optimistic updates apply a
/// JSON patch on top of `toJson()` and parse the result back, like the web's `{ ...item, ...patch }`.

enum Currency {
  brl('BRL'),
  eur('EUR');

  const Currency(this.code);
  final String code;

  static Currency parse(String value) => values.firstWhere((currency) => currency.code == value);
}

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
    required this.exchangeRate,
    required this.activeDay,
    required this.note,
    required this.createdAt,
  });

  factory Month.fromJson(Json json) => Month(
        id: json['id'] as String,
        year: json['year'] as int,
        month: json['month'] as int,
        exchangeRate: _numOrNull(json['exchangeRate']),
        activeDay: json['activeDay'] as int?,
        note: json['note'] as String?,
        createdAt: json['createdAt'] as String,
      );

  final String id;
  final int year;
  final int month;

  /// Locked EUR→BRL rate. `null` means the live rate is used.
  final double? exchangeRate;

  /// Day open for daily spending. `null` means no day was closed yet, so the open day is today.
  final int? activeDay;
  final String? note;
  final String createdAt;

  Json toJson() => {
        'id': id,
        'year': year,
        'month': month,
        'exchangeRate': exchangeRate,
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

class Conversion {
  Conversion({
    required this.id,
    required this.monthId,
    required this.day,
    required this.sentBrl,
    required this.feeBrl,
    required this.receivedEur,
    required this.note,
    required this.createdAt,
  });

  factory Conversion.fromJson(Json json) => Conversion(
        id: json['id'] as String,
        monthId: json['monthId'] as String,
        day: json['day'] as int,
        sentBrl: _num(json['sentBrl']),
        feeBrl: _num(json['feeBrl']),
        receivedEur: _num(json['receivedEur']),
        note: json['note'] as String?,
        createdAt: json['createdAt'] as String,
      );

  final String id;
  final String monthId;
  final int day;

  /// Total BRL sent, including whatever the transfer cost.
  final double sentBrl;

  /// What the transfer cost: the BRL sent beyond what the EUR received were worth at the exchange
  /// rate when the conversion was recorded. The server works it out.
  final double feeBrl;
  final double receivedEur;
  final String? note;
  final String createdAt;

  Json toJson() => {
        'id': id,
        'monthId': monthId,
        'day': day,
        'sentBrl': sentBrl,
        'feeBrl': feeBrl,
        'receivedEur': receivedEur,
        'note': note,
        'createdAt': createdAt,
      };

  Conversion patch(Json patch) => Conversion.fromJson({...toJson(), ...patch});
}

enum RateSource {
  wise('wise', 'Wise'),
  frankfurter('frankfurter', 'Frankfurter (BCE)'),
  openErApi('open-er-api', 'Open Exchange Rates'),
  cache('cache', 'último valor salvo');

  const RateSource(this.code, this.label);
  final String code;
  final String label;

  static RateSource parse(String value) => values.firstWhere((source) => source.code == value);
}

class LiveRate {
  LiveRate({required this.rate, required this.source, required this.fetchedAt, required this.stale});

  factory LiveRate.fromJson(Json json) => LiveRate(
        rate: _num(json['rate']),
        source: RateSource.parse(json['source'] as String),
        fetchedAt: json['fetchedAt'] as String,
        stale: json['stale'] as bool,
      );

  /// How many BRL one EUR costs.
  final double rate;
  final RateSource source;
  final String fetchedAt;

  /// True when every provider failed and the last stored rate is being served.
  final bool stale;
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
    required this.conversions,
    required this.rate,
    required this.rateError,
  });

  factory MonthDetail.fromJson(Json json) => MonthDetail(
        month: Month.fromJson(json['month'] as Json),
        items: [for (final item in json['items'] as List) MonthItem.fromJson(item as Json)],
        spends: [for (final spend in json['spends'] as List) DailySpend.fromJson(spend as Json)],
        conversions: [for (final conversion in json['conversions'] as List) Conversion.fromJson(conversion as Json)],
        rate: json['rate'] == null ? null : LiveRate.fromJson(json['rate'] as Json),
        rateError: json['rateError'] as String?,
      );

  Month month;
  List<MonthItem> items;

  /// Day-to-day spending, oldest first.
  List<DailySpend> spends;

  /// Completed BRL→EUR conversions, oldest first.
  List<Conversion> conversions;
  LiveRate? rate;

  /// Why the live providers failed; present with a missing or stale rate.
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
