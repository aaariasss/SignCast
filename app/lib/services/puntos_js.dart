import 'dart:async';
import 'dart:js_interop';

/// Módulo JavaScript `web/mediapipe/puntos.js` (MediaPipe web). Solo existe
/// en el navegador; las demás plataformas usan `detector_plataforma_otro.dart`.
@JS('signcastPuntos')
external PuntosJS? get _puntosGlobal;

extension type PuntosJS._(JSObject _) implements JSObject {
  /// Carga los modelos de manos, pose y rostro.
  external JSPromise<JSAny?> cargarModelos();

  /// Estado del permiso sin mostrar avisos: `granted`, `denied` o `prompt`.
  external JSPromise<JSString> estadoPermiso();

  /// Pide el permiso de la cámara y lo suelta; hay que llamarlo desde un toque.
  external JSPromise<JSBoolean> pedirPermiso();

  /// Abre la cámara frontal y muestra el video a pantalla completa, detrás de
  /// Flutter.
  external JSPromise<JSAny?> abrirCamara();

  /// Manda un `Float32Array` de 1659 valores por cada imagen procesada.
  external void suscribir(JSFunction alCuadro);

  /// Pausa o reanuda la detección sin apagar la cámara.
  external void pausar(JSBoolean pausado);

  /// Detiene la detección y apaga la cámara.
  external void detener();

  /// Tamaño del video en píxeles.
  external JSNumber get ancho;
  external JSNumber get alto;

  /// `GPU` o `CPU`, según lo que pudo usar MediaPipe.
  external JSString get delegado;
}

/// Espera a que cargue el módulo (se carga como `type="module"`, así que puede
/// terminar un poco después de que arranca Flutter).
Future<PuntosJS> esperarPuntosJs() async {
  for (var i = 0; i < 100; i++) {
    final js = _puntosGlobal;
    if (js != null) return js;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError(
    'No cargó web/mediapipe/puntos.js. ¿Corriste '
    'app/tool/preparar_mediapipe_web.ps1?',
  );
}
