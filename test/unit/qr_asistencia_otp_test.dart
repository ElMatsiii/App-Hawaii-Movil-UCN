import 'package:flutter_test/flutter_test.dart';
import 'package:hawaii_app/features/asistencia/domain/qr_asistencia_model.dart';
import 'package:hawaii_app/features/asistencia/domain/qr_asistencia_validator.dart';

void main() {
  const validator = QrAsistenciaValidator();

  group('QrAsistenciaValidator - Formato OTP Propietario', () {
    const timestampBase = 1725823940;

    test('reconoce el formato UCN_ASISTENCIA:OTP:TIMESTAMP valido', () {
      expect(
        validator.esFormatoOtp('UCN_ASISTENCIA:AB3X9F:$timestampBase'),
        isTrue,
      );
    });

    test('valida correctamente un OTP vigente dentro de la ventana de 60 segundos', () {
      final res = validator.validarContenido(
        'UCN_ASISTENCIA:AB3X9F:$timestampBase',
        ventanaSegundos: 60,
        timestampReferencia: timestampBase + 25, // 25 segundos despues
      );

      expect(res.tipo, TipoQrAsistencia.otpDinamico);
      expect(res.esValido, isTrue);
      expect(res.estaVigente, isTrue);
      expect(res.otp, 'AB3X9F');
      expect(res.timestamp, timestampBase);
      expect(res.segundosTranscurridos, 25);
      expect(res.segundosRestantes, 35);
    });

    test('detecta correctamente un OTP expirado si pasaron mas de 60 segundos', () {
      final res = validator.validarContenido(
        'UCN_ASISTENCIA:AB3X9F:$timestampBase',
        ventanaSegundos: 60,
        timestampReferencia: timestampBase + 75, // 75 segundos despues
      );

      expect(res.tipo, TipoQrAsistencia.otpDinamico);
      expect(res.esValido, isTrue);
      expect(res.estaVigente, isFalse);
      expect(res.segundosRestantes, 0);
      expect(res.segundosTranscurridos, 75);
    });

    test('funciona con ventana de 30 segundos segun contexto de Hawaii UCN', () {
      final resVigente = validator.validarContenido(
        'UCN_ASISTENCIA:K7M9P2:$timestampBase',
        ventanaSegundos: 30,
        timestampReferencia: timestampBase + 15,
      );
      expect(resVigente.estaVigente, isTrue);

      final resExpirado = validator.validarContenido(
        'UCN_ASISTENCIA:K7M9P2:$timestampBase',
        ventanaSegundos: 30,
        timestampReferencia: timestampBase + 35,
      );
      expect(resExpirado.estaVigente, isFalse);
    });

    test('rechaza codigos con prefijo incorrecto', () {
      final res = validator.validarContenido('OTRO_PREFIJO:AB3X9F:$timestampBase');
      expect(res.tipo, TipoQrAsistencia.invalido);
      expect(res.esValido, isFalse);
    });

    test('rechaza codigos con OTP vacio o formato invalido', () {
      expect(validator.esFormatoOtp('UCN_ASISTENCIA::$timestampBase'), isFalse);
      expect(validator.esFormatoOtp('UCN_ASISTENCIA:A:$timestampBase'), isFalse);
      expect(validator.esFormatoOtp('UCN_ASISTENCIA:AB3X9F:no_timestamp'), isFalse);
    });

    test('mantiene compatibilidad con URLs legacy oficiales', () {
      final res = validator.validarContenido(
        'https://losvilos.ucn.cl/tongoy/asist_marcar6.php?op=s',
      );
      expect(res.tipo, TipoQrAsistencia.urlLegacy);
      expect(res.esValido, isTrue);
      expect(res.uri, isNotNull);
    });

    test('rechaza texto aleatorio o URLs no autorizadas', () {
      final res = validator.validarContenido('https://sitio-malicioso.com');
      expect(res.tipo, TipoQrAsistencia.invalido);
      expect(res.esValido, isFalse);
    });
  });
}
