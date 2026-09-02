part of 'asistencia_screen.dart';

//lista de cursos para ver asistencia

class _ListaCursos extends ConsumerWidget {
  final String usuario;
  final int semestreId;
  final ValueChanged<CursoUsuarioEntity> onCursoTap;

  const _ListaCursos({
    required this.usuario,
    required this.semestreId,
    required this.onCursoTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cursosAsync = ref.watch(
      misCursosProvider((usuario: usuario, semestre: semestreId)),
    );

    return cursosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(child: Text('Error: $e')),
          ),
        ),
      ),
      data: (cursos) {
        if (cursos.isEmpty) {
          return LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                child: const Center(
                  child: Text('No tienes cursos registrados'),
                ),
              ),
            ),
          );
        }

        final algunCargando = cursos.any(
          (c) => ref.watch(
            asistenciaEstudianteProvider((
              curso: c.id,
              semestre: semestreId,
              rut: usuario,
            ),),
          ).isLoading,
        );

        if (algunCargando) {
          return const Center(child: CircularProgressIndicator());
        }

        return _buildList(context, cursos);
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    List<CursoUsuarioEntity> cursos,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Toca un ramo para ver el registro diario',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        ...cursos.map(
          (c) => _CursoAsistenciaTile(
            curso: c,
            semestreId: semestreId,
            rutEstudiante: usuario,
            onTap: () => onCursoTap(c),
          ),
        ),
      ],
    );
  }
}

class _CursoAsistenciaTile extends ConsumerWidget {
  final CursoUsuarioEntity curso;
  final int semestreId;
  final String rutEstudiante;
  final VoidCallback onTap;

  const _CursoAsistenciaTile({
    required this.curso,
    required this.semestreId,
    required this.rutEstudiante,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final stateColors = _attendanceColors(context, ref);

    // Igual que en el detalle: las cifras reales salen del listado de
    // clases (asist_marcar6.php), no del resumen de notas-estudiante.php,
    // cuyo formato de campos no siempre calza con lo que esperamos.
    final clasesAsync = ref.watch(
      asistenciaEstudianteProvider(
        (
          curso: curso.id,
          semestre: semestreId,
          rut: rutEstudiante,
        ),
      ),
    );

    final clases =
        clasesAsync.asData?.value ?? const <AsistenciaClaseEntity>[];
    final tieneData = clasesAsync.hasValue && clases.isNotEmpty;
    final stats = _ResumenAsistenciaStats.from(resumen: null, clases: clases);
    final pct = stats.porcentaje;

    final barColor =
        !tieneData ? colors.outlineVariant : stateColors.forPorcentaje(pct);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: tieneData ? pct / 100 : 0,
                      backgroundColor: colors.surfaceContainerHighest,
                      color: barColor,
                      strokeWidth: 5,
                    ),
                    Text(
                      tieneData ? '$pct%' : '0%',
                      style: TextStyle(
                        fontSize: tieneData ? 11 : 16,
                        fontWeight: FontWeight.w700,
                        color: barColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      curso.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${curso.codigo} - Seccion ${curso.seccion}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (tieneData) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _MiniChip(
                            label: '${stats.presentes} pres.',
                            color: _stateContainer(
                              stateColors.presente,
                              colors.surface,
                            ),
                            textColor: _readableStateText(
                              stateColors.presente,
                              Theme.of(context).brightness,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _MiniChip(
                            label: '${stats.ausentes} aus.',
                            color: _stateContainer(
                              stateColors.ausente,
                              colors.surface,
                            ),
                            textColor: _readableStateText(
                              stateColors.ausente,
                              Theme.of(context).brightness,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _MiniChip(
                            label: '${stats.total} total',
                            color: colors.surfaceContainerHighest,
                            textColor: colors.onSurface,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _MiniChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}