import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../routes.dart';
import '../theme.dart';
import 'months_screen.dart';
import 'settings_screen.dart';
import 'template_screen.dart';
import 'today_screen.dart';

/// The signed in app: one screen per [AppTab] under a bottom bar. Months and the history open as
/// pages above it.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Tabs opened so far. A tab is built on its first visit and kept from then on.
  final _visited = <AppTab>{};

  Widget _screen(AppTab tab, AppTab current) {
    // Ajustes is built again on every visit: what it lists (sessions, currencies in use) goes out of date.
    if (tab == AppTab.settings) return current == tab ? const SettingsScreen() : const SizedBox();
    if (!_visited.contains(tab)) return const SizedBox();
    return switch (tab) {
      AppTab.today => const TodayScreen(),
      AppTab.months => const MonthsScreen(),
      AppTab.template => const TemplateScreen(),
      AppTab.settings => const SizedBox(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ValueListenableBuilder(
      valueListenable: shellTab,
      builder: (context, current, _) {
        _visited.add(current);
        return Scaffold(
          body: IndexedStack(
            index: current.index,
            children: [for (final tab in AppTab.values) _screen(tab, current)],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.border))),
            child: NavigationBar(
              selectedIndex: current.index,
              onDestinationSelected: (index) => shellTab.value = AppTab.values[index],
              destinations: const [
                NavigationDestination(icon: Icon(LucideIcons.wallet), label: 'Hoje'),
                NavigationDestination(icon: Icon(LucideIcons.calendar), label: 'Meses'),
                NavigationDestination(icon: Icon(LucideIcons.layoutTemplate), label: 'Template'),
                NavigationDestination(icon: Icon(LucideIcons.settings2), label: 'Ajustes'),
              ],
            ),
          ),
        );
      },
    );
  }
}
