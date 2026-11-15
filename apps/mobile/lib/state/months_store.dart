import 'package:flutter/foundation.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../domain/summary.dart';

/// The month list shown in the drawer (the web's `months` data), shared by every screen.
class MonthsStore extends ChangeNotifier {
  MonthsStore._();

  static final instance = MonthsStore._();

  List<MonthListEntry> months = [];
  bool loaded = false;
  Object? error;

  Future<void> refresh() async {
    try {
      months = await Api.instance.months();
      error = null;
    } catch (err) {
      error = err;
    }
    loaded = true;
    notifyListeners();
  }

  MonthListEntry? get current =>
      months.where((entry) => monthPhase(entry.year, entry.monthNumber) == MonthPhase.current).firstOrNull;

  bool exists(int year, int month) => months.any((entry) => entry.year == year && entry.monthNumber == month);

  bool hasBefore(int year, int month) =>
      months.any((entry) => entry.year * 12 + entry.monthNumber < year * 12 + month);

  /// Keeps the drawer's figures in sync with a month being edited, without refetching the list.
  void updateSummary(Month month, MonthSummary summary) {
    final index = months.indexWhere((entry) => entry.year == month.year && entry.monthNumber == month.month);
    if (index < 0) return;
    months = [...months]..[index] = MonthListEntry(month: month, summary: summary);
    notifyListeners();
  }
}
