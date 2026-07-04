import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'settings.themeMode';
const _fontScaleKey = 'settings.fontScale';
const _colorBlindModeKey = 'settings.colorBlindMode';
const _seedColorKey = 'settings.seedColorHex';  // hex string, evita overflow de int32

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

  Color get seedColorValue => Color.fromARGB(
        (seedColor >> 24) & 0xFF,
        (seedColor >> 16) & 0xFF,
        (seedColor >> 8)  & 0xFF,
         seedColor        & 0xFF,
      );

  /// Convierte el int ARGB a string hex para almacenamiento seguro.
  /// SharedPreferences.setInt usa int32 con signo en Android, lo que
  /// desborda cualquier color opaco (alpha=0xFF → bit 31 en 1).
  static String _toHexString(int argb) =>
      argb.toRadixString(16).padLeft(8, '0');

  static int _fromHexString(String? hex) {
    if (hex == null || hex.length != 8) return kDefaultSeedColor;
    return int.tryParse(hex, radix: 16) ?? kDefaultSeedColor;
  }

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
            seedColor: AccessibilitySettings._fromHexString(
              _prefs.getString(_seedColorKey),
            ),
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
    // Guardamos como String hex para evitar overflow de int32 en Android.
    // setInt usa putInt de Java (32-bit signed) y desborda con alpha=0xFF.
    await _prefs.setString(
      _seedColorKey,
      AccessibilitySettings._toHexString(colorValue),
    );
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