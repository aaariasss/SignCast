// Elige el detector de puntos según la plataforma: MediaPipe web en el
// navegador, y el código nativo en las demás. Ofrece
// `DetectorPuntos crearDetectorPlataforma()`.
export 'detector_plataforma_otro.dart'
    if (dart.library.js_interop) 'detector_plataforma_web.dart';
