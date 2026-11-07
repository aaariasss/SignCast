import 'dart:typed_data';

/// Puntos crudos de MediaPipe de un cuadro de cámara.
///
/// Equivale a `Cuadro` en `ml/signcast/puntos_clave.py`. Cada arreglo guarda
/// los puntos aplanados como `x0, y0, z0, x1, y1, z1…` en coordenadas
/// normalizadas (0 a 1). Un punto o parte no detectada queda como `NaN`.
class CuadroPuntos {
  CuadroPuntos({
    Float32List? manoIzq,
    Float32List? manoDer,
    Float32List? pose,
    Float32List? cara,
  }) : manoIzq = manoIzq ?? _vacio(puntosMano),
       manoDer = manoDer ?? _vacio(puntosMano),
       pose = pose ?? _vacio(puntosPose),
       cara = cara ?? _vacio(puntosCara) {
    assert(this.manoIzq.length == puntosMano * 3);
    assert(this.manoDer.length == puntosMano * 3);
    assert(this.pose.length == puntosPose * 3);
    assert(this.cara.length == puntosCara * 3);
  }

  /// Decodifica lo que manda `web/mediapipe/puntos.js`: un solo arreglo con
  /// mano izquierda, mano derecha, pose y rostro, en ese orden.
  factory CuadroPuntos.desdePlano(Float32List datos) {
    if (datos.length != longitudPlano) {
      throw ArgumentError(
        'Se esperaban $longitudPlano valores y llegaron ${datos.length}.',
      );
    }
    var inicio = 0;
    Float32List tomar(int n) {
      final parte = Float32List.fromList(datos.sublist(inicio, inicio + n * 3));
      inicio += n * 3;
      return parte;
    }

    return CuadroPuntos(
      manoIzq: tomar(puntosMano),
      manoDer: tomar(puntosMano),
      pose: tomar(puntosPose),
      cara: tomar(puntosCara),
    );
  }

  /// 21 puntos por mano.
  static const int puntosMano = 21;

  /// 33 puntos de pose (se usan 9, ver `indicesPose`).
  static const int puntosPose = 33;

  /// 478 puntos de rostro (se usan 39, ver `indicesCara`).
  static const int puntosCara = 478;

  /// Largo del arreglo que manda `web/mediapipe/puntos.js`.
  static const int longitudPlano =
      (2 * puntosMano + puntosPose + puntosCara) * 3;

  final Float32List manoIzq;
  final Float32List manoDer;
  final Float32List pose;
  final Float32List cara;

  bool get hayMano => !(_todoNaN(manoIzq) && _todoNaN(manoDer));

  /// Copia el cuadro multiplicando `x` por [factor].
  ///
  /// Sirve para compensar que la app procesa una imagen con otra relación de
  /// aspecto que la usada al grabar (ver nota 1 de la sección 9 de
  /// `docs/formato_puntos_clave.md`). Con `factor = 1` no cambia nada.
  CuadroPuntos escalarX(double factor) {
    Float32List f(Float32List a) {
      final s = Float32List.fromList(a);
      for (var i = 0; i < s.length; i += 3) {
        s[i] = s[i] * factor;
      }
      return s;
    }

    return CuadroPuntos(
      manoIzq: f(manoIzq),
      manoDer: f(manoDer),
      pose: f(pose),
      cara: f(cara),
    );
  }

  static Float32List _vacio(int n) =>
      Float32List(n * 3)..fillRange(0, n * 3, double.nan);

  static bool _todoNaN(Float32List a) => a.every((v) => v.isNaN);
}
