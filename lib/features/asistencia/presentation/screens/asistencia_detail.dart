part of 'asistencia_screen.dart';

// ── Bottom sheet de detalle de asistencia ─────────────────────────────────────
class _AsistenciaDetalleSheet extends ConsumerWidget {
  final CursoUsuarioEntity curso;
  final int semestreId;
  final String rutEstudiante;

  const _AsistenciaDetalleSheet({
    required this.curso,
    required this.semestreId,
    required this.rutEstudiante,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asistenciasAsync = ref.watch(asistenciasProvider(semestreId));
    final detalleAsync = ref.watch(
      asistenciaEstudianteProvider(
        (
          curso: curso.id,
          semestre: semestreId,
          rut: rutEstudiante,
        ),
      ),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  curso.nombre,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${curso.codigo} · Sección ${curso.seccion}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Contenido scrolleable
          Expanded(
            child: asistenciasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error resumen: $e')),
              data: (asistencias) {
                final resumen = asistencias
                    .where(
                      (a) => a.codigo == curso.codigo && a.seccion == curso.seccion,
                    )
                    .firstOrNull;

                return detalleAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    children: [
                      if (resumen != null)
                        _ResumenCard(resumen: resumen, clases: const []),
                      Center(child: Text('No se pudo cargar el detalle: $e')),
                    ],
                  ),
                  data: (clases) => _VistaDetalle(
                    resumen: resumen,
                    clases: clases,
                    scrollController: scrollController,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _VistaDetalle extends StatelessWidget {
  final AsistenciaCursoEntity? resumen;
  final List<AsistenciaClaseEntity> clases;
  final ScrollController? scrollController;

  const _VistaDetalle({
    required this.resumen,
    required this.clases,
    this.scrollController,
  });

  Map<String, List<AsistenciaClaseEntity>> _agruparPorFecha() {
    final mapa = <String, List<AsistenciaClaseEntity>>{};
    for (final c in clases) {
      mapa.putIfAbsent(c.fecha, () => []).add(c);
    }
    for (final lista in mapa.values) {
      lista.sort((a, b) => a.bloque.compareTo(b.bloque));
    }
    final fechasOrdenadas = mapa.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final f in fechasOrdenadas) f: mapa[f]!};
  }

  String _formatFecha(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat("EEE d 'de' MMM yyyy", 'es').format(dt);
    } catch (_) {
      return iso;
    }
  }

  String _diaSemana(String iso) {
    try {
      return DateFormat('EEEE', 'es').format(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final porFecha = _agruparPorFecha();

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
      children: [
        _ResumenCard(resumen: resumen, clases: clases),
        if (clases.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Registro de clases (${clases.length} bloques)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        if (clases.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('Sin registros de asistencia aun'),
            ),
          )
        else
          ...porFecha.entries.map((entry) => _FechaCard(
                fecha: entry.key,
                fechaFormateada: _formatFecha(entry.key),
                diaSemana: _diaSemana(entry.key),
                bloques: entry.value,
              ),),
      ],
    );
  }
}

class _FechaCard extends ConsumerWidget {
  final String fecha;
  final String fechaFormateada;
  final String diaSemana;
  final List<AsistenciaClaseEntity> bloques;

  const _FechaCard({
    required this.fecha,
    required this.fechaFormateada,
    required this.diaSemana,
    required this.bloques,
  });

  bool get _esHoy {
    try {
      final dt = DateTime.parse(fecha);
      final hoy = DateTime.now();
      return dt.year == hoy.year && dt.month == hoy.month && dt.day == hoy.day;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final stateColors = _attendanceColors(context, ref);
    final hayAusente = bloques.any((b) => b.estado == 0);
    final hayAtrasado = bloques.any((b) => b.estado == -1);
    final todosPresentes = bloques.every((b) => b.estado == 1 || b.estado == 3);

    final borderColor = hayAusente
        ? stateColors.ausente
        : hayAtrasado
            ? stateColors.atrasado
            : todosPresentes
                ? stateColors.presente
                : colors.outlineVariant;

    final estadoLabel = hayAusente
        ? 'Ausente'
        : hayAtrasado
            ? 'Atrasado'
            : 'Presente';

    final estadoIcon = hayAusente
        ? Icons.cancel_outlined
        : hayAtrasado
            ? Icons.schedule_outlined
            : Icons.check_circle_outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: borderColor.withValues(alpha: 0.4), width: 1.5),
        color: colors.surface,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(estadoIcon, size: 20, color: borderColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            fechaFormateada,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: colors.onSurface,
                            ),
                          ),
                          if (_esHoy) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Hoy',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        diaSemana,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    estadoLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: borderColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: bloques.map((b) => _BloquePill(bloque: b)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BloquePill extends ConsumerWidget {
  final AsistenciaClaseEntity bloque;
  const _BloquePill({required this.bloque});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final stateColors = _attendanceColors(context, ref);
    final brightness = Theme.of(context).brightness;

    final (bg, fg, icon) = switch (bloque.estado) {
      1 => (
          _stateContainer(stateColors.presente, colors.surface),
          _readableStateText(stateColors.presente, brightness),
          Icons.check_circle_outline,
        ),
      0 => (
          _stateContainer(stateColors.ausente, colors.surface),
          _readableStateText(stateColors.ausente, brightness),
          Icons.cancel_outlined,
        ),
      3 => (
          _stateContainer(stateColors.justificado, colors.surface),
          _readableStateText(stateColors.justificado, brightness),
          Icons.verified_outlined,
        ),
      -1 => (
          _stateContainer(stateColors.atrasado, colors.surface),
          _readableStateText(stateColors.atrasado, brightness),
          Icons.schedule_outlined,
        ),
      _ => (
          colors.surfaceContainerHighest,
          colors.onSurface,
          Icons.help_outline,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bloque ${bloque.bloque}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              Text(
                bloque.estadoTexto,
                style: TextStyle(
                  fontSize: 10,
                  color: fg.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResumenCard extends ConsumerWidget {
  final AsistenciaCursoEntity? resumen;
  final List<AsistenciaClaseEntity> clases;

  const _ResumenCard({required this.resumen, required this.clases});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final stateColors = _attendanceColors(context, ref);
    final stats = _ResumenAsistenciaStats.from(
      resumen: resumen,
      clases: clases,
    );
    final pct = stats.porcentaje;
    final presentes = stats.presentes;
    final ausentes = stats.ausentes;
    final total = stats.total;
    final justificados = clases.where((c) => c.estado == 3).length;
    final atrasados = clases.where((c) => c.estado == -1).length;

    final progressColor = stateColors.forPorcentaje(pct);
    final cardColor = _stateContainer(progressColor, colors.surface, 0.18);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$pct%',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asistencia general',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 8,
                        backgroundColor: colors.surface.withValues(alpha: 0.5),
                        color: progressColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pct >= 75
                          ? 'Cumple asistencia minima'
                          : pct >= 50
                              ? 'En riesgo de reprobar por inasistencia'
                              : 'No cumple asistencia minima',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                valor: presentes,
                label: 'Presentes',
                icon: Icons.check_circle_outline,
              ),
              _Stat(
                valor: ausentes,
                label: 'Ausentes',
                icon: Icons.cancel_outlined,
              ),
              if (justificados > 0)
                _Stat(
                  valor: justificados,
                  label: 'Justif.',
                  icon: Icons.verified_outlined,
                ),
              if (atrasados > 0)
                _Stat(
                  valor: atrasados,
                  label: 'Atrasados',
                  icon: Icons.schedule_outlined,
                ),
              _Stat(
                valor: total,
                label: 'Total',
                icon: Icons.calendar_month_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResumenAsistenciaStats {
  final int porcentaje;
  final int presentes;
  final int ausentes;
  final int total;

  const _ResumenAsistenciaStats({
    required this.porcentaje,
    required this.presentes,
    required this.ausentes,
    required this.total,
  });

  factory _ResumenAsistenciaStats.from({
    required AsistenciaCursoEntity? resumen,
    required List<AsistenciaClaseEntity> clases,
  }) {
    if (clases.isNotEmpty) {
      final presentes = clases.where((c) => c.estado == 1).length;
      final ausentes = clases.where((c) => c.estado == 0).length;
      final total = clases.length;
      return _ResumenAsistenciaStats(
        porcentaje: ((presentes / total) * 100).round(),
        presentes: presentes,
        ausentes: ausentes,
        total: total,
      );
    }

    final total = resumen?.total ?? 0;
    final presentes = resumen?.presentes ?? 0;
    return _ResumenAsistenciaStats(
      porcentaje: resumen?.porcentaje ?? 0,
      presentes: presentes,
      ausentes: resumen?.ausentes ?? (total - presentes).clamp(0, total),
      total: total,
    );
  }
}

class _Stat extends StatelessWidget {
  final int valor;
  final String label;
  final IconData icon;
  const _Stat({required this.valor, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Icon(icon, size: 15, color: c.withValues(alpha: 0.6)),
        const SizedBox(height: 2),
        Text(
          '$valor',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: c.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}