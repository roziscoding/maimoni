import 'package:flutter/foundation.dart';

import '../api/models.dart';
import '../data/repository.dart';

/// The user's currencies, shared by every screen (the web's `useCurrencies`): what the screens
/// offer, and what stops making sense with a single currency (choosing one, sections per currency,
/// anything about the exchange rate).
class CurrenciesStore extends ChangeNotifier {
  CurrenciesStore._();

  static final instance = CurrenciesStore._();

  /// The user's list, the main one first; `null` until it loads, and when it couldn't be loaded.
  List<UserCurrency>? list;
  bool loaded = false;
  Object? error;

  /// Goes up on every [reset]. A caller compares it before and after a request to tell whether the
  /// session it started in is over.
  int get generation => _generation;
  int _generation = 0;

  /// Goes up on every [reset] and every change, so a read that started before either is dropped.
  int _revision = 0;
  Future<void>? _loading;

  Future<void> refresh() {
    final pending = _loading;
    if (pending != null) return pending;
    late final Future<void> request;
    // A read dropped by a change can finish while a newer one is pending; only its own end clears it.
    request = _fetch().whenComplete(() {
      if (identical(_loading, request)) _loading = null;
    });
    return _loading = request;
  }

  /// Loads the list again after a change the server didn't answer with the list: a read already in
  /// flight started before the change, so it is dropped and a new one starts.
  Future<void> reload() {
    _invalidate();
    return refresh();
  }

  /// Loads the list unless it already is: a screen awaits it so it doesn't first render for every currency.
  Future<void> ensureLoaded() => loaded ? Future.value() : refresh();

  Future<void> _fetch() async {
    final revision = _revision;
    List<UserCurrency>? result;
    Object? failure;
    try {
      result = await repository.currencies();
    } catch (err) {
      failure = err;
    }
    // The session ended, or the list changed, while the request was in flight: its answer is out of date.
    if (revision != _revision) return;
    if (result != null) list = result;
    error = failure;
    loaded = true;
    notifyListeners();
  }

  void _invalidate() {
    _revision++;
    _loading = null;
  }

  /// Takes the list a change answered with.
  void replace(List<UserCurrency> currencies) {
    _invalidate();
    list = currencies;
    error = null;
    loaded = true;
    notifyListeners();
  }

  /// Drops everything, so the next person to sign in doesn't see the previous one's currencies.
  void reset() {
    _generation++;
    _invalidate();
    list = null;
    loaded = false;
    error = null;
    notifyListeners();
  }

  /// Enabled currencies, in the app's order: the ones new items and spends can be created in.
  /// Every known currency when the list couldn't be loaded, so a failed request doesn't hide anything.
  List<Currency> get offered {
    final entries = list;
    if (entries == null) return Currency.all;
    return Currency.sorted([
      for (final entry in entries)
        if (entry.enabled) entry.currency,
    ]);
  }

  /// Whether the user has no currency to create anything in.
  bool get none => offered.isEmpty;

  /// The main currency: what a new spend starts in, and what a new month is worked out in.
  Currency? get main => list?.where((entry) => entry.main).firstOrNull?.currency ?? offered.firstOrNull;

  /// Currencies a screen has to show: the offered ones plus those its data is already in. A disabled
  /// or removed currency keeps showing where it has history, so the totals match what is listed.
  List<Currency> shown(Iterable<Currency> used) => Currency.sorted([...offered, ...used]);

  /// [shown] for a month: the currency it is worked out in, and the ones of its items and spends.
  List<Currency> shownInMonth(MonthDetail detail) => shown([
        detail.month.mainCurrency,
        for (final item in detail.items) item.currency,
        for (final spend in detail.spends) spend.currency,
      ]);
}
