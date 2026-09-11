import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hawaii_app/features/asistencia/domain/chromacode_codec.dart';

void main() {
  group('ChromaCodeCodec - Pruebas Unitarias', () {
    const codec = ChromaCodeCodec();

    test('Codifica y decodifica un OTP exacto de 6 caracteres', () {
      const otpOriginal = 'AB3C9F';
      final colores = codec.codificarOtp(otpOriginal);

      expect(colores.length, 6);
      expect(colores[0], const Color(0xFFF8FAFC)); // 'A' Blanco
      expect(colores[1], const Color(0xFFF472B6)); // 'B' Rosa
      expect(colores[2], const Color(0xFF3B82F6)); // '3' Azul
      expect(colores[3], const Color(0xFF14B8A6)); // 'C' Turquesa
      expect(colores[4], const Color(0xFF84CC16)); // '9' Lima
      expect(colores[5], const Color(0xFF64748B)); // 'F' Pizarra

      final resultado = codec.decodificarSecuencia(
        colores: colores,
        modoHawaii: true,
        timestampReferencia: 1725823940,
      );

      expect(resultado.esValido, isTrue);
      expect(resultado.codigoOtp, otpOriginal);
      expect(resultado.payloadCompleto, 'UCN_ASISTENCIA:AB3C9F:1725823940');
      expect(resultado.confianza, greaterThanOrEqualTo(0.99));
    });

    test('Tolera pequenas variaciones cromaticas simulando iluminacion ambiental', () {
      // Tomamos '1' (Rojo puro 239, 68, 68) y le agregamos ruido (+10 en G, -5 en R)
      const colorConRuidoRojo = Color(0xFFEA4E44); // ~ 234, 78, 68
      final clasificado = codec.clasificarColor(colorConRuidoRojo);

      expect(clasificado, '1');
    });

    test('Modo generico falla al no disponer de diccionario de paleta', () {
      final colores = codec.codificarOtp('123456');
      final resultado = codec.decodificarSecuencia(
        colores: colores,
        modoHawaii: false,
      );

      expect(resultado.esValido, isFalse);
      expect(resultado.codigoOtp, isNull);
      expect(resultado.mensaje, contains('Modo Generico / WhatsApp'));
    });

    test('Rechaza secuencias vacias', () {
      final resultado = codec.decodificarSecuencia(
        colores: [],
        modoHawaii: true,
      );

      expect(resultado.esValido, isFalse);
    });

    test('Verifica que los 16 caracteres de la paleta sean unicos', () {
      expect(ChromaCodeCodec.paletaOficial.length, 16);
      final simbolos = ChromaCodeCodec.paletaOficial.keys.toSet();
      expect(simbolos.length, 16);
    });
  });
}
