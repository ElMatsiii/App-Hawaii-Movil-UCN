import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'codigo_optico_alternativo_model.dart';

/// Definicion de un color calibrado en la paleta oficial ChromaCode UCN.
class ChromaColorDef {
  const ChromaColorDef({
    required this.simbolo,
    required this.color,
    required this.nombre,
  });

  final String simbolo;
  final Color color;
  final String nombre;
}

/// Codificador y decodificador del formato ChromaCode para Hawaii UCN.
///
/// Mapea caracteres hexadecimales [0-9, A-F] a una paleta de 16 colores
/// optimizada con maxima distancia euclidiana en el espacio RGB.
class ChromaCodeCodec {
  const ChromaCodeCodec();

  /// Paleta oficial de 16 colores calibrados (identica a la especificacion web).
  static const Map<String, ChromaColorDef> paletaOficial = {
    '0': ChromaColorDef(simbolo: '0', color: Color(0xFF111827), nombre: 'Negro'),
    '1': ChromaColorDef(simbolo: '1', color: Color(0xFFEF4444), nombre: 'Rojo'),
    '2': ChromaColorDef(simbolo: '2', color: Color(0xFF22C55E), nombre: 'Verde'),
    '3': ChromaColorDef(simbolo: '3', color: Color(0xFF3B82F6), nombre: 'Azul'),
    '4': ChromaColorDef(simbolo: '4', color: Color(0xFFEAB308), nombre: 'Amarillo'),
    '5': ChromaColorDef(simbolo: '5', color: Color(0xFFEC4899), nombre: 'Magenta'),
    '6': ChromaColorDef(simbolo: '6', color: Color(0xFF06B6D4), nombre: 'Cian'),
    '7': ChromaColorDef(simbolo: '7', color: Color(0xFFF97316), nombre: 'Naranja'),
    '8': ChromaColorDef(simbolo: '8', color: Color(0xFFA855F7), nombre: 'Purpura'),
    '9': ChromaColorDef(simbolo: '9', color: Color(0xFF84CC16), nombre: 'Lima'),
    'A': ChromaColorDef(simbolo: 'A', color: Color(0xFFF8FAFC), nombre: 'Blanco'),
    'B': ChromaColorDef(simbolo: 'B', color: Color(0xFFF472B6), nombre: 'Rosa'),
    'C': ChromaColorDef(simbolo: 'C', color: Color(0xFF14B8A6), nombre: 'Turquesa'),
    'D': ChromaColorDef(simbolo: 'D', color: Color(0xFF6366F1), nombre: 'Indigo'),
    'E': ChromaColorDef(simbolo: 'E', color: Color(0xFFD97706), nombre: 'Ambar'),
    'F': ChromaColorDef(simbolo: 'F', color: Color(0xFF64748B), nombre: 'Pizarra'),
  };

  /// Codifica un string de OTP (ej: 'AB3C9F') en una lista de colores oficiales.
  List<Color> codificarOtp(String otp) {
    final clean = otp.toUpperCase();
    final resultado = <Color>[];
    for (int i = 0; i < clean.length; i++) {
      final char = clean[i];
      final def = paletaOficial[char] ?? paletaOficial['0']!;
      resultado.add(def.color);
    }
    return resultado;
  }

  /// Calcula la distancia euclidiana entre dos colores en espacio RGB.
  double distanciaColor(Color c1, Color c2) {
    final r1 = (c1.r * 255.0).round().clamp(0, 255);
    final g1 = (c1.g * 255.0).round().clamp(0, 255);
    final b1 = (c1.b * 255.0).round().clamp(0, 255);
    final r2 = (c2.r * 255.0).round().clamp(0, 255);
    final g2 = (c2.g * 255.0).round().clamp(0, 255);
    final b2 = (c2.b * 255.0).round().clamp(0, 255);
    final dr = r1 - r2;
    final dg = g1 - g2;
    final db = b1 - b2;
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  /// Encuentra el simbolo mas cercano en la paleta conocida dada una muestra RGB.
  String clasificarColor(Color muestra, {double umbralTolerancia = 180.0}) {
    String mejorSimbolo = '0';
    double menorDistancia = double.infinity;

    for (final entry in paletaOficial.entries) {
      final d = distanciaColor(muestra, entry.value.color);
      if (d < menorDistancia) {
        menorDistancia = d;
        mejorSimbolo = entry.key;
      }
    }

    if (menorDistancia > umbralTolerancia) {
      return '?';
    }
    return mejorSimbolo;
  }

  /// Decodifica una secuencia de colores a un resultado estructurado.
  ResultadoDecodificacionOptica decodificarSecuencia({
    required List<Color> colores,
    bool modoHawaii = true,
    int? timestampReferencia,
  }) {
    final stopwatch = Stopwatch()..start();

    if (!modoHawaii) {
      stopwatch.stop();
      return ResultadoDecodificacionOptica(
        tipo: TipoCodigoOptico.chromaCode,
        esValido: false,
        mensaje: 'Modo Generico / WhatsApp: Sin el diccionario de calibracion RGB '
            'los colores no pueden asociarse a ningun caracter.',
        latenciaMs: stopwatch.elapsedMilliseconds,
      );
    }

    if (colores.isEmpty) {
      stopwatch.stop();
      return ResultadoDecodificacionOptica(
        tipo: TipoCodigoOptico.chromaCode,
        esValido: false,
        mensaje: 'Secuencia cromatico vacia.',
        latenciaMs: stopwatch.elapsedMilliseconds,
      );
    }

    final buffer = StringBuffer();
    double sumaConfianza = 0.0;

    for (final c in colores) {
      final simbolo = clasificarColor(c);
      if (simbolo == '?') {
        stopwatch.stop();
        return ResultadoDecodificacionOptica(
          tipo: TipoCodigoOptico.chromaCode,
          esValido: false,
          mensaje: 'Color fuera de la tolerancia de la paleta calibrada.',
          latenciaMs: stopwatch.elapsedMilliseconds,
        );
      }
      buffer.write(simbolo);
      final ref = paletaOficial[simbolo]!.color;
      final dist = distanciaColor(c, ref);
      final conf = math.max(0.0, 1.0 - (dist / 180.0));
      sumaConfianza += conf;
    }

    final codigoOtp = buffer.toString();
    final ts = timestampReferencia ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final payload = 'UCN_ASISTENCIA:$codigoOtp:$ts';
    final confianzaMedia = sumaConfianza / colores.length;

    stopwatch.stop();
    return ResultadoDecodificacionOptica(
      tipo: TipoCodigoOptico.chromaCode,
      esValido: true,
      codigoOtp: codigoOtp,
      payloadCompleto: payload,
      timestamp: ts,
      confianza: confianzaMedia,
      mensaje: 'ChromaCode decodificado con exito mediante distancia euclidiana.',
      latenciaMs: stopwatch.elapsedMilliseconds,
    );
  }
}
