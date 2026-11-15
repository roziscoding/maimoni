import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../routes.dart';
import '../state/months_store.dart';
import '../state/theme_controller.dart';
import '../theme.dart';
import 'common.dart';
import 'month_create.dart';

/// The web's sidebar: daily spending, new month, months by year (each with its EUR net), pages, theme.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final route = currentRoute(context);
    final store = MonthsStore.instance;

    void go(String target) {
      Navigator.of(context).pop();
      if (target != route) navigate(context, target);
    }

    return Drawer(
      child: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final months = store.months;
            final current = store.current;
            final rows = <Widget>[];
            int? year;
            for (final entry in months) {
              if (entry.year != year) {
                year = entry.year;
                rows.add(GroupLabel('$year', padding: const EdgeInsets.fromLTRB(12, 12, 12, 4)));
              }
              final isCurrent = monthPhase(entry.year, entry.monthNumber) == MonthPhase.current;
              final net = entry.summary.transfer.eur == null ? null : entry.summary.eur.net;
              final target = monthRoute(entry.year, entry.monthNumber);
              rows.add(_NavItem(
                icon: isCurrent ? LucideIcons.calendarCheck : LucideIcons.calendar,
                label: monthName(entry.monthNumber),
                strong: isCurrent,
                selected: route == target,
                trailing: _NetText(net),
                onTap: () => go(target),
              ));
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Text(
                    'maimoni',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: palette.highlighted),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      _NavItem(
                        icon: LucideIcons.wallet,
                        label: 'Gastos diários',
                        selected: route == todayRoute,
                        trailing: current == null ? null : _NetText(current.summary.allowance.remainingEur, muteNull: false),
                        onTap: () => go(todayRoute),
                      ),
                      const SizedBox(height: 8),
                      ActionButton(
                        label: 'Novo mês',
                        icon: LucideIcons.plus,
                        style: ActionStyle.subtle,
                        onPressed: () {
                          Navigator.of(context).pop();
                          showNewMonthSheet(context);
                        },
                      ),
                      const SizedBox(height: 8),
                      if (store.loaded && months.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text('Nenhum mês ainda.', style: TextStyle(fontSize: 14, color: palette.muted)),
                        ),
                      ...rows,
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      _NavItem(
                        icon: LucideIcons.layoutTemplate,
                        label: 'Template',
                        selected: route == templateRoute,
                        onTap: () => go(templateRoute),
                      ),
                      _NavItem(
                        icon: LucideIcons.settings2,
                        label: 'Configurações',
                        selected: route == settingsRoute,
                        onTap: () => go(settingsRoute),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.border))),
                  child: Row(
                    children: [
                      Expanded(child: Text('Tema', style: TextStyle(fontSize: 12, color: palette.muted))),
                      IconButton(
                        tooltip: 'Trocar tema',
                        icon: Icon(Theme.of(context).brightness == Brightness.dark ? LucideIcons.moon : LucideIcons.sun, size: 18),
                        onPressed: () => ThemeController.instance.toggle(Theme.of(context).brightness),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NetText extends StatelessWidget {
  const _NetText(this.value, {this.muteNull = true});

  final double? value;
  final bool muteNull;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (value == null && !muteNull) return const SizedBox();
    final color = value == null ? palette.dimmed : (value! < 0 ? palette.error : palette.muted);
    return Text(formatMoney(value, Currency.eur), style: money(fontSize: 12, color: color));
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.onTap, this.selected = false, this.strong = false, this.trailing});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool strong;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected ? palette.bgElevated : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? palette.highlighted : palette.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: strong || selected ? FontWeight.w600 : FontWeight.w500,
                    color: strong || selected ? palette.highlighted : palette.toned,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
