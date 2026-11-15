import 'dart:async';

import 'package:flutter/widgets.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../domain/summary.dart';
import 'months_store.dart';
import 'toast.dart';

const _rateRefresh = Duration(minutes: 5);
const _quoteDebounce = Duration(milliseconds: 600);

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
  Timer? _quoteTimer;
  bool _disposed = false;

  MonthSummary? get summary => _summary;

  Future<void> load() async {
    try {
      data = await _api.month(year, month);
      error = null;
    } on ApiException catch (err) {
      data = null;
      error = err;
    }
    loading = false;
    _changed();
  }

  /// Recomputes the summary, then keeps the drawer and the Wise quote in step with it.
  void _changed() {
    if (_disposed) return;
    final current = data;
    final previousSent = _summary?.transfer.projected.sentBrl;
    _summary = current == null
        ? null
        : summarizeMonth(
            current.month,
            current.items,
            rate: current.rate?.rate,
            quote: current.quote,
            fallbackFee: current.fallbackFee,
            spends: current.spends,
            conversions: current.conversions,
          );
    if (current != null && _summary != null) {
      MonthsStore.instance.updateSummary(current.month, _summary!);
      final sent = _summary!.transfer.projected.sentBrl;
      if (sent != previousSent) _scheduleQuote(sent);
    }
    notifyListeners();
  }

  // Without a manual fee the fee comes from Wise's quote for the exact amount sent. Edits change that
  // amount: the summary scales the old quote meanwhile, and a fresh one is fetched once edits settle.
  void _scheduleQuote(double sentBrl) {
    _quoteTimer?.cancel();
    final current = data;
    if (current == null || sentBrl == 0 || current.month.wiseFee != null || current.quote?.sendAmount == sentBrl) return;
    _quoteTimer = Timer(_quoteDebounce, () async {
      WiseQuote? quote;
      try {
        quote = await _api.quote(sendAmount: sentBrl);
      } catch (_) {
        quote = null;
      }
      if (data != null && _summary?.transfer.projected.sentBrl == sentBrl) {
        data!.quote = quote;
        _changed();
      }
    });
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

  void _setConversions(List<Conversion> Function(List<Conversion>) update) {
    if (data == null) return;
    data!.conversions = update(data!.conversions);
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
      data!
        ..month = saved.month
        ..quote = saved.quote;
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

  /* ------------------------------- Conversions ----------------------------- */

  Future<Conversion?> addConversion(Json body) async {
    final created = await _persist(() => _api.addConversion(year, month, body));
    if (created != null) _setConversions((conversions) => [...conversions, created]);
    return created;
  }

  Future<Conversion?> updateConversion(String id, Json patch) async {
    _setConversions((conversions) => [
          for (final conversion in conversions) conversion.id == id ? conversion.patch(patch) : conversion,
        ]);
    final saved = await _persist(() => _api.updateConversion(year, month, id, patch));
    if (saved != null) {
      _setConversions((conversions) => [for (final conversion in conversions) conversion.id == id ? saved : conversion]);
    }
    return saved;
  }

  Future<void> removeConversion(String id) async {
    _setConversions((conversions) => conversions.where((conversion) => conversion.id != id).toList());
    await _persist(() => _api.deleteConversion(year, month, id));
  }

  /* ---------------------------------- Rate --------------------------------- */

  Future<LiveRate?> refreshRate({bool refreshMonths = true}) async {
    refreshingRate = true;
    _changed();
    try {
      final rate = await _api.liveRate();
      data
        ?..rate = rate
        ..rateError = null;
      if (refreshMonths) await MonthsStore.instance.refresh();
      return rate;
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
    _quoteTimer?.cancel();
    super.dispose();
  }
}
