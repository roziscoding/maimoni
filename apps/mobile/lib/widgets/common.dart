import 'package:flutter/material.dart';

import '../theme.dart';

/// `UEmpty variant="naked"`: an icon, a title, a description and optional actions, centered.
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
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: palette.bgElevated, borderRadius: BorderRadius.circular(999)),
            child: Icon(icon, size: 24, color: palette.muted),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.highlighted),
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: palette.muted)),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: actions),
          ],
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

/// `UBadge`: a small pill, subtle (tinted fill) or outline.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.icon, this.tone = Tone.neutral, this.outline = false});

  final String label;
  final IconData? icon;
  final Tone tone;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = tone.color(palette);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: outline ? null : (tone == Tone.neutral ? palette.bgElevated : color.withValues(alpha: 0.12)),
        border: Border.all(color: outline ? palette.borderAccented : (tone == Tone.neutral ? palette.borderAccented : color.withValues(alpha: 0.25))),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}

/// `UAlert variant="subtle"`.
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: color)),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(description!, style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.85))),
                  ),
                if (action != null) Padding(padding: const EdgeInsets.only(top: 8), child: action),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A bordered, rounded block (`rounded-xl border border-default`).
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = EdgeInsets.zero, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.bg,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

/// Header row of a [Panel]: a title with an optional currency tag and a trailing widget.
class PanelHeader extends StatelessWidget {
  const PanelHeader({super.key, required this.title, this.tag, this.subtitle, this.trailing});

  final String title;
  final String? tag;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.highlighted)),
                    if (tag != null) ...[const SizedBox(width: 8), Text(tag!, style: money(fontSize: 12, color: palette.muted))],
                  ],
                ),
                if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: palette.muted)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small muted heading (`text-xs font-medium text-muted`) with an optional trailing figure.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.label, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 4)});

  final String label;
  final String? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: palette.muted))),
          if (trailing != null) Text(trailing!, style: money(fontSize: 12, color: palette.toned)),
        ],
      ),
    );
  }
}

/// Two-option segmented control (`UFieldGroup` of solid/outline buttons).
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.value, required this.options, required this.onChanged, this.expand = false, this.small = false});

  final T value;
  final List<({T value, String label, IconData? icon})> options;
  final ValueChanged<T> onChanged;
  final bool expand;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (var index = 0; index < options.length; index++) {
      final option = options[index];
      final selected = option.value == value;
      final radius = BorderRadius.horizontal(
        left: index == 0 ? const Radius.circular(8) : Radius.zero,
        right: index == options.length - 1 ? const Radius.circular(8) : Radius.zero,
      );
      final button = Material(
        color: selected ? theme.primary : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: selected ? theme.primary : palette.borderAccented)),
        child: InkWell(
          borderRadius: radius,
          onTap: selected ? null : () => onChanged(option.value),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: small ? 10 : 14, vertical: small ? 5 : 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 16, color: selected ? theme.onPrimary : palette.text),
                  const SizedBox(width: 6),
                ],
                Text(
                  option.label,
                  style: TextStyle(
                    fontSize: small ? 12 : 14,
                    fontWeight: FontWeight.w500,
                    color: selected ? theme.onPrimary : palette.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      children.add(expand ? Expanded(child: button) : button);
    }
    return Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: children);
  }
}

/// Bottom sheet scaffold used for the web's modals: title, description, body and footer buttons.
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: palette.highlighted)),
              if (description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(description, style: TextStyle(fontSize: 14, color: palette.muted)),
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

/// Right-aligned footer of a sheet: cancel plus the primary action.
class SheetActions extends StatelessWidget {
  const SheetActions({super.key, required this.primary, this.cancelLabel = 'Cancelar'});

  final Widget primary;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text(cancelLabel)),
          const SizedBox(width: 8),
          primary,
        ],
      ),
    );
  }
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
          backgroundColor: danger ? palette.error.withValues(alpha: 0.1) : palette.bgElevated,
          foregroundColor: danger ? palette.error : palette.text,
          side: BorderSide(color: danger ? palette.error.withValues(alpha: 0.25) : palette.borderAccented),
        );
        return leading == null
            ? FilledButton(onPressed: onTap, style: buttonStyle, child: child)
            : FilledButton.icon(onPressed: onTap, style: buttonStyle, icon: leading, label: child);
    }
  }
}

enum ActionStyle { solid, outline, subtle }
