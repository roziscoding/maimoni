import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light/dark choice, following the system until the person picks one.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.system);

  static final instance = ThemeController._();
  static const _key = 'theme';

  Future<void> load() async {
    try {
      final stored = (await SharedPreferences.getInstance()).getString(_key);
      if (stored != null) value = ThemeMode.values.byName(stored);
    } catch (_) {
      // Preferences unavailable: keep following the system.
    }
  }

  Future<void> toggle(Brightness current) async {
    value = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, value.name);
    } catch (_) {
      // Not persisted; the choice still applies for this session.
    }
  }
}
