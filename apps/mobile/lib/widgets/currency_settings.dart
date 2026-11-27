import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../format.dart';
import '../state/currencies_store.dart';
import '../state/toast.dart';
import '../theme.dart';
import 'common.dart';

/// The user's currencies in Configurações. A tap on one opens its actions (make it the main one,
/// stop or start offering it, remove it); every action applies at once.
class CurrencySettings extends StatefulWidget {
  const CurrencySettings({super.key});

  @override
  State<CurrencySettings> createState() => _CurrencySettingsState();
}

class _CurrencySettingsState extends State<CurrencySettings> {
  final _store = CurrenciesStore.instance;

  /// The currency a request is running for. One change runs at a time.
  final _busy = ValueNotifier<Currency?>(null);

  @override
  void initState() {
    super.initState();
    // The list another screen loaded goes out of date here: whether a currency is in use changes
    // as items and spends are added and removed.
    _store.refresh();
  }

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  /// Runs one change and takes the list it answers with, or loads the list again when it answers
  /// with something else.
  Future<bool> _change(Currency currency, String failure, Future<List<UserCurrency>?> Function() request) async {
    if (_busy.value != null) return false;
    _busy.value = currency;
    final generation = _store.generation;
    try {
      final result = await request();
      // The session ended while the change was in flight: its answer belongs to the previous one.
      if (generation != _store.generation) return false;
      if (result != null) {
        _store.replace(result);
      } else {
        await _store.reload();
      }
      return true;
    } catch (err) {
      if (generation != _store.generation) return false;
      toast(failure, description: errorMessage(err), tone: ToastTone.error);
      // What the server refused may mean the list on screen is out of date.
      await _store.refresh();
      return false;
    } finally {
      if (mounted) _busy.value = null;
    }
  }

  Future<bool> _add(Currency currency) => _change(currency, 'Não foi possível adicionar a moeda', () async {
        await Api.instance.addCurrency(currency);
        return null;
      });

  Future<bool> _update(Currency currency, Json patch, String failure) =>
      _change(currency, failure, () => Api.instance.updateCurrency(currency, patch));

  Future<bool> _remove(Currency currency) => _change(currency, 'Não foi possível remover a moeda', () async {
        await Api.instance.deleteCurrency(currency);
        return null;
      });

  Future<void> _pickNew(List<Currency> available) async {
    final picked = await showSheet<Currency>(
      context,
      title: 'Adicionar moeda',
      body: (context) => _CurrencyPicker(currencies: available),
    );
    if (picked != null) await _add(picked);
  }

  void _open(Currency currency) {
    showSheet<void>(
      context,
      title: currencyName(currency),
      description: currency.code,
      body: (context) => _CurrencyActions(
        currency: currency,
        busy: _busy,
        onMain: () => _update(currency, {'main': true}, 'Não foi possível definir a moeda principal'),
        onEnabled: (enabled) =>
            _update(currency, {'enabled': enabled}, enabled ? 'Não foi possível ativar a moeda' : 'Não foi possível desativar a moeda'),
        onRemove: () => _remove(currency),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: Listenable.merge([_store, _busy]), builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final palette = context.palette;
    final muted = TextStyle(fontSize: 14, color: palette.muted);
    final list = _store.list;
    final busy = _busy.value;

    final Widget body;
    if (list == null) {
      body = Panel(
        padding: const EdgeInsets.all(16),
        child: _store.loaded
            ? Text('Não foi possível carregar as moedas: ${errorMessage(_store.error ?? '')}', style: TextStyle(fontSize: 14, color: palette.error))
            : const Center(child: CircularProgressIndicator()),
      );
    } else {
      // The main one first, then the rest in the app's order.
      final order = Currency.sorted(list.map((entry) => entry.currency));
      final rows = [...list]..sort((a, b) {
          if (a.main != b.main) return a.main ? -1 : 1;
          return order.indexOf(a.currency).compareTo(order.indexOf(b.currency));
        });
      final available = Currency.all.where((currency) => !list.any((entry) => entry.currency == currency)).toList()
        ..sort((a, b) => currencyName(a).compareTo(currencyName(b)));
      final adding = busy != null && !list.any((entry) => entry.currency == busy);
      body = Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, entry) in rows.indexed)
              _CurrencyRow(entry: entry, first: index == 0, busy: busy == entry.currency, onTap: () => _open(entry.currency)),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Text('Nenhuma moeda adicionada. A primeira será a principal.', style: muted),
              ),
            if (available.isNotEmpty)
              InkWell(
                onTap: busy == null ? () => _pickNew(available) : null,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.border))),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 36,
                        child: Center(
                          child: adding
                              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(LucideIcons.plus, size: 18, color: palette.text),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Adicionar moeda', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.text)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Moedas'),
        body,
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Usadas nos itens e gastos. Uma moeda desativada deixa de ser oferecida e mantém o histórico.',
            style: TextStyle(fontSize: 13, height: 1.4, color: palette.muted),
          ),
        ),
      ],
    );
  }
}

/// The sign a currency's amounts are written with, in a tile.
class CurrencySymbolTile extends StatelessWidget {
  const CurrencySymbolTile(this.currency, {super.key});

  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: palette.bgAccented, borderRadius: BorderRadius.circular(8)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(currencySymbol(currency), style: money(fontSize: 13, fontWeight: FontWeight.w500, color: palette.highlighted)),
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({required this.entry, required this.first, required this.busy, required this.onTap});

  final UserCurrency entry;
  final bool first;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: first ? null : BoxDecoration(border: Border(top: BorderSide(color: palette.border))),
        child: Row(
          children: [
            // It dims with the name when the currency isn't offered.
            Expanded(
              child: Opacity(
                opacity: entry.enabled ? 1 : 0.5,
                child: Row(
                  children: [
                    CurrencySymbolTile(entry.currency),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currencyName(entry.currency),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.highlighted),
                          ),
                          Text(entry.currency.code, style: money(fontSize: 12, color: palette.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else if (entry.main)
              const Pill(label: 'Principal', icon: LucideIcons.star)
            else if (!entry.enabled)
              Text('Desativada', style: TextStyle(fontSize: 12, color: palette.muted)),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 16, color: palette.dimmed),
          ],
        ),
      ),
    );
  }
}

/// What can be done with one currency. Follows the list, so it shows the result of each action.
class _CurrencyActions extends StatelessWidget {
  const _CurrencyActions({required this.currency, required this.busy, required this.onMain, required this.onEnabled, required this.onRemove});

  final Currency currency;
  final ValueNotifier<Currency?> busy;
  final Future<bool> Function() onMain;
  final Future<bool> Function(bool enabled) onEnabled;
  final Future<bool> Function() onRemove;

  Future<void> _confirmRemove(BuildContext context) async {
    final navigator = Navigator.of(context);
    final confirmed = await showConfirmSheet(
      context,
      title: 'Remover ${currencyName(currency)}?',
      message: 'A moeda deixará de ser oferecida para novos itens e gastos. É possível adicioná-la novamente depois.',
      confirmLabel: 'Remover moeda',
      icon: LucideIcons.trash2,
      danger: true,
    );
    if (!confirmed) return;
    navigator.pop();
    await onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final store = CurrenciesStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, busy]),
      builder: (context, _) {
        final palette = context.palette;
        final entry = store.list?.where((entry) => entry.currency == currency).firstOrNull;
        // Removed, here or somewhere else: nothing left to act on.
        if (entry == null) return Text('Esta moeda não está mais na sua lista.', style: TextStyle(fontSize: 14, color: palette.muted));
        final idle = busy.value == null;
        final name = currencyName(currency);
        // Why removing is blocked: only the problem.
        final removeBlocked = entry.main
            ? 'A moeda principal não pode ser removida.'
            : entry.inUse
                ? '$name possui itens ou gastos registrados.'
                : null;
        final subtitle = TextStyle(fontSize: 13, color: palette.muted);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (entry.main)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(LucideIcons.star, size: 20, color: palette.muted),
                title: const Text('Moeda principal'),
                subtitle: Text('Os meses novos são calculados nela.', style: subtitle),
              )
            // A disabled currency can't be the main one, so it isn't offered the action.
            else if (entry.enabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: idle,
                leading: Icon(LucideIcons.star, size: 20, color: palette.muted),
                title: const Text('Definir como principal'),
                subtitle: Text('Os meses novos passam a ser calculados nela. Os que já existem não mudam.', style: subtitle),
                onTap: onMain,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(LucideIcons.eye, size: 20, color: palette.muted),
              title: const Text('Ativa'),
              subtitle: Text(
                entry.main ? 'A moeda principal não pode ser desativada.' : 'Oferecida para novos itens e gastos.',
                style: subtitle,
              ),
              value: entry.enabled,
              onChanged: entry.main || !idle ? null : onEnabled,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: removeBlocked == null && idle,
              leading: Icon(LucideIcons.trash2, size: 20, color: removeBlocked == null ? palette.error : palette.dimmed),
              title: Text('Remover', style: removeBlocked == null ? TextStyle(color: palette.error) : null),
              subtitle: removeBlocked == null ? null : Text(removeBlocked, style: subtitle),
              onTap: () => _confirmRemove(context),
            ),
          ],
        );
      },
    );
  }
}

const _accents = {'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'é': 'e', 'ê': 'e', 'í': 'i', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ú': 'u', 'ç': 'c'};

/// Lower case and without accents, so `dolar` finds `Dólar`.
String _fold(String text) => text.toLowerCase().split('').map((char) => _accents[char] ?? char).join();

/// The currencies still to add, found by name or by code. Pops the sheet with the one picked.
class _CurrencyPicker extends StatefulWidget {
  const _CurrencyPicker({required this.currencies});

  final List<Currency> currencies;

  @override
  State<_CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<_CurrencyPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final query = _fold(_query.trim());
    final found = widget.currencies
        .where((currency) => _fold(currencyName(currency)).contains(query) || currency.code.toLowerCase().contains(query))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autocorrect: false,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Buscar por nome ou código', prefixIcon: Icon(LucideIcons.search, size: 18)),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 8),
        if (found.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Nenhuma moeda encontrada.', style: TextStyle(fontSize: 14, color: palette.muted)),
          ),
        for (final currency in found)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CurrencySymbolTile(currency),
            title: Text(currencyName(currency)),
            trailing: Text(currency.code, style: money(fontSize: 12, color: palette.muted)),
            onTap: () => Navigator.of(context).pop(currency),
          ),
      ],
    );
  }
}
