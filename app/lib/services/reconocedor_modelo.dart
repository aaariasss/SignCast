import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/cuadro_puntos.dart';
import '../models/estado_deteccion.dart';
import 'caracteristicas.dart';
import 'decisor_senas.dart';
import 'frases.dart';
import 'predictor_senas.dart';
import 'reconocedor.dart';
import 'ventana_temporal.dart';

/// Reconocedor real: con los puntos de cada cuadro arma una ventana de 30
/// cuadros, corre el modelo cada [cada] cuadros y decide con [DecisorSenas]
/// (misma lógica que `ml/signcast/tiempo_real.py`).
class ReconocedorModelo implements Reconocedor {
  ReconocedorModelo({
    required this.predictor,
    DecisorSenas? decisor,
    VentanaTemporal? ventana,
    this.cada = 2,
    this.minCuadrosConMano = 5,
    this.retencionFrase = const Duration(seconds: 2),
    int Function()? reloj,
  }) : _decisor = decisor ?? DecisorSenas(),
       _ventana = ventana ?? VentanaTemporal(),
       _reloj = reloj ?? (() => DateTime.now().millisecondsSinceEpoch);

  final PredictorSenas predictor;

  /// Se infiere uno de cada [cada] cuadros.
  final int cada;

  /// Si en la ventana hay menos cuadros con manos que estos, no se corre el
  /// modelo y cuenta como reposo (sin manos no hay seña que reconocer).
  final int minCuadrosConMano;

  /// Cuánto se deja visible "Traduciendo" antes de volver a "Detectando".
  final Duration retencionFrase;

  final DecisorSenas _decisor;
  final VentanaTemporal _ventana;
  final int Function() _reloj;

  final StreamController<EventoReconocimiento> _controlador =
      StreamController<EventoReconocimiento>.broadcast();
  StreamSubscription<CuadroPuntos>? _suscripcion;

  bool _activo = false;
  bool _cargado = false;
  bool _cargando = false;
  bool _infiriendo = false;
  bool _hayMano = false;
  int _cuadros = 0;
  int _retenerHasta = 0;
  EstadoDeteccion? _ultimoEstado;
  int _ultimasGlosas = -1;

  @override
  Stream<EventoReconocimiento> get eventos => _controlador.stream;

  @override
  void conectarCuadros(Stream<CuadroPuntos> cuadros) {
    _suscripcion?.cancel();
    _suscripcion = cuadros.listen(_alCuadro);
  }

  @override
  void iniciar() {
    _activo = true;
    _reiniciar();
    _cargarModelo();
  }

  @override
  void detener() {
    _activo = false;
    _reiniciar();
  }

  @override
  Future<void> liberar() async {
    detener();
    await _suscripcion?.cancel();
    _suscripcion = null;
    await _controlador.close();
  }

  void _reiniciar() {
    _decisor.reiniciar();
    _ventana.limpiar();
    _cuadros = 0;
    _retenerHasta = 0;
    _ultimoEstado = null;
    _ultimasGlosas = -1;
  }

  Future<void> _cargarModelo() async {
    if (_cargado || _cargando) return;
    _cargando = true;
    try {
      await predictor.cargar();
      _cargado = true;
    } catch (e) {
      debugPrint('No se pudo cargar el modelo de señas: $e');
    } finally {
      _cargando = false;
    }
  }

  void _alCuadro(CuadroPuntos cuadro) {
    if (!_activo) return;
    final ahora = _reloj();
    _hayMano = cuadro.hayMano;
    _ventana.agregar(ahora, cuadro);
    _cuadros++;

    if (_cargado && !_infiriendo && _cuadros % cada == 0) {
      final muestra = _ventana.muestrear();
      if (muestra != null) _inferir(muestra);
    }

    final cerradas = _decisor.cerrarFrase(ahora);
    if (cerradas != null) {
      _cerrarFrase(cerradas, ahora);
    } else {
      _emitirEstado(ahora);
    }
  }

  Future<void> _inferir(List<CuadroPuntos> muestra) async {
    _infiriendo = true;
    try {
      final conMano = muestra.where((c) => c.hayMano).length;
      if (conMano < minCuadrosConMano) {
        _decisor.predecir(claseReposo, 1.0, _reloj());
        return;
      }
      final filas = caracteristicasSecuencia(muestra);
      final plano = Float32List(longitudSecuencia * nCaracteristicas);
      for (var i = 0; i < filas.length; i++) {
        plano.setRange(i * nCaracteristicas, (i + 1) * nCaracteristicas, filas[i]);
      }
      final probs = await predictor.predecir(plano);
      if (!_activo) return;

      var mejor = 0;
      for (var i = 1; i < probs.length; i++) {
        if (probs[i] > probs[mejor]) mejor = i;
      }
      final etiquetas = predictor.etiquetas;
      if (mejor >= etiquetas.length) return;
      final ahora = _reloj();
      if (_decisor.predecir(etiquetas[mejor], probs[mejor], ahora)) {
        _emitirEstado(ahora);
      }
    } catch (e) {
      debugPrint('Falló la inferencia: $e');
    } finally {
      _infiriendo = false;
    }
  }

  void _cerrarFrase(List<String> glosas, int ahora) {
    final frase = construirFrase(glosas);
    if (frase.isEmpty) return;
    _retenerHasta = ahora + retencionFrase.inMilliseconds;
    _ultimoEstado = EstadoDeteccion.traduciendo;
    _ultimasGlosas = glosas.length;
    _emitir(
      EventoReconocimiento(
        estado: EstadoDeteccion.traduciendo,
        glosas: glosas,
        frase: frase,
      ),
    );
  }

  /// Emite solo cuando cambia el estado o la lista de glosas.
  void _emitirEstado(int ahora) {
    final glosas = _decisor.glosas;
    // Mientras se muestra la frase traducida no se pisa, salvo que ya empiece otra.
    if (ahora < _retenerHasta && glosas.isEmpty) return;

    final estado = glosas.isNotEmpty || _hayMano
        ? EstadoDeteccion.detectando
        : EstadoDeteccion.sinManos;
    if (estado == _ultimoEstado && glosas.length == _ultimasGlosas) return;
    _ultimoEstado = estado;
    _ultimasGlosas = glosas.length;
    _emitir(EventoReconocimiento(estado: estado, glosas: glosas));
  }

  void _emitir(EventoReconocimiento evento) {
    if (!_controlador.isClosed) _controlador.add(evento);
  }
}
