import 'package:flutter_test/flutter_test.dart';
import 'package:hawaii_app/core/utils/text_normalize.dart';

void main() {
  group('normalizarBusqueda', () {
    test('elimina tildes y convierte a minusculas', () {
      expect(normalizarBusqueda('ÁÉÍÓÚ Ü Ñ'), 'aeiou u n');
      expect(normalizarBusqueda('Ingeniería'), 'ingenieria');
      expect(normalizarBusqueda('PROGRAMACIÓN'), 'programacion');
    });

    test('mantiene texto plano sin cambios', () {
      expect(normalizarBusqueda('hawaii ucn'), 'hawaii ucn');
      expect(normalizarBusqueda(''), '');
    });
  });

  group('nombreCursoCorto', () {
    test('remueve codigo y seccion entre parentesis', () {
      expect(
        nombreCursoCorto('Electivo Desarrollo Basado en Plataforma (ECIN-00003) {C1}'),
        'Electivo Desarrollo Basado en Plataforma',
      );
      expect(
        nombreCursoCorto('Pr. Introducción a la Ing. II (ECIN-00305) {C1}'),
        'Pr. Introducción a la Ing. II',
      );
    });

    test('retorna el nombre intacto si no tiene parentesis', () {
      expect(nombreCursoCorto('Taller de Liderazgo'), 'Taller de Liderazgo');
      expect(nombreCursoCorto(''), '');
    });
  });
}
