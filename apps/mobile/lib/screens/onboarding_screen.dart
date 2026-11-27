import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/auth.dart';
import '../api/client.dart';
import '../api/models.dart';
import '../data/repository.dart';
import '../domain/expression.dart';
import '../domain/summary.dart';
import '../format.dart';
import '../routes.dart';
import '../state/currencies_store.dart';
import '../state/local_mode.dart';
import '../state/months_store.dart';
import '../state/session.dart';
import '../state/toast.dart';
import '../theme.dart';
import '../widgets/backup_prompt.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

/// The screens of the setup, in order. [welcome] comes before the questions and [done] after them;
/// the progress bar counts what is in between.
enum _Step { welcome, currencies, main, income, expenses, backup, daily, done }

/// Names offered as chips, so the common items take a tap and an amount instead of typing.
const _suggestions = {
  EntryKind.income: ['Salário', 'Freelance'],
  EntryKind.expense: ['Aluguel', 'Condomínio', 'Internet', 'Celular', 'Luz', 'Academia'],
};

/// The currencies listed first whatever the device says, in this order.
const _pinned = [Currency.brl, Currency.eur, Currency('USD')];

/// Lowercase and without the accents pt-BR names have, so `dolar` finds `Dólar` and names sort as read.
String _plain(String value) {
  const accents = {'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'é': 'e', 'ê': 'e', 'í': 'i', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ú': 'u', 'ç': 'c'};
  return value.toLowerCase().split('').map((char) => accents[char] ?? char).join();
}

/// The currency of the region the device is set to, when it is one the app offers.
Currency? _deviceCurrency() {
  try {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final code = NumberFormat.simpleCurrency(locale: locale.toString()).currencyName;
    final currency = code == null ? null : Currency(code);
    return currency != null && Currency.all.contains(currency) ? currency : null;
  } catch (_) {
    // A locale `intl` has no data for: nothing to suggest.
    return null;
  }
}

/// The first-run setup: what the app needs to know before it can say how much there is to spend a
/// day, asked one question per screen. The currencies are the only answer it requires.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  Repository get _api => repository;
  final _now = DateTime.now();

  bool _loading = true;
  Object? _loadError;
  _Step _step = _Step.welcome;

  /// The currency of the device's region, listed first and marked on a first visit.
  final Currency? _suggested = _deviceCurrency();

  /// The currencies the user says they use, in the order they marked them.
  List<Currency> _picked = [];
  Currency? _main;
  String _query = '';
  bool _savingCurrencies = false;
  bool _savingBackup = false;

  List<TemplateItem> _items = [];

  /// Quoted against the main currency, for the daily amount of a user with more than one.
  LiveRates? _rates;

  /// Whether the current month was there when the setup opened. Read once, so creating it doesn't
  /// turn the question about it into "already exists".
  bool _monthExists = false;

  /// Whether this screen created the month. A second try after a failure doesn't create it again.
  bool _monthCreated = false;

  /// What is running at the end: `true` finishing with the month, `false` without it.
  bool? _finishing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final store = CurrenciesStore.instance;
    Object? error;
    TemplateDetail? template;
    try {
      // Asked again even when the store has a list: the setup decides where to start from it.
      await store.reload();
      if (store.list == null) throw store.error ?? ApiException('Sem conexão com o servidor');
      template = await _api.template();
      await MonthsStore.instance.refresh();
      await _loadRates();
    } catch (err) {
      error = err;
    }
    if (!mounted) return;
    final saved = store.list ?? const <UserCurrency>[];
    setState(() {
      _loading = false;
      _loadError = error;
      if (error != null) return;
      _items = [...template!.items]..sort((a, b) => a.position.compareTo(b.position));
      _monthExists = MonthsStore.instance.exists(_now.year, _now.month);
      _main = saved.where((entry) => entry.main).firstOrNull?.currency;
      _picked = [
        ?_main,
        for (final entry in saved)
          if (entry.enabled && !entry.main) entry.currency,
      ];
      // A user who already has currencies left in the middle, and comes back to the question after them.
      _step = saved.isEmpty ? _Step.welcome : _Step.income;
      if (saved.isEmpty && _suggested != null) _picked = [_suggested];
    });
  }

  /// The rates can be missing: the daily amount then says so instead of showing a figure.
  Future<void> _loadRates() async {
    try {
      _rates = await _api.liveRates();
    } catch (_) {
      _rates = null;
    }
  }

  /* ---------------------------------- Steps --------------------------------- */

  /// The questions the progress bar counts. With a single currency there is no main one to ask about.
  List<_Step> get _flow => [
        _Step.currencies,
        if (_picked.length > 1) _Step.main,
        _Step.income,
        _Step.expenses,
        // Without an account the data is only on the device, so the system's backup is worth asking about.
        if (LocalMode.instance.active) _Step.backup,
        _Step.daily,
      ];

  /// Turns the system's backup on or off, then goes on to the month.
  Future<void> _chooseBackup(bool enabled) async {
    setState(() => _savingBackup = true);
    try {
      await LocalMode.instance.setBackup(enabled);
      if (mounted) _go(_Step.daily);
    } catch (err) {
      toast('Não foi possível mudar o backup', description: errorMessage(err), tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _savingBackup = false);
    }
  }

  void _go(_Step step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = step);
  }

  void _back() {
    final index = _flow.indexOf(_step);
    if (index < 0) return;
    _go(index == 0 ? _Step.welcome : _flow[index - 1]);
  }

  bool get _busy => _savingCurrencies || _savingBackup || _finishing != null;

  /* ------------------------------- Currencies ------------------------------- */

  /// Every currency, in the order the list shows them: the device's, the pinned ones, then by name.
  List<Currency> get _currencyOptions {
    final first = <Currency>{?_suggested, ..._pinned};
    final rest = Currency.all.where((currency) => !first.contains(currency)).toList()
      ..sort((a, b) => _plain(currencyName(a)).compareTo(_plain(currencyName(b))));
    final wanted = _plain(_query.trim());
    return [...first, ...rest]
        .where((currency) => wanted.isEmpty || _plain(currencyName(currency)).contains(wanted) || currency.code.toLowerCase().contains(wanted))
        .toList();
  }

  void _togglePicked(Currency currency) {
    setState(() => _picked = _picked.contains(currency) ? _picked.where((entry) => entry != currency).toList() : [..._picked, currency]);
  }

  Future<void> _currenciesChosen() async {
    // The main one stays when it is still marked; otherwise it is the first one marked, likely the user's own.
    if (_main == null || !_picked.contains(_main)) _main = _picked.first;
    if (_picked.length > 1) return _go(_Step.main);
    await _saveCurrencies();
  }

  Future<void> _saveCurrencies() async {
    final main = _main;
    if (main == null) return;
    final store = CurrenciesStore.instance;
    final saved = store.list ?? const <UserCurrency>[];
    // Going back and unmarking a currency that already has entries or expenses in it, which the server refuses.
    final stillUsed = [
      for (final entry in saved)
        if (!_picked.contains(entry.currency) && entry.enabled && (entry.inUse || _items.any((item) => item.currency == entry.currency))) entry.currency,
    ];
    if (stillUsed.isNotEmpty) {
      toast(
        'Essa moeda ainda tem valores',
        description: 'Remova as entradas e saídas em ${stillUsed.map(currencyName).join(', ')} antes de desmarcar.',
        tone: ToastTone.error,
      );
      return;
    }
    setState(() => _savingCurrencies = true);
    try {
      final list = await _api.replaceCurrencies(
        enabled: _picked,
        // A currency disabled somewhere else isn't asked about here, and leaving it out would remove it.
        disabled: [
          for (final entry in saved)
            if (!entry.enabled && !_picked.contains(entry.currency)) entry.currency,
        ],
        main: main,
      );
      store.replace(list);
      // The rates are quoted against the main currency, which may have just changed.
      await _loadRates();
      if (mounted) _go(_Step.income);
    } catch (err) {
      toast('Não foi possível salvar suas moedas', description: errorMessage(err), tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _savingCurrencies = false);
    }
  }

  /* ---------------------------------- Items --------------------------------- */

  /// The main currency first: a new item starts in it.
  List<Currency> get _itemCurrencies => [?_main, ..._picked.where((currency) => currency != _main)];

  List<TemplateItem> _of(EntryKind kind) => _items.where((item) => item.kind == kind).toList();

  Future<void> _addItem(EntryKind kind, {String name = ''}) async {
    final values = await showSheet<Json>(
      context,
      title: kind == EntryKind.income ? 'Nova entrada' : 'Nova saída',
      body: (_) => _ItemSheet(name: name, example: _suggestions[kind]!.first, currencies: _itemCurrencies, submitLabel: 'Adicionar'),
    );
    if (values == null) return;
    try {
      final created = await _api.addTemplateItem({...values, 'kind': kind.name});
      if (mounted) setState(() => _items = [..._items, created]);
    } catch (err) {
      toast('Não foi possível adicionar', description: errorMessage(err), tone: ToastTone.error);
    }
  }

  Future<void> _editItem(TemplateItem item) async {
    final values = await showSheet<Json>(
      context,
      title: item.kind == EntryKind.income ? 'Entrada' : 'Saída',
      body: (_) => _ItemSheet(
        name: item.name,
        amount: item.amount,
        expression: item.expression,
        example: item.name,
        currencies: [item.currency],
        submitLabel: 'Salvar',
        removable: true,
      ),
    );
    if (values == null) return;
    if (values['remove'] == true) return _removeItem(item);
    try {
      final saved = await _api.updateTemplateItem(item.id, values);
      if (mounted) setState(() => _items = [for (final entry in _items) entry.id == item.id ? saved : entry]);
    } catch (err) {
      toast('Não foi possível salvar', description: errorMessage(err), tone: ToastTone.error);
    }
  }

  Future<void> _removeItem(TemplateItem item) async {
    setState(() => _items = _items.where((entry) => entry.id != item.id).toList());
    try {
      await _api.deleteTemplateItem(item.id);
    } catch (err) {
      toast('Não foi possível remover', description: errorMessage(err), tone: ToastTone.error);
      // Back on the list, since the server still has it.
      if (mounted) setState(() => _items = [..._items, item]..sort((a, b) => a.position.compareTo(b.position)));
    }
  }

  /* ---------------------------------- Month --------------------------------- */

  String get _monthLower => monthName(_now.month).toLowerCase();

  /// The current month as the template would make it.
  MonthSummary? get _summary {
    final main = _main;
    if (main == null) return null;
    final items = [
      for (final item in _items)
        MonthItem(
          id: item.id,
          monthId: '',
          templateItemId: item.id,
          name: item.name,
          currency: item.currency,
          kind: item.kind,
          amount: item.amount,
          expression: item.expression,
          paid: false,
          needsReview: item.variable,
          position: item.position,
        ),
    ];
    final month = Month(id: '', year: _now.year, month: _now.month, mainCurrency: main, lockedRates: const {}, activeDay: null, note: null, createdAt: '');
    // Rates quoted against another currency (the main one changed since they were loaded) don't apply.
    return summarizeMonth(month, items, rates: _rates?.base == main ? _rates!.rates : null, today: _now);
  }

  /// Records the setup as finished and shows the last screen. With [withMonth], it creates the
  /// current month first, unless it is there already.
  Future<void> _finish({required bool withMonth}) async {
    setState(() => _finishing = withMonth);
    var failure = 'Não foi possível concluir';
    try {
      if (withMonth && !_monthExists && !_monthCreated) {
        failure = 'Não foi possível criar $_monthLower';
        await _api.createMonth(_now.year, _now.month, 'template');
        _monthCreated = true;
        await MonthsStore.instance.refresh();
        failure = '${monthName(_now.month)} foi criado, mas não foi possível concluir';
      }
      await finishOnboarding();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _go(_Step.done);
    } catch (err) {
      toast(failure, description: errorMessage(err), tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _finishing = null);
    }
  }

  /// Leaves the setup for the app. With a month to spend in, Hoje opens ready to take the first spend.
  void _openApp() {
    if (_monthExists || _monthCreated) spendRequested.value = true;
    shellTab.value = AppTab.today;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  /* ---------------------------------- Build --------------------------------- */

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final position = _flow.indexOf(_step);
    final question = !_loading && _loadError == null && position >= 0;
    return PopScope(
      // The system's back goes to the question before; out of the questions, it leaves the app.
      canPop: !question,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: question ? IconButton(tooltip: 'Voltar', icon: const Icon(LucideIcons.arrowLeft, size: 22), onPressed: _busy ? null : _back) : null,
          titleSpacing: question ? 0 : 20,
          title: question
              ? _Progress(position: position, length: _flow.length)
              : Text('maimoni', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: palette.highlighted)),
          actions: [
            // Once the setup is recorded as finished there is nothing left to walk away from.
            // Without an account, leaving goes back to the start and drops what was set up so far.
            if (_step != _Step.done)
              LocalMode.instance.active
                  ? TextButton(onPressed: _busy ? null : LocalMode.instance.leave, child: const Text('Voltar ao início'))
                  : TextButton(onPressed: _busy ? null : signOut, child: const Text('Sair')),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? Center(
                      child: EmptyState(
                        icon: LucideIcons.cloudOff,
                        title: 'Não foi possível carregar',
                        description: errorMessage(_loadError!),
                        actions: [ActionButton(label: 'Tentar de novo', icon: LucideIcons.refreshCw, style: ActionStyle.subtle, onPressed: _load)],
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
                      child: KeyedSubtree(key: ValueKey(_step), child: _stepBody(context)),
                    ),
        ),
      ),
    );
  }

  Widget _stepBody(BuildContext context) {
    return switch (_step) {
      _Step.welcome => _Page(
          title: 'Boas-vindas ao maimoni',
          description:
              'O maimoni divide o que sobra do seu mês pelos dias que faltam e mostra quanto você pode gastar hoje.\n\nPara fazer essa conta, ele precisa saber algumas coisas sobre o seu dinheiro.',
          footer: [FilledButton(onPressed: () => _go(_Step.currencies), child: const Text('Começar'))],
        ),
      _Step.currencies => _Page(
          title: 'Quais moedas você usa?',
          description: 'O maimoni controla seus gastos em mais de uma moeda ao mesmo tempo. Marque todas as que fazem parte do seu mês.',
          footer: [ActionButton(label: 'Continuar', loading: _savingCurrencies, onPressed: _picked.isEmpty ? null : _currenciesChosen)],
          children: [
            TextField(
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(hintText: 'Buscar por nome ou código', prefixIcon: Icon(LucideIcons.search, size: 18)),
            ),
            const SizedBox(height: 8),
            for (final currency in _currencyOptions)
              _CurrencyChoice(
                currency: currency,
                note: currency == _suggested ? 'A moeda da região do seu aparelho' : null,
                selected: _picked.contains(currency),
                onTap: () => _togglePicked(currency),
              ),
            if (_currencyOptions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Nenhuma moeda com esse nome.', style: TextStyle(fontSize: 15, color: context.palette.muted)),
              ),
          ],
        ),
      _Step.main => _Page(
          title: 'Qual delas é a principal?',
          description: 'É a moeda do seu dia a dia. O valor que você pode gastar por dia é calculado nela, e o que estiver nas outras é convertido.',
          footer: [ActionButton(label: 'Continuar', loading: _savingCurrencies, onPressed: _main == null ? null : _saveCurrencies)],
          children: [
            for (final currency in _picked)
              _CurrencyChoice(currency: currency, selected: currency == _main, exclusive: true, onTap: () => setState(() => _main = currency)),
          ],
        ),
      _Step.income => _itemsPage(
          kind: EntryKind.income,
          title: 'O que entra todo mês?',
          description: 'Seu salário e qualquer outro valor que você recebe sempre. Todo mês novo já começa com essas entradas.',
          next: _Step.expenses,
        ),
      _Step.expenses => _itemsPage(
          kind: EntryKind.expense,
          title: 'E o que sai todo mês?',
          description: 'As contas fixas, como aluguel e internet. Os gastos do dia a dia ficam de fora: você registra cada um quando acontece.',
          next: LocalMode.instance.active ? _Step.backup : _Step.daily,
        ),
      _Step.backup => _Page(
          title: backupQuestion,
          description: backupExplanation,
          footer: [
            ActionButton(label: 'Ativar o backup', loading: _savingBackup, onPressed: _busy ? null : () => _chooseBackup(true)),
            const SizedBox(height: 4),
            TextButton(onPressed: _busy ? null : () => _chooseBackup(false), child: const Text('Agora não')),
          ],
        ),
      _Step.daily => _dailyPage(context),
      _Step.done => _donePage(context),
    };
  }

  Widget _itemsPage({required EntryKind kind, required String title, required String description, required _Step next}) {
    final items = _of(kind);
    final used = {for (final item in items) _plain(item.name)};
    return _Page(
      title: title,
      description: description,
      footer: [
        Row(
          children: [
            TextButton(onPressed: () => _go(next), child: const Text('Pular')),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: items.isEmpty ? null : () => _go(next), child: const Text('Continuar'))),
          ],
        ),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            // A name already on the list isn't offered again.
            for (final name in _suggestions[kind]!)
              if (!used.contains(_plain(name))) ActionChip(label: Text(name), onPressed: () => _addItem(kind, name: name)),
            ActionChip(avatar: const Icon(LucideIcons.plus, size: 16), label: Text(kind == EntryKind.income ? 'Outra entrada' : 'Outra saída'), onPressed: () => _addItem(kind)),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final (index, item) in items.indexed) ...[
            if (index > 0) const RowDivider(),
            _ItemRow(item: item, onTap: () => _editItem(item), onRemove: () => _removeItem(item)),
          ],
        ],
      ],
    );
  }

  Widget _dailyPage(BuildContext context) {
    final palette = context.palette;
    final summary = _summary;
    final amount = summary?.allowance.amount;
    final creates = !_monthExists;
    final footer = [
      ActionButton(
        label: creates ? 'Criar $_monthLower' : 'Concluir',
        loading: _finishing == true,
        onPressed: _busy ? null : () => _finish(withMonth: true),
      ),
      if (creates) ...[
        const SizedBox(height: 4),
        TextButton(onPressed: _busy ? null : () => _finish(withMonth: false), child: const Text('Agora não')),
      ],
    ];
    if (!creates) {
      return _Page(
        title: '${monthName(_now.month)} já está criado',
        description: 'Você já tem esse mês, então não precisa criar de novo.',
        footer: footer,
      );
    }
    if (_items.isEmpty || summary == null || amount == null) {
      return _Page(
        title: 'Criar o mês de $_monthLower?',
        description: _items.isEmpty
            ? 'Você pode adicionar suas entradas e saídas direto no mês, quando quiser.'
            : 'Não deu para calcular seu valor diário agora, porque a cotação das moedas não carregou. Ele aparece no mês assim que a cotação voltar.',
        footer: footer,
      );
    }
    final net = summary.net ?? 0;
    final days = summary.allowance.days;
    // What the answers add up to: the figure the app is about.
    return _Page(
      title: 'Em $_monthLower, você pode gastar',
      footer: footer,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMoney(amount, summary.main),
            style: money(fontSize: 52, fontWeight: FontWeight.w600, height: 1.1, color: amount < 0 ? palette.error : palette.highlighted),
          ),
        ),
        const SizedBox(height: 4),
        Text('por dia', style: TextStyle(fontSize: 16, color: palette.muted)),
        const SizedBox(height: 20),
        Text(
          '${net >= 0 ? 'Sobram ${formatMoney(net, summary.main)} depois das contas' : 'As contas passam das entradas em ${formatMoney(-net, summary.main)}'}, '
          '${days == 1 ? 'e falta 1 dia para o mês acabar.' : 'divididos pelos $days dias que faltam para o mês acabar.'}',
          style: TextStyle(fontSize: 16, height: 1.4, color: palette.muted),
        ),
      ],
    );
  }

  Widget _donePage(BuildContext context) {
    final hasMonth = _monthExists || _monthCreated;
    // A user added by hand may have their email for a name, which isn't one to greet by.
    final first = Session.instance.user?.name.trim().split(RegExp(r'\s+')).first ?? '';
    final greetable = first.isNotEmpty && !first.contains('@');
    return _Page(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
        child: Icon(LucideIcons.check, size: 22, color: Theme.of(context).colorScheme.onPrimary),
      ),
      title: greetable ? 'Tudo pronto, $first' : 'Tudo pronto',
      description: hasMonth
          ? 'Registre seus gastos conforme eles acontecem e feche o dia quando ele acabar. O que sobrar hoje vira folga nos próximos dias.'
          : 'Suas moedas e seus valores de todo mês já estão guardados. Quando quiser começar, crie o mês de $_monthLower na tela inicial.',
      footer: [FilledButton(onPressed: _openApp, child: Text(hasMonth ? 'Registrar um gasto' : 'Abrir o maimoni'))],
    );
  }
}

/// One screen of the setup: a title and what it asks for, scrolling when taller than the screen,
/// over the buttons that answer it, which stay at the bottom and above the keyboard.
class _Page extends StatelessWidget {
  const _Page({required this.title, this.description, this.leading, this.children = const [], required this.footer});

  final String title;
  final String? description;

  /// What goes over the title.
  final Widget? leading;
  final List<Widget> children;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              if (leading != null) Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 20), child: leading)),
              Semantics(
                header: true,
                child: Text(title, style: TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w600, letterSpacing: -0.6, color: palette.highlighted)),
              ),
              if (description != null) ...[
                const SizedBox(height: 10),
                Text(description!, style: TextStyle(fontSize: 16, height: 1.4, color: palette.muted)),
              ],
              if (children.isNotEmpty) const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: footer),
        ),
      ],
    );
  }
}

/// How far along the questions the user is: one segment per question, filled up to the current one.
class _Progress extends StatelessWidget {
  const _Progress({required this.position, required this.length});

  final int position;
  final int length;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: 'Pergunta ${position + 1} de $length',
      child: Row(
        children: [
          for (var index = 0; index < length; index++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: index <= position ? Theme.of(context).colorScheme.primary : palette.bgAccented,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A currency to mark: the sign its amounts are written with, its name and its code.
class _CurrencyChoice extends StatelessWidget {
  const _CurrencyChoice({required this.currency, required this.selected, required this.onTap, this.note, this.exclusive = false});

  final Currency currency;
  final bool selected;
  final VoidCallback onTap;

  /// Said under the name in place of the code, for a currency that is there for a reason.
  final String? note;

  /// Whether marking it unmarks the others, which is drawn and read out as a radio.
  final bool exclusive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: exclusive,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // As wide as its sign needs: `€` and `CHF` don't fit the same square.
              Container(
                constraints: const BoxConstraints(minWidth: 44),
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: palette.bgElevated, borderRadius: BorderRadius.circular(10)),
                child: Text(currencySymbol(currency), style: money(fontSize: 14, fontWeight: FontWeight.w500, color: palette.highlighted)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currencyName(currency), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: palette.highlighted)),
                    Text(note ?? currency.code, style: TextStyle(fontSize: 13, color: palette.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? (exclusive ? LucideIcons.circleDot : LucideIcons.squareCheck) : (exclusive ? LucideIcons.circle : LucideIcons.square),
                size: 22,
                color: selected ? palette.highlighted : palette.dimmed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An item on the list: a tap opens it for editing, swiping it away removes it.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onTap, required this.onRemove});

  final TemplateItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Dismissible(
      key: ValueKey('onboarding-item-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: palette.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(LucideIcons.trash2, size: 20, color: Colors.white),
      ),
      onDismissed: (_) => onRemove(),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(item.name, style: TextStyle(fontSize: 16, color: palette.highlighted))),
              const SizedBox(width: 12),
              Text(formatMoney(item.amount, item.currency), style: money(fontSize: 15, color: palette.text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sheet that asks for an item's name and amount. It closes with the values to save, or with
/// `{remove: true}` when the item is to be removed.
class _ItemSheet extends StatefulWidget {
  const _ItemSheet({
    required this.name,
    this.amount,
    this.expression,
    required this.example,
    required this.currencies,
    required this.submitLabel,
    this.removable = false,
  });

  final String name;
  final double? amount;
  final String? expression;

  /// A name shown while the field is empty.
  final String example;

  /// The currencies the item can be in, the one it starts in first. With a single one the sheet doesn't ask.
  final List<Currency> currencies;
  final String submitLabel;
  final bool removable;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final _name = TextEditingController(text: widget.name);
  late final _amount = TextEditingController(text: amountText(widget.amount, widget.expression));
  late Currency? _currency = widget.currencies.firstOrNull;
  String? _nameError;
  String? _amountError;

  void _submit() {
    final name = _name.text.trim();
    final amount = _amount.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Dê um nome' : null;
      _amountError = amount.isEmpty ? 'Informe o valor' : (evaluateExpression(amount) == null ? 'Use um número, como 1.250,00' : null);
    });
    if (_nameError != null || _amountError != null) return;
    Navigator.of(context).pop<Json>({
      'name': name,
      'amount': evaluateExpression(amount),
      'expression': expressionOf(amount),
      // An item keeps the currency it was created in.
      if (!widget.removable) 'currency': _currency?.code,
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A name that came filled in leaves only the amount to type, so the keyboard opens on it.
    final named = widget.name.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Nome'),
        TextField(
          controller: _name,
          autofocus: !named,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(hintText: widget.example, errorText: _nameError),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Valor por mês'),
        TextField(
          controller: _amount,
          autofocus: named,
          keyboardType: amountKeyboard,
          style: money(fontSize: 17),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: amountDecoration(context, _currency, errorText: _amountError),
        ),
        if (widget.currencies.length > 1) ...[
          const SizedBox(height: 16),
          const FieldLabel('Moeda'),
          Wrap(
            spacing: 8,
            children: [
              for (final option in widget.currencies)
                ChoiceChip(
                  label: Text(option.code, style: money(fontSize: 14)),
                  tooltip: currencyName(option),
                  selected: option == _currency,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _currency = option),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
        if (widget.removable) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop<Json>({'remove': true}),
            style: TextButton.styleFrom(foregroundColor: context.palette.error),
            child: const Text('Remover'),
          ),
        ],
      ],
    );
  }
}
