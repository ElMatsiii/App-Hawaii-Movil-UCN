import 'qr_asistencia_model.dart';

/// Validación pura de códigos QR de asistencia (URLs legacy y formato OTP propietario).
///
/// Lógica crítica de seguridad:
/// 1. Formato OTP propietario: UCN_ASISTENCIA:<CODIGO>:<TIMESTAMP>
/// 2. URLs legacy: Solo HTTPS del dominio oficial de Tongoy/Hawaii.
class QrAsistenciaValidator {
  const QrAsistenciaValidator();

  /// Dominio autorizado para los QR legacy de asistencia.
  static const dominioPermitido = 'losvilos.ucn.cl';

  /// Únicas rutas de asistencia válidas para URLs legacy.
  static const rutasPermitidas = {
    '/hawaii/asist.php',
    '/hawaii/asist_marcar6.php',
    '/tongoy/asist_marcar6.php',
  };

  /// Prefijo del formato propietario para asistencia dinámica en Hawaii UCN.
  static const prefijoOtpUcn = 'UCN_ASISTENCIA';

  /// Expresión regular para validar el formato de OTP dinámico:
  /// UCN_ASISTENCIA:<OTP_6_CHARS>:<TIMESTAMP_UNIX>
  static final RegExp _regexOtpDinamico = RegExp(
    r'^UCN_ASISTENCIA:([A-Z0-9]{4,10}):(\d{9,12})$',
  );

  /// Retorna true si [uri] corresponde a una URL de asistencia legítima legacy.
  bool esValido(Uri uri) {
    if (uri.scheme != 'https') return false;
    if (uri.host != dominioPermitido) return false;
    return rutasPermitidas.contains(uri.path);
  }

  /// Retorna true si el texto crudo corresponde a una URL legacy autorizada.
  bool esTextoValido(String raw) {
    if (raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    if (uri == null) return false;
    return esValido(uri);
  }

  /// Retorna true si el texto crudo cumple con el formato OTP propietario:
  /// UCN_ASISTENCIA:<CODIGO>:<TIMESTAMP>
  bool esFormatoOtp(String raw) {
    if (raw.isEmpty) return false;
    return _regexOtpDinamico.hasMatch(raw.trim());
  }

  /// Realiza la validación exhaustiva de cualquier contenido QR escaneado.
  ///
  /// Determina si es un código OTP dinámico o una URL legacy, y calcula
  /// la expiración temporal según [ventanaSegundos] (por defecto 60 segundos).
  /// [timestampReferencia] permite fijar el tiempo actual para testing.
  ResultadoValidacionQr validarContenido(
    String raw, {
    int ventanaSegundos = 60,
    int? timestampReferencia,
  }) {
    final texto = raw.trim();
    if (texto.isEmpty) {
      return const ResultadoValidacionQr(
        tipo: TipoQrAsistencia.invalido,
        rawText: '',
        esValido: false,
        mensaje: 'El contenido del codigo QR esta vacio.',
      );
    }

    // 1. Comprobar si corresponde al formato OTP propietario de Hawaii UCN
    final matchOtp = _regexOtpDinamico.firstMatch(texto);
    if (matchOtp != null) {
      final otp = matchOtp.group(1)!;
      final timestampStr = matchOtp.group(2)!;
      final timestamp = int.tryParse(timestampStr);

      if (timestamp == null) {
        return ResultadoValidacionQr(
          tipo: TipoQrAsistencia.invalido,
          rawText: texto,
          esValido: false,
          mensaje: 'Timestamp invalido en el codigo OTP.',
        );
      }

      final ahora = timestampReferencia ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final transcurrido = (ahora - timestamp).clamp(0, 9999999);
      final vigente = transcurrido <= ventanaSegundos;

      return ResultadoValidacionQr(
        tipo: TipoQrAsistencia.otpDinamico,
        rawText: texto,
        esValido: true,
        otp: otp,
        timestamp: timestamp,
        segundosTranscurridos: transcurrido,
        ventanaSegundos: ventanaSegundos,
        mensaje: vigente
            ? 'Codigo OTP valido y vigente.'
            : 'Codigo OTP expirado. Transcurrieron $transcurrido segundos (limite: $ventanaSegundos s).',
      );
    }

    // 2. Comprobar si corresponde a una URL legacy oficial
    final uri = Uri.tryParse(texto);
    if (uri != null && esValido(uri)) {
      return ResultadoValidacionQr(
        tipo: TipoQrAsistencia.urlLegacy,
        rawText: texto,
        esValido: true,
        uri: uri,
        mensaje: 'URL oficial de asistencia reconocida.',
      );
    }

    // 3. Formato no reconocido
    return ResultadoValidacionQr(
      tipo: TipoQrAsistencia.invalido,
      rawText: texto,
      esValido: false,
      mensaje: 'Formato de QR no autorizado o no reconocido por Hawaii UCN.',
    );
  }
}
