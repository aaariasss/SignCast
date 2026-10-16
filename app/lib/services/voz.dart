/// Contrato para leer frases en voz alta.
///
/// El issue #26 (Valeria) agrega la implementación con `flutter_tts` en
/// español de México. Mientras tanto la app usa [VozNula], que no hace nada.
abstract class Voz {
  /// Lee [texto]. [velocidad] es 1.0 para velocidad normal.
  Future<void> hablar(String texto, {required double velocidad});

  Future<void> detener();
}

/// Voz que no suena. Sirve de relleno hasta que exista el TTS real.
class VozNula implements Voz {
  const VozNula();

  @override
  Future<void> hablar(String texto, {required double velocidad}) async {}

  @override
  Future<void> detener() async {}
}
