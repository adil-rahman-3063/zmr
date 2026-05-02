import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'music_provider.dart';

class ZmrSettings {
  final double crossfadeSeconds;
  final bool gaplessPlayback;
  final bool normalizeVolume;
  final ThemeMode themeMode;
  final bool amoledMode;

  ZmrSettings({
    this.crossfadeSeconds = 0,
    this.gaplessPlayback = true,
    this.normalizeVolume = false,
    this.themeMode = ThemeMode.system,
    this.amoledMode = false,
  });

  ZmrSettings copyWith({
    double? crossfadeSeconds,
    bool? gaplessPlayback,
    bool? normalizeVolume,
    ThemeMode? themeMode,
    bool? amoledMode,
  }) {
    return ZmrSettings(
      crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      normalizeVolume: normalizeVolume ?? this.normalizeVolume,
      themeMode: themeMode ?? this.themeMode,
      amoledMode: amoledMode ?? this.amoledMode,
    );
  }
}

class SettingsNotifier extends Notifier<ZmrSettings> {
  static const _keyCrossfade = 'settings_crossfade';
  static const _keyGapless = 'settings_gapless';
  static const _keyNormalize = 'settings_normalize';
  static const _keyTheme = 'settings_theme';
  static const _keyAmoled = 'settings_amoled';

  @override
  ZmrSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    
    return ZmrSettings(
      crossfadeSeconds: prefs.getDouble(_keyCrossfade) ?? 0,
      gaplessPlayback: prefs.getBool(_keyGapless) ?? true,
      normalizeVolume: prefs.getBool(_keyNormalize) ?? false,
      themeMode: _parseThemeMode(prefs.getString(_keyTheme)),
      amoledMode: prefs.getBool(_keyAmoled) ?? false,
    );
  }

  ThemeMode _parseThemeMode(String? value) {
    if (value == 'dark') return ThemeMode.dark;
    if (value == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  void setCrossfade(double seconds) {
    state = state.copyWith(crossfadeSeconds: seconds);
    ref.read(sharedPreferencesProvider).setDouble(_keyCrossfade, seconds);
  }

  void setGapless(bool value) {
    state = state.copyWith(gaplessPlayback: value);
    ref.read(sharedPreferencesProvider).setBool(_keyGapless, value);
  }

  void setNormalize(bool value) {
    state = state.copyWith(normalizeVolume: value);
    ref.read(sharedPreferencesProvider).setBool(_keyNormalize, value);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    ref.read(sharedPreferencesProvider).setString(_keyTheme, mode.name);
  }

  void setAmoled(bool value) {
    state = state.copyWith(amoledMode: value);
    ref.read(sharedPreferencesProvider).setBool(_keyAmoled, value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, ZmrSettings>(SettingsNotifier.new);
