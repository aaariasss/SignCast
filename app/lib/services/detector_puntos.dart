import 'dart:ui' show Size;

import '../models/cuadro_puntos.dart';

/// Quien saca los puntos de MediaPipe (manos, pose y rostro) de la cámara.
/// Las pantallas solo conocen este contrato. La implementación real es
/// `detector_plataforma_web.dart`: MediaPipe corre en el navegador
/// (`web/mediapipe/puntos.js`) con los mismos modelos `.task` que Python, así
/// los puntos son comparables con los del entrenamiento.
abstract class DetectorPuntos {
  /// Un evento por cada imagen procesada.
  Stream<CuadroPuntos> get cuadros;

  /// Tamaño del video en píxeles, para colocar los puntos encima. Es nulo
  /// mientras la cámara no ha empezado.
  Size? get tamanoVideo;

  /// Carga los modelos y abre la cámara.
  Future<void> iniciar();

  /// Pausa o reanuda la detección sin apagar la cámara (por ejemplo, cuando la
  /// pestaña del traductor queda oculta).
  void pausar(bool pausado);

  Future<void> liberar();
}
