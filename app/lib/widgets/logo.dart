import 'package:flutter/material.dart';

/// Logo de SignCast (`assets/logo.png`): mano con globo de subtítulos sobre el
/// degradado azul. Es el mismo ícono con el que se instala la app.
class Logo extends StatelessWidget {
  const Logo({super.key, this.tamano = 32});

  final double tamano;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(tamano * .24),
    child: Image.asset(
      'assets/logo.png',
      width: tamano,
      height: tamano,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'SignCast',
    ),
  );
}
