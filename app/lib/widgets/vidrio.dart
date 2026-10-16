import 'dart:ui';

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
    return ClipRRect(
      borderRadius: forma,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: desenfoque, sigmaY: desenfoque),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? p.vidrio,
            borderRadius: forma,
            border: Border.all(color: borde ?? p.linea),
          ),
          child: child,
        ),
      ),
    );
  }
}
