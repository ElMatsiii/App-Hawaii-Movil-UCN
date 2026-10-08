import 'package:flutter_test/flutter_test.dart';
import 'package:hawaii_app/features/asistencia/domain/beacon_attendance_models.dart';
import 'package:hawaii_app/features/asistencia/domain/ucn_beacon_parser.dart';

void main() {
  const parser = UcnBeaconParser();

  group('UcnBeaconParser - Decodificación por Manufacturer Data', () {
    test('decodifica payload UCN con header "N1", cursoId, token y bloque', () {
      // Header: 'N', '1' (0x4E, 0x31)
      // CursoId: 1042 (0x0412) -> [0x04, 0x12]
      // Token: 'A8F2' -> [0x41, 0x38, 0x46, 0x32]
      // Bloque: 3 -> [0x03]
      // SemestreId: 2 -> [0x02]
      final bytes = <int>[
        0x4E, 0x31, // Header
        0x04, 0x12, // CursoId = 1042
        0x41, 0x38, 0x46, 0x32, // Token = 'A8F2'
        0x03, // Bloque = 3 (3-4)
        0x02, // SemestreId = 2
      ];

      final payload = parser.parse(
        manufacturerData: {UcnBeaconParser.ucnManufacturerId: bytes},
        rssi: -65,
        deviceId: 'AA:BB:CC:DD:EE:FF',
      );

      expect(payload, isNotNull);
      expect(payload!.cursoId, equals(1042));
      expect(payload.token, equals('A8F2'));
      expect(payload.bloque, equals('3-4'));
      expect(payload.semestreId, equals(2));
      expect(payload.rssi, equals(-65));
      expect(payload.nivelProximidad, equals(NivelProximidad.enSala));
      expect(payload.esAceptableParaAsistencia, isTrue);
    });

    test('decodifica payload UCN sin encabezado explícito (solo cursoId y token)', () {
      final bytes = <int>[
        0x03, 0x84, // CursoId = 900 (0x0384)
        0x54, 0x45, 0x53, 0x54, // Token = 'TEST'
      ];

      final payload = parser.parse(
        manufacturerData: {UcnBeaconParser.ucnManufacturerId: bytes},
        rssi: -78,
      );

      expect(payload, isNotNull);
      expect(payload!.cursoId, equals(900));
      expect(payload.token, equals('TEST'));
      expect(payload.rssi, equals(-78));
      expect(payload.nivelProximidad, equals(NivelProximidad.cercano));
      expect(payload.esAceptableParaAsistencia, isTrue);
    });

    test('ignora manufacturerData con id diferente al de UCN', () {
      final bytes = <int>[0x04, 0x12, 0x41, 0x42];
      final payload = parser.parse(
        manufacturerData: {0x1234: bytes},
        rssi: -60,
      );

      expect(payload, isNull);
    });
  });

  group('UcnBeaconParser - Decodificación por Local Name', () {
    test('decodifica nombre de dispositivo "UCN-ASIST-1042-TOKEN99"', () {
      final payload = parser.parse(
        deviceName: 'UCN-ASIST-1042-TOKEN99',
        rssi: -70,
        deviceId: '11:22:33:44:55:66',
      );

      expect(payload, isNotNull);
      expect(payload!.cursoId, equals(1042));
      expect(payload.token, equals('TOKEN99'));
      expect(payload.rssi, equals(-70));
      expect(payload.deviceId, equals('11:22:33:44:55:66'));
    });

    test('decodifica nombre sin token secundario "UCN-ASIST-500"', () {
      final payload = parser.parse(
        deviceName: 'UCN-ASIST-500',
        rssi: -82,
      );

      expect(payload, isNotNull);
      expect(payload!.cursoId, equals(500));
      expect(payload.token, equals('DEFAULT'));
    });

    test('ignora nombres que no coinciden con el prefijo oficial', () {
      expect(parser.parse(deviceName: 'OTRO-ASIST-1042', rssi: -60), isNull);
      expect(parser.parse(deviceName: 'Earphones-Bluetooth', rssi: -50), isNull);
      expect(parser.parse(deviceName: '', rssi: -60), isNull);
    });
  });

  group('UcnBeaconParser - Decodificación por iBeacon', () {
    test('decodifica iBeacon con UUID UCN, Major (curso) y Minor (token)', () {
      final cleanUuid =
          UcnBeaconParser.ibeaconProximityUuid.replaceAll('-', '');
      final uuidBytes = <int>[];
      for (var i = 0; i < cleanUuid.length; i += 2) {
        uuidBytes.add(int.parse(cleanUuid.substring(i, i + 2), radix: 16));
      }

      final iBeaconBytes = <int>[
        0x02, 0x15, // Header iBeacon
        ...uuidBytes, // 16 bytes UUID
        0x04, 0x00, // Major = 1024
        0x10, 0x20, // Minor = 4128
        0xC5, // TxPower = -59 dBm
      ];

      final payload = parser.parse(
        manufacturerData: {0x004C: iBeaconBytes},
        rssi: -62,
      );

      expect(payload, isNotNull);
      expect(payload!.cursoId, equals(1024));
      expect(payload.token, equals('4128'));
      expect(payload.rssi, equals(-62));
    });
  });

  group('UcnBeaconPayload - Cálculos de Proximidad y Distancia', () {
    test('clasifica niveles de proximidad según RSSI correctamente', () {
      final ahora = DateTime.now();

      final enSala = UcnBeaconPayload(
        cursoId: 1,
        token: 'T',
        rssi: -65,
        timestamp: ahora,
      );
      expect(enSala.nivelProximidad, equals(NivelProximidad.enSala));
      expect(enSala.esAceptableParaAsistencia, isTrue);

      final cercano = UcnBeaconPayload(
        cursoId: 1,
        token: 'T',
        rssi: -80,
        timestamp: ahora,
      );
      expect(cercano.nivelProximidad, equals(NivelProximidad.cercano));
      expect(cercano.esAceptableParaAsistencia, isTrue);

      final alLimite = UcnBeaconPayload(
        cursoId: 1,
        token: 'T',
        rssi: -89,
        timestamp: ahora,
      );
      expect(alLimite.nivelProximidad, equals(NivelProximidad.alLimite));
      expect(alLimite.esAceptableParaAsistencia, isFalse);

      final fueraDeRango = UcnBeaconPayload(
        cursoId: 1,
        token: 'T',
        rssi: -98,
        timestamp: ahora,
      );
      expect(fueraDeRango.nivelProximidad, equals(NivelProximidad.fueraDeRango));
      expect(fueraDeRango.esAceptableParaAsistencia, isFalse);
    });

    test('calcula porcentaje de señal coherentemente', () {
      final ahora = DateTime.now();

      final excelente = UcnBeaconPayload(
        cursoId: 1,
        token: 'T',
        rssi: -50,
        timestamp: ahora,
      );
      expect(excelente.porcentajeCalidadSenal, equals(100));

      final muyDebil = UcnBeaconPayload(
        cursoId: 1,
        token: 'T',
        rssi: -100,
        timestamp: ahora,
      );
      expect(muyDebil.porcentajeCalidadSenal, equals(0));

      final media = UcnBeaconPayload(
        cursoId: 1,
        token: 'T',
        rssi: -75,
        timestamp: ahora,
      );
      expect(media.porcentajeCalidadSenal, inInclusiveRange(45, 55));
    });
  });
}
