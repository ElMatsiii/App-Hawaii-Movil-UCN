import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/asistencia/presentation/screens/asistencia_screen.dart';
import '../../features/asistencia/presentation/screens/asistencia_test_screen.dart';
import '../../features/auth/presentation/providers/auth_provider_notif.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/horario/presentation/screens/horario_screen_notif.dart';
import '../../features/mis_cursos/presentation/screens/mis_cursos_screen.dart';
import '../../shared/widgets/main_scaffold.dart';

/// Rutas que requieren sesión activa.
const _rutasPrivadas = {AppRoutes.misCursos, AppRoutes.asistencia};

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRouterNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.horario,
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;
      final isLogin = location == AppRoutes.login;

      // Todavía cargando — no redirigir
      if (authState is AuthInitial || authState is AuthLoading) return null;

      final autenticado = authState is AuthAuthenticated;

      // Si ya está autenticado y va al login → mis cursos
      if (isLogin && autenticado) return AppRoutes.misCursos;

      // Si no está autenticado e intenta una ruta privada → login
      if (!autenticado && _rutasPrivadas.contains(location)) {
        return AppRoutes.login;
      }

      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainScaffold(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.horario,
                name: AppRoutes.horarioName,
                builder: (_, __) => const HorarioScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.misCursos,
                name: AppRoutes.misCursosName,
                builder: (_, __) => const MisCursosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.asistencia,
                name: AppRoutes.asistenciaName,
                builder: (_, __) => const AsistenciaScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.asistenciaTest,
        name: AppRoutes.asistenciaTestName,
        builder: (_, __) => const AsistenciaTestScreen(),
      ),
    ],
  );
});

/// Notifier que avisa al router cuando cambia el estado de auth.
class _AuthRouterNotifier extends ChangeNotifier {
  final Ref _ref;
  _AuthRouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}

abstract class AppRoutes {
  static const horario = '/horario';
  static const horarioName = 'horario';
  static const misCursos = '/mis-cursos';
  static const misCursosName = 'mis-cursos';
  static const asistencia = '/asistencia';
  static const asistenciaName = 'asistencia';
  static const asistenciaTest = '/asistencia/test';
  static const asistenciaTestName = 'asistencia-test';
  static const login = '/login';
  static const loginName = 'login';
}
