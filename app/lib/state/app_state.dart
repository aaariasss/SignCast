import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ajustes.dart';
import '../models/estado_deteccion.dart';
import '../models/frase_historial.dart';
import '../services/barra_navegador.dart';
import '../services/detector_plataforma.dart';
import '../services/permiso_camara.dart';
import '../services/permiso_camara_plataforma.dart';
import '../services/reconocedor.dart';
import '../services/reconocedor_falso.dart';
import '../services/voz.dart';
import '../theme/paleta.dart';

const String _kTamano = 'ajustes_tamano';
const String _kVoz = 'ajustes_voz_activa';
const String _kVelocidad = 'ajustes_velocidad_voz';
const String _kOscuro = 'ajustes_oscuro';

/// Estado compartido de toda la app: ajustes, reconocimiento e historial.
class AppState extends ChangeNotifier {
  AppState({
    required this.reconocedor,
    required this.voz,
    this.permisoCamara = const PermisoCamaraNulo(),
    this._prefs,
  });

  /// Crea el estado y carga los ajustes guardados.
  static Future<AppState> crear({
    Reconocedor? reconocedor,
    Voz? voz,
    PermisoCamara? permisoCamara,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final estado = AppState(
      reconocedor: reconocedor ?? ReconocedorFalso(),
      voz: voz ?? const VozNula(),
      permisoCamara: permisoCamara ?? crearPermisoCamara(),
      prefs: prefs,
    );
    estado._cargar();
    return estado;
  }

  final Reconocedor reconocedor;
  final Voz voz;
  final PermisoCamara permisoCamara;
  final SharedPreferences? _prefs;

  Ajustes _ajustes = const Ajustes();
  EstadoDeteccion _estado = EstadoDeteccion.sinManos;
  List<String> _glosas = const [];
  String _fraseActual = '';
  final List<FraseHistorial> _historial = [];
  StreamSubscription<EventoReconocimiento>? _suscripcion;
  bool _pausado = false;

  Ajustes get ajustes => _ajustes;
  EstadoDeteccion get estado => _estado;
  List<String> get glosas => _glosas;
  String get fraseActual => _fraseActual;
  List<FraseHistorial> get historial => List.unmodifiable(_historial);
  Paleta get paleta => _ajustes.oscuro ? Paleta.oscura : Paleta.clara;

  /// Si está activo, se reconocen letras sueltas del alfabeto en lugar de señas.
  bool get deletreo => reconocedor.deletreo;

  void alternarDeletreo() {
    reconocedor.deletreo = !reconocedor.deletreo;
    notifyListeners();
  }

  void _cargar() {
    final p = _prefs;
    if (p == null) return;
    _ajustes = Ajustes(
      tamano: (p.getDouble(_kTamano) ?? 26)
          .clamp(Ajustes.tamanoMin, Ajustes.tamanoMax)
          .toDouble(),
      vozActiva: p.getBool(_kVoz) ?? true,
      velocidadVoz: (p.getDouble(_kVelocidad) ?? 1.0)
          .clamp(Ajustes.velocidadMin, Ajustes.velocidadMax)
          .toDouble(),
      oscuro: p.getBool(_kOscuro) ?? true,
    );
    pintarBarraNavegador(paleta.lienzo);
  }

  Future<void> _guardar() async {
    final p = _prefs;
    if (p == null) return;
    await p.setDouble(_kTamano, _ajustes.tamano);
    await p.setBool(_kVoz, _ajustes.vozActiva);
    await p.setDouble(_kVelocidad, _ajustes.velocidadVoz);
    await p.setBool(_kOscuro, _ajustes.oscuro);
  }

  Future<void> _aplicar(Ajustes nuevos) async {
    _ajustes = nuevos;
    pintarBarraNavegador(paleta.lienzo);
    notifyListeners();
    await _guardar();
  }

  Future<void> cambiarTamano(double valor) => _aplicar(
    _ajustes.copiar(
      tamano: valor.clamp(Ajustes.tamanoMin, Ajustes.tamanoMax).toDouble(),
    ),
  );

  Future<void> cambiarVelocidad(double valor) {
    final redondeada = (valor * 10).round() / 10;
    return _aplicar(
      _ajustes.copiar(
        velocidadVoz: redondeada
            .clamp(Ajustes.velocidadMin, Ajustes.velocidadMax)
            .toDouble(),
      ),
    );
  }

  /// Al silenciar también se corta la frase que esté sonando.
  Future<void> alternarVoz() {
    if (_ajustes.vozActiva) voz.detener();
    return _aplicar(_ajustes.copiar(vozActiva: !_ajustes.vozActiva));
  }

  Future<void> cambiarOscuro(bool oscuro) =>
      _aplicar(_ajustes.copiar(oscuro: oscuro));

  /// Deja listo todo lo pesado antes de abrir la cámara: el modelo de señas y
  /// los modelos de MediaPipe. Los fallos se anotan y no se propagan: la
  /// pantalla del traductor avisa si algo no cargó.
  Future<void> precargar() async {
    Future<void> seguro(Future<void> Function() carga, String que) async {
      try {
        await carga();
      } catch (e) {
        debugPrint('No se pudo precargar $que: $e');
      }
    }

    await Future.wait([
      seguro(reconocedor.precargar, 'el modelo de señas'),
      seguro(precargarDetector, 'MediaPipe'),
    ]);
  }

  /// Empieza a escuchar al reconocedor. Se llama al entrar a la app principal.
  void iniciarReconocimiento() {
    _pausado = false;
    _suscripcion ??= reconocedor.eventos.listen(aplicarEvento);
    reconocedor.iniciar();
  }

  void detenerReconocimiento() {
    reconocedor.detener();
    voz.detener();
  }

  /// Al salir del traductor (historial, ajustes) deja de reconocer y de hablar:
  /// la cámara sigue encendida, pero no debe salir ninguna frase nueva ni
  /// seguir sonando la voz.
  void pausarReconocimiento() {
    _pausado = true;
    reconocedor.detener();
    voz.detener();
  }

  /// Al volver al traductor empieza a reconocer desde cero.
  void reanudarReconocimiento() {
    if (!_pausado) return;
    _pausado = false;
    reconocedor.iniciar();
  }

  /// Procesa un evento del reconocedor. Es público para poder probarlo.
  void aplicarEvento(EventoReconocimiento evento) {
    if (_pausado) return;
    _estado = evento.estado;
    _glosas = evento.glosas;
    final frase = evento.frase;
    if (evento.estado == EstadoDeteccion.traduciendo &&
        frase != null &&
        frase.isNotEmpty) {
      _fraseActual = frase;
      _historial.insert(0, FraseHistorial(hora: DateTime.now(), texto: frase));
      if (_ajustes.vozActiva) {
        voz.hablar(frase, velocidad: _ajustes.velocidadVoz);
      }
    }
    notifyListeners();
  }

  /// Vuelve a leer la frase actual (acción explícita del usuario: suena aunque
  /// la lectura automática esté apagada).
  Future<void> repetir() => reproducir(_fraseActual);

  Future<void> reproducir(String texto) async {
    if (texto.isEmpty) return;
    await voz.hablar(texto, velocidad: _ajustes.velocidadVoz);
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    reconocedor.liberar();
    super.dispose();
  }
}

/// Hace llegar el [AppState] a cualquier widget.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState estado, required super.child})
    : super(notifier: estado);

  /// Lee el estado y reconstruye el widget cuando cambia.
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'Falta un AppScope arriba en el árbol de widgets');
    return scope!.notifier!;
  }

  /// Lee el estado sin reconstruir (sirve en initState).
  static AppState leer(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'Falta un AppScope arriba en el árbol de widgets');
    return scope!.notifier!;
  }
}

extension ContextoApp on BuildContext {
  AppState get app => AppScope.of(this);
  Paleta get paleta => AppScope.of(this).paleta;
}
