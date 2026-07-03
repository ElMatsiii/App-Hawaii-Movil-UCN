import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/settings/accessibility_settings.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/accessibility_settings_button.dart';
import '../../../../shared/widgets/logout_button.dart';
import '../../../auth/presentation/providers/auth_provider_notif.dart';
import '../../../horario/presentation/providers/horario_provider_notif.dart';
import '../../../mis_cursos/data/mis_cursos_datasource.dart';
import '../../../mis_cursos/data/notas_datasource.dart';
import '../../../mis_cursos/domain/entities/curso_usuario_entity.dart';
import '../../data/asistencia_datasource.dart';
import '../../domain/qr_asistencia_validator.dart';

part 'asistencia_course_list.dart';
part 'asistencia_detail.dart';
part 'qr_scanner_sheet.dart';

//pantalla principal

class AsistenciaScreen extends ConsumerStatefulWidget {
  const AsistenciaScreen({super.key});

  @override
  ConsumerState<AsistenciaScreen> createState() => _AsistenciaScreenState();
}

class _AsistenciaScreenState extends ConsumerState<AsistenciaScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState is! AuthAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 12),
              const Text('Inicia sesion para ver la asistencia'),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push('/login'),
                icon: const Icon(Icons.login),
                label: const Text('Iniciar sesion'),
              ),
            ],
          ),
        ),
      );
    }

    final usuario = authState.usuario;
    final master = ref.watch(masterProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.assignment_outlined),
          tooltip: 'Justificar asistencia',
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Justificar asistencia'),
                content: const Text(
                  'Serás redirigido al formulario oficial de justificación de asistencia de la UCN.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Abrir formulario'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      launchUrl(
                        Uri.parse('https://docs.google.com/forms/d/e/1FAIpQLScgGuPfQU-W5yYPEU-5M1EcgO0fYskyEjelR2Si434IuTHnuw/viewform'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        title: const Text('Asistencia'),
        actions: const [
          AccessibilitySettingsButton(),
          LogoutButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirEscaner(context),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Pasar asistencia'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Solo invalidamos master y cursos — las asistencias por curso se
          // recargan on-demand cuando el usuario abre el detalle, evitando
          // N requests simultáneos al refrescar.
          ref..invalidate(masterProvider)
          ..invalidate(misCursosProvider);
        },
        child: master.when(
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
          data: (masterData) {
            final semestreActual = semestreActualOrNull(masterData);
            if (semestreActual == null) {
              return const Center(child: Text('No hay semestres disponibles'));
            }

            return _ListaCursos(
              usuario: usuario.rut,
              semestreId: semestreActual.id,
              onCursoTap: (curso) => _mostrarDetalle(context, curso, semestreActual.id, usuario.rut),
            );
          },
        ),
      ),
    );
  }

  void _mostrarDetalle(
    BuildContext context,
    CursoUsuarioEntity curso,
    int semestreId,
    String rutEstudiante,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AsistenciaDetalleSheet(
        curso: curso,
        semestreId: semestreId,
        rutEstudiante: rutEstudiante,
      ),
    );
  }

  void _abrirEscaner(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _QrScannerSheet(),
    );
  }
}


AttendanceStateColors _attendanceColors(BuildContext context, WidgetRef ref) {
  final colorBlindMode =
      ref.watch(accessibilitySettingsProvider).colorBlindMode;
  return AttendanceStateColors.resolve(
    brightness: Theme.of(context).brightness,
    colorBlindMode: colorBlindMode,
  );
}

Color _stateContainer(Color color, Color surface, [double alpha = 0.16]) {
  return Color.alphaBlend(color.withValues(alpha: alpha), surface);
}

Color _readableStateText(Color color, Brightness brightness) {
  if (brightness == Brightness.light && color.computeLuminance() > 0.35) {
    return const Color(0xFF3D2A00);
  }
  return color;
}