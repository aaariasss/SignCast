import 'dart:async';
import 'dart:js_interop';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import '../models/cuadro_puntos.dart';
import 'detector_puntos.dart';
import 'puntos_js.dart';

/// Detector del navegador: MediaPipe web en `web/mediapipe/`. El módulo
/// JavaScript abre la cámara, muestra el video y calcula los puntos; este
/// detector los recibe como `CuadroPuntos`.
class DetectorPuntosWeb implements DetectorPuntos {
  final StreamController<CuadroPuntos> _controlador =
      StreamController<CuadroPuntos>.broadcast();
  PuntosJS? _js;
  Size? _tamano;

  @override
  Stream<CuadroPuntos> get cuadros => _controlador.stream;

  @override
  Size? get tamanoVideo {
    final js = _js;
    if (js == null || _tamano == null) return _tamano;
    final ancho = js.ancho.toDartDouble;
    final alto = js.alto.toDartDouble;
    if (ancho > 0 &&
        alto > 0 &&
        (ancho != _tamano!.width || alto != _tamano!.height)) {
      _tamano = Size(ancho, alto);
    }
    return _tamano;
  }

  @override
  Future<void> iniciar() async {
    final js = await esperarPuntosJs();
    _js = js;
    await js.cargarModelos().toDart;
    await js.abrirCamara().toDart;
    _tamano = Size(js.ancho.toDartDouble, js.alto.toDartDouble);
    debugPrint(
      'Puntos: video ${_tamano!.width.toInt()}x${_tamano!.height.toInt()}, '
      'delegado ${js.delegado.toDart}',
    );
    js.suscribir(
      ((JSFloat32Array datos) {
        final plano = datos.toDart;
        if (plano.length == CuadroPuntos.longitudPlano &&
            !_controlador.isClosed) {
          _controlador.add(CuadroPuntos.desdePlano(plano));
        }
      }).toJS,
    );
  }

  @override
  void pausar(bool pausado) => _js?.pausar(pausado.toJS);

  @override
  Future<void> liberar() async {
    _js?.detener();
    _js = null;
    await _controlador.close();
  }
}

DetectorPuntos crearDetectorPlataforma() => DetectorPuntosWeb();
