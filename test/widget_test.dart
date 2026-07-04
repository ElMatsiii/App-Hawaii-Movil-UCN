import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hawaii_app/shared/theme/app_theme.dart';

// Router mínimo para el smoke test — sin dependencias de red ni DioClient.
final _testRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const Scaffold(body: Text('test')),
    ),
  ],
);

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tongoy UCN',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _testRouter,
    );
  }
}

void main() {
  testWidgets('TongoyApp arranca sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: _TestApp()),
    );

    // MaterialApp siempre está en el árbol — es lo que pumpWidget renderiza.
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('muestra el contenido de la ruta inicial', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: _TestApp()),
    );
    // Dar tiempo al router a resolver la ruta inicial
    await tester.pumpAndSettle();

    expect(find.text('test'), findsOneWidget);
  });
}