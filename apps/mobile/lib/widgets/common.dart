import 'package:flutter/material.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../routes.dart';
import '../theme.dart';

/// An icon, a title, a description and optional actions, centered: what a screen shows in place of
/// content it doesn't have.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.description, this.actions = const []});

  final IconData icon;
  final String title;
  final String? description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: palette.bgElevated, shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: palette.muted),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: palette.highlighted),
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description!, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: palette.muted)),
          ],
          if (actions.isNotEmpty) const SizedBox(height: 24),
          // One under the other, each as wide as the screen allows.
          for (final (index, action) in actions.indexed) Padding(padding: EdgeInsets.only(top: index == 0 ? 0 : 8), child: action),
        ],
      ),
    );
  }
}

enum Tone { neutral, success, error, warning }

extension ToneColor on Tone {
  Color color(Palette palette) => switch (this) {
        Tone.neutral => palette.toned,
        Tone.success => palette.success,
        Tone.error => palette.error,
        Tone.warning => palette.warning,
      };
}

/// A small tinted pill.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.icon, this.tone = Tone.neutral});

  final String label;
  final IconData? icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = tone.color(palette);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone == Tone.neutral ? palette.bgAccented : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// A tinted notice with an icon, a title, a description and optionally one action.
class Callout extends StatelessWidget {
  const Callout({super.key, required this.icon, required this.title, this.description, this.tone = Tone.warning, this.action});

  final IconData icon;
  final String title;
  final String? description;
  final Tone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = tone.color(palette);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: color)),
                    if (description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(description!, style: TextStyle(fontSize: 14, color: color.withValues(alpha: 0.85))),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 12), child: action),
        ],
      ),
    );
  }
}

/// Shown where something would be added: nothing can be without a currency to add it in.
class NoCurrenciesCallout extends StatelessWidget {
  const NoCurrenciesCallout({super.key});

  @override
  Widget build(BuildContext context) {
    return Callout(
      icon: LucideIcons.coins,
      title: 'Nenhuma moeda ativa',
      description: 'Itens e gastos são registrados em uma moeda. Adicione uma moeda nos ajustes para começar.',
      action: OutlinedButton(onPressed: () => openTab(context, AppTab.settings), child: const Text('Abrir ajustes')),
    );
  }
}

/// A filled, rounded group of rows. A [Material], so the rows inside it show their ink.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = EdgeInsets.zero, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? context.palette.bgElevated,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// The heading over a [Panel]: a title, an optional tag in the mono face, and a trailing widget.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.tag, this.trailing});

  final String title;
  final String? tag;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.muted),
                  ),
                ),
                if (tag != null) ...[const SizedBox(width: 8), Text(tag!, style: money(fontSize: 12, color: palette.dimmed))],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Small muted label inside a [Panel], over a run of rows, with an optional trailing figure.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.label, {super.key, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.muted))),
          if (trailing != null) Text(trailing!, style: money(fontSize: 13, color: palette.toned)),
        ],
      ),
    );
  }
}

/// A label and the figure it names, as one row of a [Panel].
class FigureRow extends StatelessWidget {
  const FigureRow({super.key, required this.label, required this.value, this.strong = false, this.color});

  final String label;
  final String value;

  /// For the figure the rows above add up to.
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: strong ? palette.highlighted : palette.toned))),
          const SizedBox(width: 12),
          Text(
            value,
            style: money(fontSize: strong ? 17 : 15, fontWeight: strong ? FontWeight.w600 : null, color: color ?? (strong ? palette.highlighted : palette.text)),
          ),
        ],
      ),
    );
  }
}

/// The line between two rows of a [Panel], starting where their text does.
class RowDivider extends StatelessWidget {
  const RowDivider({super.key, this.indent = 16});

  final double indent;

  @override
  Widget build(BuildContext context) => Divider(height: 1, indent: indent);
}

/// A segmented control: one of a few options, all visible.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.value, required this.options, required this.onChanged});

  final T value;
  final List<({T value, String label, IconData? icon})> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: palette.bgElevated, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Material(
                color: option.value == value ? palette.bg : Colors.transparent,
                elevation: option.value == value ? 1 : 0,
                shadowColor: Colors.black38,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: option.value == value ? null : () => onChanged(option.value),
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (option.icon != null) ...[
                          Icon(option.icon, size: 16, color: option.value == value ? palette.highlighted : palette.muted),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: option.value == value ? palette.highlighted : palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A bottom sheet with a title, an optional description and a body. It grows with its content,
/// scrolls when that is taller than the screen, and stays above the keyboard.
Future<T?> showSheet<T>(
  BuildContext context, {
  required String title,
  String? description,
  required WidgetBuilder body,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final palette = context.palette;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: palette.highlighted)),
              if (description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(description, style: TextStyle(fontSize: 15, height: 1.4, color: palette.muted)),
                ),
              const SizedBox(height: 20),
              body(context),
            ],
          ),
        ),
      );
    },
  );
}

/// Asks before doing something: a sheet with the action as a full-width button and a way out under
/// it. Answers whether the action was confirmed.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  String? message,
  Widget? body,
  required String confirmLabel,
  IconData? icon,
  bool danger = false,
}) async {
  final confirmed = await showSheet<bool>(
    context,
    title: title,
    description: message,
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (body != null) ...[body, const SizedBox(height: 20)],
        ActionButton(label: confirmLabel, icon: icon, danger: danger, onPressed: () => Navigator.of(context).pop(true)),
        const SizedBox(height: 4),
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A button that shows a spinner in place of its icon while [loading].
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.style = ActionStyle.solid,
    this.danger = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final ActionStyle style;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = switch (style) {
      ActionStyle.solid => danger ? Colors.white : Theme.of(context).colorScheme.onPrimary,
      _ => danger ? palette.error : palette.text,
    };
    final Widget? leading = loading
        ? SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: foreground))
        : icon == null
            ? null
            : Icon(icon, size: 18);
    final child = Text(label);
    final onTap = loading ? null : onPressed;
    switch (style) {
      case ActionStyle.solid:
        final buttonStyle = danger ? FilledButton.styleFrom(backgroundColor: palette.error, foregroundColor: Colors.white) : null;
        return leading == null
            ? FilledButton(onPressed: onTap, style: buttonStyle, child: child)
            : FilledButton.icon(onPressed: onTap, style: buttonStyle, icon: leading, label: child);
      case ActionStyle.outline:
        final buttonStyle = danger ? OutlinedButton.styleFrom(foregroundColor: palette.error, side: BorderSide(color: palette.error.withValues(alpha: 0.5))) : null;
        return leading == null
            ? OutlinedButton(onPressed: onTap, style: buttonStyle, child: child)
            : OutlinedButton.icon(onPressed: onTap, style: buttonStyle, icon: leading, label: child);
      case ActionStyle.subtle:
        final buttonStyle = FilledButton.styleFrom(
          backgroundColor: danger ? palette.error.withValues(alpha: 0.12) : palette.bgAccented,
          foregroundColor: danger ? palette.error : palette.text,
        );
        return leading == null
            ? FilledButton(onPressed: onTap, style: buttonStyle, child: child)
            : FilledButton.icon(onPressed: onTap, style: buttonStyle, icon: leading, label: child);
    }
  }
}

enum ActionStyle { solid, outline, subtle }

/// The screen's main action, floating over its content. Without a hero: the shell keeps several
/// screens (and so several of these) in one route.
class AppFab extends StatelessWidget {
  const AppFab({super.key, required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(heroTag: null, onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label));
  }
}

/// A row of a sheet that does something: an icon, a label and optionally a line under it.
class SheetAction extends StatelessWidget {
  const SheetAction({super.key, required this.icon, required this.label, this.subtitle, this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final String? subtitle;

  /// Null when the action can't be taken; [subtitle] then says why.
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = danger && onTap != null ? palette.error : null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: onTap != null,
      leading: Icon(icon, size: 20, color: color ?? (onTap == null ? palette.dimmed : palette.muted)),
      title: Text(label, style: color == null ? null : TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: onTap,
    );
  }
}
