import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/client.dart';
import '../format.dart';
import '../routes.dart';
import '../state/months_store.dart';
import '../state/toast.dart';
import '../theme.dart';
import 'common.dart';

/// Creates [year]/[month] from the template or the previous month, then opens it.
Future<bool> createMonth(BuildContext context, int year, int month, String source) async {
  try {
    await Api.instance.createMonth(year, month, source);
    await MonthsStore.instance.refresh();
    if (context.mounted) navigate(context, monthRoute(year, month));
    return true;
  } catch (err) {
    toast('Não foi possível criar o mês', description: errorMessage(err), tone: ToastTone.error);
    return false;
  }
}

/// Port of `MonthCreate.vue`: shown where a month that doesn't exist yet was expected.
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

  Future<void> _create(String source) async {
    setState(() => _pending = source);
    final created = await createMonth(context, widget.year, widget.month, source);
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

/// Port of `NewMonthModal.vue`, as a bottom sheet.
Future<void> showNewMonthSheet(BuildContext context) {
  return showSheet(
    context,
    title: 'Novo mês',
    description: 'Escolha o mês e de onde vêm os itens.',
    body: (context) => const _NewMonthForm(),
  );
}

class _NewMonthForm extends StatefulWidget {
  const _NewMonthForm();

  @override
  State<_NewMonthForm> createState() => _NewMonthFormState();
}

class _NewMonthFormState extends State<_NewMonthForm> {
  late int _year;
  late int _month;
  String _source = 'template';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Suggest the first month from now on that doesn't exist yet.
    final store = MonthsStore.instance;
    final now = DateTime.now();
    var index = now.year * 12 + now.month - 1;
    while (store.exists(index ~/ 12, index % 12 + 1)) {
      index++;
    }
    _year = index ~/ 12;
    _month = index % 12 + 1;
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    try {
      await Api.instance.createMonth(_year, _month, _source);
      await MonthsStore.instance.refresh();
      navigator.pop();
      navigateWith(navigator, monthRoute(_year, _month));
    } catch (err) {
      toast('Não foi possível criar o mês', description: errorMessage(err), tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final taken = MonthsStore.instance.exists(_year, _month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mês', style: TextStyle(fontWeight: FontWeight.w500, color: palette.text)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: _month,
                    items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(monthName(m)))],
                    onChanged: (value) => setState(() => _month = value ?? _month),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ano', style: TextStyle(fontWeight: FontWeight.w500, color: palette.text)),
                  const SizedBox(height: 6),
                  _Stepper(
                    value: _year,
                    onChanged: (value) => setState(() => _year = value.clamp(2000, 2100)),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (taken) ...[
          const SizedBox(height: 16),
          Callout(
            icon: LucideIcons.calendarX,
            title: '${monthLabel(_year, _month)} já existe',
            action: OutlinedButton(
              onPressed: () {
                final navigator = Navigator.of(context)..pop();
                navigateWith(navigator, monthRoute(_year, _month));
              },
              child: const Text('Abrir'),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text('Itens', style: TextStyle(fontWeight: FontWeight.w500, color: palette.text)),
        const SizedBox(height: 6),
        for (final option in const [
          (value: 'template', label: 'Template', description: 'Valores fixos de sempre; os variáveis chegam para confirmar.'),
          (value: 'previous', label: 'Mês anterior', description: 'Copia os itens do último mês antes deste, como estão.'),
        ])
          _Choice(
            label: option.label,
            description: option.description,
            selected: _source == option.value,
            first: option.value == 'template',
            onTap: () => setState(() => _source = option.value),
          ),
        SheetActions(
          primary: ActionButton(
            label: 'Criar mês',
            icon: LucideIcons.calendarPlus,
            loading: _saving,
            onPressed: taken ? null : _submit,
          ),
        ),
      ],
    );
  }
}

/// Year field with − and + buttons.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: palette.bgElevated,
        border: Border.all(color: palette.borderAccented),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(LucideIcons.minus, size: 16), onPressed: () => onChanged(value - 1)),
          Expanded(child: Text('$value', textAlign: TextAlign.center, style: money(fontSize: 15, color: palette.text))),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(LucideIcons.plus, size: 16), onPressed: () => onChanged(value + 1)),
        ],
      ),
    );
  }
}

/// One row of a `URadioGroup variant="table"`.
class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.description, required this.selected, required this.first, required this.onTap});

  final String label;
  final String description;
  final bool selected;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final primary = Theme.of(context).colorScheme.primary;
    final radius = BorderRadius.vertical(
      top: first ? const Radius.circular(8) : Radius.zero,
      bottom: first ? Radius.zero : const Radius.circular(8),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? palette.bgElevated : null,
          borderRadius: radius,
          border: Border.all(color: selected ? palette.borderAccented : palette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(top: 1, right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? primary : palette.borderAccented, width: selected ? 5 : 1.5),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: palette.highlighted)),
                  Text(description, style: TextStyle(fontSize: 13, color: palette.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
