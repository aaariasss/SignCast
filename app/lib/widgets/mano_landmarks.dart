import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/paleta.dart';

/// Esqueleto de mano con la burbuja "Hola" (pantalla de bienvenida).
/// Coordenadas tomadas del SVG del prototipo (viewBox 342 × 320).
class ManoLandmarks extends StatelessWidget {
  const ManoLandmarks({super.key, required this.paleta});

  final Paleta paleta;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ManoPainter(paleta), size: Size.infinite);
}

class _ManoPainter extends CustomPainter {
  const _ManoPainter(this.paleta);

  final Paleta paleta;

  static const double _ancho = 342;
  static const double _alto = 320;

  static const List<List<Offset>> _lineas = [
    [Offset(170, 260), Offset(170, 210)],
    [
      Offset(170, 210),
      Offset(145, 190),
      Offset(130, 150),
      Offset(125, 110),
      Offset(135, 75),
    ],
    [
      Offset(170, 210),
      Offset(170, 185),
      Offset(165, 135),
      Offset(170, 90),
      Offset(180, 55),
    ],
    [
      Offset(170, 210),
      Offset(195, 190),
      Offset(205, 145),
      Offset(215, 110),
      Offset(220, 80),
    ],
    [
      Offset(170, 210),
      Offset(215, 205),
      Offset(235, 175),
      Offset(250, 150),
      Offset(260, 128),
    ],
    [Offset(170, 210), Offset(130, 215), Offset(100, 195), Offset(78, 170)],
  ];

  static const List<List<Offset>> _lineasSuaves = [
    [Offset(145, 190), Offset(170, 185), Offset(195, 190), Offset(215, 205)],
    [Offset(130, 215), Offset(145, 190)],
  ];

  /// Centro y radio de cada articulación.
  static const List<(Offset, double)> _puntos = [
    (Offset(170, 260), 4),
    (Offset(170, 210), 4),
    (Offset(145, 190), 4),
    (Offset(170, 185), 4),
    (Offset(195, 190), 4),
    (Offset(215, 205), 4),
    (Offset(130, 150), 4),
    (Offset(125, 110), 4),
    (Offset(135, 75), 4.5),
    (Offset(165, 135), 4),
    (Offset(170, 90), 4),
    (Offset(180, 55), 4.5),
    (Offset(205, 145), 4),
    (Offset(215, 110), 4),
    (Offset(220, 80), 4.5),
    (Offset(235, 175), 4),
    (Offset(250, 150), 4),
    (Offset(260, 128), 4.5),
    (Offset(130, 215), 4),
    (Offset(100, 195), 4),
    (Offset(78, 170), 4.5),
  ];

  Path _trazo(List<Offset> puntos) {
    final path = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (final p in puntos.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final escala = math.min(size.width / _ancho, size.height / _alto);
    canvas.save();
    canvas.translate(
      (size.width - _ancho * escala) / 2,
      (size.height - _alto * escala) / 2,
    );
    canvas.scale(escala);

    final degradado = ui.Gradient.linear(
      const Offset(78, 56),
      const Offset(260, 260),
      const [Paleta.cian, Paleta.azul2, Paleta.azul],
      const [0, .48, 1],
    );
    final linea = Paint()
      ..shader = degradado
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Líneas principales (opacidad .82) y secundarias (más tenues).
    canvas.saveLayer(null, Paint()..color = const Color(0xD1FFFFFF));
    for (final l in _lineas) {
      canvas.drawPath(_trazo(l), linea);
    }
    canvas.restore();
    canvas.saveLayer(null, Paint()..color = const Color(0x69FFFFFF));
    for (final l in _lineasSuaves) {
      canvas.drawPath(_trazo(l), linea);
    }
    canvas.restore();

    // Articulaciones con resplandor.
    const relleno = Color(0xFFBFD4FF);
    final brillo = Paint()
      ..color = relleno
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final punto = Paint()..color = relleno;
    final contorno = Paint()
      ..shader = degradado
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final (centro, radio) in _puntos) {
      canvas.drawCircle(centro, radio, brillo);
      canvas.drawCircle(centro, radio, punto);
      canvas.drawCircle(centro, radio, contorno);
    }

    // Burbuja "Hola".
    final burbuja = RRect.fromRectAndRadius(
      const Rect.fromLTWH(269, 64, 64, 34),
      const Radius.circular(17),
    );
    canvas.drawRRect(
      burbuja,
      Paint()
        ..color = paleta.oscuro
            ? const Color(0x14FFFFFF)
            : const Color(0xE6FFFFFF),
    );
    canvas.drawRRect(
      burbuja,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = paleta.oscuro
            ? const Color(0x29FFFFFF)
            : const Color(0xFFD8E2F2),
    );
    final texto = TextPainter(
      text: TextSpan(
        text: 'Hola',
        style: TextStyle(
          color: paleta.tinta,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    texto.paint(canvas, Offset(301 - texto.width / 2, 81 - texto.height / 2));

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ManoPainter old) => old.paleta != paleta;
}
