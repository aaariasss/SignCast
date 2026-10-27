import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../state/app_state.dart';

/// Tarjeta "de vidrio": fondo translúcido con desenfoque y borde fino.
class Vidrio extends StatelessWidget {
  const Vidrio({
    super.key,
    required this.child,
    this.radio = 28,
    this.padding = EdgeInsets.zero,
    this.desenfoque = 24,
    this.color,
    this.borde,
  });

  final Widget child;
  final double radio;
  final EdgeInsetsGeometry padding;
  final double desenfoque;
  final Color? color;
  final Color? borde;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final forma = BorderRadius.circular(radio);
    final tarjeta = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.vidrio,
        borderRadius: forma,
        border: Border.all(color: borde ?? p.linea),
      ),
      child: child,
    );
    // En web el desenfoque no alcanza al video de la cámara (es un elemento
    // HTML aparte) y cuesta cuadros por segundo, así que solo se usa fuera de
    // la web.
    return ClipRRect(
      borderRadius: forma,
      child: kIsWeb || desenfoque <= 0
          ? tarjeta
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: desenfoque, sigmaY: desenfoque),
              child: tarjeta,
            ),
    );
  }
}
