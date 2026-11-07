import 'dart:async';
import 'dart:typed_data';

import 'package:app/models/cuadro_puntos.dart';
import 'package:app/models/estado_deteccion.dart';
import 'package:app/services/caracteristicas.dart';
import 'package:app/services/frases.dart';
import 'package:app/services/predictor_senas.dart';
import 'package:app/services/reconocedor.dart';
import 'package:app/services/reconocedor_modelo.dart';
import 'package:flutter_test/flutter_test.dart';

class _PredictorFalso implements PredictorSenas {
  int actual = 0;
  int llamadas = 0;
  int largoVentana = 0;

  @override
  List<String> get etiquetas => const ['_REPOSO', 'HOLA', 'ADIOS'];

  @override
  Future<void> cargar() async {}

  @override
  Future<Float32List> predecir(Float32List ventana) async {
    llamadas++;
    largoVentana = ventana.length;
    final p = Float32List(3)..[actual] = 0.95;
    return p;
  }
}

CuadroPuntos _cuadroConMano() =>
    CuadroPuntos(manoDer: Float32List.fromList(List.filled(63, 0.5)));

void main() {
  test('traduce una seña y cierra la frase tras la pausa', () async {
    final predictor = _PredictorFalso();
    var ms = 0;
    final cuadros = StreamController<CuadroPuntos>.broadcast(sync: true);
    final r = ReconocedorModelo(predictor: predictor, reloj: () => ms);
    final eventos = <EventoReconocimiento>[];
    r.eventos.listen(eventos.add);
    r.conectarCuadros(cuadros.stream);
    r.iniciar();
    await pumpEventQueue();

    Future<void> mandar(int n, int etiqueta) async {
      predictor.actual = etiqueta;
      for (var i = 0; i < n; i++) {
        ms += 33;
        cuadros.add(_cuadroConMano());
        await pumpEventQueue();
      }
    }

    await mandar(45, 0); // reposo: llena la ventana
    expect(eventos.last.estado, EstadoDeteccion.detectando);
    expect(eventos.last.glosas, isEmpty);

    await mandar(15, 1); // seña HOLA
    expect(eventos.last.estado, EstadoDeteccion.detectando);
    expect(eventos.last.glosas, ['HOLA']);
    expect(predictor.largoVentana, longitudSecuencia * nCaracteristicas);

    await mandar(80, 0); // reposo largo: se cierra la frase
    final traduciendo = eventos.where(
      (e) => e.estado == EstadoDeteccion.traduciendo,
    );
    expect(traduciendo.length, 1);
    expect(traduciendo.single.glosas, ['HOLA']);
    expect(traduciendo.single.frase, construirFrase(['HOLA']));

    await r.liberar();
    await cuadros.close();
  });

  test('sin manos y sin seña informa sinManos', () async {
    final predictor = _PredictorFalso();
    var ms = 0;
    final cuadros = StreamController<CuadroPuntos>.broadcast(sync: true);
    final r = ReconocedorModelo(predictor: predictor, reloj: () => ms);
    final eventos = <EventoReconocimiento>[];
    r.eventos.listen(eventos.add);
    r.conectarCuadros(cuadros.stream);
    r.iniciar();
    await pumpEventQueue();

    ms += 33;
    cuadros.add(CuadroPuntos());
    await pumpEventQueue();
    expect(eventos.single.estado, EstadoDeteccion.sinManos);

    await r.liberar();
    await cuadros.close();
  });

  test(
    'sin manos en la ventana no corre el modelo y cuenta como reposo',
    () async {
      final predictor = _PredictorFalso()..actual = 1; // diría HOLA
      var ms = 0;
      final cuadros = StreamController<CuadroPuntos>.broadcast(sync: true);
      final r = ReconocedorModelo(predictor: predictor, reloj: () => ms);
      final eventos = <EventoReconocimiento>[];
      r.eventos.listen(eventos.add);
      r.conectarCuadros(cuadros.stream);
      r.iniciar();
      await pumpEventQueue();

      for (var i = 0; i < 60; i++) {
        ms += 33;
        cuadros.add(CuadroPuntos());
        await pumpEventQueue();
      }
      expect(predictor.llamadas, 0);
      expect(eventos.every((e) => e.glosas.isEmpty), isTrue);

      await r.liberar();
      await cuadros.close();
    },
  );

  test('detenido no procesa cuadros', () async {
    final predictor = _PredictorFalso();
    final cuadros = StreamController<CuadroPuntos>.broadcast(sync: true);
    final r = ReconocedorModelo(predictor: predictor);
    final eventos = <EventoReconocimiento>[];
    r.eventos.listen(eventos.add);
    r.conectarCuadros(cuadros.stream);
    cuadros.add(_cuadroConMano());
    await pumpEventQueue();
    expect(eventos, isEmpty);
    expect(predictor.llamadas, 0);

    await r.liberar();
    await cuadros.close();
  });
}
