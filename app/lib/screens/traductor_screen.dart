import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/camara_fondo.dart';
import '../widgets/hoja_subtitulos.dart';
import '../widgets/logo.dart';
import '../widgets/pildora_estado.dart';

/// Pantalla principal: cámara, estado de detección y subtítulos.
class TraductorScreen extends StatelessWidget {
  const TraductorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final inferior = MediaQuery.of(context).viewPadding.bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        const CamaraFondo(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Logo(),
                      SizedBox(width: 8),
                      Text(
                        'SignCast',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  PildoraEstado(estado: app.estado),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 104 + inferior,
          child: const HojaSubtitulos(),
        ),
      ],
    );
  }
}
