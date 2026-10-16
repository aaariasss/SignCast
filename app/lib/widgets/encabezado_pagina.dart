import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/paleta.dart';

/// Encabezado de Historial y Ajustes: sobretítulo azul + título grande.
class EncabezadoPagina extends StatelessWidget {
  const EncabezadoPagina({
    super.key,
    required this.sobretitulo,
    required this.titulo,
    this.extremo,
  });

  final String sobretitulo;
  final String titulo;

  /// Widget opcional a la derecha (la insignia de "N frases").
  final Widget? extremo;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sobretitulo,
                style: const TextStyle(
                  color: Paleta.azul2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.9,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                titulo,
                style: TextStyle(
                  color: p.tinta,
                  fontSize: 38,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          ?extremo,
        ],
      ),
    );
  }
}
