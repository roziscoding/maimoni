import 'package:flutter/material.dart';

import 'screens/month_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/template_screen.dart';
import 'screens/today_screen.dart';

const todayRoute = '/';
const templateRoute = '/template';
const settingsRoute = '/settings';
String monthRoute(int year, int month) => '/months/$year/$month';

final _monthPath = RegExp(r'^/months/(\d{4})/(\d{1,2})$');

/// Tells Hoje when the page above it closes. Pages only: dialogs and sheets closing over Hoje
/// don't count.
final routeObserver = RouteObserver<PageRoute<void>>();

Route<void> onGenerateRoute(RouteSettings settings) {
  final name = settings.name ?? todayRoute;
  final Widget screen;
  final match = _monthPath.firstMatch(name);
  if (match != null) {
    screen = MonthScreen(key: ValueKey(name), year: int.parse(match.group(1)!), month: int.parse(match.group(2)!));
  } else if (name == templateRoute) {
    screen = const TemplateScreen();
  } else if (name == settingsRoute) {
    screen = const SettingsScreen();
  } else {
    screen = const TodayScreen();
  }
  return MaterialPageRoute(settings: RouteSettings(name: match == null && screen is TodayScreen ? todayRoute : name), builder: (_) => screen);
}

/// Opens a top-level page: Hoje stays at the bottom of the stack, so back always returns to it.
void navigate(BuildContext context, String route) => navigateWith(Navigator.of(context), route);

/// [navigate] for callers that close their own route first (sheets, dialogs).
void navigateWith(NavigatorState navigator, String route) {
  if (route == todayRoute) {
    navigator.popUntil((route) => route.isFirst);
    return;
  }
  navigator.pushNamedAndRemoveUntil(route, (route) => route.isFirst);
}

/// Name of the page currently on top, to highlight it in the drawer.
String? currentRoute(BuildContext context) => ModalRoute.of(context)?.settings.name;
