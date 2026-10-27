import 'detector_puntos.dart';

/// Android y demás plataformas con código nativo (`DetectorPuntos.kt`).
DetectorPuntos crearDetectorPlataforma() => DetectorPuntosNativo();
