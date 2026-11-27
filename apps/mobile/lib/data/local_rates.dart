import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api/client.dart';
import '../api/models.dart';
import 'database.dart';

const _retryAfterFailure = Duration(minutes: 5);

typedef _Provider = ({RateSource source, String label, Uri Function(Currency base, List<Currency> quotes) url});

/// The same providers as the server (apps/backend/src/services/rates.ts), in the same order.
final List<_Provider> _providers = [
  (
    source: RateSource.frankfurter,
    label: 'Frankfurter (BCE)',
    url: (base, quotes) => Uri.https('api.frankfurter.dev', '/v1/latest', {'base': base.code, 'symbols': quotes.map((quote) => quote.code).join(',')}),
  ),
  (
    source: RateSource.openErApi,
    label: 'Open ER API',
    url: (base, _) => Uri.https('open.er-api.com', '/v6/latest/${base.code}'),
  ),
];

/// Live rates for the local mode, asked of the providers straight from the device.
///
/// Rates fetched on a UTC day are kept in [StoredRates] and served for the rest of that day. When
/// every provider fails, the stored rates are served as stale; a failure is retried after five minutes.
class LocalRates {
  LocalRates(this._db, {http.Client? client, DateTime Function()? now})
      : _http = client ?? http.Client(),
        _now = now ?? DateTime.now;

  final LocalDatabase _db;
  final http.Client _http;
  final DateTime Function() _now;
  final _failedAt = <Currency, DateTime>{};
  final _pending = <Currency, Future<LiveRates>>{};

  /// Rates against [base]; throws [ApiException] when there are none, fetched or stored.
  Future<LiveRates> get(Currency base) => _pending[base] ??= _get(base).whenComplete(() {
        // A block: `remove` returns this same future, which `whenComplete` would then wait on.
        _pending.remove(base);
      });

  Future<LiveRates> _get(Currency base) async {
    final quotes = [for (final currency in Currency.all) if (currency != base) currency];
    final stored = await (_db.select(_db.storedRates)..where((row) => row.base.equals(base.code))).getSingleOrNull();
    final now = _now().toUtc();
    if (stored != null && _sameUtcDay(DateTime.parse(stored.fetchedAt), now)) return _toLive(stored, stale: false);
    final failedAt = _failedAt[base];
    if (failedAt != null && now.difference(failedAt) < _retryAfterFailure) {
      if (stored != null) return _toLive(stored, stale: true);
      throw ApiException('Nenhuma cotação disponível. Tente de novo em alguns minutos.');
    }

    final errors = <String>[];
    for (final provider in _providers) {
      try {
        final rates = await _fetch(provider, base, quotes);
        final row = StoredRate(base: base.code, rates: jsonEncode(ratesToJson(rates)), source: provider.source.code, fetchedAt: now.toIso8601String());
        await _db.into(_db.storedRates).insertOnConflictUpdate(row);
        _failedAt.remove(base);
        return _toLive(row, stale: false);
      } catch (error) {
        errors.add('${provider.label}: $error');
      }
    }
    _failedAt[base] = now;
    if (stored != null) return _toLive(stored, stale: true);
    throw ApiException('Nenhuma cotação disponível. ${errors.join('; ')}');
  }

  Future<Rates> _fetch(_Provider provider, Currency base, List<Currency> quotes) async {
    final response = await _http.get(provider.url(base, quotes)).timeout(const Duration(seconds: 5));
    if (response.statusCode >= 400) throw 'HTTP ${response.statusCode}';
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    final rates = body['rates'] as Map;
    return {
      for (final quote in quotes)
        quote: switch (rates[quote.code]) {
          final num value when value > 0 => value.toDouble(),
          _ => throw 'no rate for ${quote.code}',
        },
    };
  }

  LiveRates _toLive(StoredRate row, {required bool stale}) => LiveRates(
        base: Currency.parse(row.base),
        rates: ratesFromJson(jsonDecode(row.rates)),
        // The server says `cache` for every stale answer.
        source: stale ? RateSource.cache : RateSource.parse(row.source),
        fetchedAt: row.fetchedAt,
        stale: stale,
      );

  static bool _sameUtcDay(DateTime a, DateTime b) {
    final x = a.toUtc();
    final y = b.toUtc();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}
