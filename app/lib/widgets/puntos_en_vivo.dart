import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/cuadro_puntos.dart';
import '../services/caracteristicas.dart';

/// Dibuja sobre la cámara los puntos que detecta MediaPipe: manos, hombros y
/// brazos, y el rostro. Va dentro del mismo recuadro que la vista previa, así
/// las coordenadas normalizadas (0 a 1) caen en el mismo lugar.
///
/// [espejo] voltea el dibujo en horizontal; la vista previa de la cámara
/// frontal se ve como espejo y los puntos vienen de la imagen sin voltear.
class PuntosEnVivo extends StatefulWidget {
  const PuntosEnVivo({super.key, required this.cuadros, this.espejo = true});

  final Stream<CuadroPuntos> cuadros;
  final bool espejo;

  @override
  State<PuntosEnVivo> createState() => _PuntosEnVivoState();
}

class _PuntosEnVivoState extends State<PuntosEnVivo> {
  final ValueNotifier<CuadroPuntos?> _ultimo = ValueNotifier(null);
  StreamSubscription<CuadroPuntos>? _suscripcion;

  @override
  void initState() {
    super.initState();
    _suscripcion = widget.cuadros.listen((c) => _ultimo.value = c);
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _ultimo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _PuntosPainter(_ultimo, widget.espejo),
      size: Size.infinite,
    ),
  );
}

class _PuntosPainter extends CustomPainter {
  _PuntosPainter(this.ultimo, this.espejo) : super(repaint: ultimo);

  final ValueListenable<CuadroPuntos?> ultimo;
  final bool espejo;

  /// Dedos y palma (índices de MediaPipe Hands).
  static const List<List<int>> _huesos = [
    [0, 1, 2, 3, 4],
    [0, 5, 6, 7, 8],
    [0, 9, 10, 11, 12],
    [0, 13, 14, 15, 16],
    [0, 17, 18, 19, 20],
    [5, 9, 13, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cuadro = ultimo.value;
    if (cuadro == null) return;

    Offset? punto(List<double> p, int i) {
      final x = p[i * 3], y = p[i * 3 + 1];
      if (x.isNaN || y.isNaN) return null;
      // Un punto fuera del cuadro es una estimación del modelo (por ejemplo
      // hombros cortados por estar muy cerca): no se dibuja.
      if (x < 0 || x > 1 || y < 0 || y > 1) return null;
      return Offset((espejo ? 1 - x : x) * size.width, y * size.height);
    }

    void mano(List<double> p, Color color) {
      final linea = Paint()
        ..color = color.withValues(alpha: .7)
        ..strokeWidth = 2;
      for (final hueso in _huesos) {
        for (var k = 0; k < hueso.length - 1; k++) {
          final a = punto(p, hueso[k]), b = punto(p, hueso[k + 1]);
          if (a != null && b != null) canvas.drawLine(a, b, linea);
        }
      }
      final relleno = Paint()..color = color;
      for (var i = 0; i < puntosMano; i++) {
        final o = punto(p, i);
        if (o != null) canvas.drawCircle(o, 3.5, relleno);
      }
    }

    mano(cuadro.manoIzq, const Color(0xFFFFC800));
    mano(cuadro.manoDer, const Color(0xFF0078FF));

    final verde = Paint()..color = const Color(0xFF00C800);
    for (final i in indicesPose) {
      final o = punto(cuadro.pose, i);
      if (o != null) canvas.drawCircle(o, 4, verde);
    }
    final hi = punto(cuadro.pose, hombroIzq),
        hd = punto(cuadro.pose, hombroDer);
    if (hi != null && hd != null) {
      canvas.drawLine(hi, hd, verde..strokeWidth = 2);
    }

    final blanco = Paint()..color = const Color(0xB3FFFFFF);
    for (final i in indicesCara) {
      final o = punto(cuadro.cara, i);
      if (o != null) canvas.drawCircle(o, 1.5, blanco);
    }
  }

  @override
  bool shouldRepaint(_PuntosPainter anterior) => anterior.espejo != espejo;
}
