import 'dart:math' as math;

/// Nivel de proximidad física respecto a la baliza (beacon) del profesor.
enum NivelProximidad {
  /// Dentro de la sala de clases (0 a 5 metros aproximadamente, RSSI >= -75 dBm)
  enSala,

  /// Cerca de la sala o en puerta (5 a 12 metros, -85 <= RSSI < -75 dBm)
  cercano,

  /// Señal débil en el límite (12 a 20 metros, -92 <= RSSI < -85 dBm)
  alLimite,

  /// Señal insuficiente o fuera del aula (RSSI < -92 dBm)
  fueraDeRango,
}

extension NivelProximidadExt on NivelProximidad {
  String get etiqueta => switch (this) {
        NivelProximidad.enSala => 'Dentro del aula (Excelente)',
        NivelProximidad.cercano => 'En la sala (Buena señal)',
        NivelProximidad.alLimite => 'Señal débil (Acércate al aula)',
        NivelProximidad.fueraDeRango => 'Fuera de rango (Demasiado lejos)',
      };

  bool get esValidoParaMarcar =>
      this == NivelProximidad.enSala || this == NivelProximidad.cercano;
}

/// Datos extraídos de la señal Bluetooth (BLE Advertising / Beacon) de la clase.
class UcnBeaconPayload {
  final int cursoId;
  final String token;
  final int? semestreId;
  final String? bloque;
  final String? sigla;
  final int rssi; // dBm
  final DateTime timestamp;
  final String? deviceId;

  const UcnBeaconPayload({
    required this.cursoId,
    required this.token,
    required this.rssi,
    required this.timestamp,
    this.semestreId,
    this.bloque,
    this.sigla,
    this.deviceId,
  });

  /// Estima la distancia física aproximada en metros según la atenuación del RSSI.
  /// TxPower de referencia típicamente -59 dBm a 1 metro, coeficiente n = 2.0 en interiores.
  double get distanciaAproximadaMetros {
    const int txPower = -59;
    const double n = 2.0;
    if (rssi == 0) return 999.0;
    final ratio = (txPower - rssi) / (10 * n);
    final distancia = math.pow(10, ratio).toDouble();
    return double.parse(distancia.toStringAsFixed(1));
  }

  /// Nivel de proximidad clasificado según el RSSI medido.
  NivelProximidad get nivelProximidad {
    if (rssi >= -75) return NivelProximidad.enSala;
    if (rssi >= -85) return NivelProximidad.cercano;
    if (rssi >= -92) return NivelProximidad.alLimite;
    return NivelProximidad.fueraDeRango;
  }

  /// Indica si el estudiante está lo suficientemente cerca para que sea seguro
  /// registrar la asistencia y evitar fraudes a distancia.
  bool get esAceptableParaAsistencia => nivelProximidad.esValidoParaMarcar;

  /// Retorna un porcentaje representativo de la calidad de señal (0 - 100%).
  int get porcentajeCalidadSenal {
    if (rssi <= -100) return 0;
    if (rssi >= -50) return 100;
    return (((rssi + 100) / 50) * 100).round().clamp(0, 100);
  }

  UcnBeaconPayload copyWith({
    int? cursoId,
    String? token,
    int? semestreId,
    String? bloque,
    String? sigla,
    int? rssi,
    DateTime? timestamp,
    String? deviceId,
  }) {
    return UcnBeaconPayload(
      cursoId: cursoId ?? this.cursoId,
      token: token ?? this.token,
      rssi: rssi ?? this.rssi,
      timestamp: timestamp ?? this.timestamp,
      semestreId: semestreId ?? this.semestreId,
      bloque: bloque ?? this.bloque,
      sigla: sigla ?? this.sigla,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}

/// Resultado de registrar la asistencia (local o sincronizado con Hawaii).
class AsistenciaRegistroResult {
  final bool exitoso;
  final String mensaje;
  final int cursoId;
  final String? cursoNombre;
  final DateTime fechaRegistro;
  final String tokenUtilizado;
  final int rssiRegistrado;

  const AsistenciaRegistroResult({
    required this.exitoso,
    required this.mensaje,
    required this.cursoId,
    required this.fechaRegistro,
    required this.tokenUtilizado,
    required this.rssiRegistrado,
    this.cursoNombre,
  });
}
