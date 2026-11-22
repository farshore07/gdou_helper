import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefThemeModeKey = 'app_theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  bool _userUpdated = false;

  @override
  ThemeMode build() {
    Future.microtask(_loadSaved);
    return ThemeMode.system;
  }

  Future<void> _loadSaved() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (!ref.mounted || _userUpdated) return;
      final saved = sp.getString(_prefThemeModeKey);
      if (saved == null) return;
      state = _decodeThemeMode(saved);
    } catch (e) {
      debugPrint('加载主题设置失败: $e');
    }
  }

  Future<void> setDarkMode(bool enabled) =>
      setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);

  Future<void> setThemeMode(ThemeMode mode) async {
    _userUpdated = true;
    state = mode;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_prefThemeModeKey, _encodeThemeMode(mode));
    } catch (e) {
      debugPrint('保存主题设置失败: $e');
    }
  }

  static String _encodeThemeMode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  static ThemeMode _decodeThemeMode(String raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
