// Elige el detector de puntos según la plataforma: MediaPipe web en el
// navegador y, fuera de él, un aviso de que no existe. Ofrece
// `DetectorPuntos crearDetectorPlataforma()` y
// `Future<void> precargarDetector()`.
export 'detector_plataforma_otro.dart'
    if (dart.library.js_interop) 'detector_plataforma_web.dart';
