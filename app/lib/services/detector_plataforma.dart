// Elige el detector de puntos según la plataforma: MediaPipe web en el
// navegador y, fuera de él, un aviso de que no existe. Ofrece
// `DetectorPuntos crearDetectorPlataforma()`.
export 'detector_plataforma_otro.dart'
    if (dart.library.js_interop) 'detector_plataforma_web.dart';
