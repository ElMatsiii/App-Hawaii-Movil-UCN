import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/accessibility_settings_button.dart';
import '../../../../shared/widgets/logout_button.dart';
import '../../../asistencia/data/asistencia_datasource.dart';
import '../../../auth/presentation/providers/auth_provider_notif.dart';
import '../../../horario/presentation/providers/horario_provider_notif.dart';
import '../../data/mis_cursos_datasource.dart';
import '../../data/notas_datasource.dart';
import '../../domain/entities/curso_usuario_entity.dart';

class MisCursosScreen extends ConsumerWidget {
  const MisCursosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState is AuthUnauthenticated || authState is AuthInitial) {
      return _SinSesionView(
        onLogin: () => context.pushNamed(AppRoutes.loginName),
      );
    }

    if (authState is AuthLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (authState is! AuthAuthenticated) {
      return _SinSesionView(
        onLogin: () => context.pushNamed(AppRoutes.loginName),
      );
    }

    final usuario = authState.usuario;
    final master = ref.watch(masterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mis Cursos'),
            Text(
              usuario.nombre,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
        actions: const [
          AccessibilitySettingsButton(),
          LogoutButton(),
        ],
      ),
      body: master.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error al cargar: $e')),
        data: (masterData) {
          final semestreActual = semestreActualOrNull(masterData);
          if (semestreActual == null) {
            return const Center(child: Text('Sin semestres disponibles'));
          }

          final cursosAsync = ref.watch(
            misCursosProvider(
              (usuario: usuario.rut, semestre: semestreActual.id),
            ),
          );

          Future<void> onRefresh() async {
            ref
              ..invalidate(masterProvider)
              ..invalidate(misCursosProvider)
              ..invalidate(asistenciasProvider)
              ..invalidate(notasProvider);
            await Future.wait([
              // ignore: body_might_complete_normally_catch_error
              ref.read(masterProvider.future).catchError((_) {}),
              ref
                  .read(
                    misCursosProvider(
                      (usuario: usuario.rut, semestre: semestreActual.id),
                    ).future,
                  )
                  .catchError((_) => const <CursoUsuarioEntity>[]),
            ]);
          }

          return RefreshIndicator(
            onRefresh: onRefresh,
            child: cursosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorCursos(
                mensaje: e.toString(),
                onRetry: () => ref.invalidate(misCursosProvider),
              ),
              data: (cursos) => _CursosList(
                cursos: cursos,
                semestreNombre: semestreActual.nombre,
                semestreId: semestreActual.id,
              ),
            ),
          );
        },
      ),
    );
  }

}

// ── Lista de cursos ───────────────────────────────────────────────────────────

class _CursosList extends StatelessWidget {
  final List<CursoUsuarioEntity> cursos;
  final String semestreNombre;
  final int semestreId;

  const _CursosList({
    required this.cursos,
    required this.semestreNombre,
    required this.semestreId,
  });

  @override
  Widget build(BuildContext context) {
    if (cursos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.book_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('Sin cursos en $semestreNombre'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: cursos.length,
      itemBuilder: (_, i) => _CursoCard(
        curso: cursos[i],
        semestreId: semestreId,
      ),
    );
  }
}

// ── Tarjeta de curso ──────────────────────────────────────────────────────────

class _CursoCard extends ConsumerWidget {
  final CursoUsuarioEntity curso;
  final int semestreId;

  const _CursoCard({required this.curso, required this.semestreId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: curso.esProfesor
              ? colors.tertiaryContainer
              : colors.secondaryContainer,
          child: Icon(
            curso.esProfesor ? Icons.co_present_outlined : Icons.person_outline,
            color: curso.esProfesor
                ? colors.onTertiaryContainer
                : colors.onSecondaryContainer,
          ),
        ),
        title: Text(
          curso.nombre,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${curso.codigo} · Sección ${curso.seccion}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (curso.tieneAsistencia)
              _Badge(
                label: 'Asist.',
                color: colors.primaryContainer,
                textColor: colors.onPrimaryContainer,
              ),
            if (curso.tieneNotas)
              _Badge(
                label: 'Notas',
                color: colors.secondaryContainer,
                textColor: colors.onSecondaryContainer,
              ),
          ],
        ),
        onTap: () => _mostrarDetalle(context, ref),
      ),
    );
  }

  void _mostrarDetalle(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CursoDetalleSheet(
        curso: curso,
        semestreId: semestreId,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 10 * MediaQuery.textScalerOf(context).scale(1), color: textColor)),
    );
  }
}

// ── Detalle del curso ─────────────────────────────────────────────────────────

class _CursoDetalleSheet extends ConsumerWidget {
  final CursoUsuarioEntity curso;
  final int semestreId;

  const _CursoDetalleSheet({
    required this.curso,
    required this.semestreId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asistenciasAsync = ref.watch(asistenciasProvider(semestreId));
    final notasAsync = ref.watch(notasProvider(semestreId));
    final usuario = ref.watch(currentUserProvider);
    final detalleAsistenciaAsync = usuario == null
        ? const AsyncValue<List<AsistenciaClaseEntity>>.data([])
        : ref.watch(
            asistenciaEstudianteProvider(
              (
                curso: curso.id,
                semestre: semestreId,
                rut: usuario.rut,
              ),
            ),
          );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                // Asistencia
                const _SeccionTitulo(titulo: 'Asistencia'),
                asistenciasAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                  data: (asistencias) {
                    final match = asistencias
                        .where(
                          (a) =>
                              a.codigo == curso.codigo &&
                              a.seccion == curso.seccion,
                        )
                        .firstOrNull;
                    return detalleAsistenciaAsync.when(
                      loading: () => match == null
                          ? const Center(child: CircularProgressIndicator())
                          : _AsistenciaCard(asistencia: match),
                      error: (_, __) => match == null
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Sin datos de asistencia'),
                            )
                          : _AsistenciaCard(asistencia: match),
                      data: (clases) {
                        if (match == null && clases.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Sin datos de asistencia'),
                          );
                        }
                        return _AsistenciaCard(
                          asistencia: match,
                          clases: clases,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Notas
                const _SeccionTitulo(titulo: 'Notas'),
                notasAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                  data: (notas) {
                    final match = notas
                        .where(
                          (n) =>
                              n.codigo == curso.codigo &&
                              n.seccion == curso.seccion,
                        )
                        .firstOrNull;
                    if (match == null || match.notas.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Sin notas disponibles'),
                      );
                    }
                    return _NotasCard(notasCurso: match);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SeccionTitulo extends StatelessWidget {
  final String titulo;
  const _SeccionTitulo({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _AsistenciaCard extends StatelessWidget {
  final AsistenciaCursoEntity? asistencia;
  final List<AsistenciaClaseEntity> clases;

  const _AsistenciaCard({
    required this.asistencia,
    this.clases = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stats = _AsistenciaStats.from(
      resumen: asistencia,
      clases: clases,
    );
    final porcentaje = stats.porcentaje;
    final color = porcentaje >= 75
        ? colors.primaryContainer
        : porcentaje >= 50
            ? colors.secondaryContainer
            : colors.errorContainer;

    final total = stats.total;
    final presentes = stats.presentes;
    final ausentes = stats.ausentes;

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$porcentaje%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Asistencia actual'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: porcentaje / 100,
                        backgroundColor: colors.surface,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(
                  label: 'Asistidas',
                  value: '$presentes',
                  icon: Icons.check_circle_outline,
                  color: colors.onSurface,
                ),
                _StatChip(
                  label: 'Ausentes',
                  value: '$ausentes',
                  icon: Icons.cancel_outlined,
                  color: colors.onSurface,
                ),
                _StatChip(
                  label: 'Total',
                  value: '$total',
                  icon: Icons.calendar_month_outlined,
                  color: colors.onSurface,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AsistenciaStats {
  final int porcentaje;
  final int presentes;
  final int ausentes;
  final int total;

  const _AsistenciaStats({
    required this.porcentaje,
    required this.presentes,
    required this.ausentes,
    required this.total,
  });

  factory _AsistenciaStats.from({
    required AsistenciaCursoEntity? resumen,
    required List<AsistenciaClaseEntity> clases,
  }) {
    if (clases.isNotEmpty) {
      final presentes = clases.where((c) => c.estado == 1).length;
      final ausentes = clases.where((c) => c.estado == 0).length;
      final total = clases.length;
      return _AsistenciaStats(
        porcentaje: ((presentes / total) * 100).round(),
        presentes: presentes,
        ausentes: ausentes,
        total: total,
      );
    }

    final total = resumen?.total ?? 0;
    final presentes = resumen?.presentes ?? 0;
    return _AsistenciaStats(
      porcentaje: resumen?.porcentaje ?? 0,
      presentes: presentes,
      ausentes: resumen?.ausentes ?? (total - presentes).clamp(0, total),
      total: total,
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _NotasCard extends StatelessWidget {
  final NotasCursoEntity notasCurso;
  const _NotasCard({required this.notasCurso});

  // Detecta notas con formato NOTA_1, NOTA_2, NOTA_FINAL, NOTA_1_FINAL, etc.
  // Solo mayúsculas, guion bajo como separador.
  static bool _esNotaDestacada(String nombre) {
    const patternNotaFinal = r'^NOTA(_\d+)*(_FINAL)?$';
    const patternNotaCatedra = r'^NOTA(_\d+)*(_CATEDRA)?(_\d+)?$';
    return RegExp(patternNotaFinal).hasMatch(nombre.trim()) || RegExp(patternNotaCatedra).hasMatch(nombre.trim());
  }

  // Parsea la nota a double; retorna null si no es numérica.
  static double? _parseNota(String nota) {
    if (nota.isEmpty || nota == '-' || nota == 'S/N') return null;
    return double.tryParse(nota.replaceAll(',', '.'));
  }

  // Color según el valor numérico de la nota (escala 1-7 chilena).
  static Color _colorNota(double? valor, ColorScheme colors) {
    if (valor == null) return colors.surfaceContainerHighest;
    if (valor >= 5.0) return colors.primaryContainer;
    if (valor >= 4.0) return colors.secondaryContainer;
    return colors.errorContainer;
  }

  static Color _colorNotaText(double? valor, ColorScheme colors) {
    if (valor == null) return colors.onSurfaceVariant;
    if (valor >= 5.0) return colors.onPrimaryContainer;
    if (valor >= 4.0) return colors.onSecondaryContainer;
    return colors.onErrorContainer;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final notas = notasCurso.notas;

    final finales = notas.where((n) => _esNotaDestacada(n.nombre)).toList();
    final evaluaciones = notas.where((n) => !_esNotaDestacada(n.nombre)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Nota(s) final(es) destacadas ──────────────────────────────────
        if (finales.isNotEmpty) ...[
          ...finales.map((n) {
            final valor = _parseNota(n.nota);
            final bg = _colorNota(valor, colors);
            final fg = _colorNotaText(valor, colors);
            return Card(
              color: bg,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      n.nota,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (evaluaciones.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Evaluaciones',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
              ),
            ),
        ],
        // ── Lista de evaluaciones ──────────────────────────────────────────
        if (evaluaciones.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: evaluaciones.asMap().entries.map((entry) {
                  final i = entry.key;
                  final n = entry.value;
                  final valor = _parseNota(n.nota);
                  final notaColor = _colorNota(valor, colors);
                  final notaTextColor = _colorNotaText(valor, colors);
                  final isLast = i == evaluaciones.length - 1;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: notaColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                n.nota.isEmpty ? '-' : n.nota,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: notaTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: colors.outlineVariant.withValues(alpha: 0.5),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Vistas auxiliares ─────────────────────────────────────────────────────────

class _SinSesionView extends StatelessWidget {
  final VoidCallback onLogin;
  const _SinSesionView({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Inicia sesión para ver tus cursos',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onLogin,
                icon: const Icon(Icons.login),
                label: const Text('Iniciar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCursos extends StatelessWidget {
  final String mensaje;
  final VoidCallback onRetry;
  const _ErrorCursos({required this.mensaje, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  Text(mensaje, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: onRetry,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}