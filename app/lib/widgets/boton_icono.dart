import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/paleta.dart';

/// Botón circular de 42 px (reproducir, copiar, voz...).
class BotonIcono extends StatelessWidget {
  const BotonIcono({
    super.key,
    required this.icono,
    required this.etiqueta,
    this.onPressed,
    this.activo = false,
  });

  final IconData icono;

  /// Texto para lectores de pantalla.
  final String etiqueta;
  final VoidCallback? onPressed;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Semantics(
      button: true,
      label: etiqueta,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activo ? Paleta.azul : (p.oscuro ? p.vidrio : Colors.white),
            border: Border.all(
              color: activo ? Colors.white.withValues(alpha: .16) : p.linea,
            ),
            boxShadow: activo
                ? [
                    BoxShadow(
                      color: Paleta.azul.withValues(alpha: .44),
                      blurRadius: 22,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icono,
            size: 22,
            color: activo ? Colors.white : (p.oscuro ? p.tenue : p.tinta),
          ),
        ),
      ),
    );
  }
}
