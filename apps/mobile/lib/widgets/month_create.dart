import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../format.dart';
import '../routes.dart';
import '../state/currencies_store.dart';
import '../state/months_store.dart';
import '../state/toast.dart';
import '../theme.dart';
import 'common.dart';
import 'currency_settings.dart';
import 'fields.dart';

/// Creates [year]/[month] from the template or the previous month, in [mainCurrency], then opens it.
Future<bool> createMonth(BuildContext context, int year, int month, String source, {Currency? mainCurrency}) async {
  final navigator = Navigator.of(context);
  try {
    await Api.instance.createMonth(year, month, source, mainCurrency: mainCurrency);
    await MonthsStore.instance.refresh();
    // Only while the screen that asked for the month is still open: leaving it cancels the visit.
    if (context.mounted) openMonthWith(navigator, year, month);
    return true;
  } catch (err) {
    toast('Não foi possível criar o mês', description: errorMessage(err), tone: ToastTone.error);
    return false;
  }
}

/// Which currency a new month is worked out in: the offered ones by name, the main one first and
/// picked until another is. Nothing shows with a single currency, as there is nothing to choose.
class MonthCurrencyChoice extends StatelessWidget {
  const MonthCurrencyChoice({super.key, required this.picked, required this.onChanged, this.enabled = true, this.spacing = 0});

  /// The one tapped, if any. [resolve] tells which one the month goes in.
  final Currency? picked;
  final ValueChanged<Currency> onChanged;
  final bool enabled;

  /// Space under it, left out with it when there is nothing to choose.
  final double spacing;

  /// The currency the month goes in: the picked one while it is still offered, otherwise the main one.
  static Currency? resolve(Currency? picked) {
    final store = CurrenciesStore.instance;
    return picked != null && store.offered.contains(picked) ? picked : store.main;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CurrenciesStore.instance,
      builder: (context, _) {
        final store = CurrenciesStore.instance;
        final main = store.main;
        final options = [
          if (main != null && store.offered.contains(main)) main,
          for (final currency in store.offered)
            if (currency != main) currency,
        ];
        if (options.length < 2) return const SizedBox.shrink();
        final selected = resolve(picked);
        final palette = context.palette;
        return Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Moeda do mês'),
              Panel(
                child: Column(
                  children: [
                    for (final (index, currency) in options.indexed) ...[
                      if (index > 0) const RowDivider(indent: 64),
                      _CurrencyOption(
                        currency: currency,
                        main: currency == main,
                        selected: currency == selected,
                        onTap: enabled ? () => onChanged(currency) : null,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Os totais e o saldo saem nela. As outras moedas entram convertidas pela cotação.',
                style: TextStyle(fontSize: 13, height: 1.4, color: palette.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({required this.currency, required this.main, required this.selected, required this.onTap});

  final Currency currency;
  final bool main;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                CurrencySymbolTile(currency),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currencyName(currency),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: palette.highlighted),
                      ),
                      if (main) Text('Sua moeda principal', style: TextStyle(fontSize: 13, color: palette.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: 22,
                  color: selected ? Theme.of(context).colorScheme.primary : palette.dimmed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown where a month that doesn't exist yet was expected: the two ways to create it.
class MonthCreate extends StatefulWidget {
  const MonthCreate({super.key, required this.year, required this.month, this.onCreated});

  final int year;
  final int month;

  /// Called once the month was created and opened, for a screen left below it that has to reload.
  final VoidCallback? onCreated;

  @override
  State<MonthCreate> createState() => _MonthCreateState();
}

class _MonthCreateState extends State<MonthCreate> {
  String? _pending;
  Currency? _currency;

  Future<void> _create(String source) async {
    setState(() => _pending = source);
    final created = await createMonth(context, widget.year, widget.month, source, mainCurrency: MonthCurrencyChoice.resolve(_currency));
    if (!mounted) return;
    setState(() => _pending = null);
    if (created) widget.onCreated?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hasPrevious = MonthsStore.instance.hasBefore(widget.year, widget.month);
    return EmptyState(
      icon: LucideIcons.calendarPlus,
      title: '${monthLabel(widget.year, widget.month)} ainda não existe',
      description: 'Comece pelo template, com os valores fixos de sempre, ou copie o último mês como está.',
      actions: [
        MonthCurrencyChoice(
          picked: _currency,
          enabled: _pending == null,
          onChanged: (currency) => setState(() => _currency = currency),
          spacing: 16,
        ),
        ActionButton(
          label: 'Criar do template',
          icon: LucideIcons.layoutTemplate,
          loading: _pending == 'template',
          onPressed: _pending == null ? () => _create('template') : null,
        ),
        ActionButton(
          label: 'Copiar mês anterior',
          icon: LucideIcons.copy,
          style: ActionStyle.subtle,
          loading: _pending == 'previous',
          onPressed: _pending == null && hasPrevious ? () => _create('previous') : null,
        ),
      ],
    );
  }
}

/// Opens the sheet that creates a month: which one, and where its items come from.
Future<void> showNewMonthSheet(BuildContext context) {
  return showSheet(context, title: 'Novo mês', body: (context) => const _NewMonthForm());
}

class _NewMonthForm extends StatefulWidget {
  const _NewMonthForm();

  @override
  State<_NewMonthForm> createState() => _NewMonthFormState();
}

class _NewMonthFormState extends State<_NewMonthForm> {
  /// The month picked, as `year * 12 + month - 1`, so the arrows step it across years.
  late int _index;
  String? _pending;
  Currency? _currency;

  int get _year => _index ~/ 12;
  int get _month => _index % 12 + 1;

  @override
  void initState() {
    super.initState();
    // Starts on the first month from now on that doesn't exist yet.
    final store = MonthsStore.instance;
    final now = DateTime.now();
    _index = now.year * 12 + now.month - 1;
    while (store.exists(_year, _month)) {
      _index++;
    }
  }

  Future<void> _create(String source) async {
    setState(() => _pending = source);
    final navigator = Navigator.of(context);
    final year = _year;
    final month = _month;
    try {
      await Api.instance.createMonth(year, month, source, mainCurrency: MonthCurrencyChoice.resolve(_currency));
      await MonthsStore.instance.refresh();
      navigator.pop();
      openMonthWith(navigator, year, month);
    } catch (err) {
      toast('Não foi possível criar o mês', description: errorMessage(err), tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final store = MonthsStore.instance;
    final taken = store.exists(_year, _month);
    final idle = _pending == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Mês anterior',
                icon: const Icon(LucideIcons.chevronLeft, size: 22),
                onPressed: idle ? () => setState(() => _index--) : null,
              ),
              Expanded(
                child: Text(
                  monthLabel(_year, _month),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: palette.highlighted),
                ),
              ),
              IconButton(
                tooltip: 'Mês seguinte',
                icon: const Icon(LucideIcons.chevronRight, size: 22),
                onPressed: idle ? () => setState(() => _index++) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (taken)
          Callout(
            icon: LucideIcons.calendarX,
            title: '${monthLabel(_year, _month)} já existe',
            action: OutlinedButton(
              onPressed: () {
                final navigator = Navigator.of(context)..pop();
                openMonthWith(navigator, _year, _month);
              },
              child: const Text('Abrir'),
            ),
          )
        else ...[
          MonthCurrencyChoice(
            picked: _currency,
            enabled: idle,
            onChanged: (currency) => setState(() => _currency = currency),
            spacing: 24,
          ),
          ActionButton(
            label: 'Criar do template',
            icon: LucideIcons.layoutTemplate,
            loading: _pending == 'template',
            onPressed: idle ? () => _create('template') : null,
          ),
          const SizedBox(height: 6),
          Text(
            'Valores fixos de sempre. Os que variam chegam para confirmar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: palette.muted),
          ),
          const SizedBox(height: 16),
          ActionButton(
            label: 'Copiar mês anterior',
            icon: LucideIcons.copy,
            style: ActionStyle.subtle,
            loading: _pending == 'previous',
            onPressed: idle && store.hasBefore(_year, _month) ? () => _create('previous') : null,
          ),
          const SizedBox(height: 6),
          Text(
            store.hasBefore(_year, _month) ? 'Os itens do último mês antes deste, como estão.' : 'Não há mês antes deste para copiar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: palette.muted),
          ),
        ],
      ],
    );
  }
}
