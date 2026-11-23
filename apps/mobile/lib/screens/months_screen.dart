import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../routes.dart';
import '../state/months_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/month_create.dart';

/// Every month, by year, each with what it leaves after the bills. A tap opens the month.
class MonthsScreen extends StatelessWidget {
  const MonthsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = MonthsStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Meses')),
      floatingActionButton: AppFab(label: 'Novo mês', icon: LucideIcons.plus, onPressed: () => showNewMonthSheet(context)),
      body: RefreshIndicator(
        onRefresh: store.refresh,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(
            // A short list still takes the pull that reloads it.
            physics: const AlwaysScrollableScrollPhysics(),
            // Room under the last row for the floating button.
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
            children: _content(context, store),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, MonthsStore store) {
    if (!store.loaded) {
      return const [Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))];
    }
    final months = store.months;
    if (months.isEmpty) {
      final error = store.error;
      return [
        if (error != null)
          EmptyState(
            icon: LucideIcons.cloudOff,
            title: 'Não foi possível carregar os meses',
            description: errorMessage(error),
            actions: [
              ActionButton(label: 'Tentar de novo', icon: LucideIcons.refreshCw, style: ActionStyle.subtle, onPressed: store.refresh),
            ],
          )
        else
          const EmptyState(
            icon: LucideIcons.calendarPlus,
            title: 'Nenhum mês ainda',
            description: 'Crie o primeiro a partir do template.',
          ),
      ];
    }

    final years = <int, List<MonthListEntry>>{};
    for (final entry in months) {
      years.putIfAbsent(entry.year, () => []).add(entry);
    }
    return [
      for (final MapEntry(key: year, value: entries) in years.entries) ...[
        SectionHeader('$year'),
        Panel(
          child: Column(
            children: [
              for (final (index, entry) in entries.indexed) ...[
                if (index > 0) const RowDivider(),
                _MonthRow(entry: entry),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    ];
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.entry});

  final MonthListEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final current = monthPhase(entry.year, entry.monthNumber) == MonthPhase.current;
    final net = entry.summary.net;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 12),
      title: Row(
        children: [
          Flexible(child: Text(monthName(entry.monthNumber), overflow: TextOverflow.ellipsis)),
          if (current) ...[const SizedBox(width: 8), const Pill(label: 'atual')],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMoney(net, entry.summary.main),
            style: money(fontSize: 15, color: net == null ? palette.dimmed : (net < 0 ? palette.error : palette.toned)),
          ),
          const SizedBox(width: 4),
          Icon(LucideIcons.chevronRight, size: 18, color: palette.dimmed),
        ],
      ),
      onTap: () => openMonth(context, entry.year, entry.monthNumber),
    );
  }
}
