import 'package:flutter/foundation.dart';

/// Contrato para leer frases en voz alta.
abstract class Voz {
  /// `true` mientras suena una frase. La cámara se pausa en ese rato para que
  /// el iPhone no tenga que detectar manos y hablar a la vez (la voz sale
  /// entrecortada).
  ValueListenable<bool> get hablando;

  /// Lee [texto] cortando lo que esté sonando. [velocidad] es 1.0 para
  /// velocidad normal.
  Future<void> hablar(String texto, {required double velocidad});

  /// Corta la lectura en curso.
  Future<void> detener();

  /// Deja la voz lista para sonar. Safari solo permite audio después de un
  /// toque del usuario, así que se llama en cada toque; solo la primera vez
  /// hace algo.
  Future<void> preparar();
}

/// Voz que no suena (pruebas y plataformas sin síntesis de voz).
class VozNula implements Voz {
  const VozNula();

  static final ValueNotifier<bool> _nunca = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get hablando => _nunca;

  @override
  Future<void> hablar(String texto, {required double velocidad}) async {}

  @override
  Future<void> detener() async {}

  @override
  Future<void> preparar() async {}
}
