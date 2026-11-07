// El vector de la app debe ser idéntico al de Python (`ml/signcast/puntos_clave.py`).
//
// Los casos salen de `test/fixtures/referencia_vector.json`, que genera
// `python -m signcast.referencia_dart` desde la carpeta `ml/` con puntos
// sintéticos y los resultados de Python. Ver `docs/formato_puntos_clave.md`,
// sección 10.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/models/cuadro_puntos.dart';
import 'package:app/services/caracteristicas.dart';
import 'package:flutter_test/flutter_test.dart';

/// `null` → todo `NaN`; si no, lista de puntos (`null` = punto ausente).
Float32List _puntos(Object? json, int n) {
  final salida = Float32List(n * 3)..fillRange(0, n * 3, double.nan);
  if (json == null) return salida;
  final lista = json as List<dynamic>;
  for (var i = 0; i < n; i++) {
    final p = lista[i] as List<dynamic>?;
    if (p == null) continue;
    for (var k = 0; k < 3; k++) {
      salida[i * 3 + k] = (p[k] as num).toDouble();
    }
  }
  return salida;
}

void _iguales(Iterable<double> real, List<dynamic> esperado, double tol) {
  final r = real.toList();
  expect(r.length, esperado.length, reason: 'largo del vector');
  for (var i = 0; i < r.length; i++) {
    final e = (esperado[i] as num).toDouble();
    expect(
      (r[i] - e).abs(),
      lessThanOrEqualTo(tol),
      reason: 'columna $i: Dart ${r[i]} vs Python $e',
    );
  }
}

void main() {
  final datos = jsonDecode(
    File('test/fixtures/referencia_vector.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final tol = (datos['tolerancia'] as num).toDouble();
  final cara = (datos['cara'] as List<dynamic>)
      .map((c) => _puntos(c, CuadroPuntos.puntosCara))
      .toList();

  CuadroPuntos cuadro(Map<String, dynamic> j, int t) => CuadroPuntos(
    manoIzq: _puntos(j['mano_izq'], CuadroPuntos.puntosMano),
    manoDer: _puntos(j['mano_der'], CuadroPuntos.puntosMano),
    pose: _puntos(j['pose'], CuadroPuntos.puntosPose),
    cara: cara[t],
  );

  group('constantes', () {
    test('mismas dimensiones que config.py', () {
      expect(indicesPose.length, 9);
      expect(indicesCara.length, 39);
      expect(nPuntos, 90);
      expect(nCaracteristicas, 270);
      expect(nCaracteristicasMano, 63);
      expect(longitudSecuencia, 30);
      expect(CuadroPuntos.longitudPlano, 1659);
    });
  });

  group('caracteristicasSecuencia (270 valores por cuadro)', () {
    for (final caso in datos['secuencias'] as List<dynamic>) {
      final c = caso as Map<String, dynamic>;
      test('${c['nombre']}: ${c['descripcion']}', () {
        final cuadros = (c['cuadros'] as List<dynamic>)
            .asMap()
            .entries
            .map((e) => cuadro(e.value as Map<String, dynamic>, e.key))
            .toList();
        final real = caracteristicasSecuencia(cuadros);
        final esperado = c['esperado'] as List<dynamic>;
        expect(real.length, esperado.length);
        for (var t = 0; t < real.length; t++) {
          expect(real[t].length, nCaracteristicas);
          _iguales(real[t], esperado[t] as List<dynamic>, tol);
        }
      });
    }

    test('ventana vacía', () {
      expect(caracteristicasSecuencia([]), isEmpty);
    });
  });

  group('caracteristicasMano (63 valores)', () {
    for (final caso in datos['manos'] as List<dynamic>) {
      final c = caso as Map<String, dynamic>;
      test('${c['nombre']}', () {
        final real = caracteristicasMano(
          _puntos(c['mano'], CuadroPuntos.puntosMano),
        );
        _iguales(real, c['esperado'] as List<dynamic>, tol);
      });
    }
  });

  group('manoPrincipal + caracteristicasMano', () {
    for (final caso in datos['mano_principal'] as List<dynamic>) {
      final c = caso as Map<String, dynamic>;
      test('${c['nombre']}', () {
        final q = CuadroPuntos(
          manoIzq: _puntos(c['mano_izq'], CuadroPuntos.puntosMano),
          manoDer: _puntos(c['mano_der'], CuadroPuntos.puntosMano),
        );
        _iguales(
          caracteristicasMano(manoPrincipal(q)),
          c['esperado'] as List<dynamic>,
          tol,
        );
      });
    }
  });

  group('CuadroPuntos', () {
    test('desdePlano reparte los valores en orden', () {
      final plano = Float32List(CuadroPuntos.longitudPlano);
      for (var i = 0; i < plano.length; i++) {
        plano[i] = i.toDouble();
      }
      final q = CuadroPuntos.desdePlano(plano);
      expect(q.manoIzq.first, 0);
      expect(q.manoDer.first, 63);
      expect(q.pose.first, 126);
      expect(q.cara.first, 126 + 99);
      expect(q.cara.last, CuadroPuntos.longitudPlano - 1);
    });

    test('desdePlano rechaza un largo incorrecto', () {
      expect(
        () => CuadroPuntos.desdePlano(Float32List(10)),
        throwsArgumentError,
      );
    });

    test('hayMano', () {
      expect(CuadroPuntos().hayMano, isFalse);
      final con = CuadroPuntos(
        manoDer: Float32List(63), // ceros, no NaN
      );
      expect(con.hayMano, isTrue);
    });

    test('escalarX solo cambia x', () {
      final m = Float32List(63);
      for (var i = 0; i < 63; i++) {
        m[i] = i + 1.0;
      }
      final e = CuadroPuntos(manoIzq: m).escalarX(2);
      expect(e.manoIzq[0], 2.0);
      expect(e.manoIzq[1], 2.0);
      expect(e.manoIzq[2], 3.0);
      expect(e.manoIzq[3], 8.0);
      expect(m[0], 1.0); // no modifica el original
    });
  });
}
