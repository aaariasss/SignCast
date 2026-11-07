import 'dart:typed_data';

import 'package:app/services/clasificador_alfabeto.dart';
import 'package:flutter_test/flutter_test.dart';

// Red de prueba: 3 entradas → 2 ocultas (ReLU) → 2 salidas (softmax).
// Los valores esperados salen de numpy con los mismos pesos.
ClasificadorAlfabeto _clasificador() => ClasificadorAlfabeto(
  etiquetas: const ['A', 'B'],
  entradas: 3,
  ocultas: const [2],
  pesos: Float32List.fromList([
    1, -1, 0.5, 2, -1, 0.5, // kernel 3×2
    0.1, -0.2, // sesgo
    1, 2, -1, 0.5, // kernel 2×2
    0, 0.3, // sesgo
  ]),
);

void main() {
  test('calcula el mismo resultado que numpy', () {
    final p = _clasificador().predecir(Float32List.fromList([1, 2, 3]));
    expect(p[0], closeTo(0.00116951, 1e-6));
    expect(p[1], closeTo(0.9988305, 1e-6));
    expect(p[0] + p[1], closeTo(1.0, 1e-6));
  });

  test('rechaza una entrada de otro tamaño', () {
    expect(() => _clasificador().predecir(Float32List(5)), throwsArgumentError);
  });

  test('rechaza pesos de otro tamaño', () {
    expect(
      () => ClasificadorAlfabeto(
        etiquetas: const ['A', 'B'],
        entradas: 3,
        ocultas: const [2],
        pesos: Float32List(10),
      ),
      throwsArgumentError,
    );
  });

  test('desdeBytes lee float32 little-endian', () {
    final datos = ByteData(4 * 4);
    for (var i = 0; i < 4; i++) {
      datos.setFloat32(i * 4, i + 0.5, Endian.little);
    }
    // 1 entrada y 2 salidas sin capas ocultas: 2 pesos + 2 sesgos.
    final c = ClasificadorAlfabeto.desdeBytes(
      datos,
      'A B',
      ocultas: const [],
      entradas: 1,
    );
    expect(c.etiquetas, ['A', 'B']);
    final p = c.predecir(Float32List.fromList([1]));
    // logits: [0.5 + 2.5, 1.5 + 3.5] = [3, 5]
    expect(p[1], greaterThan(p[0]));
    expect(p[0] + p[1], closeTo(1.0, 1e-6));
  });
}
