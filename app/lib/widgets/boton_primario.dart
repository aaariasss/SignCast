import 'package:flutter/material.dart';

import '../theme/paleta.dart';

/// Botón grande con degradado azul (Comenzar, Permitir cámara).
class BotonPrimario extends StatelessWidget {
  const BotonPrimario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.alto = 56,
  });

  final String texto;
  final VoidCallback onPressed;
  final IconData? icono;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(999);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: forma,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Paleta.azul, Paleta.azul2],
        ),
        boxShadow: [
          BoxShadow(
            color: Paleta.azul.withValues(alpha: .4),
            blurRadius: 34,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: forma,
          onTap: onPressed,
          child: SizedBox(
            height: alto,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  texto,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                  ),
                ),
                if (icono != null) ...[
                  const SizedBox(width: 12),
                  Icon(icono, size: 20, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
