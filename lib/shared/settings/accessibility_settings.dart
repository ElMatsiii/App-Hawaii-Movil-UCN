import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'settings.themeMode';
const _fontScaleKey = 'settings.fontScale';
const _colorBlindModeKey = 'settings.colorBlindMode';
const _seedColorKey = 'settings.seedColor';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main.');
});

final accessibilitySettingsProvider =
    StateNotifierProvider<AccessibilitySettingsNotifier, AccessibilitySettings>(
  (ref) => AccessibilitySettingsNotifier(ref.watch(sharedPreferencesProvider)),
);

/// Color seed por defecto (azul UCN).
const int kDefaultSeedColor = 0xFF005CBB;

class AccessibilitySettings {
  const AccessibilitySettings({
    required this.themeMode,
    required this.fontScale,
    required this.colorBlindMode,
    required this.seedColor,
  });

  final ThemeMode themeMode;
  final double fontScale;
  final bool colorBlindMode;
  /// Color seed de la paleta Material You (almacenado como int ARGB).
  final int seedColor;

  Color get seedColorValue => Color(seedColor);

  AccessibilitySettings copyWith({
    ThemeMode? themeMode,
    double? fontScale,
    bool? colorBlindMode,
    int? seedColor,
  }) {
    return AccessibilitySettings(
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
      colorBlindMode: colorBlindMode ?? this.colorBlindMode,
      seedColor: seedColor ?? this.seedColor,
    );
  }
}

class AccessibilitySettingsNotifier
    extends StateNotifier<AccessibilitySettings> {
  AccessibilitySettingsNotifier(this._prefs)
      : super(
          AccessibilitySettings(
            themeMode: _readThemeMode(_prefs),
            fontScale: _prefs.getDouble(_fontScaleKey) ?? 1.0,
            colorBlindMode: _prefs.getBool(_colorBlindModeKey) ?? false,
            seedColor: _prefs.getInt(_seedColorKey) ?? kDefaultSeedColor,
          ),
        );

  final SharedPreferences _prefs;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_themeModeKey, mode.name);
  }

  Future<void> setFontScale(double scale) async {
    final clamped = scale.clamp(0.9, 1.6).toDouble();
    state = state.copyWith(fontScale: clamped);
    await _prefs.setDouble(_fontScaleKey, clamped);
  }

  Future<void> setColorBlindMode(bool enabled) async {
    state = state.copyWith(colorBlindMode: enabled);
    await _prefs.setBool(_colorBlindModeKey, enabled);
  }

  Future<void> setSeedColor(int colorValue) async {
    state = state.copyWith(seedColor: colorValue);
    await _prefs.setInt(_seedColorKey, colorValue);
  }

  Future<void> resetSeedColor() => setSeedColor(kDefaultSeedColor);

  static ThemeMode _readThemeMode(SharedPreferences prefs) {
    return switch (prefs.getString(_themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}