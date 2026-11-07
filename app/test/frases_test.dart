// Pruebas del constructor de frases. Mismos casos que `ml/tests/test_frases.py`
// y `docs/frases.md`: el resultado en Dart debe ser idéntico al de Python.

import 'package:app/services/frases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const casos = <(List<String>, String)>[
    (['YO', 'NO', 'ENTENDER'], 'No entiendo.'),
    (['ENTENDER', 'NO'], 'No entiendo.'),
    (['REPETIR', 'POR-FAVOR'], '¿Puede repetir, por favor?'),
    (['AYUDAR', 'YO', 'POR-FAVOR'], '¿Me puede ayudar, por favor?'),
    (['YO', 'PODER', 'IR', 'BANO'], '¿Puedo ir al baño?'),
    (['TAREA', 'CUANDO'], '¿Cuándo es la tarea?'),
    (['BANO', 'DONDE'], '¿Dónde está el baño?'),
    (['MANANA', 'EXAMEN'], 'Mañana hay examen.'),
    (['YO', 'TENER', 'PREGUNTA'], 'Tengo una pregunta.'),
    (['MAESTRO', 'REPETIR'], 'El maestro repite.'),
    (['MANANA', 'YO', 'IR', 'CLASE'], 'Mañana voy a la clase.'),
    (['HOLA', 'YO', 'A', 'N', 'A'], 'Hola. Soy Ana.'),
    (['SI'], 'Sí.'),
    (['GRACIAS'], 'Gracias.'),
    (
      ['HOLA', 'HOLA', '_REPOSO', 'YO', 'NO', 'ENTENDER', 'GRACIAS'],
      'Hola. No entiendo. Gracias.',
    ),
  ];

  group('construirFrase', () {
    for (final (glosas, esperado) in casos) {
      test(glosas.join(' '), () {
        expect(construirFrase(glosas), esperado);
      });
    }

    test('lista vacía o solo reposo da cadena vacía', () {
      expect(construirFrase([]), '');
      expect(construirFrase(['_REPOSO']), '');
    });
  });

  test('limpiar quita repeticiones', () {
    expect(limpiar(['HOLA', 'HOLA', 'HOLA', 'TAREA']), ['HOLA', 'TAREA']);
  });

  test('deletreo separado por reposo', () {
    expect(unirDeletreo(['A', 'N', 'A', '_REPOSO', 'L', 'U', 'Z']), [
      '#Ana',
      '#Luz',
    ]);
  });
}
