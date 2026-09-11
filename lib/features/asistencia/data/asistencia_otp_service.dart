import '../domain/qr_asistencia_model.dart';
import '../domain/qr_asistencia_validator.dart';
import 'device_binding_service.dart';

/// Estados posibles al registrar asistencia mediante código OTP dinámico.
enum EstadoRegistroAsistencia {
  exitosa,
  codigoExpirado,
  dispositivoNoAutorizado,
  formatoInvalido,
  errorServidor,
}

/// Resultado de una operación de registro de asistencia con OTP.
class RegistroAsistenciaResultado {
  const RegistroAsistenciaResultado({
    required this.estado,
    required this.mensaje,
    this.otp,
    this.timestamp,
    this.deviceId,
    this.rutEstudiante,
    this.segundosRestantes = 0,
  });

  final EstadoRegistroAsistencia estado;
  final String mensaje;
  final String? otp;
  final int? timestamp;
  final String? deviceId;
  final String? rutEstudiante;
  final int segundosRestantes;

  bool get esExitosa => estado == EstadoRegistroAsistencia.exitosa;
}

/// Servicio que orquesta la validación de OTP, Device Binding y registro de asistencia.
class AsistenciaOtpService {
  AsistenciaOtpService({
    QrAsistenciaValidator? validator,
    DeviceBindingService? deviceBinding,
  })  : _validator = validator ?? const QrAsistenciaValidator(),
        _deviceBinding = deviceBinding ?? DeviceBindingService();

  final QrAsistenciaValidator _validator;
  final DeviceBindingService _deviceBinding;

  /// Procesa el contenido escaneado de un QR o ingresado manualmente.
  Future<RegistroAsistenciaResultado> procesarAsistenciaOtp({
    required String rawContent,
    required String rutEstudiante,
    int ventanaSegundos = 60,
  }) async {
    // 1. Validar el formato y la expiración temporal del QR
    final validacion = _validator.validarContenido(
      rawContent,
      ventanaSegundos: ventanaSegundos,
    );

    if (validacion.tipo != TipoQrAsistencia.otpDinamico || !validacion.esValido) {
      return RegistroAsistenciaResultado(
        estado: EstadoRegistroAsistencia.formatoInvalido,
        mensaje: validacion.mensaje ?? 'Formato de codigo QR no reconocido.',
        rutEstudiante: rutEstudiante,
      );
    }

    if (!validacion.estaVigente) {
      return RegistroAsistenciaResultado(
        estado: EstadoRegistroAsistencia.codigoExpirado,
        mensaje: 'El codigo OTP ha expirado. Han transcurrido ${validacion.segundosTranscurridos} segundos (maximo $ventanaSegundos s).',
        otp: validacion.otp,
        timestamp: validacion.timestamp,
        rutEstudiante: rutEstudiante,
        segundosRestantes: 0,
      );
    }

    // 2. Validar Device Binding (Seccion 5.3: registro por dispositivo)
    final deviceId = await _deviceBinding.getDeviceId();
    final dispositivoAutorizado = await _deviceBinding.estaDispositivoVinculado(rutEstudiante);

    if (!dispositivoAutorizado) {
      return RegistroAsistenciaResultado(
        estado: EstadoRegistroAsistencia.dispositivoNoAutorizado,
        mensaje: 'Dispositivo no autorizado. Este celular no esta vinculado a tu cuenta universitaria.',
        otp: validacion.otp,
        timestamp: validacion.timestamp,
        deviceId: deviceId,
        rutEstudiante: rutEstudiante,
        segundosRestantes: validacion.segundosRestantes,
      );
    }

    // 3. Registro exitoso
    return RegistroAsistenciaResultado(
      estado: EstadoRegistroAsistencia.exitosa,
      mensaje: 'Asistencia registrada correctamente.',
      otp: validacion.otp,
      timestamp: validacion.timestamp,
      deviceId: deviceId,
      rutEstudiante: rutEstudiante,
      segundosRestantes: validacion.segundosRestantes,
    );
  }
}
