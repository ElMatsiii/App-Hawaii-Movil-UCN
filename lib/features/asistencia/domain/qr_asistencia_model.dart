/// Modelos de datos para la validación y decodificación de códigos QR de asistencia.
enum TipoQrAsistencia {
  /// URL legacy del sistema web (ej: https://losvilos.ucn.cl/hawaii/asist.php).
  urlLegacy,

  /// Código OTP dinámico propietario de Hawaii UCN (ej: UCN_ASISTENCIA:AB3X9F:1725823940).
  otpDinamico,

  /// Contenido no reconocido o mal formado.
  invalido,
}

/// Representa el resultado completo de validar un código QR de asistencia.
class ResultadoValidacionQr {
  const ResultadoValidacionQr({
    required this.tipo,
    required this.rawText,
    required this.esValido,
    this.otp,
    this.timestamp,
    this.uri,
    this.mensaje,
    this.segundosTranscurridos = 0,
    this.ventanaSegundos = 60,
  });

  /// Tipo de QR detectado.
  final TipoQrAsistencia tipo;

  /// Texto sin procesar obtenido del escáner.
  final String rawText;

  /// Indica si el formato y las reglas de seguridad son válidas.
  final bool esValido;

  /// Código OTP extraído (ej: 'AB3X9F') si es de tipo [TipoQrAsistencia.otpDinamico].
  final String? otp;

  /// Timestamp Unix en segundos en que se generó el código.
  final int? timestamp;

  /// URI parseada si es de tipo [TipoQrAsistencia.urlLegacy].
  final Uri? uri;

  /// Mensaje descriptivo del resultado o del error.
  final String? mensaje;

  /// Segundos que han pasado desde la creación del código.
  final int segundosTranscurridos;

  /// Ventana de vigencia máxima configurada para el código (por defecto 60 segundos).
  final int ventanaSegundos;

  /// Indica si el código OTP aún se encuentra dentro de su ventana temporal de validez.
  bool get estaVigente {
    if (tipo != TipoQrAsistencia.otpDinamico || !esValido) return false;
    return segundosTranscurridos <= ventanaSegundos;
  }

  /// Segundos restantes antes de que el código expire. Retorna 0 si ya expiró.
  int get segundosRestantes {
    if (!estaVigente) return 0;
    return (ventanaSegundos - segundosTranscurridos).clamp(0, ventanaSegundos);
  }
}
