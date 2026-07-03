import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/widgets/accessibility_settings_button.dart';
import '../../../../shared/widgets/logout_button.dart';
import '../../../auth/presentation/providers/auth_provider_notif.dart';
import '../../domain/entities/horario_entity.dart';
import '../providers/horario_provider_notif.dart';
import '../widgets/horario_filtros_sheet.dart';
import '../widgets/horario_grilla.dart';
import '../widgets/horario_search_bar.dart';

class HorarioScreen extends ConsumerStatefulWidget {
  const HorarioScreen({super.key});

  @override
  ConsumerState<HorarioScreen> createState() => _HorarioScreenState();
}

class _HorarioScreenState extends ConsumerState<HorarioScreen> {
  final _searchController = TextEditingController();
  bool _misRamosActivado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState is AuthAuthenticated && !_misRamosActivado) {
        _activarMisRamos();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _activarMisRamos() async {
    _misRamosActivado = true;
    _searchController.text = ':';
    ref.read(horarioSearchProvider.notifier).state = ':';

    // Pre-poblar el filtro de carrera con la carrera del usuario logueado.
    final carreraId = await ref.read(carreraUsuarioProvider.future);
    if (carreraId != null && mounted) {
      ref.read(horarioFiltroProvider.notifier).setCarreraId(carreraId);
    }
  }

  void _desactivarMisRamos() {
    _misRamosActivado = false;
    _searchController.clear();
    ref.read(horarioSearchProvider.notifier).state = '';
    ref.read(horarioFiltroProvider.notifier).reset();
    ref.read(modoVistaHorarioProvider.notifier).state =
        ModoVistaHorario.estudiante;
  }

  @override
  Widget build(BuildContext context) {
    final horario = ref.watch(horarioFiltradoProvider);
    final master = ref.watch(masterProvider);
    ref.watch(idsCursosPorRolProvider);
    // esAyudanteProvider usa siempre el semestre actual, sin depender del
    // filtro activo. Así los botones no desaparecen al limpiar filtros.
    final esAyudante =
        ref.watch(esAyudanteProvider).valueOrNull ?? false;
    final modo = ref.watch(modoVistaHorarioProvider);
    final search = ref.watch(horarioSearchProvider);
    final modoToggleVisible = esAyudante && search == ':';

    ref
      ..listen<AuthState>(authProvider, (previous, next) {
        if (next is AuthAuthenticated && !_misRamosActivado) {
          _activarMisRamos();
        } else if (next is AuthUnauthenticated || next is AuthError) {
          if (_misRamosActivado) _desactivarMisRamos();
        }
      })

      // Programar notificaciones cuando el horario del usuario esté listo
      ..listen(notificacionesProgramadasProvider, (_, next) {
        // El provider se encarga de todo; solo escuchamos para activarlo
      });

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Información',
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Instructivos UCN'),
                    content: const Text(
                      'Accede a los instructivos de la Escuela de Ingeniería de la UCN.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cerrar'),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Abrir'),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          launchUrl(
                            Uri.parse('https://losvilos.ucn.cl/InstructivosEscuelaIngenieria/'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Filtros',
              onPressed: () => _mostrarFiltros(context, ref),
            ),
          ],
        ),
        leadingWidth: 96,
        title: const Text('Horario'),
        actions: const [
          AccessibilitySettingsButton(),
          LogoutButton(),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(modoToggleVisible ? 108 : 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: HorarioSearchBar(
                  controller: _searchController,
                  onChanged: (text) =>
                      ref.read(horarioSearchProvider.notifier).state = text,
                ),
              ),
              if (modoToggleVisible)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SegmentedButton<ModoVistaHorario>(
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(
                        value: ModoVistaHorario.estudiante,
                        icon: Icon(Icons.person_outline, size: 16),
                        label: Text('Como estudiante'),
                      ),
                      ButtonSegment(
                        value: ModoVistaHorario.ayudante,
                        icon: Icon(Icons.co_present_outlined, size: 16),
                        label: Text('Como ayudante'),
                      ),
                    ],
                    selected: {modo},
                    onSelectionChanged: (s) => ref
                        .read(modoVistaHorarioProvider.notifier)
                        .state = s.first,
                  ),
                ),
            ],
          ),
        ),
      ),
      body: master.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          mensaje: e.toString(),
          onRetry: () => ref.invalidate(masterProvider),
        ),
        data: (masterData) => _HorarioBody(
          horario: horario,
          master: masterData,
          onRetry: () => ref.invalidate(horarioProvider),
        ),
      ),
    );
  }

  void _mostrarFiltros(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const HorarioFiltrosSheet(),
    );
  }
}

// ── Cuerpo con la grilla ──────────────────────────────────────────────────────

class _HorarioBody extends StatelessWidget {
  final AsyncValue<List<HorarioItemEntity>> horario;
  final MasterEntity master;
  final VoidCallback onRetry;

  const _HorarioBody({
    required this.horario,
    required this.master,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return horario.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(mensaje: e.toString(), onRetry: onRetry),
      data: (items) => items.isEmpty
          ? const _EmptyView()
          : HorarioGrilla(items: items, master: master),
    );
  }
}

// ── Vistas auxiliares ─────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String mensaje;
  final VoidCallback onRetry;

  const _ErrorView({required this.mensaje, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: colors.error),
            const SizedBox(height: 16),
            Text(
              'No se pudo cargar el horario',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin resultados',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Ajusta los filtros para ver el horario',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}