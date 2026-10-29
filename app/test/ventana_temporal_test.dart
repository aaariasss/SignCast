import 'package:app/models/cuadro_puntos.dart';
import 'package:app/services/caracteristicas.dart';
import 'package:app/services/ventana_temporal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VentanaTemporal', () {
    test('no da ventana con menos de ~1 s de historia', () {
      final v = VentanaTemporal();
      for (var t = 0; t <= 500; t += 50) {
        v.agregar(t, CuadroPuntos());
      }
      expect(v.muestrear(), isNull);
    });

    test('reparte en 30 posiciones los cuadros de una cámara a 20 por segundo', () {
      final v = VentanaTemporal();
      final cuadros = [for (var i = 0; i < 30; i++) CuadroPuntos()];
      for (var i = 0; i < cuadros.length; i++) {
        v.agregar(i * 50, cuadros[i]);
      }
      final m = v.muestrear()!;
      expect(m.length, longitudSecuencia);
      expect(identical(m.last, cuadros.last), isTrue);
      // Primer instante: 1450 - 29 × 33.3 ≈ 483 ms → cuadro de 450 ms.
      expect(identical(m.first, cuadros[9]), isTrue);
    });

    test('olvida lo que pasó hace más de la memoria', () {
      final v = VentanaTemporal(memoriaMs: 1000);
      for (var t = 0; t <= 3000; t += 50) {
        v.agregar(t, CuadroPuntos());
      }
      expect(v.cantidad, 21);
    });
  });
}
