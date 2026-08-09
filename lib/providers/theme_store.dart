import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ThemeModePreference {
  dark,
  light,
  system,
}

class ThemeStore extends Notifier<ThemeModePreference> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'theme_mode';

  @override
  ThemeModePreference build() => ThemeModePreference.dark;

  Future<void> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null) {
        state = ThemeModePreference.values.firstWhere(
          (e) => e.name == raw,
          orElse: () => ThemeModePreference.dark,
        );
      }
    } catch (_) {}
  }

  Future<void> setMode(ThemeModePreference mode) async {
    state = mode;
    try {
      await _storage.write(key: _key, value: mode.name);
    } catch (_) {}
  }
}

final themeStoreProvider =
    NotifierProvider<ThemeStore, ThemeModePreference>(ThemeStore.new);

ThemeMode themeModeFromPreference(ThemeModePreference p) {
  switch (p) {
    case ThemeModePreference.light:
      return ThemeMode.light;
    case ThemeModePreference.system:
      return ThemeMode.system;
    case ThemeModePreference.dark:
      return ThemeMode.dark;
  }
}
