import 'package:flutter/material.dart';

import '../theme/paleta.dart';

/// Logo provisional de SignCast: ícono de seña con el degradado azul-cian.
///
/// El de Figma es un globo de diálogo con una mano dentro. Si lo exportan como
/// SVG, se puede cambiar este widget por `SvgPicture.asset` (`flutter_svg`).
class Logo extends StatelessWidget {
  const Logo({super.key, this.tamano = 32});

  final double tamano;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (rect) => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Paleta.azul, Paleta.cian],
    ).createShader(rect),
    child: Icon(Icons.sign_language, size: tamano, color: Colors.white),
  );
}
