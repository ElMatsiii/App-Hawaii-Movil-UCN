import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/result.dart';
import '../../../mis_cursos/domain/entities/curso_usuario_entity.dart';
import '../../data/asistencia_datasource.dart';
import '../../data/bluetooth_beacon_scanner.dart';
import '../../domain/beacon_attendance_models.dart';

enum BluetoothAsistenciaStatus {
  idle,
  checkingPermissions,
  bluetoothOff,
  permissionsDenied,
  scanning,
  beaconFound,
  registering,
  success,
  error,
}

class BluetoothAsistenciaState {
  final BluetoothAsistenciaStatus status;
  final UcnBeaconPayload? payload;
  final CursoUsuarioEntity? cursoCoincidente;
  final AsistenciaRegistroResult? resultado;
  final String? mensajeError;
  final bool esModoSimulado;

  const BluetoothAsistenciaState({
    required this.status,
    this.payload,
    this.cursoCoincidente,
    this.resultado,
    this.mensajeError,
    this.esModoSimulado = false,
  });

  factory BluetoothAsistenciaState.initial() => const BluetoothAsistenciaState(
        status: BluetoothAsistenciaStatus.idle,
      );

  BluetoothAsistenciaState copyWith({
    BluetoothAsistenciaStatus? status,
    UcnBeaconPayload? payload,
    CursoUsuarioEntity? cursoCoincidente,
    AsistenciaRegistroResult? resultado,
    String? mensajeError,
    bool? esModoSimulado,
  }) {
    return BluetoothAsistenciaState(
      status: status ?? this.status,
      payload: payload ?? this.payload,
      cursoCoincidente: cursoCoincidente ?? this.cursoCoincidente,
      resultado: resultado ?? this.resultado,
      mensajeError: mensajeError ?? this.mensajeError,
      esModoSimulado: esModoSimulado ?? this.esModoSimulado,
    );
  }
}

final bluetoothScannerProvider = Provider<BluetoothBeaconScanner>((ref) {
  final scanner = BluetoothBeaconScanner();
  ref.onDispose(() => scanner.dispose());
  return scanner;
});

final bluetoothAsistenciaProvider = StateNotifierProvider.autoDispose<
    BluetoothAsistenciaNotifier, BluetoothAsistenciaState>((ref) {
  final scanner = ref.watch(bluetoothScannerProvider);
  final dataSource = ref.watch(asistenciaEstudianteRemoteProvider);
  return BluetoothAsistenciaNotifier(scanner, dataSource);
});

class BluetoothAsistenciaNotifier
    extends StateNotifier<BluetoothAsistenciaState> {
  final BluetoothBeaconScanner _scanner;
  final AsistenciaEstudianteRemoteDataSource _dataSource;
  StreamSubscription<UcnBeaconPayload>? _beaconSub;
  Timer? _scanTimeoutTimer;

  BluetoothAsistenciaNotifier(this._scanner, this._dataSource)
      : super(BluetoothAsistenciaState.initial());

  /// Inicia el proceso de detección por Bluetooth.
  Future<void> iniciarEscaneo({List<CursoUsuarioEntity>? cursosDisponibles}) async {
    state = state.copyWith(
      status: BluetoothAsistenciaStatus.checkingPermissions,
      mensajeError: null,
      resultado: null,
      payload: null,
      cursoCoincidente: null,
    );

    final estadoHardware = await _scanner.verificarPermisosYEstado();

    if (estadoHardware == BluetoothEstadoHardware.bluetoothApagado) {
      state = state.copyWith(
        status: BluetoothAsistenciaStatus.bluetoothOff,
        mensajeError: 'Por favor enciende el Bluetooth para detectar tu clase.',
      );
      return;
    }

    if (estadoHardware == BluetoothEstadoHardware.permisosDenegados) {
      state = state.copyWith(
        status: BluetoothAsistenciaStatus.permissionsDenied,
        mensajeError:
            'Se requieren permisos de Bluetooth y Ubicación para registrar asistencia.',
      );
      return;
    }

    // Iniciar escaneo
    state = state.copyWith(
      status: BluetoothAsistenciaStatus.scanning,
      esModoSimulado: false,
    );

    await _beaconSub?.cancel();
    _beaconSub = _scanner.beaconStream.listen((beacon) {
      _procesarBeaconDetectado(beacon, cursosDisponibles);
    });

    await _scanner.iniciarEscaneo(duracion: const Duration(seconds: 25));

    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = Timer(const Duration(seconds: 25), () {
      if (state.status == BluetoothAsistenciaStatus.scanning) {
        state = state.copyWith(
          status: BluetoothAsistenciaStatus.error,
          mensajeError:
              'No se detectó ninguna señal de asistencia cercana. Asegúrate de que el profesor haya iniciado la clase y que estés dentro del aula.',
        );
      }
    });
  }

  void _procesarBeaconDetectado(
    UcnBeaconPayload beacon,
    List<CursoUsuarioEntity>? cursosDisponibles,
  ) {
    // Si la señal es extremadamente débil, informamos pero no bloqueamos de inmediato
    CursoUsuarioEntity? cursoMatch;
    if (cursosDisponibles != null && cursosDisponibles.isNotEmpty) {
      for (final curso in cursosDisponibles) {
        if (curso.id == beacon.cursoId) {
          cursoMatch = curso;
          break;
        }
      }
    }

    state = state.copyWith(
      status: BluetoothAsistenciaStatus.beaconFound,
      payload: beacon,
      cursoCoincidente: cursoMatch,
    );
  }

  /// Registra la asistencia una vez que el usuario confirma o automáticamente.
  Future<void> confirmarAsistencia({
    required String rutEstudiante,
    int? semestreId,
  }) async {
    final payload = state.payload;
    if (payload == null) return;

    if (!payload.esAceptableParaAsistencia) {
      state = state.copyWith(
        status: BluetoothAsistenciaStatus.error,
        mensajeError:
            'La señal Bluetooth es demasiado débil (-${payload.rssi.abs()} dBm). Debes estar físicamente en la sala de clases para registrar asistencia.',
      );
      return;
    }

    state = state.copyWith(status: BluetoothAsistenciaStatus.registering);

    final resultadoEnvio = await _dataSource.marcarAsistenciaConBeacon(
      cursoId: payload.cursoId,
      token: payload.token,
      rssi: payload.rssi,
      rutEstudiante: rutEstudiante,
      semestreId: semestreId ?? payload.semestreId,
    );

    if (resultadoEnvio is Success<bool>) {
      final cursoNombre = state.cursoCoincidente?.nombre ??
          'Curso #${payload.cursoId}';

      final res = AsistenciaRegistroResult(
        exitoso: true,
        mensaje: '¡Asistencia registrada exitosamente en $cursoNombre!',
        cursoId: payload.cursoId,
        fechaRegistro: DateTime.now(),
        tokenUtilizado: payload.token,
        rssiRegistrado: payload.rssi,
        cursoNombre: cursoNombre,
      );

      state = state.copyWith(
        status: BluetoothAsistenciaStatus.success,
        resultado: res,
      );
    } else {
      final err = resultadoEnvio as Failure<bool>;
      state = state.copyWith(
        status: BluetoothAsistenciaStatus.error,
        mensajeError: 'Error al registrar asistencia: ${err.error.message}',
      );
    }
  }

  /// Permite simular una baliza para pruebas locales o en emulador.
  void simularDeteccion({
    required CursoUsuarioEntity curso,
    String token = 'UCN88',
    int rssi = -64,
  }) {
    final payload = UcnBeaconPayload(
      cursoId: curso.id,
      token: token,
      sigla: curso.codigo,
      bloque: '1-2',
      rssi: rssi,
      timestamp: DateTime.now(),
      deviceId: 'SIMULATED-BEACON-UCN',
    );

    state = state.copyWith(
      status: BluetoothAsistenciaStatus.beaconFound,
      payload: payload,
      cursoCoincidente: curso,
      esModoSimulado: true,
      mensajeError: null,
    );
  }

  /// Detiene el escaneo y reinicia el estado.
  void reiniciar() {
    _scanTimeoutTimer?.cancel();
    _beaconSub?.cancel();
    _scanner.detenerEscaneo();
    state = BluetoothAsistenciaState.initial();
  }

  @override
  void dispose() {
    _scanTimeoutTimer?.cancel();
    _beaconSub?.cancel();
    super.dispose();
  }
}
