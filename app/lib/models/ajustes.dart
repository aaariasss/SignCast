/// Preferencias del usuario (issue #24). Se guardan en el teléfono.
class Ajustes {
  const Ajustes({
    this.tamano = 26,
    this.vozActiva = true,
    this.velocidadVoz = 1.0,
    this.oscuro = true,
  });

  static const double tamanoMin = 18;
  static const double tamanoMax = 36;
  static const double velocidadMin = 0.5;
  static const double velocidadMax = 1.5;

  /// Tamaño del texto de los subtítulos, en px.
  final double tamano;

  /// Si la frase traducida se lee en voz alta automáticamente.
  final bool vozActiva;

  /// Velocidad de la voz (1.0 = normal).
  final double velocidadVoz;

  /// Tema oscuro (por defecto) o claro.
  final bool oscuro;

  Ajustes copiar({
    double? tamano,
    bool? vozActiva,
    double? velocidadVoz,
    bool? oscuro,
  }) => Ajustes(
    tamano: tamano ?? this.tamano,
    vozActiva: vozActiva ?? this.vozActiva,
    velocidadVoz: velocidadVoz ?? this.velocidadVoz,
    oscuro: oscuro ?? this.oscuro,
  );
}
