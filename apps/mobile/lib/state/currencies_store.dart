import 'package:flutter/foundation.dart';

import '../api/client.dart';
import '../api/models.dart';

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

  /// Goes up on every [reset], so a refresh can tell that the session it asked for is over.
  int _generation = 0;
  Future<void>? _loading;

  Future<void> refresh() => _loading ??= _fetch().whenComplete(() => _loading = null);

  /// Loads the list unless it already is: a screen awaits it so it doesn't first render for every currency.
  Future<void> ensureLoaded() => loaded ? Future.value() : refresh();

  Future<void> _fetch() async {
    final generation = _generation;
    List<UserCurrency>? result;
    Object? failure;
    try {
      result = await Api.instance.currencies();
    } catch (err) {
      failure = err;
    }
    // The session ended while the request was in flight: the answer belongs to someone else.
    if (generation != _generation) return;
    if (result != null) list = result;
    error = failure;
    loaded = true;
    notifyListeners();
  }

  /// Takes the list a change answered with.
  void replace(List<UserCurrency> currencies) {
    list = currencies;
    error = null;
    loaded = true;
    notifyListeners();
  }

  /// Drops everything, so the next person to sign in doesn't see the previous one's currencies.
  void reset() {
    _generation++;
    _loading = null;
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
