import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider_notif.dart';
import '../providers/shell_navigation_provider.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell shell;
  const MainScaffold({required this.shell, super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIndex());
  }

  @override
  void didUpdateWidget(covariant MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIndex());
  }

  void _syncIndex() {
    if (!mounted) return;
    final current = ref.read(currentShellIndexProvider);
    if (current != widget.shell.currentIndex) {
      ref.read(currentShellIndexProvider.notifier).state =
          widget.shell.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final autenticado = authState is AuthAuthenticated;

    if (autenticado) {
      return _ScaffoldAutenticado(shell: widget.shell);
    } else {
      return _ScaffoldInvitado(shell: widget.shell);
    }
  }
}

// ── Navbar cuando hay sesión: 3 destinos normales ─────────────────────────────

class _ScaffoldAutenticado extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _ScaffoldAutenticado({required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Horario',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Mis Cursos',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Asistencia',
          ),
        ],
      ),
    );
  }
}

// ── Navbar cuando no hay sesión: Horario + Iniciar sesión ─────────────────────

class _ScaffoldInvitado extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _ScaffoldInvitado({required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        // El invitado solo puede estar en el branch 0 (Horario).
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 0) {
            shell.goBranch(0, initialLocation: true);
          } else {
            context.go('/login');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Horario',
          ),
          NavigationDestination(
            icon: Icon(Icons.login_outlined),
            selectedIcon: Icon(Icons.login),
            label: 'Iniciar sesión',
          ),
        ],
      ),
    );
  }
}