// Vectores que consume el modelo, a partir de los puntos crudos de MediaPipe.
//
// Traducción línea por línea de `ml/signcast/puntos_clave.py`
// (`caracteristicas_secuencia`, `caracteristicas_mano`, `mano_principal`) y
// de las constantes de `ml/signcast/config.py`. La especificación completa
// está en `docs/formato_puntos_clave.md`. Si cambia el código de Python,
// hay que cambiar este archivo y regenerar las referencias de la prueba
// (`python -m signcast.referencia_dart`).

import 'dart:math' as math;
import 'dart:typed_data';

import '../models/cuadro_puntos.dart';

/// Índices de pose usados: nariz, hombros, codos, muñecas y caderas.
const List<int> indicesPose = [0, 11, 12, 13, 14, 15, 16, 23, 24];
const int hombroIzq = 11;
const int hombroDer = 12;

/// Índices del rostro usados: labios, cejas, ojos y nariz (39 puntos).
const List<int> indicesCara = [
  // labios
  61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409, 270, 269, 267, 0, 37,
  39, 40, 185,
  // cejas
  70, 63, 105, 66, 107, 336, 296, 334, 293, 300,
  // ojos
  33, 133, 159, 145, 362, 263, 386, 374,
  // nariz
  1,
];

const int puntosMano = CuadroPuntos.puntosMano;

/// 21 + 21 + 9 + 39 puntos.
const int nPuntos = 2 * puntosMano + 9 + 39;

/// Valores por cuadro para el modelo de señas (90 puntos × 3).
const int nCaracteristicas = nPuntos * 3;

/// Valores de una mano para el clasificador del alfabeto (21 × 3).
const int nCaracteristicasMano = puntosMano * 3;

/// Cuadros por secuencia que recibe el modelo.
const int longitudSecuencia = 30;

/// Puntos crudos de una ventana de cuadros → matriz `(T, 270)`.
///
/// Normaliza por el centro y la distancia entre hombros. Lo que no se detectó
/// queda en 0.0 (no se rellena con otros cuadros), salvo el centro y la escala
/// de los hombros, que sí se rellenan.
List<Float32List> caracteristicasSecuencia(List<CuadroPuntos> cuadros) {
  final t = cuadros.length;
  if (t == 0) return [];

  final cx = List<double>.filled(t, double.nan);
  final cy = List<double>.filled(t, double.nan);
  final escala = List<double>.filled(t, double.nan);
  for (var i = 0; i < t; i++) {
    final p = cuadros[i].pose;
    final ix = p[hombroIzq * 3].toDouble();
    final iy = p[hombroIzq * 3 + 1].toDouble();
    final dx = p[hombroDer * 3].toDouble();
    final dy = p[hombroDer * 3 + 1].toDouble();
    cx[i] = (ix + dx) / 2;
    cy[i] = (iy + dy) / 2;
    escala[i] = math.sqrt((ix - dx) * (ix - dx) + (iy - dy) * (iy - dy));
  }

  _rellenar(cx);
  _rellenar(cy);
  _rellenar(escala);

  // Nunca se vio el cuerpo: centro fijo en el medio de la imagen.
  if (cx.any((v) => v.isNaN) || cy.any((v) => v.isNaN)) {
    cx.fillRange(0, t, 0.5);
    cy.fillRange(0, t, 0.5);
  }
  for (var i = 0; i < t; i++) {
    if (escala[i].isNaN || escala[i] < 1e-3) escala[i] = 0.3;
  }

  final salida = <Float32List>[];
  for (var i = 0; i < t; i++) {
    final c = cuadros[i];
    final fila = Float32List(nCaracteristicas);
    var k = 0;

    void punto(Float32List fuente, int indice) {
      final x = fuente[indice * 3].toDouble();
      final y = fuente[indice * 3 + 1].toDouble();
      final z = fuente[indice * 3 + 2].toDouble();
      fila[k++] = _cero((x - cx[i]) / escala[i]);
      fila[k++] = _cero((y - cy[i]) / escala[i]);
      fila[k++] = _cero(z / escala[i]);
    }

    for (var j = 0; j < puntosMano; j++) {
      punto(c.manoIzq, j);
    }
    for (var j = 0; j < puntosMano; j++) {
      punto(c.manoDer, j);
    }
    for (final j in indicesPose) {
      punto(c.pose, j);
    }
    for (final j in indicesCara) {
      punto(c.cara, j);
    }
    salida.add(fila);
  }
  return salida;
}

/// Una mano `(21 × 3)` → vector de 63 valores para el alfabeto estático.
///
/// Relativo a la muñeca y dividido entre el mayor alcance en `x`, `y`.
/// Si falta algún punto, o la mano no tiene tamaño, devuelve 63 ceros.
Float32List caracteristicasMano(Float32List mano) {
  final ceros = Float32List(nCaracteristicasMano);
  if (mano.any((v) => v.isNaN)) return ceros;

  final x0 = mano[0].toDouble();
  final y0 = mano[1].toDouble();
  final z0 = mano[2].toDouble();

  var escala = 0.0;
  for (var i = 0; i < puntosMano; i++) {
    final rx = mano[i * 3] - x0;
    final ry = mano[i * 3 + 1] - y0;
    escala = math.max(escala, math.sqrt(rx * rx + ry * ry));
  }
  if (escala < 1e-6) return ceros;

  final salida = Float32List(nCaracteristicasMano);
  for (var i = 0; i < puntosMano; i++) {
    salida[i * 3] = (mano[i * 3] - x0) / escala;
    salida[i * 3 + 1] = (mano[i * 3 + 1] - y0) / escala;
    salida[i * 3 + 2] = (mano[i * 3 + 2] - z0) / escala;
  }
  return salida;
}

/// De las dos manos del cuadro, la de mayor área de caja. Si no hay ninguna,
/// una mano toda en `NaN`.
Float32List manoPrincipal(CuadroPuntos cuadro) {
  final candidatas = [
    cuadro.manoIzq,
    cuadro.manoDer,
  ].where((m) => !m.every((v) => v.isNaN)).toList();
  if (candidatas.isEmpty) {
    return Float32List(nCaracteristicasMano)
      ..fillRange(0, nCaracteristicasMano, double.nan);
  }
  // Igual que `max(..., key=area)` de Python: gana la primera y solo la
  // reemplaza una con área estrictamente mayor (con NaN la comparación falla).
  var mejor = candidatas.first;
  var mejorArea = _area(mejor);
  for (final m in candidatas.skip(1)) {
    final a = _area(m);
    if (a > mejorArea) {
      mejor = m;
      mejorArea = a;
    }
  }
  return mejor;
}

/// `np.ptp(x) * np.ptp(y)`; es `NaN` si algún valor lo es.
double _area(Float32List mano) {
  var minX = double.infinity, maxX = double.negativeInfinity;
  var minY = double.infinity, maxY = double.negativeInfinity;
  for (var i = 0; i < puntosMano; i++) {
    final x = mano[i * 3], y = mano[i * 3 + 1];
    if (x.isNaN || y.isNaN) return double.nan;
    minX = math.min(minX, x);
    maxX = math.max(maxX, x);
    minY = math.min(minY, y);
    maxY = math.max(maxY, y);
  }
  return (maxX - minX) * (maxY - minY);
}

/// Rellena `NaN` hacia adelante y luego hacia atrás (`_rellenar` de Python).
void _rellenar(List<double> v) {
  for (var t = 1; t < v.length; t++) {
    if (v[t].isNaN) v[t] = v[t - 1];
  }
  for (var t = v.length - 2; t >= 0; t--) {
    if (v[t].isNaN) v[t] = v[t + 1];
  }
}

/// `np.nan_to_num(..., nan=0.0)`.
double _cero(double v) => v.isNaN ? 0.0 : v;
