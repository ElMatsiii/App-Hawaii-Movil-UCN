import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/text_normalize.dart';
import '../../domain/entities/horario_entity.dart';
import '../providers/horario_provider_notif.dart';

// ── Nombres de días que usa la API ────────────────────────────────────────────

const _diasSemana = [
  'Lunes',
  'Martes',
  'Miercoles',
  'Jueves',
  'Viernes',
  'Sabado',
];

const _diasAbrev = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

// ── Sheet principal ───────────────────────────────────────────────────────────

class HorarioFiltrosSheet extends ConsumerStatefulWidget {
  final bool misRamosActivo;
  final ValueChanged<bool> onMisRamosToggle;

  const HorarioFiltrosSheet({
    required this.misRamosActivo, required this.onMisRamosToggle, super.key,
  });

  @override
  ConsumerState<HorarioFiltrosSheet> createState() =>
      _HorarioFiltrosSheetState();
}

class _HorarioFiltrosSheetState extends ConsumerState<HorarioFiltrosSheet> {
  // Controllers de búsqueda para carrera y profesor
  final _carreraCtrl = TextEditingController();
  final _profesorCtrl = TextEditingController();
  final _cursoCtrl = TextEditingController();

  @override
  void dispose() {
    _carreraCtrl.dispose();
    _profesorCtrl.dispose();
    _cursoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final master = ref.watch(masterProvider);
    final filtro = ref.watch(horarioFiltroProvider);
    final notifier = ref.read(horarioFiltroProvider.notifier);
    final carrerasAsync = ref.watch(carrerasDisponiblesProvider);
    final cursosAsync = ref.watch(cursosDisponiblesProvider);
    final colors = Theme.of(context).colorScheme;

    // Cuenta de filtros activos (sin semestre)
    final filtroCounts = _contarFiltrosActivos(filtro);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Column(
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // ── Encabezado ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: colors.primary, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Filtrar horarios',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (filtroCounts > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$filtroCounts',
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () {
                    notifier.reset();
                    _carreraCtrl.clear();
                    _profesorCtrl.clear();
                    _cursoCtrl.clear();
                  },
                  child: const Text('Limpiar'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Contenido ────────────────────────────────────────────────────
          Expanded(
            child: master.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (m) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  // ── Mis Ramos ──────────────────────────────────────────
                  _MisRamosToggle(
                    activo: widget.misRamosActivo,
                    onToggle: (v) {
                      widget.onMisRamosToggle(v);
                      if (v) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Sección: Académico ─────────────────────────────────
                  const _SeccionLabel(
                    label: 'Académico',
                    icon: Icons.school_outlined,
                  ),
                  const SizedBox(height: 10),

                  // Semestre — chips horizontales
                  const _FiltroLabel(label: 'Semestre'),
                  const SizedBox(height: 8),
                  _ChipsHorizontales<int>(
                    items: m.semestres
                        .map((s) => _ChipItem(value: s.id, label: s.nombre))
                        .toList(),
                    selected: filtro.semestre == -1 ? null : filtro.semestre,
                    onSelected: (v) => notifier.setSemestre(v ?? -1),
                  ),
                  const SizedBox(height: 16),

                  // Carrera — búsqueda con texto
                  const _FiltroLabel(label: 'Carrera'),
                  const SizedBox(height: 8),
                  carrerasAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (carreras) => carreras.isEmpty
                        ? Text(
                            'Carga el horario primero para filtrar por carrera',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          )
                        : _BusquedaDropdown<int>(
                            hint: 'Buscar carrera...',
                            icon: Icons.school_outlined,
                            value: filtro.carreraId == -1
                                ? null
                                : filtro.carreraId,
                            items: carreras
                                .map(
                                  (c) => _DropItem(
                                    value: c.id,
                                    label: c.nombre,
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => notifier.setCarreraId(v ?? -1),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Área
                  const _FiltroLabel(label: 'Área'),
                  const SizedBox(height: 8),
                  m.areas.isEmpty
                      ? Text(
                          'No hay áreas disponibles por ahora',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        )
                      : _BusquedaDropdown<int>(
                          hint: '-- Todas --',
                          icon: Icons.business_outlined,
                          value: filtro.area == -1 ? null : filtro.area,
                          items: m.areas
                              .map(
                                (a) => _DropItem(value: a.id, label: a.nombre),
                              )
                              .toList(),
                          onChanged: (v) => notifier.setArea(v ?? -1),
                        ),
                  const SizedBox(height: 24),

                  // ── Sección: Horario ───────────────────────────────────
                  const _SeccionLabel(
                    label: 'Horario',
                    icon: Icons.schedule_outlined,
                  ),
                  const SizedBox(height: 10),

                  // Día — chips tipo botón (selección múltiple)
                  const _FiltroLabel(label: 'Día'),
                  const SizedBox(height: 8),
                  _DiaChips(
                    diasSeleccionados: filtro.dias,
                    onDiaToggled: notifier.toggleDia,
                  ),
                  const SizedBox(height: 16),

                  // Nivel (semestreC)
                  const _FiltroLabel(label: 'Nivel'),
                  const SizedBox(height: 8),
                  _ChipsHorizontales<int>(
                    items: List.generate(
                      10,
                      (i) => _ChipItem(value: i + 1, label: '${i + 1}°'),
                    ),
                    selected: filtro.semestreC == -1 ? null : filtro.semestreC,
                    onSelected: (v) => notifier.setNivel(v ?? -1),
                  ),
                  const SizedBox(height: 24),

                  // ── Sección: Detalles ──────────────────────────────────
                  const _SeccionLabel(
                    label: 'Detalles',
                    icon: Icons.info_outline_rounded,
                  ),
                  const SizedBox(height: 10),

                  // Sala
                  const _FiltroLabel(label: 'Sala'),
                  const SizedBox(height: 8),
                  _BusquedaDropdown<int>(
                    hint: '-- Todas --',
                    icon: Icons.room_outlined,
                    value: filtro.sala == -1 ? null : filtro.sala,
                    items: m.salas
                        .map(
                          (s) => _DropItem(value: s.id, label: s.nombre),
                        )
                        .toList(),
                    onChanged: (v) => notifier.setSala(v ?? -1),
                  ),
                  const SizedBox(height: 16),

                  // Profesor
                  const _FiltroLabel(label: 'Profesor'),
                  const SizedBox(height: 8),
                  _BusquedaDropdown<int>(
                    hint: 'Buscar profesor...',
                    icon: Icons.person_outline,
                    value: filtro.profesor == -1 ? null : filtro.profesor,
                    items: m.profesores
                        .map(
                          (p) => _DropItem(value: p.id, label: p.nombre),
                        )
                        .toList(),
                    onChanged: (v) => notifier.setProfesor(v ?? -1),
                  ),
                  const SizedBox(height: 16),

                  // Curso
                  const _FiltroLabel(label: 'Curso'),
                  const SizedBox(height: 8),
                  cursosAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (cursos) => cursos.isEmpty
                        ? Text(
                            'Carga el horario primero para filtrar por curso',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          )
                        : _BusquedaMultiDropdown<int>(
                            hint: '-- Ninguno --',
                            icon: Icons.book_outlined,
                            value: filtro.curso,
                            items: cursos
                                .map(
                                  (c) => _DropItem(
                                    value: c.id,
                                    label: c.nombre,
                                  ),
                                )
                                .toList(),
                            onChanged: (ids) => notifier.setCursos(ids),
                          ),
                  ),
                  const SizedBox(height: 28),

                  // ── Botón aplicar ──────────────────────────────────────
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.filter_alt_rounded),
                    label: const Text('Aplicar filtros'),
                  ),
                  if (filtroCounts > 0) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () {
                        notifier.reset();
                        _carreraCtrl.clear();
                        _profesorCtrl.clear();
                        _cursoCtrl.clear();
                      },
                      child: const Text('Limpiar todos los filtros'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _contarFiltrosActivos(HorarioFiltro filtro) {
    var count = 0;
    if (widget.misRamosActivo) count++;
    if (filtro.area != -1) count++;
    if (filtro.sala != -1) count++;
    if (filtro.profesor != -1) count++;
    if (filtro.curso.isNotEmpty) count++;
    if (filtro.semestreC != -1) count++;
    if (filtro.carreraId != -1) count++;
    if (filtro.dias.isNotEmpty) count++;
    return count;
  }
}

// ── Chips de día (selección múltiple) ────────────────────────────────────────

class _DiaChips extends StatelessWidget {
  final Set<String> diasSeleccionados;
  final ValueChanged<String> onDiaToggled;

  const _DiaChips({
    required this.diasSeleccionados,
    required this.onDiaToggled,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(_diasSemana.length, (i) {
        final dia = _diasSemana[i];
        final abrev = _diasAbrev[i];
        final seleccionado = diasSeleccionados.contains(dia);
        return GestureDetector(
          onTap: () => onDiaToggled(dia),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: seleccionado
                  ? colors.primary
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: seleccionado
                  ? null
                  : Border.all(
                      color: colors.outlineVariant,
                      width: 1,
                    ),
            ),
            child: Text(
              abrev,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: seleccionado ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Chips horizontales scrolleables ──────────────────────────────────────────

class _ChipItem<T> {
  final T value;
  final String label;
  const _ChipItem({required this.value, required this.label});
}

class _ChipsHorizontales<T> extends StatelessWidget {
  final List<_ChipItem<T>> items;
  final T? selected;
  final ValueChanged<T?> onSelected;

  const _ChipsHorizontales({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final sel = selected == item.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(sel ? null : item.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: sel ? colors.primary : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: sel ? null : Border.all(color: colors.outlineVariant),
                ),
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? colors.onPrimary : colors.onSurface,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Dropdown con búsqueda integrada ──────────────────────────────────────────

class _DropItem<T> {
  final T value;
  final String label;
  const _DropItem({required this.value, required this.label});
}

class _BusquedaDropdown<T> extends StatefulWidget {
  final String hint;
  final IconData icon;
  final T? value;
  final List<_DropItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _BusquedaDropdown({
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_BusquedaDropdown<T>> createState() => _BusquedaDropdownState<T>();
}

class _BusquedaDropdownState<T> extends State<_BusquedaDropdown<T>> {
  String get _labelActual {
    if (widget.value == null) return '';
    return widget.items
        .firstWhere(
          (i) => i.value == widget.value,
          orElse: () => _DropItem(value: widget.value as T, label: ''),
        )
        .label;
  }

  void _abrirBuscador(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BuscadorModal<T>(
        hint: widget.hint,
        items: widget.items,
        selected: widget.value,
        onSelected: (v) {
          widget.onChanged(v);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tieneValor = widget.value != null;

    return GestureDetector(
      onTap: () => _abrirBuscador(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: colors.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tieneValor ? _labelActual : widget.hint,
                style: TextStyle(
                  color:
                      tieneValor ? colors.onSurface : colors.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (tieneValor)
              GestureDetector(
                onTap: () => widget.onChanged(null),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Dropdown con búsqueda integrada y selección múltiple ─────────────────────

class _BusquedaMultiDropdown<T> extends StatefulWidget {
  final String hint;
  final IconData icon;
  final Set<T> value;
  final List<_DropItem<T>> items;
  final ValueChanged<Set<T>> onChanged;

  const _BusquedaMultiDropdown({
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_BusquedaMultiDropdown<T>> createState() =>
      _BusquedaMultiDropdownState<T>();
}

class _BusquedaMultiDropdownState<T> extends State<_BusquedaMultiDropdown<T>> {
  String get _labelActual {
    if (widget.value.isEmpty) return '';
    if (widget.value.length == 1) {
      final id = widget.value.first;
      return widget.items
          .firstWhere(
            (i) => i.value == id,
            orElse: () => _DropItem(value: id, label: ''),
          )
          .label;
    }
    return '${widget.value.length} seleccionados';
  }

  Future<void> _abrirBuscador(BuildContext context) async {
    final colors = Theme.of(context).colorScheme;
    final resultado = await showModalBottomSheet<Set<T>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BuscadorModalMulti<T>(
        hint: widget.hint,
        items: widget.items,
        seleccionados: widget.value,
      ),
    );
    if (resultado != null) {
      widget.onChanged(resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tieneValor = widget.value.isNotEmpty;

    return GestureDetector(
      onTap: () => _abrirBuscador(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: colors.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tieneValor ? _labelActual : widget.hint,
                style: TextStyle(
                  color:
                      tieneValor ? colors.onSurface : colors.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (tieneValor)
              GestureDetector(
                onTap: () => widget.onChanged(<T>{}),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Modal de búsqueda con selección múltiple (checkboxes) ────────────────────

class _BuscadorModalMulti<T> extends StatefulWidget {
  final String hint;
  final List<_DropItem<T>> items;
  final Set<T> seleccionados;

  const _BuscadorModalMulti({
    required this.hint,
    required this.items,
    required this.seleccionados,
  });

  @override
  State<_BuscadorModalMulti<T>> createState() =>
      _BuscadorModalMultiState<T>();
}

class _BuscadorModalMultiState<T> extends State<_BuscadorModalMulti<T>> {
  String _query = '';
  late Set<T> _seleccionados;

  @override
  void initState() {
    super.initState();
    _seleccionados = Set<T>.from(widget.seleccionados);
  }

  List<_DropItem<T>> get _filtrados {
    if (_query.isEmpty) return widget.items;
    final q = normalizarBusqueda(_query);
    return widget.items
        .where((i) => normalizarBusqueda(i.label).contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtrados = _filtrados;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() => _query = ''),
                              )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_seleccionados.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_seleccionados.length} seleccionado${_seleccionados.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _seleccionados.clear()),
                      child: const Text('Limpiar'),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtrados.length,
                      itemBuilder: (_, i) {
                        final item = filtrados[i];
                        final sel = _seleccionados.contains(item.value);
                        return CheckboxListTile(
                          dense: true,
                          value: sel,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (v) {
                            setState(() {
                              if (v ?? false) {
                                _seleccionados.add(item.value);
                              } else {
                                _seleccionados.remove(item.value);
                              }
                            });
                          },
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _seleccionados),
                  child: Text(
                    _seleccionados.isEmpty
                        ? 'Aplicar'
                        : 'Aplicar (${_seleccionados.length})',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modal de búsqueda ─────────────────────────────────────────────────────────

class _BuscadorModal<T> extends StatefulWidget {
  final String hint;
  final List<_DropItem<T>> items;
  final T? selected;
  final ValueChanged<T?> onSelected;

  const _BuscadorModal({
    required this.hint,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_BuscadorModal<T>> createState() => _BuscadorModalState<T>();
}

class _BuscadorModalState<T> extends State<_BuscadorModal<T>> {
  String _query = '';

  List<_DropItem<T>> get _filtrados {
    if (_query.isEmpty) return widget.items;
    final q = normalizarBusqueda(_query);
    return widget.items
        .where((i) => normalizarBusqueda(i.label).contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtrados = _filtrados;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() => _query = ''),
                              )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Opción "Todos"
            ListTile(
              dense: true,
              leading: Icon(
                Icons.clear_all_rounded,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
              title: Text(
                'Todos',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              onTap: () => widget.onSelected(null),
              selected: widget.selected == null,
              selectedColor: colors.primary,
            ),
            const Divider(height: 1),
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtrados.length,
                      itemBuilder: (_, i) {
                        final item = filtrados[i];
                        final sel = widget.selected == item.value;
                        return ListTile(
                          dense: true,
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          trailing: sel
                              ? Icon(
                                  Icons.check_rounded,
                                  color: colors.primary,
                                  size: 18,
                                )
                              : null,
                          onTap: () => widget.onSelected(item.value),
                          selected: sel,
                          selectedColor: colors.primary,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toggle Mis Ramos ──────────────────────────────────────────────────────────

class _MisRamosToggle extends StatelessWidget {
  final bool activo;
  final ValueChanged<bool> onToggle;

  const _MisRamosToggle({required this.activo, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: activo ? colors.primaryContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activo ? colors.primary : colors.outlineVariant,
          width: activo ? 1.5 : 1,
        ),
      ),
      child: SwitchListTile(
        value: activo,
        onChanged: onToggle,
        secondary: Icon(
          Icons.person_pin_outlined,
          color: activo ? colors.primary : colors.onSurfaceVariant,
        ),
        title: Text(
          'Mis ramos',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: activo ? colors.onPrimaryContainer : colors.onSurface,
          ),
        ),
        subtitle: Text(
          'Solo los ramos en los que estás inscrito',
          style: TextStyle(
            fontSize: 12,
            color: activo
                ? colors.onPrimaryContainer.withValues(alpha: 0.7)
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SeccionLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SeccionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(color: colors.primary.withValues(alpha: 0.3)),
        ),
      ],
    );
  }
}

class _FiltroLabel extends StatelessWidget {
  final String label;
  const _FiltroLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}