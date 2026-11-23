import 'package:flutter/material.dart';

import 'screens/month_screen.dart';

/// The destinations of the bottom bar, in its order.
enum AppTab { today, months, template, settings }

/// The tab the home shell shows. Screens that keep their state between visits listen to it and
/// reload when they come back to the front.
final shellTab = ValueNotifier<AppTab>(AppTab.today);

/// Set by whoever wants Hoje to open the sheet that enters a spend, which Hoje does once it has a
/// day to enter it on. The first-run setup ends on it.
final spendRequested = ValueNotifier<bool>(false);

/// Tells Hoje when the page above the shell closes. Pages only: dialogs and sheets closing over it
/// don't count.
final routeObserver = RouteObserver<PageRoute<void>>();

/// Shows a tab of the shell, closing any page open above it.
void openTab(BuildContext context, AppTab tab) => openTabWith(Navigator.of(context), tab);

/// [openTab] for callers that hold the navigator (after an await, or from outside the tree).
void openTabWith(NavigatorState navigator, AppTab tab) {
  navigator.popUntil((route) => route.isFirst);
  shellTab.value = tab;
}

/// Opens a month above the shell, replacing any other page open there: back returns to the tab.
void openMonth(BuildContext context, int year, int month) => openMonthWith(Navigator.of(context), year, month);

/// [openMonth] for callers that close their own route first (sheets).
void openMonthWith(NavigatorState navigator, int year, int month) {
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: '/months/$year/$month'),
      builder: (_) => MonthScreen(year: year, month: month),
    ),
    (route) => route.isFirst,
  );
}
