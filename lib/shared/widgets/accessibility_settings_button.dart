import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/accessibility_settings.dart';

// Paleta de colores predefinidos para personalización
const _paleta = [
  (nombre: 'UCN Azul',    color: Color(0xFF005CBB)),
  (nombre: 'Esmeralda',   color: Color(0xFF00796B)),
  (nombre: 'Violeta',     color: Color(0xFF6A1B9A)),
  (nombre: 'Granate',     color: Color(0xFFC62828)),
  (nombre: 'Naranja',     color: Color(0xFFE65100)),
  (nombre: 'Dorado',      color: Color(0xFFF9A825)),
  (nombre: 'Rosa',        color: Color(0xFFAD1457)),
  (nombre: 'Índigo',      color: Color(0xFF283593)),
  (nombre: 'Pizarra',     color: Color(0xFF37474F)),
  (nombre: 'Café',        color: Color(0xFF4E342E)),
];

class AccessibilitySettingsButton extends StatelessWidget {
  const AccessibilitySettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Accesibilidad',
      icon: const Icon(Icons.accessibility_new_outlined),
      onPressed: () => showAccessibilitySettingsSheet(context),
    );
  }
}

void showAccessibilitySettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // isScrollControlled + el SingleChildScrollView de abajo permiten que el
    // sheet crezca y se pueda scrollear si el fontScale hace que el
    // contenido no entre en la altura por defecto (evita que el slider de
    // tamaño de letra quede recortado fuera de la pantalla).
    isScrollControlled: true,
    builder: (_) => const _AccessibilitySettingsSheet(),
  );
}

class _AccessibilitySettingsSheet extends ConsumerWidget {
  const _AccessibilitySettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilitySettingsProvider);
    final notifier = ref.read(accessibilitySettingsProvider.notifier);

    const maxOwnScale = 1.25;
    final ownScale = settings.fontScale.clamp(0.9, maxOwnScale).toDouble();
    final currentSeed = settings.seedColorValue;
    final isDefault = settings.seedColor == kDefaultSeedColor;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(ownScale),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accesibilidad',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 18),

                // ── Tema ────────────────────────────────────────────────────
                Text('Tema', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('Sistema'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Claro'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Oscuro'),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (v) => notifier.setThemeMode(v.first),
                  ),
                ),
                const SizedBox(height: 22),

                // ── Color de la app ──────────────────────────────────────────
                Row(
                  children: [
                    Text('Color', style: Theme.of(context).textTheme.labelLarge),
                    const Spacer(),
                    if (!isDefault)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: const Text('Restablecer'),
                        onPressed: notifier.resetSeedColor,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Paleta predefinida
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in _paleta)
                      _ColorChip(
                        color: item.color,
                        nombre: item.nombre,
                        seleccionado: currentSeed.toARGB32() == item.color.toARGB32(),
                        onTap: () => notifier.setSeedColor(item.color.toARGB32()),
                      ),

                  ],
                ),
                const SizedBox(height: 18),

                // ── Daltonismo ──────────────────────────────────────────────
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.visibility_outlined),
                  title: const Text('Modo daltonico'),
                  subtitle: const Text('Usa paleta Okabe-Ito en toda la app'),
                  value: settings.colorBlindMode,
                  onChanged: notifier.setColorBlindMode,
                ),
                const SizedBox(height: 8),

                // ── Tamaño de fuente ────────────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.format_size_outlined),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Tamaño de fuente',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text('${(settings.fontScale * 100).round()}%'),
                    IconButton(
                      tooltip: 'Restablecer tamaño de fuente',
                      icon: const Icon(Icons.restart_alt),
                      onPressed: settings.fontScale == 1.0
                          ? null
                          : () => notifier.setFontScale(1.0),
                    ),
                  ],
                ),
                Slider(
                  min: 0.9,
                  max: 1.6,
                  divisions: 7,
                  label: '${(settings.fontScale * 100).round()}%',
                  value: settings.fontScale,
                  onChanged: notifier.setFontScale,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Chip de color predefinido ─────────────────────────────────────────────────

class _ColorChip extends StatelessWidget {
  final Color color;
  final String nombre;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ColorChip({
    required this.color,
    required this.nombre,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: nombre,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: seleccionado
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 2.5,
                  )
                : Border.all(color: Colors.transparent, width: 2.5),
            boxShadow: seleccionado
                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                : null,
          ),
          child: seleccionado
              ? Icon(
                  Icons.check_rounded,
                  color: ThemeData.estimateBrightnessForColor(color) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  size: 18,
                )
              : null,
        ),
      ),
    );
  }
}