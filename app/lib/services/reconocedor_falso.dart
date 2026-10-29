import 'dart:async';
import 'dart:math';

import '../models/cuadro_puntos.dart';
import '../models/estado_deteccion.dart';
import 'frases.dart';
import 'reconocedor.dart';

enum _Etapa { reposo, signando, mostrando }

/// Reconocedor de mentira para probar la interfaz sin modelo.
///
/// Repite en bucle: unos segundos sin manos, luego va "reconociendo" las
/// glosas de una frase al azar (de `docs/frases.md`) y por último entrega la
/// frase armada con `construirFrase`.
class ReconocedorFalso implements Reconocedor {
  ReconocedorFalso({
    Random? azar,
    this.paso = const Duration(milliseconds: 700),
  }) : _azar = azar ?? Random();

  static const List<List<String>> _frases = [
    ['YO', 'NO', 'ENTENDER'],
    ['REPETIR', 'POR-FAVOR'],
    ['AYUDAR', 'YO', 'POR-FAVOR'],
    ['YO', 'PODER', 'IR', 'BANO'],
    ['TAREA', 'CUANDO'],
    ['BANO', 'DONDE'],
    ['MANANA', 'EXAMEN'],
    ['YO', 'TENER', 'PREGUNTA'],
    ['MAESTRO', 'REPETIR'],
    ['MANANA', 'YO', 'IR', 'CLASE'],
    ['HOLA', 'YO', 'A', 'N', 'A'],
  ];

  final Random _azar;

  /// Tiempo entre un evento y el siguiente.
  final Duration paso;

  final StreamController<EventoReconocimiento> _controlador =
      StreamController<EventoReconocimiento>.broadcast();

  Timer? _timer;
  _Etapa _etapa = _Etapa.reposo;
  int _espera = 0;
  int _visibles = 0;
  List<String> _actual = const [];

  @override
  Stream<EventoReconocimiento> get eventos => _controlador.stream;

  @override
  void conectarCuadros(Stream<CuadroPuntos> cuadros) {}

  @override
  void iniciar() {
    detener();
    _etapa = _Etapa.reposo;
    _espera = 0;
    _timer = Timer.periodic(paso, (_) => _avanzar());
  }

  @override
  void detener() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> liberar() async {
    detener();
    await _controlador.close();
  }

  void _emitir(EventoReconocimiento evento) {
    if (!_controlador.isClosed) _controlador.add(evento);
  }

  void _avanzar() {
    switch (_etapa) {
      case _Etapa.reposo:
        if (_espera == 0) {
          _emitir(const EventoReconocimiento(estado: EstadoDeteccion.sinManos));
        }
        _espera++;
        if (_espera >= 3) {
          _actual = _frases[_azar.nextInt(_frases.length)];
          _visibles = 0;
          _espera = 0;
          _etapa = _Etapa.signando;
        }
      case _Etapa.signando:
        _visibles++;
        _emitir(
          EventoReconocimiento(
            estado: EstadoDeteccion.detectando,
            glosas: _actual.sublist(0, _visibles),
          ),
        );
        if (_visibles >= _actual.length) {
          _espera = 0;
          _etapa = _Etapa.mostrando;
        }
      case _Etapa.mostrando:
        if (_espera == 0) {
          _emitir(
            EventoReconocimiento(
              estado: EstadoDeteccion.traduciendo,
              glosas: _actual,
              frase: construirFrase(_actual),
            ),
          );
        }
        _espera++;
        if (_espera >= 6) {
          _espera = 0;
          _etapa = _Etapa.reposo;
        }
    }
  }
}
