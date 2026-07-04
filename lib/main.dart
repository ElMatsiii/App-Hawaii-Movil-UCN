import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/services/notificaciones_service.dart';
import 'shared/settings/accessibility_settings.dart';
import 'shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La app está diseñada solo para vertical: bloqueamos horizontal (normal
  // e invertido) para que no rote al girar el celular.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await DioClient.init();
  final prefs = await SharedPreferences.getInstance();

  // Inicializar el servicio de notificaciones locales
  final notifService = NotificacionesService();
  await notifService.init();

  runApp(
    ProviderScope(
      overrides: [
        // Inyectamos la instancia ya inicializada
        notificacionesServiceProvider.overrideWithValue(notifService),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const TongoyApp(),
    ),
  );
}

class TongoyApp extends ConsumerWidget {
  const TongoyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(accessibilitySettingsProvider);
    return MaterialApp.router(
      title: 'Tongoy UCN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(settings.seedColorValue),
      darkTheme: AppTheme.dark(settings.seedColorValue),
      themeMode: settings.themeMode,
      routerConfig: router,
      builder: (context, child) {
        final systemScale = MediaQuery.textScalerOf(context).scale(1);
        final scale = (systemScale * settings.fontScale).clamp(0.9, 1.6);
        Widget content = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale.toDouble()),
          ),
          child: child ?? const SizedBox.shrink(),
        );
        if (settings.colorBlindMode) {
          // Matriz de simulación Okabe-Ito (deuteranopía) aplicada globalmente.
          content = ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.625, 0.375, 0,     0, 0,
              0.700, 0.300, 0,     0, 0,
              0,     0.300, 0.700, 0, 0,
              0,     0,     0,     1, 0,
            ]),
            child: content,
          );
        }
        return content;
      },
    );
  }
}