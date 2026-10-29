// Elige el predictor según la plataforma: LiteRT.js en el navegador y, fuera
// de él, un aviso de que no existe. Ofrece `PredictorSenas crearPredictorPlataforma()`.
export 'predictor_plataforma_otro.dart'
    if (dart.library.js_interop) 'predictor_plataforma_web.dart';
