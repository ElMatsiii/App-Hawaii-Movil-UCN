import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/notificaciones_service.dart';
import '../../../../core/utils/json_read.dart';
import '../../../../core/utils/text_normalize.dart';
import '../../../auth/presentation/providers/auth_provider_notif.dart';
import '../../../mis_cursos/data/mis_cursos_datasource.dart';
import '../../data/repositories/horario_repository.dart';
import '../../domain/entities/horario_entity.dart';
import '../../domain/usecases/horario_usecases.dart';

// ── Master (datos estáticos de la API) ───────────────────────────────────────

final masterProvider = FutureProvider<MasterEntity>((ref) async {
  final repo = ref.watch(horarioRepositoryProvider);
  final useCase = GetMasterUseCase(repo);
  final result = await useCase();
  if (result is Success<MasterEntity>) return result.data;
  throw Exception((result as Failure<MasterEntity>).error.message);
});

SemestreEntity? semestreActualOrNull(MasterEntity master) {
  if (master.semestres.isEmpty) return null;
  return master.semestres.firstWhere(
    (s) => s.esActual,
    orElse: () => master.semestres.first,
  );
}

// ── Filtro activo ────────────────────────────────────────────────────────────

final horarioFiltroProvider =
    StateNotifierProvider<HorarioFiltroNotifier, HorarioFiltro>((ref) {
  return HorarioFiltroNotifier();
});

class HorarioFiltroNotifier extends StateNotifier<HorarioFiltro> {
  HorarioFiltroNotifier() : super(const HorarioFiltro());

  void setSemestre(int id) => state = state.copyWith(semestre: id);
  void setArea(int id) => state = state.copyWith(area: id);
  void setProfesor(int id) => state = state.copyWith(profesor: id);

  /// Reemplaza el conjunto completo de cursos seleccionados.
  void setCursos(Set<int> ids) => state = state.copyWith(curso: ids);

  void setSala(int id) => state = state.copyWith(sala: id);
  void setCarrera(int id) => state = state.copyWith(carrera: id);
  void setNivel(int nivel) => state = state.copyWith(semestreC: nivel);
  /// Agrega o quita [dia] del conjunto de días seleccionados (toggle).
  void toggleDia(String dia) {
    final actual = {...state.dias};
    if (actual.contains(dia)) {
      actual.remove(dia);
    } else {
      actual.add(dia);
    }
    state = state.copyWith(dias: actual);
  }
  void setCarreraId(int id) => state = state.copyWith(carreraId: id);

  void reset() => state = const HorarioFiltro();
}

// ── Horario completo del semestre ─────────────────────────────────────────────

final horarioProvider = FutureProvider<List<HorarioItemEntity>>((ref) async {
  var filtro = ref.watch(horarioFiltroProvider);

  // Observar currentUserProvider para que este provider se reconstruya
  // automáticamente cuando cambia la sesión (login / logout).
  ref.watch(currentUserProvider);

  // Si aún no sabemos el estado de auth, devolver vacío sin hacer request.
  final authState = ref.watch(authProvider);
  if (authState is AuthInitial || authState is AuthLoading) {
    return [];
  }

  if (filtro.semestre == -1) {
    final master = await ref.watch(masterProvider.future);
    final semestre = semestreActualOrNull(master);
    if (semestre == null) return [];
    filtro = filtro.copyWith(semestre: semestre.id);
  }

  final repo = ref.watch(horarioRepositoryProvider);
  final useCase = GetHorarioUseCase(repo);
  final filtroApi = HorarioFiltro(
    sala: filtro.sala,
    curso: filtro.curso,
    profesor: filtro.profesor,
    semestre: filtro.semestre,
    semestreC: filtro.semestreC,
    carrera: filtro.carrera,
    area: filtro.area,
  );
  final result = await useCase(filtroApi);

  if (result is! Success<List<HorarioItemEntity>>) {
    throw Exception(
      (result as Failure<List<HorarioItemEntity>>).error.message,
    );
  }

  return result.data;
});

// ── Modo de vista: estudiante o ayudante ─────────────────────────────────────

enum ModoVistaHorario { estudiante, ayudante }

final modoVistaHorarioProvider = StateProvider<ModoVistaHorario>(
  (ref) => ModoVistaHorario.estudiante,
);

// ── IDs de cursos separados por rol ──────────────────────────────────────────

typedef RolesCursos = ({Set<int> comoEstudiante, Set<int> comoProfesor});

final idsCursosPorRolProvider = FutureProvider<RolesCursos>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) {
    return (comoEstudiante: <int>{}, comoProfesor: <int>{});
  }

  final master = await ref.watch(masterProvider.future);

  // Usar el semestre del filtro activo; si no hay filtro (-1), usar el actual.
  final filtro = ref.watch(horarioFiltroProvider);
  final semestreId = filtro.semestre != -1
      ? filtro.semestre
      : (semestreActualOrNull(master)?.id ?? -1);

  if (semestreId == -1) {
    return (comoEstudiante: <int>{}, comoProfesor: <int>{});
  }

  final cursos = await ref.watch(
    misCursosProvider((usuario: currentUser.rut, semestre: semestreId)).future,
  );

  final comoEstudiante = cursos
      .where((c) => !c.esProfesor)
      .expand((c) => c.todosLosIds)
      .toSet();
  final comoProfesor = cursos
      .where((c) => c.esProfesor)
      .expand((c) => c.todosLosIds)
      .toSet();

  return (comoEstudiante: comoEstudiante, comoProfesor: comoProfesor);
});

// ── Provider que indica si el usuario es ayudante (no depende del filtro) ─────
// Siempre usa el semestre actual, así que no se ve afectado por reset() del
// filtro. Evita que los botones "Como estudiante / Como ayudante" desaparezcan
// al limpiar filtros.

final esAyudanteProvider = FutureProvider<bool>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return false;

  final master = await ref.watch(masterProvider.future);
  final semestre = semestreActualOrNull(master);
  if (semestre == null) return false;

  final cursos = await ref.watch(
    misCursosProvider((usuario: currentUser.rut, semestre: semestre.id)).future,
  );

  final tieneComoEstudiante = cursos.any((c) => !c.esProfesor);
  final tieneComoProfesor = cursos.any((c) => c.esProfesor);
  return tieneComoEstudiante && tieneComoProfesor;
});

// ── Provider legacy (mantiene compatibilidad con AsistenciaScreen) ────────────

final idsCursosUsuarioProvider = FutureProvider<Set<int>>((ref) async {
  final roles = await ref.watch(idsCursosPorRolProvider.future);
  return {...roles.comoEstudiante, ...roles.comoProfesor};
});

// ── Programar notificaciones cuando el horario del usuario está listo ─────────

final notificacionesProgramadasProvider = FutureProvider<void>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return;

  final rolesCursos = await ref.watch(idsCursosPorRolProvider.future);
  final horarioItems = await ref.watch(horarioProvider.future);
  final master = await ref.watch(masterProvider.future);

  final itemsUsuario = horarioItems
      .where((i) => rolesCursos.comoEstudiante.contains(i.idCurso))
      .toList();

  if (itemsUsuario.isEmpty) return;

  final notifService = ref.watch(notificacionesServiceProvider);
  await notifService.programarSemana(
    items: itemsUsuario,
    bloques: master.bloques,
  );
});

// ── Texto de búsqueda rápida ─────────────────────────────────────────────────

final horarioSearchProvider = StateProvider<String>((ref) => '');

// ── Toggle "Mis Ramos" (reemplaza la lógica del ':' en el search) ─────────────

final misRamosActivoProvider = StateProvider<bool>((ref) => false);

/// Horario final con búsqueda y filtros locales aplicados.
final horarioFiltradoProvider =
    Provider<AsyncValue<List<HorarioItemEntity>>>((ref) {
  final horario = ref.watch(horarioProvider);
  final search = ref.watch(horarioSearchProvider).trim();
  final filtro = ref.watch(horarioFiltroProvider);
  final misRamosActivo = ref.watch(misRamosActivoProvider);

  if (misRamosActivo) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return const AsyncData([]);
    }

    final rolesCursos = ref.watch(idsCursosPorRolProvider);
    final modo = ref.watch(modoVistaHorarioProvider);
    final nombreUsuario = currentUser.nombre.toLowerCase();
    final carreraUsuario = ref.watch(carreraUsuarioActivaProvider);

    return rolesCursos.when(
      loading: () => const AsyncLoading(),
      error: (e, st) => AsyncError(e, st),
      data: (roles) {
        if (modo == ModoVistaHorario.ayudante) {
          return horario.whenData(
            (items) => _aplicarFiltrosLocales(
              items
                  .where(
                    (i) =>
                        roles.comoProfesor.contains(i.idCurso) &&
                        i.profesor.toLowerCase().contains(nombreUsuario),
                  )
                  .toList(),
              filtro,
              search,
            ),
          );
        }

        return horario.whenData(
          (items) {
            // Mostrar solo si está inscrito Y pertenece a la carrera del usuario.
            final misItems = items.where((i) {
              final inscrito = roles.comoEstudiante.contains(i.idCurso);
              final esDeCarrera = carreraUsuario == null ||
                  i.carreras.any((c) => c.id == carreraUsuario);
              return inscrito && esDeCarrera;
            }).toList();
            return _aplicarFiltrosLocales(misItems, filtro, search);
          },
        );
      },
    );
  }

  return horario.whenData(
    (items) => _aplicarFiltrosLocales(items, filtro, search),
  );
});

List<HorarioItemEntity> _aplicarFiltrosLocales(
  List<HorarioItemEntity> items,
  HorarioFiltro filtro,
  String search,
) {
  var resultado = items;

  if (filtro.dias.isNotEmpty) {
    resultado = resultado.where((i) => filtro.dias.contains(i.dia)).toList();
  }

  if (filtro.carreraId != -1) {
    resultado = resultado
        .where((i) => i.carreras.any((c) => c.id == filtro.carreraId))
        .toList();
  }

  // Filtro de seguridad local: aunque 'curso' ya se envía a la API cuando
  // hay una sola selección, la selección múltiple siempre se resuelve acá,
  // comparando contra el Set completo de ids seleccionados.
  if (filtro.curso.isNotEmpty) {
    resultado = resultado.where((i) => filtro.curso.contains(i.idCurso)).toList();
  }

  if (search.isNotEmpty) {
    final query = normalizarBusqueda(search);
    resultado = resultado.where((item) {
      return normalizarBusqueda(item.curso).contains(query) ||
          normalizarBusqueda(item.profesor).contains(query) ||
          normalizarBusqueda(item.sala).contains(query) ||
          normalizarBusqueda(item.area).contains(query);
    }).toList();
  }

  return resultado;
}

// ── Carreras únicas desde los items cargados ──────────────────────────────────

final carrerasDisponiblesProvider =
    Provider<AsyncValue<List<CarreraEnHorario>>>((ref) {
  return ref.watch(horarioProvider).whenData((items) {
    final seen = <int, CarreraEnHorario>{};
    for (final item in items) {
      for (final carrera in item.carreras) {
        seen.putIfAbsent(carrera.id, () => carrera);
      }
    }
    final lista = seen.values.toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    return lista;
  });
});

// ── Cursos únicos desde los items cargados ─────────────────────────────────────
// A diferencia de m.cursos (catálogo completo de la universidad), esta lista
// sólo contiene los cursos que efectivamente están en el horario cargado, es
// decir, los que pertenecen a alguna de las carreras/áreas disponibles. Evita
// que el filtro de curso ofrezca opciones que después no traen resultados.

final cursosDisponiblesProvider =
    Provider<AsyncValue<List<CursoEntity>>>((ref) {
  return ref.watch(horarioProvider).whenData((items) {
    final seen = <int, CursoEntity>{};
    for (final item in items) {
      seen.putIfAbsent(
        item.idCurso,
        () => CursoEntity(id: item.idCurso, nombre: item.curso),
      );
    }
    final lista = seen.values.toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    return lista;
  });
});

// ── Provider auxiliar (carrera del usuario) ───────────────────────────────────

// ── Carrera activa del usuario (seteada al login, limpiada al logout) ─────────
// Separada de horarioFiltroProvider para no disparar re-requests a la API.
final carreraUsuarioActivaProvider = StateProvider<int?>((ref) => null);

final carreraUsuarioProvider = FutureProvider<int?>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return null;

  final master = await ref.watch(masterProvider.future);
  final semestre = semestreActualOrNull(master);
  if (semestre == null) return null;

  final dio = ref.watch(dioClientProvider);
  try {
    final response = await dio.get<Map<String, dynamic>>(
      ApiConstants.carreraUsuario,
      queryParameters: <String, dynamic>{'s': semestre.id},
    );
    final data = response.data;
    if (data == null) return null;
    final id = readInt(data['id'], fallback: -1);
    return id == -1 ? null : id;
  } catch (_) {
    return null;
  }
});