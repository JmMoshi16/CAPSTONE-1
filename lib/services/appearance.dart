import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark / follow the phone, chosen in Profile > Appearance and remembered on this phone.
class Appearance {
  static const _key = 'theme_mode';
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      mode.value = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    } catch (_) {}
  }

  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, m.name);
    } catch (_) {}
  }

  static String label(ThemeMode m) => switch (m) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'Same as phone',
      };
}
