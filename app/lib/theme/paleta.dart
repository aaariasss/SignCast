import 'package:flutter/material.dart';

/// Colores del prototipo de Figma, en modo oscuro y claro.
class Paleta {
  const Paleta({
    required this.oscuro,
    required this.lienzo,
    required this.tinta,
    required this.tenue,
    required this.vidrio,
    required this.linea,
    required this.fondoBarra,
  });

  final bool oscuro;

  /// Fondo de las pantallas.
  final Color lienzo;

  /// Texto principal.
  final Color tinta;

  /// Texto secundario.
  final Color tenue;

  /// Relleno de tarjetas "de vidrio".
  final Color vidrio;

  /// Bordes finos.
  final Color linea;

  /// Fondo de la barra de navegación inferior.
  final Color fondoBarra;

  static const Color azul = Color(0xFF3D7BFF);
  static const Color azul2 = Color(0xFF6C9BFF);
  static const Color cian = Color(0xFF22D3EE);
  static const Color grisEstado = Color(0xFF9AA6BF);

  static const Paleta oscura = Paleta(
    oscuro: true,
    lienzo: Color(0xFF070B16),
    tinta: Color(0xFFFFFFFF),
    tenue: Color(0xFF9AA6BF),
    vidrio: Color(0x12FFFFFF), // blanco 7 %
    linea: Color(0x1FFFFFFF), // blanco 12 %
    fondoBarra: Color(0xB80F1422), // 72 %
  );

  static const Paleta clara = Paleta(
    oscuro: false,
    lienzo: Color(0xFFF5F8FC),
    tinta: Color(0xFF0E1A33),
    tenue: Color(0xFF69748A),
    vidrio: Color(0xE0FFFFFF), // blanco 88 %
    linea: Color(0xFFE3E9F2),
    fondoBarra: Color(0xD6FFFFFF), // blanco 84 %
  );

  Color get azulSuave => azul.withValues(alpha: .14);

  /// Fondo de página: color liso con el resplandor azul de la esquina.
  BoxDecoration get fondo => BoxDecoration(
    color: lienzo,
    gradient: RadialGradient(
      center: const Alignment(1.55, -1.1),
      radius: 1.15,
      colors: [
        azul.withValues(alpha: oscuro ? .34 : .14),
        azul.withValues(alpha: oscuro ? .12 : .04),
        const Color(0x00000000),
      ],
      stops: const [0, .22, .48],
    ),
  );
}
