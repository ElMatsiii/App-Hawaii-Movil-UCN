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
                    // Chip de color custom
                    _ColorChipCustom(
                      currentSeed: currentSeed,
                      esPaletaPredefinida: _paleta.any(
                        (p) => p.color.toARGB32() == currentSeed.toARGB32(),
                      ),
                      onColorPicked: (c) => notifier.setSeedColor(c.toARGB32()),
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

// ── Chip de color personalizado (abre selector) ────────────────────────────────

class _ColorChipCustom extends StatelessWidget {
  final Color currentSeed;
  final bool esPaletaPredefinida;
  final ValueChanged<Color> onColorPicked;

  const _ColorChipCustom({
    required this.currentSeed,
    required this.esPaletaPredefinida,
    required this.onColorPicked,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Si el color actual es custom (no está en paleta), mostrarlo en el chip.
    final displayColor = esPaletaPredefinida ? null : currentSeed;
    final seleccionado = !esPaletaPredefinida;

    return Tooltip(
      message: 'Color personalizado',
      child: GestureDetector(
        onTap: () => _abrirSelector(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: displayColor ?? colors.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: seleccionado
                ? Border.all(color: colors.onSurface, width: 2.5)
                : Border.all(color: colors.outlineVariant, width: 1.5),
          ),
          child: Icon(
            Icons.colorize_rounded,
            size: 18,
            color: displayColor != null
                ? (ThemeData.estimateBrightnessForColor(displayColor) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black)
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _abrirSelector(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ColorPickerDialog(
        initialColor: currentSeed,
        onColorPicked: (c) {
          onColorPicked(c);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ── Diálogo selector de color custom ──────────────────────────────────────────

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorPicked;

  const _ColorPickerDialog({
    required this.initialColor,
    required this.onColorPicked,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selected;
  late TextEditingController _hexCtrl;
  String? _hexError;

  // Grid ampliada de colores para el picker custom
  static const _grid = [
    // Rojos/rosas
    Color(0xFFB71C1C), Color(0xFFC62828), Color(0xFFE53935),
    Color(0xFFAD1457), Color(0xFFC2185B), Color(0xFFE91E63),
    // Morados
    Color(0xFF6A1B9A), Color(0xFF7B1FA2), Color(0xFF8E24AA),
    Color(0xFF4527A0), Color(0xFF512DA8), Color(0xFF673AB7),
    // Azules
    Color(0xFF283593), Color(0xFF1565C0), Color(0xFF005CBB),
    Color(0xFF0277BD), Color(0xFF0288D1), Color(0xFF039BE5),
    // Verdes/teal
    Color(0xFF00695C), Color(0xFF00796B), Color(0xFF00897B),
    Color(0xFF2E7D32), Color(0xFF388E3C), Color(0xFF43A047),
    // Amarillo/naranja/café
    Color(0xFFE65100), Color(0xFFEF6C00), Color(0xFFF57C00),
    Color(0xFFF9A825), Color(0xFFFBC02D), Color(0xFFFFD600),
    Color(0xFF4E342E), Color(0xFF5D4037), Color(0xFF6D4C41),
    // Grises
    Color(0xFF263238), Color(0xFF37474F), Color(0xFF455A64),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor;
    _hexCtrl = TextEditingController(text: _toHex(widget.initialColor));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  String _toHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  void _onHexChanged(String raw) {
    final hex = raw.trim().replaceAll('#', '');
    if (hex.length == 6) {
      final parsed = int.tryParse('FF$hex', radix: 16);
      if (parsed != null) {
        setState(() {
          _selected = Color(parsed);
          _hexError = null;
        });
        return;
      }
    }
    setState(() => _hexError = hex.isEmpty ? null : 'Formato: #RRGGBB');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final brightness = ThemeData.estimateBrightnessForColor(_selected);
    final onSelected =
        brightness == Brightness.dark ? Colors.white : Colors.black;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Color personalizado',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            // Preview
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              decoration: BoxDecoration(
                color: _selected,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _toHex(_selected),
                style: TextStyle(
                  color: onSelected,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Grid de colores
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _grid.length,
              itemBuilder: (_, i) {
                final c = _grid[i];
                final sel = c.toARGB32() == _selected.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() {
                    _selected = c;
                    _hexCtrl.text = _toHex(c);
                    _hexError = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: sel
                          ? Border.all(color: colors.onSurface, width: 2.5)
                          : null,
                    ),
                    child: sel
                        ? Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: ThemeData.estimateBrightnessForColor(c) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          )
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Input hex
            TextField(
              controller: _hexCtrl,
              decoration: InputDecoration(
                labelText: 'Código HEX',
                hintText: '#005CBB',
                errorText: _hexError,
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _selected,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                isDense: true,
              ),
              onChanged: _onHexChanged,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    backgroundColor: _selected,
                    foregroundColor: onSelected,
                  ),
                  onPressed: _hexError != null
                      ? null
                      : () => widget.onColorPicked(_selected),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}