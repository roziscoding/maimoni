import 'package:flutter/foundation.dart';

import '../api/models.dart';
import '../data/repository.dart';
import '../domain/summary.dart';

/// The month list shown in the drawer (the web's `months` data), shared by every screen.
class MonthsStore extends ChangeNotifier {
  MonthsStore._();

  static final instance = MonthsStore._();

  List<MonthListEntry> months = [];
  bool loaded = false;
  Object? error;

  /// Goes up on every [reset], so a refresh can tell that the session it asked for is over.
  int _generation = 0;

  Future<void> refresh() async {
    final generation = _generation;
    List<MonthListEntry>? result;
    Object? failure;
    try {
      result = await repository.months();
    } catch (err) {
      failure = err;
    }
    // The session ended while the request was in flight: the answer belongs to someone else.
    if (generation != _generation) return;
    if (result != null) months = result;
    error = failure;
    loaded = true;
    notifyListeners();
  }

  /// Drops everything, so the next person to sign in doesn't see the previous one's months.
  void reset() {
    _generation++;
    months = [];
    loaded = false;
    error = null;
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
