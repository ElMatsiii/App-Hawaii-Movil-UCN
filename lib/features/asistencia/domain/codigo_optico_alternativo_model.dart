import 'package:flutter/foundation.dart';

/// Tipos de estructuras opticas no convencionales para mitigacion de captura fotografica.
enum TipoCodigoOptico {
  chromaCode,
  barras1D,
  aztec,
  dataMatrix,
  ondasFase,
  flashesTemporales,
  constelacion,
}

extension TipoCodigoOpticoExtension on TipoCodigoOptico {
  String get titulo {
    switch (this) {
      case TipoCodigoOptico.chromaCode:
        return 'ChromaCode (Colores)';
      case TipoCodigoOptico.barras1D:
        return 'Barras 1D (Code 128)';
      case TipoCodigoOptico.aztec:
        return 'Codigo Aztec (2D Concentrico)';
      case TipoCodigoOptico.dataMatrix:
        return 'Data Matrix (2D Industrial)';
      case TipoCodigoOptico.ondasFase:
        return 'Ondas Sinusoidales (Fase/FFT)';
      case TipoCodigoOptico.flashesTemporales:
        return 'Flashes Temporales';
      case TipoCodigoOptico.constelacion:
        return 'Constelacion NxN';
    }
  }

  String get descripcion {
    switch (this) {
      case TipoCodigoOptico.chromaCode:
        return 'Secuencia de bloques cromaticos mapeados por valores RGB discretos.';
      case TipoCodigoOptico.barras1D:
        return 'Code 128 real con alternancia de zonas y ventana de escaneo limpio.';
      case TipoCodigoOptico.aztec:
        return 'Matriz 2D concentrica con diana central cuadrada sin esquinas QR.';
      case TipoCodigoOptico.dataMatrix:
        return 'Matriz 2D perimetral con guia en L y maxima densidad optica.';
      case TipoCodigoOptico.ondasFase:
        return 'Frecuencias espaciales bidimensionales discretas en fase continua.';
      case TipoCodigoOptico.flashesTemporales:
        return 'Emision serial de destellos opticos en el tiempo (1 frame = 0 bits).';
      case TipoCodigoOptico.constelacion:
        return 'Coordenadas geometricas en grilla invisible inmunes a lectura manual.';
    }
  }
}

/// Modelo de resultado de decodificacion de una estructura optica alternativa.
@immutable
class ResultadoDecodificacionOptica {
  const ResultadoDecodificacionOptica({
    required this.tipo,
    required this.esValido,
    required this.mensaje,
    this.codigoOtp,
    this.payloadCompleto,
    this.timestamp,
    this.confianza = 1.0,
    this.latenciaMs = 0,
  });

  final TipoCodigoOptico tipo;
  final bool esValido;
  final String? codigoOtp;
  final String? payloadCompleto;
  final int? timestamp;
  final String mensaje;
  final double confianza;
  final int latenciaMs;

  @override
  String toString() {
    return 'ResultadoDecodificacionOptica(tipo: $tipo, esValido: $esValido, otp: $codigoOtp, msg: $mensaje)';
  }
}

/// Modos de proteccion anti-captura fotografica para la emision del Codigo Aztec.
enum ModoAntiCapturaAztec {
  rollingShutter,
  dianaPulsante,
  estatico,
}

extension ModoAntiCapturaAztecExtension on ModoAntiCapturaAztec {
  String get titulo {
    switch (this) {
      case ModoAntiCapturaAztec.rollingShutter:
        return 'Rolling Shutter (Barrido)';
      case ModoAntiCapturaAztec.dianaPulsante:
        return 'Diana Pulsante';
      case ModoAntiCapturaAztec.estatico:
        return 'Estatico Puro';
    }
  }

  String get descripcion {
    switch (this) {
      case ModoAntiCapturaAztec.rollingShutter:
        return 'Banda de obturacion continua que interrumpe la diana central en fotos.';
      case ModoAntiCapturaAztec.dianaPulsante:
        return 'El nucleo central parpadea a alta velocidad con ventana limpia para el video.';
      case ModoAntiCapturaAztec.estatico:
        return 'Emision fija nitida sin modulacion temporal.';
    }
  }
}
