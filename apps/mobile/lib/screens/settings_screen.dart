import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../routes.dart';
import '../state/app_updates.dart';
import '../state/months_store.dart';
import '../state/toast.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

/// Port of `pages/settings.vue`: the fallback Wise fee and the danger zone.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Settings? _settings;
  double? _wiseFee;
  ApiException? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _settings = (await Api.instance.template()).settings;
      _wiseFee = _settings!.wiseFee;
      _error = null;
    } on ApiException catch (err) {
      _error = err;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final fee = _wiseFee;
    if (fee == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      _settings = await Api.instance.updateSettings({'wiseFee': fee});
      toast('Configurações salvas', tone: ToastTone.success);
    } catch (err) {
      toast('Não foi possível salvar', description: errorMessage(err), tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmClear() async {
    final cleared = await showDialog<bool>(context: context, builder: (context) => const _ClearDataDialog());
    if (cleared != true || !mounted) return;
    await MonthsStore.instance.refresh();
    toast('Dados apagados', description: 'Meses, template e configurações voltaram ao zero.', icon: LucideIcons.trash2);
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
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_settings != null) ...[
            Text('Taxa Wise de reserva', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: palette.text)),
            const SizedBox(height: 2),
            Text(
              'Os meses usam a taxa real cotada pela Wise para o valor enviado. Esta só entra quando a Wise não responde.',
              style: TextStyle(fontSize: 14, color: palette.muted),
            ),
            const SizedBox(height: 8),
            SizedBox(width: 160, child: PercentField(value: _wiseFee, onCommit: (value) => setState(() => _wiseFee = value))),
            const SizedBox(height: 24),
            Align(alignment: Alignment.centerLeft, child: ActionButton(label: 'Salvar', loading: _saving, onPressed: _save)),
          ] else
            EmptyState(
              icon: LucideIcons.cloudOff,
              title: 'Não foi possível carregar as configurações',
              description: _error?.message,
              actions: [ActionButton(label: 'Tentar de novo', icon: LucideIcons.refreshCw, style: ActionStyle.subtle, onPressed: _load)],
            ),
          const SizedBox(height: 48),
          const _UpdatesSection(),
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
                  'Apaga todos os meses, o template, as configurações e o histórico de cotações. Não dá para desfazer.',
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
          const Text('Meses, itens, template, configurações e cotações salvas serão apagados de vez.'),
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
