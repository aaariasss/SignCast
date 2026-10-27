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
/// Hoy lo implementa `ReconocedorFalso`; la implementación con el modelo real
/// cumple esta misma interfaz y las pantallas no cambian.
abstract class Reconocedor {
  Stream<EventoReconocimiento> get eventos;

  void iniciar();

  void detener();

  Future<void> liberar();
}
