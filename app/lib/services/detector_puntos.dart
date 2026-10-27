import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/cuadro_puntos.dart';

/// Quien saca los puntos de MediaPipe (manos, pose y rostro) de las imágenes
/// de la cámara. Las pantallas solo conocen este contrato.
abstract class DetectorPuntos {
  /// Un evento por cada imagen procesada.
  Stream<CuadroPuntos> get cuadros;

  /// Solo en web: tamaño del video en píxeles, para colocar los puntos encima.
  /// En las demás plataformas es nulo y la cámara la maneja el paquete `camera`.
  Size? get tamanoVideo;

  Future<void> iniciar();

  /// Pausa o reanuda la detección sin apagar la cámara (por ejemplo, cuando la
  /// pestaña del traductor queda oculta).
  void pausar(bool pausado);

  /// Entrega una imagen de la cámara. [rotacion] son los grados que hay que
  /// girarla para que quede derecha (`sensorOrientation` de la cámara).
  /// Si el detector sigue ocupado con la anterior, la ignora.
  void procesar(CameraImage imagen, {required int rotacion});

  Future<void> liberar();
}

/// Detector con MediaPipe Tasks en Android (`DetectorPuntos.kt`), conectado
/// por canales de plataforma. Usa los mismos modelos `.task` que Python, así
/// los puntos son comparables con los del entrenamiento.
class DetectorPuntosNativo implements DetectorPuntos {
  static const MethodChannel _metodos = MethodChannel('signcast/puntos');
  static const EventChannel _eventos = EventChannel('signcast/puntos/cuadros');

  final StreamController<CuadroPuntos> _controlador =
      StreamController<CuadroPuntos>.broadcast();
  StreamSubscription<dynamic>? _suscripcion;
  bool _ocupado = false;

  // Promedio de milisegundos por etapa, impreso cada 20 imágenes.
  final List<int> _sumaMs = [0, 0, 0, 0];
  int _imagenesMedidas = 0;

  void _registrarTiempos(List<dynamic>? ms) {
    if (ms == null || ms.length != 4) return;
    for (var i = 0; i < 4; i++) {
      _sumaMs[i] += (ms[i] as num).toInt();
    }
    if (++_imagenesMedidas < 20) return;
    final p = _sumaMs.map((s) => (s / _imagenesMedidas).round()).toList();
    debugPrint(
      'Puntos: ms por imagen -> conversión ${p[0]}, manos ${p[1]}, '
      'pose ${p[2]}, rostro ${p[3]}',
    );
    _sumaMs.fillRange(0, 4, 0);
    _imagenesMedidas = 0;
  }

  @override
  Stream<CuadroPuntos> get cuadros => _controlador.stream;

  @override
  Size? get tamanoVideo => null;

  @override
  void pausar(bool pausado) {}

  @override
  Future<void> iniciar() async {
    await _metodos.invokeMethod<void>('iniciar');
    await _suscripcion?.cancel();
    _suscripcion = _eventos.receiveBroadcastStream().listen(
      (dynamic datos) {
        if (datos is Float32List && datos.length == CuadroPuntos.longitudPlano) {
          _controlador.add(CuadroPuntos.desdePlano(datos));
        }
      },
      onError: (Object e) => debugPrint('Puntos: error del canal: $e'),
    );
  }

  @override
  void procesar(CameraImage imagen, {required int rotacion}) {
    // Solo YUV420 (3 planos), que es lo que entrega la cámara en Android.
    if (_ocupado || imagen.planes.length != 3) return;
    _ocupado = true;
    final y = imagen.planes[0], u = imagen.planes[1], v = imagen.planes[2];
    _metodos
        .invokeMethod<List<dynamic>>('procesar', <String, Object>{
          'ancho': imagen.width,
          'alto': imagen.height,
          'rotacion': rotacion,
          'y': y.bytes,
          'u': u.bytes,
          'v': v.bytes,
          'filaY': y.bytesPerRow,
          'filaUV': u.bytesPerRow,
          'pixelUV': u.bytesPerPixel ?? 1,
        })
        .then(_registrarTiempos)
        .catchError((Object e) => debugPrint('Puntos: no se procesó: $e'))
        .whenComplete(() {
          _ocupado = false;
        });
  }

  @override
  Future<void> liberar() async {
    await _suscripcion?.cancel();
    _suscripcion = null;
    try {
      await _metodos.invokeMethod<void>('liberar');
    } on MissingPluginException {
      // Sin código nativo (pruebas o escritorio): no hay nada que liberar.
    }
    await _controlador.close();
  }
}
