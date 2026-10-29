import 'dart:async';
import 'dart:js_interop';

/// Módulo JavaScript `web/modelo/modelo.js` (LiteRT.js). Solo existe en el
/// navegador.
@JS('signcastModelo')
external ModeloJS? get _modeloGlobal;

extension type ModeloJS._(JSObject _) implements JSObject {
  /// Carga el modelo `.tflite` y `etiquetas.txt` desde el propio sitio.
  external JSPromise<JSAny?> cargar();

  /// Recibe 30 × 270 valores y devuelve una probabilidad por etiqueta.
  external JSPromise<JSFloat32Array> predecir(JSFloat32Array ventana);

  /// Etiquetas separadas por espacios.
  external JSString get etiquetas;
}

/// Espera a que cargue el módulo (se carga como `type="module"`, así que puede
/// terminar un poco después de que arranca Flutter).
Future<ModeloJS> esperarModeloJs() async {
  for (var i = 0; i < 100; i++) {
    final js = _modeloGlobal;
    if (js != null) return js;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError(
    'No cargó web/modelo/modelo.js. ¿Corriste '
    'app/tool/preparar_litert_web.ps1?',
  );
}
