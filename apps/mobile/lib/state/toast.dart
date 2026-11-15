import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();

enum ToastTone { neutral, success, error }

/// The web's `toast.add`: a title, an optional description, and optionally one action.
void toast(
  String title, {
  String? description,
  ToastTone tone = ToastTone.neutral,
  IconData? icon,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = messengerKey.currentState;
  final context = messengerKey.currentContext;
  if (messenger == null || context == null) return;
  final palette = context.palette;
  final color = switch (tone) {
    ToastTone.neutral => palette.highlighted,
    ToastTone.success => palette.success,
    ToastTone.error => palette.error,
  };
  final glyph = icon ??
      switch (tone) {
        ToastTone.neutral => null,
        ToastTone.success => LucideIcons.check,
        ToastTone.error => LucideIcons.circleAlert,
      };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: duration,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (glyph != null) Padding(padding: const EdgeInsets.only(right: 10, top: 1), child: Icon(glyph, size: 18, color: color)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: palette.highlighted)),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(description, style: TextStyle(color: palette.muted, fontSize: 13)),
                  ),
              ],
            ),
          ),
        ],
      ),
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ));
}
