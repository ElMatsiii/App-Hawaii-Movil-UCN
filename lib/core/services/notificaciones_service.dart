import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/horario/domain/entities/horario_entity.dart';
import '../utils/text_normalize.dart';

final notificacionesServiceProvider = Provider<NotificacionesService>((ref) {
  return NotificacionesService();
});

class NotificacionesService {
  static const _channelId = 'tongoy_clases';
  static const _channelName = 'Clases UCN';
  static const _channelDesc = 'Avisos de clases proximas a iniciar';
  static const _minutosAntes = 15;
  static const _zonaHoraria = 'America/Santiago';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_zonaHoraria));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  Future<void> programarSemana({
    required List<HorarioItemEntity> items,
    required List<BloqueEntity> bloques,
  }) async {
    await _plugin.cancelAll();

    final ahora = tz.TZDateTime.now(tz.local);
    final lunesDeEstaSemana = _lunesDe(ahora);

    final horarioBloque = <String, _HoraBloque>{};
    for (final bloque in bloques) {
      final hora = _parsearHorario(bloque.horario);
      if (hora != null) {
        horarioBloque[bloque.nombre] = hora;
      }
    }

    const offsetDia = {
      'Lunes': 0,
      'Martes': 1,
      'Miercoles': 2,
      'Jueves': 3,
      'Viernes': 4,
      'Sabado': 5,
    };

    var notifId = 0;

    for (final item in items) {
      final offset = offsetDia[item.dia];
      final hora = horarioBloque[item.bloque];
      if (offset == null || hora == null) continue;

      final diaClase = lunesDeEstaSemana.add(Duration(days: offset));
      final fechaClase = tz.TZDateTime(
        tz.local,
        diaClase.year,
        diaClase.month,
        diaClase.day,
        hora.hora,
        hora.minuto,
      );

      final fechaNotif =
          fechaClase.subtract(const Duration(minutes: _minutosAntes));
      if (fechaNotif.isBefore(ahora)) continue;

      final nombreCorto = nombreCursoCorto(item.curso);

      await _plugin.zonedSchedule(
        notifId++,
        'Clase en $_minutosAntes minutos',
        '$nombreCorto - Bloque ${item.bloque} - ${item.sala}',
        fechaNotif,
        _detalles(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelarTodas() => _plugin.cancelAll();

  NotificationDetails _detalles() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  tz.TZDateTime _lunesDe(tz.TZDateTime fecha) {
    final diasDesdeElLunes = fecha.weekday - 1;
    return tz.TZDateTime(
      tz.local,
      fecha.year,
      fecha.month,
      fecha.day,
    ).subtract(Duration(days: diasDesdeElLunes));
  }

  _HoraBloque? _parsearHorario(String? horario) {
    if (horario == null) return null;
    final partes = horario.split(' - ');
    if (partes.isEmpty) return null;
    final tiempoInicio = partes[0].trim().split(':');
    if (tiempoInicio.length < 2) return null;
    final hora = int.tryParse(tiempoInicio[0]);
    final minuto = int.tryParse(tiempoInicio[1]);
    if (hora == null || minuto == null) return null;
    return _HoraBloque(hora, minuto);
  }
}

class _HoraBloque {
  const _HoraBloque(this.hora, this.minuto);

  final int hora;
  final int minuto;
}
