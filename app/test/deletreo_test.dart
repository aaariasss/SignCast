import 'dart:async';
import 'dart:typed_data';

import 'package:app/models/cuadro_puntos.dart';
import 'package:app/models/estado_deteccion.dart';
import 'package:app/services/clasificador_alfabeto.dart';
import 'package:app/services/frases.dart';
import 'package:app/services/predictor_senas.dart';
import 'package:app/services/reconocedor.dart';
import 'package:app/services/reconocedor_modelo.dart';
import 'package:flutter_test/flutter_test.dart';

class _PredictorNulo implements PredictorSenas {
  int llamadas = 0;

  @override
  List<String> get etiquetas => const ['_REPOSO', 'HOLA'];

  @override
  Future<void> cargar() async {}

  @override
  Future<Float32List> predecir(Float32List ventana) async {
    llamadas++;
    return Float32List.fromList([1, 0]);
  }
}

class _PredictorLetras implements PredictorSenas {
  int actual = 0;

  @override
  List<String> get etiquetas => const ['_REPOSO', 'HOLA', 'J'];

  @override
  Future<void> cargar() async {}

  @override
  Future<Float32List> predecir(Float32List ventana) async =>
      Float32List(3)..[actual] = 0.95;
}

/// Nunca llega al umbral: todas las letras salen con la misma probabilidad.
ClasificadorAlfabeto _sinLetra() => ClasificadorAlfabeto(
  etiquetas: const ['A', 'B'],
  pesos: Float32List(63 * 2 + 2),
  ocultas: const [],
);

/// Clasifica siempre como `A` (sesgo grande, pesos en cero).
ClasificadorAlfabeto _siempreA() {
  final pesos = Float32List(63 * 2 + 2)..[63 * 2] = 6;
  return ClasificadorAlfabeto(
    etiquetas: const ['A', 'B'],
    pesos: pesos,
    ocultas: const [],
  );
}

/// Una mano con tamaño (los puntos no están todos en el mismo lugar).
CuadroPuntos _mano([double desplazamiento = 0]) {
  final m = Float32List(63);
  for (var i = 0; i < 21; i++) {
    m[i * 3] = 0.3 + 0.01 * i + desplazamiento;
    m[i * 3 + 1] = 0.4 + 0.02 * i;
  }
  return CuadroPuntos(manoDer: m);
}

void main() {
  test(
    'el deletreo acepta una letra, no la repite y cierra la frase sin manos',
    () async {
      final predictor = _PredictorNulo();
      var ms = 0;
      final cuadros = StreamController<CuadroPuntos>.broadcast(sync: true);
      final r = ReconocedorModelo(
        predictor: predictor,
        cargarAlfabeto: () async => _siempreA(),
        reloj: () => ms,
      );
      final eventos = <EventoReconocimiento>[];
      r.eventos.listen(eventos.add);
      r.conectarCuadros(cuadros.stream);
      r.iniciar();
      await pumpEventQueue();
      r.deletreo = true;

      Future<void> mandar(int n, CuadroPuntos Function() cuadro) async {
        for (var i = 0; i < n; i++) {
          ms += 33;
          cuadros.add(cuadro());
          await pumpEventQueue();
        }
      }

      await mandar(19, _mano); // 594 ms: todavía no la sostiene 600 ms
      expect(eventos.last.glosas, isEmpty);

      await mandar(1, _mano);
      expect(eventos.last.glosas, ['A']);

      await mandar(30, _mano); // la misma letra no se repite
      expect(eventos.last.glosas, ['A']);

      await mandar(50, CuadroPuntos.new); // sin manos: la frase se cierra
      final cerradas = eventos.where(
        (e) => e.estado == EstadoDeteccion.traduciendo,
      );
      expect(cerradas.length, 1);
      expect(cerradas.single.glosas, ['A']);
      expect(cerradas.single.frase, construirFrase(['A']));

      await r.liberar();
      await cuadros.close();
    },
  );

  test('sin el clasificador el deletreo no hace nada', () async {
    final predictor = _PredictorNulo();
    var ms = 0;
    final cuadros = StreamController<CuadroPuntos>.broadcast(sync: true);
    final r = ReconocedorModelo(predictor: predictor, reloj: () => ms);
    final eventos = <EventoReconocimiento>[];
    r.eventos.listen(eventos.add);
    r.conectarCuadros(cuadros.stream);
    r.iniciar();
    await pumpEventQueue();
    r.deletreo = true;

    for (var i = 0; i < 40; i++) {
      ms += 33;
      cuadros.add(_mano());
      await pumpEventQueue();
    }
    expect(eventos.every((e) => e.glosas.isEmpty), isTrue);

    await r.liberar();
    await cuadros.close();
  });

  test('en deletreo reconoce las letras con movimiento, pero no con la mano quieta ni las palabras', () async {
    final predictor = _PredictorLetras();
    var ms = 0;
    final cuadros = StreamController<CuadroPuntos>.broadcast(sync: true);
    final r = ReconocedorModelo(
      predictor: predictor,
      cargarAlfabeto: () async => _sinLetra(),
      reloj: () => ms,
    );
    final eventos = <EventoReconocimiento>[];
    r.eventos.listen(eventos.add);
    r.conectarCuadros(cuadros.stream);
    r.iniciar();
    await pumpEventQueue();
    r.deletreo = true;

    var paso = 0;
    Future<void> mandar(int n, int etiqueta, {bool mover = false}) async {
      predictor.actual = etiqueta;
      for (var i = 0; i < n; i++) {
        ms += 33;
        if (mover) paso++;
        cuadros.add(_mano(paso * 0.05));
        await pumpEventQueue();
      }
    }

    await mandar(45, 1); // una palabra: se ignora
    expect(eventos.last.glosas, isEmpty);

    await mandar(60, 2); // el modelo dice J, pero la mano está quieta (la N)
    expect(eventos.last.glosas, isEmpty);

    await mandar(15, 2, mover: true); // la J con movimiento
    expect(eventos.last.glosas, ['J']);

    await r.liberar();
    await cuadros.close();
  });
}
