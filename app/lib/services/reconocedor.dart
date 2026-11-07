import '../models/cuadro_puntos.dart';
import '../models/estado_deteccion.dart';

/// Lo que el reconocedor le cuenta a la interfaz.
class EventoReconocimiento {
  const EventoReconocimiento({
    required this.estado,
    this.glosas = const [],
    this.frase,
  });

  final EstadoDeteccion estado;

  /// Glosas reconocidas hasta ahora (`YO`, `NO`, `ENTENDER`...).
  final List<String> glosas;

  /// Frase en español ya construida. Solo viene con
  /// [EstadoDeteccion.traduciendo].
  final String? frase;
}

/// Contrato entre las pantallas y quien reconoce las señas.
///
/// `ReconocedorModelo` usa el modelo real; `ReconocedorFalso` inventa frases
/// para probar la interfaz sin cámara.
abstract class Reconocedor {
  Stream<EventoReconocimiento> get eventos;

  /// Con el deletreo activo se reconocen letras sueltas del alfabeto con la
  /// mano quieta, en lugar de señas con movimiento.
  bool get deletreo;
  set deletreo(bool activo);

  /// Puntos de cada cuadro de cámara. Solo los usa el reconocedor real; el
  /// falso los ignora.
  void conectarCuadros(Stream<CuadroPuntos> cuadros);

  /// Deja listo lo pesado (el modelo de señas) antes de abrir la cámara.
  /// Puede llamarse varias veces; no falla si ya estaba cargado.
  Future<void> precargar();

  void iniciar();

  void detener();

  Future<void> liberar();
}
