import 'package:app/services/decisor_senas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DecisorSenas', () {
    test('acepta una glosa tras 3 predicciones iguales seguidas', () {
      final d = DecisorSenas();
      expect(d.predecir('HOLA', 0.9, 0), isFalse);
      expect(d.predecir('HOLA', 0.9, 100), isFalse);
      expect(d.predecir('HOLA', 0.9, 200), isTrue);
      expect(d.glosas, ['HOLA']);
    });

    test('ignora predicciones por debajo del umbral', () {
      final d = DecisorSenas();
      for (var i = 0; i < 5; i++) {
        expect(d.predecir('HOLA', 0.5, i * 100), isFalse);
      }
      expect(d.glosas, isEmpty);
    });

    test('una predicción distinta rompe la racha', () {
      final d = DecisorSenas();
      d.predecir('HOLA', 0.9, 0);
      d.predecir('ADIOS', 0.9, 100);
      d.predecir('HOLA', 0.9, 200);
      expect(d.glosas, isEmpty);
    });

    test('no repite la misma glosa hasta que haya otra o un reposo', () {
      final d = DecisorSenas();
      for (var i = 0; i < 6; i++) {
        d.predecir('HOLA', 0.9, i * 100);
      }
      expect(d.glosas, ['HOLA']);
      for (var i = 0; i < 3; i++) {
        d.predecir('_REPOSO', 0.9, 1000 + i * 100);
      }
      for (var i = 0; i < 3; i++) {
        d.predecir('HOLA', 0.9, 1400 + i * 100);
      }
      expect(d.glosas, ['HOLA', 'HOLA']);
    });

    test('cierra la frase tras la pausa y no antes', () {
      final d = DecisorSenas();
      for (var i = 0; i < 3; i++) {
        d.predecir('YO', 0.9, i * 100);
      }
      for (var i = 0; i < 3; i++) {
        d.predecir('_REPOSO', 0.9, 1000 + i * 100);
      }
      // El reposo estable empezó en 1200 ms; la pausa es de 1200 ms.
      expect(d.cerrarFrase(2000), isNull);
      expect(d.cerrarFrase(2400), ['YO']);
      expect(d.glosas, isEmpty);
      expect(d.cerrarFrase(5000), isNull);
    });

    test('sin glosas no hay frase que cerrar', () {
      final d = DecisorSenas();
      for (var i = 0; i < 3; i++) {
        d.predecir('_REPOSO', 0.9, i * 100);
      }
      expect(d.cerrarFrase(10000), isNull);
    });
  });
}
