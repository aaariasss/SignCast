import 'dart:math';

import 'package:app/models/estado_deteccion.dart';
import 'package:app/services/reconocedor.dart';
import 'package:app/services/reconocedor_falso.dart';
import 'package:app/services/voz.dart';
import 'package:app/state/app_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _VozEspia implements Voz {
  final List<String> dichas = [];
  final List<double> velocidades = [];
  int cortes = 0;

  @override
  final ValueNotifier<bool> hablando = ValueNotifier<bool>(false);

  @override
  Future<void> hablar(String texto, {required double velocidad}) async {
    dichas.add(texto);
    velocidades.add(velocidad);
  }

  @override
  Future<void> detener() async => cortes++;

  @override
  Future<void> preparar() async {}
}

const _traduciendo = EventoReconocimiento(
  estado: EstadoDeteccion.traduciendo,
  glosas: ['YO', 'NO', 'ENTENDER'],
  frase: 'No entiendo.',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppState', () {
    test('una frase nueva entra al historial y se lee en voz alta', () async {
      final voz = _VozEspia();
      final app = await AppState.crear(
        reconocedor: ReconocedorFalso(),
        voz: voz,
      );

      app.aplicarEvento(
        const EventoReconocimiento(
          estado: EstadoDeteccion.detectando,
          glosas: ['YO', 'NO'],
        ),
      );
      expect(app.historial, isEmpty);
      expect(app.estado, EstadoDeteccion.detectando);

      app.aplicarEvento(_traduciendo);
      expect(app.historial.single.texto, 'No entiendo.');
      expect(app.fraseActual, 'No entiendo.');
      expect(voz.dichas, ['No entiendo.']);
    });

    test('con la voz apagada no lee solo, pero Repetir sí', () async {
      final voz = _VozEspia();
      final app = await AppState.crear(
        reconocedor: ReconocedorFalso(),
        voz: voz,
      );

      await app.alternarVoz();
      expect(app.ajustes.vozActiva, isFalse);

      app.aplicarEvento(_traduciendo);
      expect(voz.dichas, isEmpty);

      await app.repetir();
      expect(voz.dichas, ['No entiendo.']);
    });

    test('la velocidad elegida llega a la voz', () async {
      final voz = _VozEspia();
      final app = await AppState.crear(
        reconocedor: ReconocedorFalso(),
        voz: voz,
      );

      await app.cambiarVelocidad(0.7);
      app.aplicarEvento(_traduciendo);
      expect(voz.velocidades, [0.7]);
    });

    test('silenciar la voz corta la frase que está sonando', () async {
      final voz = _VozEspia();
      final app = await AppState.crear(
        reconocedor: ReconocedorFalso(),
        voz: voz,
      );

      await app.alternarVoz();
      expect(voz.cortes, 1);

      // Volver a activarla no corta nada.
      await app.alternarVoz();
      expect(voz.cortes, 1);
    });

    test('los ajustes se guardan y se recuperan', () async {
      final app = await AppState.crear(
        reconocedor: ReconocedorFalso(),
        voz: const VozNula(),
      );
      await app.cambiarTamano(32);
      await app.cambiarVelocidad(1.3);
      await app.cambiarOscuro(false);

      final otra = await AppState.crear(
        reconocedor: ReconocedorFalso(),
        voz: const VozNula(),
      );
      expect(otra.ajustes.tamano, 32);
      expect(otra.ajustes.velocidadVoz, 1.3);
      expect(otra.ajustes.oscuro, isFalse);
    });

    test('los ajustes respetan sus límites', () async {
      final app = await AppState.crear(
        reconocedor: ReconocedorFalso(),
        voz: const VozNula(),
      );
      await app.cambiarTamano(99);
      expect(app.ajustes.tamano, 36);
      await app.cambiarVelocidad(0.1);
      expect(app.ajustes.velocidadVoz, 0.5);
    });
  });

  test(
    'el reconocedor falso recorre sin manos, detectando y traduciendo',
    () async {
      final reconocedor = ReconocedorFalso(
        azar: Random(1),
        paso: const Duration(milliseconds: 10),
      );
      final estados = <EstadoDeteccion>[];
      final frases = <String>[];
      final sub = reconocedor.eventos.listen((e) {
        estados.add(e.estado);
        final frase = e.frase;
        if (frase != null) frases.add(frase);
      });

      reconocedor.iniciar();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      reconocedor.detener();

      expect(estados.first, EstadoDeteccion.sinManos);
      expect(estados, contains(EstadoDeteccion.detectando));
      expect(estados, contains(EstadoDeteccion.traduciendo));
      expect(frases, isNotEmpty);
      expect(frases.first, isNotEmpty);

      await sub.cancel();
      await reconocedor.liberar();
    },
  );
}
