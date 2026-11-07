import 'detector_puntos.dart';

/// Fuera del navegador (por ejemplo en `flutter test`) no hay detector: la
/// detección de puntos solo existe en web.
DetectorPuntos crearDetectorPlataforma() => throw UnsupportedError(
  'La detección de puntos solo funciona en el navegador.',
);

/// Sin navegador no hay nada que precargar.
Future<void> precargarDetector() async {}
