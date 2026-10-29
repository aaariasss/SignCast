import 'predictor_senas.dart';

/// Fuera del navegador (por ejemplo en `flutter test`) no hay modelo: corre
/// solo en web.
PredictorSenas crearPredictorPlataforma() =>
    throw UnsupportedError('El modelo de señas solo corre en el navegador.');
