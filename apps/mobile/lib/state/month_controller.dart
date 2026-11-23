import 'dart:async';

import 'package:flutter/widgets.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../domain/summary.dart';
import 'currencies_store.dart';
import 'months_store.dart';
import 'toast.dart';

const _rateRefresh = Duration(minutes: 5);

/// Port of the web's `useMonth`: loads one month and exposes optimistic mutations. Local state
/// changes first (so the summary recomputes instantly), then the request is sent; on failure a
/// toast is shown and the month is refetched.
class MonthController extends ChangeNotifier {
  MonthController(this.year, this.month) {
    // Only in the foreground, like the web's interval, which stops with the tab.
    _rateTimer = Timer.periodic(_rateRefresh, (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) refreshRate(refreshMonths: false);
    });
    load();
  }

  final int year;
  final int month;
  final _api = Api.instance;

  MonthDetail? data;
  ApiException? error;
  bool loading = true;
  bool refreshingRate = false;
  MonthSummary? _summary;
  Timer? _rateTimer;
  bool _disposed = false;

  MonthSummary? get summary => _summary;

  Future<void> load() async {
    try {
      // The screens lay themselves out by the user's currencies, so the first frame waits for them too.
      final currencies = CurrenciesStore.instance.ensureLoaded();
      final detail = await _api.month(year, month);
      await currencies;
      data = detail;
      error = null;
    } on ApiException catch (err) {
      data = null;
      error = err;
    }
    loading = false;
    _changed();
  }

  /// Recomputes the summary, then keeps the drawer in step with it.
  void _changed() {
    if (_disposed) return;
    final current = data;
    _summary = current == null
        ? null
        : summarizeMonth(current.month, current.items, rates: current.rates?.rates, spends: current.spends);
    if (current != null && _summary != null) MonthsStore.instance.updateSummary(current.month, _summary!);
    notifyListeners();
  }

  Future<T?> _persist<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (err) {
      toast('Não foi possível salvar', description: errorMessage(err), tone: ToastTone.error);
      await load();
      return null;
    }
  }

  void _setItems(List<MonthItem> Function(List<MonthItem>) update) {
    if (data == null) return;
    data!.items = update(data!.items);
    _changed();
  }

  void _setSpends(List<DailySpend> Function(List<DailySpend>) update) {
    if (data == null) return;
    data!.spends = update(data!.spends);
    _changed();
  }

  /* --------------------------------- Items --------------------------------- */

  Future<void> updateItem(String id, Json patch) async {
    _setItems((items) => [
          for (final item in items)
            item.id == id
                ? item.patch({
                    ...patch,
                    'needsReview': patch['needsReview'] ?? (patch.containsKey('amount') ? false : item.needsReview),
                  })
                : item,
        ]);
    final saved = await _persist(() => _api.updateItem(year, month, id, patch));
    if (saved != null) _setItems((items) => [for (final item in items) item.id == id ? saved : item]);
  }

  Future<void> addItem(Json body) async {
    final created = await _persist(() => _api.addItem(year, month, body));
    if (created != null) _setItems((items) => [...items, created]);
  }

  Future<void> removeItem(String id) async {
    _setItems((items) => items.where((item) => item.id != id).toList());
    await _persist(() => _api.deleteItem(year, month, id));
  }

  Future<void> promoteItem(String id) async {
    final promoted = await _persist(() => _api.promoteItem(year, month, id));
    if (promoted == null) return;
    _setItems((items) => [for (final item in items) item.id == id ? item.patch({'templateItemId': promoted.id}) : item]);
    toast('Salvo no template', description: '${promoted.name} vai aparecer nos próximos meses.', tone: ToastTone.success);
  }

  /* --------------------------------- Month --------------------------------- */

  /// Returns whether the server saved the change.
  Future<bool> updateMonth(Json patch) async {
    if (data != null) {
      data!.month = data!.month.patch(patch);
      _changed();
    }
    final saved = await _persist(() => _api.updateMonth(year, month, patch));
    if (saved != null && data != null) {
      data!.month = saved.month;
      _changed();
    }
    return saved != null;
  }

  /// Throws on failure: the caller shows its own message.
  Future<void> removeMonth() async {
    await _api.deleteMonth(year, month);
    await MonthsStore.instance.refresh();
  }

  /// Moves the open day forward (to today, or to tomorrow if today is open); returns the previous
  /// value for undo, or `null` when nothing was saved.
  Future<({int? previous})?> closeDay() async {
    final current = data;
    if (current == null) return null;
    final previous = current.month.activeDay;
    final next = nextActiveDay(current.month);
    if (next == null) return null;
    if (!await updateMonth({'activeDay': next})) return null;
    return (previous: previous);
  }

  /* --------------------------------- Spends -------------------------------- */

  Future<DailySpend?> addSpend(Json body) async {
    final created = await _persist(() => _api.addSpend(year, month, body));
    if (created != null) _setSpends((spends) => [...spends, created]);
    return created;
  }

  Future<void> updateSpend(String id, Json patch) async {
    _setSpends((spends) => [for (final spend in spends) spend.id == id ? spend.patch(patch) : spend]);
    final saved = await _persist(() => _api.updateSpend(year, month, id, patch));
    if (saved != null) _setSpends((spends) => [for (final spend in spends) spend.id == id ? saved : spend]);
  }

  Future<void> removeSpend(String id) async {
    _setSpends((spends) => spends.where((spend) => spend.id != id).toList());
    await _persist(() => _api.deleteSpend(year, month, id));
  }

  /// Freezes [currency]'s rate at [rate], leaving the other locked rates as they are. The server
  /// replaces the whole map, so the others are sent again.
  Future<bool> lockRate(Currency currency, double rate) =>
      updateMonth({'lockedRates': ratesToJson({...?data?.month.lockedRates, currency: rate})});

  /// Sends [currency] back to the live rate.
  Future<bool> unlockRate(Currency currency) =>
      updateMonth({'lockedRates': ratesToJson({...?data?.month.lockedRates}..remove(currency))});

  /* ---------------------------------- Rate --------------------------------- */

  Future<LiveRates?> refreshRate({bool refreshMonths = true}) async {
    // Nothing to ask before the month is loaded: the rates are quoted against its main currency.
    final base = data?.month.mainCurrency;
    if (base == null) return null;
    refreshingRate = true;
    _changed();
    try {
      final rates = await _api.liveRates(base: base);
      data
        ?..rates = rates
        ..rateError = null;
      if (refreshMonths) await MonthsStore.instance.refresh();
      return rates;
    } catch (err) {
      data?.rateError = errorMessage(err);
      return null;
    } finally {
      refreshingRate = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _rateTimer?.cancel();
    super.dispose();
  }
}
