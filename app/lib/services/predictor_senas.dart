import 'dart:typed_data';

/// Corre el modelo de señas sobre una ventana de 30 cuadros × 270 valores.
/// En el navegador lo hace LiteRT.js (`web/modelo/modelo.js`).
abstract class PredictorSenas {
  /// Carga el modelo y las etiquetas. Falla si no están en el sitio.
  Future<void> cargar();

  /// Glosas en el orden de la salida del modelo (`etiquetas.txt`).
  List<String> get etiquetas;

  /// [ventana] es la matriz (30, 270) aplanada. Devuelve una probabilidad por
  /// etiqueta.
  Future<Float32List> predecir(Float32List ventana);
}
