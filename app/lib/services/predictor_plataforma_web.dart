import 'dart:js_interop';
import 'dart:typed_data';

import 'modelo_js.dart';
import 'predictor_senas.dart';

/// Predictor del navegador: LiteRT.js corre el `.tflite` de `assets/modelos/`.
class PredictorSenasWeb implements PredictorSenas {
  ModeloJS? _js;
  List<String> _etiquetas = const [];

  @override
  List<String> get etiquetas => _etiquetas;

  @override
  Future<void> cargar() async {
    final js = await esperarModeloJs();
    await js.cargar().toDart;
    _etiquetas = js.etiquetas.toDart
        .split(' ')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    _js = js;
  }

  @override
  Future<Float32List> predecir(Float32List ventana) async {
    final salida = await _js!.predecir(ventana.toJS).toDart;
    return salida.toDart;
  }
}

PredictorSenas crearPredictorPlataforma() => PredictorSenasWeb();
