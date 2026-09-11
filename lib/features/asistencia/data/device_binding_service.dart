import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para la gestion y verificacion de Device Binding (registro por dispositivo).
///
/// Segun la especificacion del sistema de asistencia Hawaii UCN (Seccion 5.3):
/// 1. Cada dispositivo genera y almacena un identificador unico persistente.
/// 2. Las asistencias solo son aceptadas si el Device ID coincide con el vinculado al usuario.
/// 3. Solo se permite un dispositivo activo por cuenta.
class DeviceBindingService {
  DeviceBindingService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  static const _keyDeviceId = 'hawaii_ucn_device_id';
  static const _prefixBinding = 'hawaii_ucn_binding_';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Obtiene o genera el Device ID unico y persistente de este dispositivo.
  Future<String> getDeviceId() async {
    final prefs = await _getPrefs();
    var id = prefs.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      id = _generarNuevoDeviceId();
      await prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  /// Genera un identificador representativo para el dispositivo.
  String _generarNuevoDeviceId() {
    final random = Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final token = List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
    return 'UCN-DEV-$timestamp-$token';
  }

  /// Verifica si el dispositivo actual esta autorizado para el [rut] del estudiante.
  Future<bool> estaDispositivoVinculado(String rut) async {
    final prefs = await _getPrefs();
    final rutKey = '$_prefixBinding${rut.trim().toUpperCase()}';
    final dispositivoRegistrado = prefs.getString(rutKey);

    final actualId = await getDeviceId();

    // Si aun no hay dispositivo vinculado para este RUT en pruebas, se vincula automaticamente
    if (dispositivoRegistrado == null) {
      await prefs.setString(rutKey, actualId);
      return true;
    }

    return dispositivoRegistrado == actualId;
  }

  /// Vincula explícitamente el dispositivo actual al [rut] del estudiante.
  Future<void> vincularDispositivo(String rut) async {
    final prefs = await _getPrefs();
    final actualId = await getDeviceId();
    final rutKey = '$_prefixBinding${rut.trim().toUpperCase()}';
    await prefs.setString(rutKey, actualId);
  }

  /// Desvincula el dispositivo para simular intentos desde otros dispositivos.
  Future<void> simularDispositivoAjeno(String rut) async {
    final prefs = await _getPrefs();
    final rutKey = '$_prefixBinding${rut.trim().toUpperCase()}';
    await prefs.setString(rutKey, 'UCN-DEV-OTRO-DISPOSITIVO-DESCONOCIDO');
  }

  /// Restablece la vinculacion para pruebas.
  Future<void> resetearVinculacion(String rut) async {
    final prefs = await _getPrefs();
    final rutKey = '$_prefixBinding${rut.trim().toUpperCase()}';
    await prefs.remove(rutKey);
  }
}
