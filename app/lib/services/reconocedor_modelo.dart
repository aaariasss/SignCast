import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/cuadro_puntos.dart';
import '../models/estado_deteccion.dart';
import 'caracteristicas.dart';
import 'clasificador_alfabeto.dart';
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
    this.cargarAlfabeto,
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

  /// Carga el clasificador del alfabeto para el deletreo. Sin él, el deletreo
  /// no hace nada.
  final Future<ClasificadorAlfabeto?> Function()? cargarAlfabeto;

  /// Una letra del deletreo se acepta cuando, en los últimos [ventanaLetraMs],
  /// la misma letra sale en al menos [mayoriaLetra] de las lecturas y la mano
  /// lleva al menos [sostenerLetraMs] así. Se mide en tiempo y no en cuadros
  /// para que no dependa de los FPS, y así las posturas intermedias al cambiar
  /// de letra no alcanzan a contar.
  static const int ventanaLetraMs = 700;
  static const int sostenerLetraMs = 600;
  static const double mayoriaLetra = 0.85;

  /// En el deletreo, el modelo de señas solo puede aportar una letra con
  /// movimiento (J, K, Ñ, Q, X, Z) si en los últimos [cuadrosMovimiento] de la
  /// ventana la mano se movió o cambió de forma al menos [movimientoMinimo]
  /// veces su tamaño. Si está quieta, la letra es del alfabeto estático (la N
  /// quieta, por ejemplo, el modelo de señas la confunde con K y Ñ).
  static const int cuadrosMovimiento = 10;
  static const double movimientoMinimo = 0.4;

  final DecisorSenas _decisor;
  final VentanaTemporal _ventana;
  final int Function() _reloj;

  final StreamController<EventoReconocimiento> _controlador =
      StreamController<EventoReconocimiento>.broadcast();
  StreamSubscription<CuadroPuntos>? _suscripcion;

  ClasificadorAlfabeto? _alfabeto;
  final List<(int, String?)> _letras = [];
  bool _deletreo = false;
  bool _activo = false;
  bool _cargado = false;
  Future<void>? _carga;
  bool _infiriendo = false;
  bool _hayMano = false;
  int _cuadros = 0;
  int _retenerHasta = 0;
  EstadoDeteccion? _ultimoEstado;
  int _ultimasGlosas = -1;

  @override
  bool get deletreo => _deletreo;

  @override
  set deletreo(bool activo) {
    if (activo == _deletreo) return;
    _deletreo = activo;
    _letras.clear();
    // Al salir del deletreo la frase se cierra tras la pausa.
    if (!activo) _decisor.iniciarReposo(_reloj());
  }

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
    _letras.clear();
    _ventana.limpiar();
    _cuadros = 0;
    _retenerHasta = 0;
    _ultimoEstado = null;
    _ultimasGlosas = -1;
  }

  @override
  Future<void> precargar() => _cargarModelo();

  /// Carga el modelo una sola vez; quien lo pide mientras carga espera la
  /// misma carga. Si falla, se puede volver a intentar.
  Future<void> _cargarModelo() {
    if (_cargado) return Future.value();
    return _carga ??= () async {
      try {
        await predictor.cargar();
        _cargado = true;
      } catch (e) {
        debugPrint('No se pudo cargar el modelo de señas: $e');
      }
      try {
        _alfabeto ??= await cargarAlfabeto?.call();
      } catch (e) {
        debugPrint('No se pudo cargar el clasificador del alfabeto: $e');
      } finally {
        _carga = null;
      }
    }();
  }

  void _alCuadro(CuadroPuntos cuadro) {
    if (!_activo) return;
    final ahora = _reloj();
    _hayMano = cuadro.hayMano;
    _ventana.agregar(ahora, cuadro);
    _cuadros++;

    // En el deletreo las letras quietas las pone el clasificador del alfabeto y
    // las que llevan movimiento (J, K, Ñ, Q, X, Z) el modelo de señas.
    final deletreando = _deletreo && _alfabeto != null;
    if (deletreando) _deletrear(manoPrincipal(cuadro), ahora);
    if (_cargado && !_infiriendo && _cuadros % cada == 0) {
      final muestra = _ventana.muestrear();
      if (muestra != null) _inferir(muestra, soloLetras: deletreando);
    }

    final cerradas = _decisor.cerrarFrase(ahora);
    if (cerradas != null) {
      _cerrarFrase(cerradas, ahora);
    } else {
      _emitirEstado(ahora);
    }
  }

  /// Deletreo: con la mano principal de este cuadro se clasifica una letra y se
  /// acepta cuando la mano la sostiene (ver [sostenerLetraMs]).
  /// Sin mano cuenta como reposo, así la frase se cierra tras la pausa.
  void _deletrear(Float32List mano, int ahora) {
    if (mano.every((v) => v.isNaN)) {
      _decisor.iniciarReposo(ahora);
      return;
    }
    _decisor.cancelarReposo();
    final vector = caracteristicasMano(mano);
    if (vector.every((v) => v == 0)) return;

    final alfabeto = _alfabeto!;
    final probs = alfabeto.predecir(vector);
    var mejor = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[mejor]) mejor = i;
    }
    final letra = probs[mejor] >= _decisor.umbral
        ? alfabeto.etiquetas[mejor]
        : null;
    _letras.add((ahora, letra));
    _letras.removeWhere((l) => ahora - l.$1 > ventanaLetraMs);
    if (ahora - _letras.first.$1 < sostenerLetraMs) return;

    // La más repetida; si empatan, la que apareció primero.
    final cuentas = <String?, int>{};
    for (final l in _letras) {
      cuentas[l.$2] = (cuentas[l.$2] ?? 0) + 1;
    }
    String? comun;
    var veces = 0;
    for (final e in cuentas.entries) {
      if (e.value > veces) {
        comun = e.key;
        veces = e.value;
      }
    }
    if (comun != null &&
        veces >= mayoriaLetra * _letras.length &&
        _decisor.agregarGlosa(comun)) {
      _letras.clear();
    }
  }

  /// Cuánto se movió o cambió de forma la mano principal en los últimos
  /// [cuadrosMovimiento] cuadros de [muestra], en tamaños de mano (la muñeca
  /// respecto al último cuadro y los puntos ya normalizados por la muñeca).
  double _movimiento(List<CuadroPuntos> muestra) {
    final ultimos = muestra.length > cuadrosMovimiento
        ? muestra.sublist(muestra.length - cuadrosMovimiento)
        : muestra;
    final manos = <Float32List>[];
    for (final c in ultimos) {
      final m = manoPrincipal(c);
      if (!m.any((v) => v.isNaN)) manos.add(m);
    }
    if (manos.length < 4) return 0;

    final ref = manos.last;
    var tamano = 0.0;
    for (var i = 0; i < puntosMano; i++) {
      final dx = ref[i * 3] - ref[0];
      final dy = ref[i * 3 + 1] - ref[1];
      tamano = math.max(tamano, math.sqrt(dx * dx + dy * dy));
    }
    if (tamano < 1e-6) return 0;

    final vectorRef = caracteristicasMano(ref);
    var mayor = 0.0;
    for (final m in manos) {
      final dx = m[0] - ref[0];
      final dy = m[1] - ref[1];
      mayor = math.max(mayor, math.sqrt(dx * dx + dy * dy) / tamano);
      final v = caracteristicasMano(m);
      for (var i = 0; i < puntosMano; i++) {
        mayor = math.max(mayor, (v[i * 3] - vectorRef[i * 3]).abs());
        mayor = math.max(mayor, (v[i * 3 + 1] - vectorRef[i * 3 + 1]).abs());
      }
    }
    return mayor;
  }

  /// Con [soloLetras] solo cuentan las predicciones de letras (etiquetas de un
  /// carácter); palabras y reposo se ignoran porque el reposo lo lleva
  /// [_deletrear].
  Future<void> _inferir(
    List<CuadroPuntos> muestra, {
    bool soloLetras = false,
  }) async {
    _infiriendo = true;
    try {
      final conMano = muestra.where((c) => c.hayMano).length;
      if (conMano < minCuadrosConMano) {
        if (!soloLetras) _decisor.predecir(claseReposo, 1.0, _reloj());
        return;
      }
      final filas = caracteristicasSecuencia(muestra);
      final plano = Float32List(longitudSecuencia * nCaracteristicas);
      for (var i = 0; i < filas.length; i++) {
        plano.setRange(
          i * nCaracteristicas,
          (i + 1) * nCaracteristicas,
          filas[i],
        );
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
      var prob = probs[mejor];
      if (soloLetras &&
          (etiquetas[mejor].length != 1 ||
              _movimiento(muestra) < movimientoMinimo)) {
        prob = 0;
      }
      if (_decisor.predecir(etiquetas[mejor], prob, ahora)) {
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
