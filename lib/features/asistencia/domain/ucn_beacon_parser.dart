import 'dart:convert';
import 'dart:typed_data';
import 'beacon_attendance_models.dart';

/// Decodificador y validador de paquetes BLE (Advertising) para balizas UCN Hawaii.
///
/// Lógica pura testeable sin dependencias de hardware.
/// Soporta múltiples formatos de baliza para máxima compatibilidad:
/// 1. Manufacturer Data UCN (`0x5543` / "UC"): formato binario optimizado con cursoId, token, bloque.
/// 2. Local Name: `UCN-ASIST-<cursoId>-<token>`.
/// 3. Service Data UCN (`0xA515` o `0000a515-beef-4c8d-9e9a-24e67e967520`).
/// 4. iBeacon UCN (UUID `e2c56db5-dffb-48d2-b060-d0f5a71096e0`, Major = cursoId, Minor = token).
class UcnBeaconParser {
  const UcnBeaconParser();

  /// UUID de servicio oficial de Asistencia UCN (128 bits).
  static const String serviceUuid = '0000a515-beef-4c8d-9e9a-24e67e967520';

  /// UUID de servicio corto (16 bits).
  static const String shortServiceUuid = 'a515';

  /// ID de fabricante asignado a UCN (ASCII para 'U' y 'C' = 0x5543 = 21827).
  static const int ucnManufacturerId = 0x5543;

  /// Prefijo de nombre de dispositivo para anuncios BLE.
  static const String namePrefix = 'UCN-ASIST-';

  /// UUID de proximidad para formato iBeacon UCN.
  static const String ibeaconProximityUuid =
      'e2c56db5-dffb-48d2-b060-d0f5a71096e0';

  /// Intenta decodificar un anuncio BLE recibido.
  ///
  /// Retorna un [UcnBeaconPayload] si los datos corresponden a una clase UCN válida,
  /// o `null` si es un dispositivo ajeno o datos corruptos.
  UcnBeaconPayload? parse({
    required int rssi,
    String? deviceName,
    Map<int, List<int>>? manufacturerData,
    List<String>? serviceUuids,
    Map<String, List<int>>? serviceData,
    String? deviceId,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();

    // 1. Intentar decodificar por Manufacturer Data UCN (Formato principal)
    if (manufacturerData != null &&
        manufacturerData.containsKey(ucnManufacturerId)) {
      final bytes = manufacturerData[ucnManufacturerId]!;
      final parsed = _parseUcnManufacturerBytes(bytes, rssi, now, deviceId);
      if (parsed != null) return parsed;
    }

    // 2. Intentar decodificar por formato iBeacon (0x004C = Apple Company ID)
    if (manufacturerData != null && manufacturerData.containsKey(0x004C)) {
      final bytes = manufacturerData[0x004C]!;
      final parsed = _parseIBeaconBytes(bytes, rssi, now, deviceId);
      if (parsed != null) return parsed;
    }

    // 3. Intentar decodificar por Service Data
    if (serviceData != null) {
      for (final entry in serviceData.entries) {
        final keyLower = entry.key.toLowerCase();
        if (keyLower.contains('a515')) {
          final parsed = _parseServiceDataBytes(entry.value, rssi, now, deviceId);
          if (parsed != null) return parsed;
        }
      }
    }

    // 4. Intentar decodificar por Nombre de Dispositivo Local Name
    if (deviceName != null && deviceName.isNotEmpty) {
      final parsed = _parseDeviceName(deviceName, rssi, now, deviceId);
      if (parsed != null) return parsed;
    }

    return null;
  }

  /// Decodifica payload binario UCN:
  /// Bytes:
  /// [0, 1]: 'N', '1' (0x4E, 0x31) -> Magic header
  /// [2, 3]: cursoId (uint16 big endian)
  /// [4, 7]: token de sesión (4 bytes UTF-8 o uint32)
  /// [8]: bloque (opcional)
  /// [9]: semestreId (opcional)
  UcnBeaconPayload? _parseUcnManufacturerBytes(
    List<int> bytes,
    int rssi,
    DateTime timestamp,
    String? deviceId,
  ) {
    if (bytes.length < 4) return null;

    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));

    // Validar encabezado si tiene al menos 4 bytes y contiene 'N', '1'
    int offset = 0;
    if (bytes.length >= 6 && bytes[0] == 0x4E && bytes[1] == 0x31) {
      offset = 2;
    }

    if (bytes.length < offset + 2) return null;
    final cursoId = byteData.getUint16(offset);
    offset += 2;

    String token = 'UCN';
    if (bytes.length >= offset + 4) {
      // Leer 4 bytes de token como caracteres ASCII o hex
      final tokenBytes = bytes.sublist(offset, offset + 4);
      final isAscii = tokenBytes.every((b) => b >= 32 && b <= 126);
      if (isAscii) {
        token = utf8.decode(tokenBytes);
      } else {
        token = tokenBytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join()
            .toUpperCase();
      }
      offset += 4;
    }

    String? bloque;
    if (bytes.length > offset) {
      final bloqueNum = bytes[offset];
      if (bloqueNum > 0) {
        bloque = '$bloqueNum-${bloqueNum + 1}';
      }
      offset += 1;
    }

    int? semestreId;
    if (bytes.length > offset) {
      semestreId = bytes[offset];
    }

    return UcnBeaconPayload(
      cursoId: cursoId,
      token: token,
      bloque: bloque,
      semestreId: semestreId,
      rssi: rssi,
      timestamp: timestamp,
      deviceId: deviceId,
    );
  }

  /// Decodifica formato iBeacon estándar:
  /// Bytes:
  /// [0, 1]: 0x02, 0x15 (Sub-tipo iBeacon y longitud 21)
  /// [2..17]: Proximity UUID (16 bytes)
  /// [18, 19]: Major (uint16 Big Endian) -> Usado como cursoId
  /// [20, 21]: Minor (uint16 Big Endian) -> Usado como token
  /// [22]: TxPower (int8)
  UcnBeaconPayload? _parseIBeaconBytes(
    List<int> bytes,
    int rssi,
    DateTime timestamp,
    String? deviceId,
  ) {
    if (bytes.length < 22) return null;
    if (bytes[0] != 0x02 || bytes[1] != 0x15) return null;

    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));

    // Extraer UUID
    final uuidBytes = bytes.sublist(2, 18);
    final hexUuid = uuidBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toLowerCase();

    final cleanTargetUuid =
        ibeaconProximityUuid.replaceAll('-', '').toLowerCase();

    // Solo aceptar si coincide con el UUID de UCN
    if (hexUuid != cleanTargetUuid) return null;

    final major = byteData.getUint16(18); // cursoId
    final minor = byteData.getUint16(20); // token

    return UcnBeaconPayload(
      cursoId: major,
      token: minor.toString(),
      rssi: rssi,
      timestamp: timestamp,
      deviceId: deviceId,
    );
  }

  /// Decodifica datos de servicio:
  /// Formato: cursoId (2 bytes) + token (hasta 6 bytes)
  UcnBeaconPayload? _parseServiceDataBytes(
    List<int> bytes,
    int rssi,
    DateTime timestamp,
    String? deviceId,
  ) {
    if (bytes.length < 2) return null;
    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
    final cursoId = byteData.getUint16(0);

    String token = 'UCN';
    if (bytes.length > 2) {
      final tokenBytes = bytes.sublist(2);
      try {
        token = utf8.decode(tokenBytes);
      } catch (_) {
        token = tokenBytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join()
            .toUpperCase();
      }
    }

    return UcnBeaconPayload(
      cursoId: cursoId,
      token: token,
      rssi: rssi,
      timestamp: timestamp,
      deviceId: deviceId,
    );
  }

  /// Decodifica a partir del nombre anunciado:
  /// "UCN-ASIST-<cursoId>-<token>" o "UCN-ASIST-<cursoId>"
  UcnBeaconPayload? _parseDeviceName(
    String name,
    int rssi,
    DateTime timestamp,
    String? deviceId,
  ) {
    if (!name.startsWith(namePrefix)) return null;

    final parts = name.substring(namePrefix.length).split('-');
    if (parts.isEmpty) return null;

    final cursoId = int.tryParse(parts[0]);
    if (cursoId == null) return null;

    final token = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : 'DEFAULT';

    return UcnBeaconPayload(
      cursoId: cursoId,
      token: token,
      rssi: rssi,
      timestamp: timestamp,
      deviceId: deviceId,
    );
  }
}
