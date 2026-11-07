import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'caracteristicas.dart';

/// Clasificador de las letras estáticas del alfabeto (`modelos/alfabeto_final`).
///
/// Es el mismo MLP que entrena `ml/signcast/entrenar.py --tarea alfabeto`
/// (63 → 256 → 128 → letras, con ReLU y softmax), calculado directo en Dart:
/// pesa unos 200 KB y no necesita LiteRT. Los pesos salen de
/// `python -m signcast.exportar_alfabeto`.
///
/// Formato de `alfabeto.bin`: float32 little-endian, por capa primero la
/// matriz `(entradas, salidas)` por filas y luego el sesgo.
class ClasificadorAlfabeto {
  ClasificadorAlfabeto({
    required this.etiquetas,
    required Float32List pesos,
    List<int> ocultas = const [256, 128],
    int entradas = nCaracteristicasMano,
  }) : _tamanos = [entradas, ...ocultas, etiquetas.length],
       _pesos = pesos {
    var esperados = 0;
    for (var i = 0; i < _tamanos.length - 1; i++) {
      esperados += _tamanos[i] * _tamanos[i + 1] + _tamanos[i + 1];
    }
    if (pesos.length != esperados) {
      throw ArgumentError(
        'El alfabeto necesita $esperados pesos y llegaron ${pesos.length}.',
      );
    }
  }

  /// Lee `alfabeto.bin` ([bytes]) y `alfabeto_etiquetas.txt` ([etiquetas]).
  factory ClasificadorAlfabeto.desdeBytes(
    ByteData bytes,
    String etiquetas, {
    List<int> ocultas = const [256, 128],
    int entradas = nCaracteristicasMano,
  }) {
    final pesos = Float32List(bytes.lengthInBytes ~/ 4);
    for (var i = 0; i < pesos.length; i++) {
      pesos[i] = bytes.getFloat32(i * 4, Endian.little);
    }
    return ClasificadorAlfabeto(
      etiquetas: etiquetas
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .toList(),
      pesos: pesos,
      ocultas: ocultas,
      entradas: entradas,
    );
  }

  /// Letras en el orden de la salida.
  final List<String> etiquetas;

  final List<int> _tamanos;
  final Float32List _pesos;

  /// Una probabilidad por letra para el vector de [mano] (63 valores, ver
  /// [caracteristicasMano]).
  Float32List predecir(Float32List mano) {
    if (mano.length != _tamanos.first) {
      throw ArgumentError(
        'Se esperaban ${_tamanos.first} valores y llegaron ${mano.length}.',
      );
    }
    var actual = mano;
    var inicio = 0;
    final capas = _tamanos.length - 1;
    for (var c = 0; c < capas; c++) {
      final entra = _tamanos[c];
      final sale = _tamanos[c + 1];
      final sesgo = inicio + entra * sale;
      final siguiente = Float32List(sale);
      for (var j = 0; j < sale; j++) {
        siguiente[j] = _pesos[sesgo + j];
      }
      for (var i = 0; i < entra; i++) {
        final x = actual[i];
        if (x == 0) continue;
        final fila = inicio + i * sale;
        for (var j = 0; j < sale; j++) {
          siguiente[j] += x * _pesos[fila + j];
        }
      }
      inicio = sesgo + sale;
      if (c < capas - 1) {
        for (var j = 0; j < sale; j++) {
          if (siguiente[j] < 0) siguiente[j] = 0;
        }
      }
      actual = siguiente;
    }
    return _softmax(actual);
  }

  static Float32List _softmax(Float32List z) {
    var mayor = z[0];
    for (final v in z) {
      if (v > mayor) mayor = v;
    }
    final salida = Float32List(z.length);
    var suma = 0.0;
    for (var i = 0; i < z.length; i++) {
      final e = math.exp(z[i] - mayor);
      salida[i] = e;
      suma += e;
    }
    for (var i = 0; i < z.length; i++) {
      salida[i] = salida[i] / suma;
    }
    return salida;
  }
}

/// Carga el clasificador incluido con la app (`assets/modelos/`). Devuelve
/// `null` si los archivos no están: entonces el deletreo no se puede usar.
Future<ClasificadorAlfabeto?> cargarAlfabetoIncluido() async {
  try {
    final bytes = await rootBundle.load('assets/modelos/alfabeto.bin');
    final etiquetas = await rootBundle.loadString(
      'assets/modelos/alfabeto_etiquetas.txt',
    );
    return ClasificadorAlfabeto.desdeBytes(bytes, etiquetas);
  } catch (_) {
    return null;
  }
}
