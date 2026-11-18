import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../format.dart';
import '../routes.dart';
import '../state/app_updates.dart';
import '../state/months_store.dart';
import '../state/toast.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

/// Port of `pages/settings.vue`: app updates, sessions and the danger zone.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _confirmClear() async {
    final cleared = await showDialog<bool>(context: context, builder: (context) => const _ClearDataDialog());
    if (cleared != true || !mounted) return;
    await MonthsStore.instance.refresh();
    toast('Dados apagados', description: 'Meses e template voltaram ao zero.', icon: LucideIcons.trash2);
    if (mounted) navigate(context, todayRoute);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
        children: [
          const _UpdatesSection(),
          const SizedBox(height: 48),
          const _SessionsSection(),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.error.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Zona de perigo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.error)),
                const SizedBox(height: 4),
                Text(
                  'Apaga todos os meses e o template. Não dá para desfazer.',
                  style: TextStyle(fontSize: 14, color: palette.muted),
                ),
                const SizedBox(height: 12),
                ActionButton(
                  label: 'Apagar todos os dados',
                  icon: LucideIcons.trash2,
                  style: ActionStyle.subtle,
                  danger: true,
                  onPressed: _confirmClear,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Installed version and, on Android, the update channel and in-app download of new releases.
class _UpdatesSection extends StatelessWidget {
  const _UpdatesSection();

  @override
  Widget build(BuildContext context) {
    final updates = AppUpdates.instance;
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        final palette = context.palette;
        final muted = TextStyle(fontSize: 14, color: palette.muted);
        final available = updates.available;
        final progress = updates.progress;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Atualizações', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.text)),
            const SizedBox(height: 2),
            Text(
              updates.version == null ? 'Versão desconhecida.' : 'Versão ${updates.version} (${updates.build}).',
              style: muted,
            ),
            if (!updates.supported) ...[
              const SizedBox(height: 4),
              Text('No iPhone, as atualizações chegam pelo TestFlight.', style: muted),
            ] else ...[
              const SizedBox(height: 12),
              Segmented<UpdateChannel>(
                value: updates.channel,
                options: [for (final channel in UpdateChannel.values) (value: channel, label: channel.label, icon: null)],
                onChanged: updates.installing ? (_) {} : updates.setChannel,
              ),
              const SizedBox(height: 6),
              Text(
                updates.channel == UpdateChannel.beta
                    ? 'Recebe as versões beta primeiro, e as estáveis quando ficam mais novas.'
                    : 'Recebe só as versões estáveis.',
                style: muted,
              ),
              const SizedBox(height: 16),
              if (available != null)
                Panel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Versão ${available.version} disponível',
                        style: TextStyle(fontWeight: FontWeight.w600, color: palette.highlighted),
                      ),
                      if (available.notes != null && available.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(available.notes!.trim(), maxLines: 8, overflow: TextOverflow.ellipsis, style: muted),
                      ],
                      const SizedBox(height: 12),
                      if (progress != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(value: progress, minHeight: 6, color: palette.bgInverted),
                        ),
                        const SizedBox(height: 6),
                        Text('Baixando… ${(progress * 100).round()}%', style: muted),
                      ] else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ActionButton(label: 'Baixar e instalar', icon: LucideIcons.download, onPressed: updates.install),
                        ),
                    ],
                  ),
                )
              else
                ActionButton(
                  label: 'Procurar atualização',
                  icon: LucideIcons.refreshCw,
                  style: ActionStyle.subtle,
                  loading: updates.checking,
                  onPressed: () async {
                    if (await updates.check() == null && updates.error == null) {
                      toast('Você já está na versão mais nova', tone: ToastTone.success);
                    }
                  },
                ),
              if (updates.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(updates.error!, style: TextStyle(fontSize: 13, color: palette.error)),
                ),
            ],
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
    final muted = TextStyle(fontSize: 14, color: palette.muted);
    final sessions = _sessions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sessões', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.text)),
        const SizedBox(height: 2),
        Text('Onde sua conta está conectada. Encerre as que você não reconhece ou não usa mais.', style: muted),
        const SizedBox(height: 12),
        if (sessions == null && _error == null)
          const Center(child: CircularProgressIndicator())
        else if (sessions == null)
          Text('Não foi possível carregar as sessões: $_error', style: TextStyle(fontSize: 14, color: palette.error))
        else ...[
          Panel(
            child: Column(
              children: [
                for (final (index, session) in sessions.indexed)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    decoration: index == 0 ? null : BoxDecoration(border: Border(top: BorderSide(color: palette.border))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.current ? '${deviceLabel(session.userAgent)} · esta sessão' : deviceLabel(session.userAgent),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.highlighted),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  'Entrou em ${formatDateTime(session.createdAt)}',
                                  if (session.ipAddress != null && session.ipAddress!.isNotEmpty) session.ipAddress!,
                                ].join(' · '),
                                style: muted,
                              ),
                            ],
                          ),
                        ),
                        if (!session.current) ...[
                          const SizedBox(width: 12),
                          ActionButton(
                            label: 'Encerrar',
                            style: ActionStyle.subtle,
                            loading: _ending == session.id,
                            onPressed: _ending == null ? () => _end(session.id) : null,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (sessions.length > 1) ...[
            const SizedBox(height: 12),
            ActionButton(
              label: 'Encerrar todas as outras',
              icon: LucideIcons.logOut,
              style: ActionStyle.outline,
              loading: _ending == _others,
              onPressed: _ending == null ? _end : null,
            ),
          ],
        ],
      ],
    );
  }
}

class _ClearDataDialog extends StatefulWidget {
  const _ClearDataDialog();

  @override
  State<_ClearDataDialog> createState() => _ClearDataDialogState();
}

class _ClearDataDialogState extends State<_ClearDataDialog> {
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
    final confirmed = _input.text == _confirmation;
    return AlertDialog(
      title: const Text('Apagar todos os dados?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Meses, itens e template serão apagados de vez.'),
          const SizedBox(height: 16),
          const FieldLabel('Digite "$_confirmation" para confirmar'),
          TextField(
            controller: _input,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => confirmed ? _clear() : null,
          ),
        ],
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        ActionButton(
          label: 'Apagar tudo',
          icon: LucideIcons.trash2,
          danger: true,
          loading: _clearing,
          onPressed: confirmed ? _clear : null,
        ),
      ],
    );
  }
}
