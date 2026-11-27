import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/auth.dart';
import '../api/client.dart';
import '../data/repository.dart';
import '../api/models.dart';
import '../data/export_file.dart';
import '../format.dart';
import '../main.dart' show navigatorKey;
import '../routes.dart';
import '../state/app_updates.dart';
import '../state/currencies_store.dart';
import '../state/local_mode.dart';
import '../state/months_store.dart';
import '../state/session.dart';
import '../state/theme_controller.dart';
import '../state/toast.dart';
import '../theme.dart';
import '../widgets/backup_prompt.dart';
import '../widgets/common.dart';
import '../widgets/currency_settings.dart';
import '../widgets/fields.dart';
import 'login_screen.dart';

/// The account, the theme, currencies, app updates, sessions and, when the server allows it, the
/// danger zone.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// The danger zone shows without an account, and signed in when the server serves `DELETE /api/data`.
  bool _purge = LocalMode.instance.active;

  @override
  void initState() {
    super.initState();
    if (!LocalMode.instance.active) _loadFlags();
  }

  Future<void> _loadFlags() async {
    try {
      final flags = await Api.instance.flags();
      if (mounted) setState(() => _purge = flags.purge);
    } catch (_) {
      // Without an answer there is nothing to offer.
    }
  }

  Future<void> _confirmClear() async {
    final navigator = Navigator.of(context);
    final cleared = await showSheet<bool>(
      context,
      title: 'Apagar todos os dados?',
      description: 'Meses, itens e template serão apagados de vez.',
      body: (context) => const _ClearDataForm(),
    );
    if (cleared != true) return;
    await MonthsStore.instance.refresh();
    toast('Dados apagados', description: 'Meses e template voltaram ao zero.', icon: LucideIcons.trash2);
    if (navigator.mounted) openTabWith(navigator, AppTab.today);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _AccountSection(),
          const SizedBox(height: 24),
          const _ThemeSection(),
          const SizedBox(height: 24),
          const CurrencySettings(),
          const SizedBox(height: 24),
          const _UpdatesSection(),
          if (!LocalMode.instance.active) ...[
            const SizedBox(height: 24),
            const _SessionsSection(),
          ],
          if (_purge) ...[
            const SizedBox(height: 24),
            const SectionHeader('Zona de perigo'),
            Panel(
              child: ListTile(
                leading: Icon(LucideIcons.trash2, size: 20, color: palette.error),
                title: Text('Apagar todos os dados', style: TextStyle(color: palette.error)),
                subtitle: Text(LocalMode.instance.active
                    ? 'Meses e template. As moedas são mantidas. Não dá para desfazer.'
                    : 'Meses e template. Moedas e sessões são mantidas. Não dá para desfazer.'),
                onTap: _confirmClear,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Buttons that close a sheet with the value of the one tapped, the first one being the main action.
Widget _choices<T>(BuildContext context, List<({String label, T value, bool danger})> choices) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, choice) in choices.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          ActionButton(
            label: choice.label,
            danger: choice.danger,
            style: index == 0 || choice.danger ? ActionStyle.solid : ActionStyle.outline,
            onPressed: () => Navigator.of(context).pop(choice.value),
          ),
        ],
        const SizedBox(height: 4),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      ],
    );

/// Saves an export through the share sheet, with a toast when it failed.
Future<void> _export(Future<Json> Function() read) async {
  try {
    await shareExport(await read());
  } catch (err) {
    toast('Não foi possível exportar', description: errorMessage(err), tone: ToastTone.error);
  }
}

/// Who is signed in, or that there is no account, and what can be done with the data.
class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Session.instance, LocalMode.instance]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Conta'),
          Panel(child: LocalMode.instance.active ? const _LocalAccount() : const _CloudAccount()),
        ],
      ),
    );
  }
}

class _CloudAccount extends StatelessWidget {
  const _CloudAccount();

  /// Offers to keep using the app without an account, with a copy of the account's data.
  Future<void> _signOut(BuildContext context) async {
    final choice = await showSheet<String>(
      context,
      title: 'Sair da conta?',
      description: 'Você pode continuar usando o maimoni sem conta, com uma cópia dos seus dados neste aparelho. A conta continua com tudo o que tem.',
      body: (context) => _choices(context, [
        (label: 'Sair e usar sem conta', value: 'local', danger: false),
        (label: 'Só sair', value: 'out', danger: false),
      ]),
    );
    if (choice == 'out') return signOut();
    if (choice != 'local') return;
    try {
      // Read while the session still holds.
      final data = await Api.instance.exportData();
      // No navigation: the listener in MaimoniApp replaces the whole stack.
      signOut();
      await LocalMode.instance.start(data: data);
    } catch (err) {
      return toast('Não foi possível trazer seus dados', description: errorMessage(err), tone: ToastTone.error);
    }
    // The setup that asks about the backup is skipped, so the question comes here, over the new stack.
    await WidgetsBinding.instance.endOfFrame;
    final root = navigatorKey.currentContext;
    if (root != null && root.mounted) await askForBackup(root);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final user = Session.instance.user;
    return Column(
      children: [
        if (user != null) ...[
          ListTile(
            leading: const Icon(LucideIcons.circleUserRound, size: 20),
            title: Text(user.name.isEmpty ? user.email : user.name),
            subtitle: user.name.isEmpty ? null : Text(user.email),
          ),
          const RowDivider(indent: 56),
        ],
        ListTile(
          leading: Icon(LucideIcons.download, size: 20, color: palette.muted),
          title: const Text('Exportar dados'),
          subtitle: const Text('Salve uma cópia em arquivo, para guardar ou levar para outro aparelho.'),
          onTap: () => _export(Api.instance.exportData),
        ),
        const RowDivider(indent: 56),
        ListTile(
          leading: Icon(LucideIcons.logOut, size: 20, color: palette.muted),
          title: const Text('Sair'),
          onTap: () => _signOut(context),
        ),
      ],
    );
  }
}

class _LocalAccount extends StatelessWidget {
  const _LocalAccount();

  Future<void> _import(BuildContext context) async {
    final navigator = Navigator.of(context);
    final Object? data;
    try {
      data = await pickExport();
    } catch (err) {
      return toast('Não foi possível ler o arquivo', description: errorMessage(err), tone: ToastTone.error);
    }
    if (data == null || !context.mounted) return;
    final confirmed = await showSheet<bool>(
      context,
      title: 'Substituir os dados deste aparelho?',
      description: 'Os meses, o template e as moedas daqui são trocados pelos do arquivo. Não dá para desfazer.',
      body: (context) => _choices(context, [(label: 'Importar', value: true, danger: true)]),
    );
    if (confirmed != true) return;
    try {
      await LocalMode.instance.import(data);
    } catch (err) {
      return toast('Não foi possível importar', description: errorMessage(err), tone: ToastTone.error);
    }
    await Future.wait([MonthsStore.instance.refresh(), CurrenciesStore.instance.reload()]);
    toast('Dados importados', icon: LucideIcons.upload);
    if (navigator.mounted) openTabWith(navigator, AppTab.today);
  }

  /// Signing in leaves the local mode, and the data on the device goes with it.
  Future<void> _signIn(BuildContext context) async {
    final choice = await showSheet<String>(
      context,
      title: 'Entrar numa conta?',
      description: 'Os dados deste aparelho não vão para a conta. Ao entrar, eles são apagados daqui e não dá para recuperar. '
          'Para guardar uma cópia, exporte antes.',
      body: (context) => _choices(context, [
        (label: 'Exportar dados', value: 'export', danger: false),
        (label: 'Apagar dados e entrar', value: 'sign-in', danger: true),
      ]),
    );
    if (choice == 'export') return _export(LocalMode.instance.repository.export);
    if (choice != 'sign-in') return;
    // The listener in MaimoniApp swaps the stack for the welcome screen; the sign in opens above it.
    await LocalMode.instance.leave();
    navigatorKey.currentState?.push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        const ListTile(
          leading: Icon(LucideIcons.smartphone, size: 20),
          title: Text('Sem conta'),
          subtitle: Text('Seus dados ficam só neste aparelho.'),
        ),
        const RowDivider(indent: 56),
        SwitchListTile(
          secondary: Icon(LucideIcons.cloudUpload, size: 20, color: palette.muted),
          title: Text('Backup do ${Platform.isIOS ? 'iCloud' : 'Google'}'),
          subtitle: const Text('Guarda uma cópia dos dados com o backup do celular, para você não perder nada se trocar de aparelho.'),
          value: LocalMode.instance.backup,
          onChanged: (value) async {
            try {
              await LocalMode.instance.setBackup(value);
            } catch (err) {
              toast('Não foi possível mudar o backup', description: errorMessage(err), tone: ToastTone.error);
            }
          },
        ),
        const RowDivider(indent: 56),
        ListTile(
          leading: Icon(LucideIcons.download, size: 20, color: palette.muted),
          title: const Text('Exportar dados'),
          subtitle: const Text('Salve uma cópia em arquivo, para guardar ou levar para outro aparelho.'),
          onTap: () => _export(LocalMode.instance.repository.export),
        ),
        const RowDivider(indent: 56),
        ListTile(
          leading: Icon(LucideIcons.upload, size: 20, color: palette.muted),
          title: const Text('Importar dados'),
          subtitle: const Text('Traga os dados de um arquivo exportado.'),
          onTap: () => _import(context),
        ),
        const RowDivider(indent: 56),
        ListTile(
          leading: Icon(LucideIcons.logIn, size: 20, color: palette.muted),
          title: const Text('Entrar numa conta'),
          onTap: () => _signIn(context),
        ),
      ],
    );
  }
}

/// Light, dark, or whatever the phone is set to.
class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  static const _modes = [
    (mode: ThemeMode.system, label: 'Igual ao sistema', icon: LucideIcons.smartphone),
    (mode: ThemeMode.light, label: 'Claro', icon: LucideIcons.sun),
    (mode: ThemeMode.dark, label: 'Escuro', icon: LucideIcons.moon),
  ];

  void _pick(BuildContext context) {
    showSheet<void>(
      context,
      title: 'Tema',
      body: (context) => ValueListenableBuilder(
        valueListenable: ThemeController.instance,
        builder: (context, current, _) => Column(
          children: [
            for (final option in _modes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(option.icon, size: 20),
                title: Text(option.label),
                trailing: option.mode == current ? Icon(LucideIcons.check, size: 20, color: context.palette.highlighted) : null,
                onTap: () {
                  ThemeController.instance.set(option.mode);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ThemeController.instance,
      builder: (context, current, _) {
        final option = _modes.firstWhere((entry) => entry.mode == current);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Aparência'),
            Panel(
              child: ListTile(
                leading: Icon(option.icon, size: 20),
                title: const Text('Tema'),
                trailing: _Value(option.label),
                onTap: () => _pick(context),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The current value of a row that opens a choice, with the chevron that says so.
class _Value extends StatelessWidget {
  const _Value(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 15, color: palette.muted)),
        const SizedBox(width: 4),
        Icon(LucideIcons.chevronRight, size: 18, color: palette.dimmed),
      ],
    );
  }
}

/// Installed version and, on Android, the update channel and in-app download of new releases.
class _UpdatesSection extends StatelessWidget {
  const _UpdatesSection();

  void _pickChannel(BuildContext context) {
    final updates = AppUpdates.instance;
    showSheet<void>(
      context,
      title: 'Canal de atualizações',
      body: (context) => Column(
        children: [
          for (final channel in UpdateChannel.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(channel.label),
              subtitle: Text(
                channel == UpdateChannel.beta
                    ? 'Recebe as versões beta primeiro, e as estáveis quando ficam mais novas.'
                    : 'Recebe só as versões estáveis.',
              ),
              trailing: channel == updates.channel ? Icon(LucideIcons.check, size: 20, color: context.palette.highlighted) : null,
              onTap: () {
                updates.setChannel(channel);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updates = AppUpdates.instance;
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        final palette = context.palette;
        final available = updates.available;
        final progress = updates.progress;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Atualizações'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.info, size: 20),
                    title: const Text('Versão'),
                    subtitle: updates.supported ? null : const Text('No iPhone, as atualizações chegam pelo TestFlight.'),
                    trailing: Text(
                      updates.version == null ? 'desconhecida' : '${updates.version} (${updates.build})',
                      style: money(fontSize: 14, color: palette.muted),
                    ),
                  ),
                  if (updates.supported) ...[
                    const RowDivider(indent: 56),
                    ListTile(
                      leading: const Icon(LucideIcons.gitBranch, size: 20),
                      title: const Text('Canal'),
                      trailing: _Value(updates.channel.label),
                      onTap: updates.installing ? null : () => _pickChannel(context),
                    ),
                    const RowDivider(indent: 56),
                    if (available == null)
                      ListTile(
                        leading: updates.checking
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(LucideIcons.refreshCw, size: 20),
                        title: const Text('Procurar atualização'),
                        subtitle: updates.error == null ? null : Text(updates.error!, style: TextStyle(color: palette.error)),
                        onTap: updates.checking
                            ? null
                            : () async {
                                if (await updates.check() == null && updates.error == null) {
                                  toast('Você já está na versão mais nova', tone: ToastTone.success);
                                }
                              },
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Versão ${available.version} disponível',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.highlighted),
                            ),
                            if (available.notes != null && available.notes!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                available.notes!.trim(),
                                maxLines: 8,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, height: 1.4, color: palette.muted),
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (progress != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(value: progress, minHeight: 6, color: palette.bgInverted),
                              ),
                              const SizedBox(height: 6),
                              Text('Baixando… ${(progress * 100).round()}%', style: TextStyle(fontSize: 14, color: palette.muted)),
                            ] else
                              ActionButton(label: 'Baixar e instalar', icon: LucideIcons.download, onPressed: updates.install),
                            if (updates.error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(updates.error!, style: TextStyle(fontSize: 13, color: palette.error)),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Where the account is signed in, with a way to end the sessions on other devices.
class _SessionsSection extends StatefulWidget {
  const _SessionsSection();

  @override
  State<_SessionsSection> createState() => _SessionsSectionState();
}

class _SessionsSectionState extends State<_SessionsSection> {
  static const _others = 'others';

  List<SessionEntry>? _sessions;
  String? _error;

  /// ID of the session being ended, or [_others] for all but the current one.
  String? _ending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _sessions = await Api.instance.sessions();
      _error = null;
    } catch (err) {
      _error = errorMessage(err);
    }
    if (mounted) setState(() {});
  }

  Future<void> _end([String? id]) async {
    setState(() => _ending = id ?? _others);
    try {
      await (id == null ? Api.instance.endOtherSessions() : Api.instance.endSession(id));
      toast(id == null ? 'Outras sessões encerradas' : 'Sessão encerrada', tone: ToastTone.success);
    } catch (err) {
      toast('Não foi possível encerrar', description: errorMessage(err), tone: ToastTone.error);
    }
    await _load();
    if (mounted) setState(() => _ending = null);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sessions = _sessions;
    final Widget body;
    if (sessions == null && _error == null) {
      body = const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    } else if (sessions == null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Não foi possível carregar as sessões: $_error', style: TextStyle(fontSize: 14, color: palette.error)),
      );
    } else {
      body = Column(
        children: [
          for (final (index, session) in sessions.indexed) ...[
            if (index > 0) const RowDivider(),
            ListTile(
              contentPadding: const EdgeInsets.only(left: 16, right: 8),
              title: Text(session.current ? '${deviceLabel(session.userAgent)} · esta sessão' : deviceLabel(session.userAgent)),
              subtitle: Text([
                'Entrou em ${formatDateTime(session.createdAt)}',
                if (session.ipAddress != null && session.ipAddress!.isNotEmpty) session.ipAddress!,
              ].join(' · ')),
              trailing: session.current
                  ? null
                  : _ending == session.id
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : TextButton(onPressed: _ending == null ? () => _end(session.id) : null, child: const Text('Encerrar')),
            ),
          ],
          if (sessions.length > 1) ...[
            const RowDivider(),
            ListTile(
              leading: _ending == _others
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(LucideIcons.logOut, size: 20, color: palette.error),
              title: Text('Encerrar todas as outras', style: TextStyle(color: palette.error)),
              onTap: _ending == null ? _end : null,
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Sessões'),
        Panel(child: body),
      ],
    );
  }
}

/// The body of the sheet that clears everything: the word to type, then the button.
class _ClearDataForm extends StatefulWidget {
  const _ClearDataForm();

  @override
  State<_ClearDataForm> createState() => _ClearDataFormState();
}

class _ClearDataFormState extends State<_ClearDataForm> {
  static const _confirmation = 'apagar';
  final _input = TextEditingController();
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  Future<void> _clear() async {
    // The keyboard's done key can submit again while the request is in flight.
    if (_clearing) return;
    setState(() => _clearing = true);
    try {
      await repository.clearData();
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      toast('Não foi possível apagar os dados', description: errorMessage(err), tone: ToastTone.error);
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = _input.text.trim().toLowerCase() == _confirmation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Digite "$_confirmation" para confirmar'),
        TextField(
          controller: _input,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => confirmed ? _clear() : null,
        ),
        const SizedBox(height: 20),
        ActionButton(
          label: 'Apagar tudo',
          icon: LucideIcons.trash2,
          danger: true,
          loading: _clearing,
          onPressed: confirmed ? _clear : null,
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
      ],
    );
  }
}
