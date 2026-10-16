import 'package:flutter/material.dart';

/// Cuatro esquinas redondeadas, como el recuadro de encuadre del diseño.
/// Úsalo dentro de un widget con tamaño (por ejemplo `Positioned.fill`).
class Esquinas extends StatelessWidget {
  const Esquinas({
    super.key,
    required this.color,
    this.largo = 24,
    this.radio = 8,
    this.grosor = 1,
  });

  final Color color;
  final double largo;
  final double radio;
  final double grosor;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _EsquinasPainter(color, largo, radio, grosor));
}

class _EsquinasPainter extends CustomPainter {
  const _EsquinasPainter(this.color, this.largo, this.radio, this.grosor);

  final Color color;
  final double largo;
  final double radio;
  final double grosor;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final l = largo;
    final r = radio;
    final arco = Radius.circular(r);

    canvas.drawPath(
      Path()
        ..moveTo(0, l)
        ..lineTo(0, r)
        ..arcToPoint(Offset(r, 0), radius: arco)
        ..lineTo(l, 0),
      pincel,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - l, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: arco)
        ..lineTo(w, l),
      pincel,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w, h - l)
        ..lineTo(w, h - r)
        ..arcToPoint(Offset(w - r, h), radius: arco)
        ..lineTo(w - l, h),
      pincel,
    );
    canvas.drawPath(
      Path()
        ..moveTo(l, h)
        ..lineTo(r, h)
        ..arcToPoint(Offset(0, h - r), radius: arco)
        ..lineTo(0, h - l),
      pincel,
    );
  }

  @override
  bool shouldRepaint(_EsquinasPainter old) =>
      old.color != color ||
      old.largo != largo ||
      old.radio != radio ||
      old.grosor != grosor;
}
