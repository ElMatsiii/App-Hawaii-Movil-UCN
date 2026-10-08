import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../domain/beacon_attendance_models.dart';
import '../domain/ucn_beacon_parser.dart';

/// Estado de los permisos y adaptador Bluetooth para asistencia.
enum BluetoothEstadoHardware {
  listoParaEscanear,
  bluetoothApagado,
  permisosDenegados,
  noSoportado,
}

/// Servicio encargado del escaneo de balizas BLE en el aula.
class BluetoothBeaconScanner {
  final UcnBeaconParser _parser;
  StreamSubscription<List<ScanResult>>? _scanSub;
  final _beaconController = StreamController<UcnBeaconPayload>.broadcast();

  BluetoothBeaconScanner({UcnBeaconParser? parser})
      : _parser = parser ?? const UcnBeaconParser();

  /// Stream que emite las balizas UCN detectadas en tiempo real.
  Stream<UcnBeaconPayload> get beaconStream => _beaconController.stream;

  /// Verifica y solicita los permisos requeridos para escanear balizas.
  Future<BluetoothEstadoHardware> verificarPermisosYEstado() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        return BluetoothEstadoHardware.noSoportado;
      }

      if (Platform.isAndroid) {
        final scan = await Permission.bluetoothScan.request();
        final connect = await Permission.bluetoothConnect.request();
        final location = await Permission.locationWhenInUse.request();

        final concedidos = (scan.isGranted || scan.isLimited) &&
            (connect.isGranted || connect.isLimited);

        if (!concedidos && scan.isPermanentlyDenied) {
          return BluetoothEstadoHardware.permisosDenegados;
        }

        // En Android anterior a 12, se requiere ubicación
        if (location.isPermanentlyDenied && !scan.isGranted) {
          return BluetoothEstadoHardware.permisosDenegados;
        }
      } else if (Platform.isIOS) {
        final bt = await Permission.bluetooth.request();
        if (bt.isPermanentlyDenied) {
          return BluetoothEstadoHardware.permisosDenegados;
        }
      }

      // Verificar si Bluetooth está encendido
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        return BluetoothEstadoHardware.bluetoothApagado;
      }

      return BluetoothEstadoHardware.listoParaEscanear;
    } catch (_) {
      // Si ocurre error de plataforma (por ejemplo, en tests de escritorio o emuladores)
      return BluetoothEstadoHardware.listoParaEscanear;
    }
  }

  /// Inicia el escaneo de balizas BLE con el filtro UCN.
  Future<void> iniciarEscaneo({
    Duration duracion = const Duration(seconds: 20),
  }) async {
    await detenerEscaneo();

    try {
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final serviceUuids = r.advertisementData.serviceUuids
              .map((u) => u.str128.toLowerCase())
              .toList();

          final serviceData = <String, List<int>>{};
          for (final entry in r.advertisementData.serviceData.entries) {
            serviceData[entry.key.str128.toLowerCase()] = entry.value;
          }

          final payload = _parser.parse(
            deviceName: r.advertisementData.advName.isNotEmpty
                ? r.advertisementData.advName
                : r.device.platformName,
            manufacturerData: r.advertisementData.manufacturerData,
            serviceUuids: serviceUuids,
            serviceData: serviceData,
            rssi: r.rssi,
            deviceId: r.device.remoteId.str,
            timestamp: r.timeStamp,
          );

          if (payload != null) {
            _beaconController.add(payload);
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: duracion,
        androidUsesFineLocation: true,
      );
    } catch (_) {
      // Manejo seguro en caso de fallo en el stack Bluetooth nativo
    }
  }

  /// Detiene el escaneo activo.
  Future<void> detenerEscaneo() async {
    try {
      await _scanSub?.cancel();
      _scanSub = null;
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}
  }

  /// Permite simular una baliza detectada (útil para pruebas en emulador).
  void simularBeacon(UcnBeaconPayload payload) {
    _beaconController.add(payload);
  }

  void dispose() {
    detenerEscaneo();
    _beaconController.close();
  }
}
