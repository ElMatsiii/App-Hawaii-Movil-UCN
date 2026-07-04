import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const seedBlue = Color(0xFF005CBB);
  static const primaryDeep = Color(0xFF003B7E);
  static const terracotta = Color(0xFFAC6D33);
  static const terracottaText = Color(0xFF8A551F);
  static const teal = Color(0xFF2F8E9E);
  static const ucnRed = Color(0xFFC4312C);
  static const amber = Color(0xFFECAB3B);
  static const lightSurface = Color(0xFFFCFBF8);
  static const lightBackground = Color(0xFFFAF7F1);
  static const outline = Color(0xFF8C8A85);
  static const darkSurface = Color(0xFF15140F);
  static const darkBackground = Color(0xFF100F0B);

  static const statePresente = Color(0xFF2E7D46);
  static const stateAusente = Color(0xFFC4312C);
  static const stateJustificado = Color(0xFF2F8E9E);
  static const stateAtrasado = Color(0xFFB5791A);

  static const statePresenteDark = Color(0xFF7FD79A);
  static const stateAusenteDark = Color(0xFFFFB4AB);
  static const stateJustificadoDark = Color(0xFF7FD0DF);
  static const stateAtrasadoDark = Color(0xFFECAB3B);

  static const okabePresente = Color(0xFF009E73);
  static const okabeAusente = Color(0xFFD55E00);
  static const okabeJustificado = Color(0xFF0072B2);
  static const okabeAtrasado = Color(0xFFE69F00);
}

class AttendanceStateColors {
  const AttendanceStateColors({
    required this.presente,
    required this.ausente,
    required this.justificado,
    required this.atrasado,
  });

  final Color presente;
  final Color ausente;
  final Color justificado;
  final Color atrasado;

  Color forEstado(int estado) {
    return switch (estado) {
      1 => presente,
      0 => ausente,
      3 => justificado,
      -1 => atrasado,
      _ => presente,
    };
  }

  /// Buena asistencia (≥75%) → primary del tema
  /// En riesgo (50–74%)      → tertiary del tema
  /// Mala (<50%)             → error del tema
  Color forPorcentaje(int porcentaje) {
    if (porcentaje >= 75) return presente;
    if (porcentaje >= 50) return atrasado;
    return ausente;
  }

  /// Deriva los colores de estado desde el [ColorScheme] activo del tema.
  ///
  /// • Modo daltónico: paleta Okabe-Ito (sin cambios).
  /// • Modo normal: colores semánticos del esquema Material You.
  ///   - presente   → [ColorScheme.primary]
  ///   - ausente    → [ColorScheme.error]
  ///   - justificado → [ColorScheme.secondary]
  ///   - atrasado   → [ColorScheme.tertiary]  (tono cálido del tema)
  static AttendanceStateColors resolve({
    required ColorScheme colorScheme,
    required bool colorBlindMode,
  }) {
    if (colorBlindMode) {
      return const AttendanceStateColors(
        presente: AppColors.okabePresente,
        ausente: AppColors.okabeAusente,
        justificado: AppColors.okabeJustificado,
        atrasado: AppColors.okabeAtrasado,
      );
    }

    return AttendanceStateColors(
      presente: colorScheme.primary,
      ausente: colorScheme.error,
      justificado: colorScheme.secondary,
      atrasado: colorScheme.tertiary,
    );
  }
}