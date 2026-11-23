import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/auth.dart';
import '../api/client.dart';
import '../api/models.dart';
import '../format.dart';
import '../routes.dart';
import '../state/app_updates.dart';
import '../state/months_store.dart';
import '../state/session.dart';
import '../state/theme_controller.dart';
import '../state/toast.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/currency_settings.dart';
import '../widgets/fields.dart';

/// The account, the theme, currencies, app updates, sessions and, when the server allows it, the
/// danger zone.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// The danger zone only shows when the server serves `DELETE /api/data`.
  bool _purge = false;

  @override
  void initState() {
    super.initState();
    _loadFlags();
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
          const SizedBox(height: 24),
          const _SessionsSection(),
          if (_purge) ...[
            const SizedBox(height: 24),
            const SectionHeader('Zona de perigo'),
            Panel(
              child: ListTile(
                leading: Icon(LucideIcons.trash2, size: 20, color: palette.error),
                title: Text('Apagar todos os dados', style: TextStyle(color: palette.error)),
                subtitle: const Text('Meses e template. Moedas e sessões são mantidas. Não dá para desfazer.'),
                onTap: _confirmClear,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Who is signed in, and the way out.
class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) {
        final user = Session.instance.user;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Conta'),
            Panel(
              child: Column(
                children: [
                  if (user != null) ...[
                    ListTile(
                      leading: const Icon(LucideIcons.circleUserRound, size: 20),
                      title: Text(user.name.isEmpty ? user.email : user.name),
                      subtitle: user.name.isEmpty ? null : Text(user.email),
                    ),
                    const RowDivider(indent: 56),
                  ],
                  // No navigation: the session listener in MaimoniApp replaces the whole stack.
                  ListTile(
                    leading: Icon(LucideIcons.logOut, size: 20, color: palette.muted),
                    title: const Text('Sair'),
                    onTap: signOut,
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
    setState(() => _clearing = true);
    try {
      await Api.instance.clearData();
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
