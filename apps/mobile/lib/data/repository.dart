import '../api/client.dart';
import '../api/models.dart';
import '../state/local_mode.dart';

/// Where the user's data is read and written: the server ([Api]) or the device.
///
/// Failures are thrown as [ApiException], whichever the implementation, so callers handle both the same.
abstract interface class Repository {
  Future<List<MonthListEntry>> months();
  Future<MonthDetail> month(int year, int month);

  /// [source] is `template` or `previous`. Without [mainCurrency] the month is worked out in the user's main one.
  Future<void> createMonth(int year, int month, String source, {Currency? mainCurrency});
  Future<MonthDetail> updateMonth(int year, int month, Json patch);
  Future<void> deleteMonth(int year, int month);

  Future<MonthItem> addItem(int year, int month, Json body);
  Future<MonthItem> updateItem(int year, int month, String id, Json patch);
  Future<void> deleteItem(int year, int month, String id);
  Future<TemplateItem> promoteItem(int year, int month, String id);

  Future<DailySpend> addSpend(int year, int month, Json body);
  Future<DailySpend> updateSpend(int year, int month, String id, Json patch);
  Future<void> deleteSpend(int year, int month, String id);

  /// Live rates quoted against [base]; without one, against the user's main currency.
  Future<LiveRates> liveRates({Currency? base});

  /// The user's currencies, the main one first.
  Future<List<UserCurrency>> currencies();
  Future<void> addCurrency(Currency currency);

  /// [patch] is `{ enabled?, main? }`. Answers with the whole list: making one the main one changes another.
  Future<List<UserCurrency>> updateCurrency(Currency currency, Json patch);

  /// Replaces the whole list with [enabled] and [disabled], [main] being one of the enabled. A
  /// currency left out is removed, which is refused for one that is in use.
  Future<List<UserCurrency>> replaceCurrencies({
    required List<Currency> enabled,
    List<Currency> disabled = const [],
    required Currency main,
  });
  Future<void> deleteCurrency(Currency currency);

  Future<TemplateDetail> template();
  Future<TemplateItem> addTemplateItem(Json body);
  Future<TemplateItem> updateTemplateItem(String id, Json patch);
  Future<void> deleteTemplateItem(String id);
  Future<List<TemplateItem>> reorderTemplate(List<String> ids);

  /// Deletes every month (with its items and spends) and the template. Currencies stay.
  Future<void> clearData();
}

/// The repository the app works with: the device's in the local mode, the server's otherwise.
Repository get repository => LocalMode.instance.active ? LocalMode.instance.repository : Api.instance;
