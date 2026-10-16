import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/paleta.dart';
import '../widgets/encabezado_pagina.dart';
import '../widgets/tarjeta_historial.dart';

/// Frases traducidas en esta sesión (la más reciente arriba).
class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = context.paleta;
    final frases = app.historial;
    final inferior = MediaQuery.of(context).viewPadding.bottom;
    return DecoratedBox(
      decoration: p.fondo,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EncabezadoPagina(
              sobretitulo: 'ESTA SESIÓN',
              titulo: 'Historial',
              extremo: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Paleta.azul.withValues(alpha: .14),
                  border: Border.all(color: Paleta.azul.withValues(alpha: .24)),
                ),
                child: Text(
                  frases.length == 1 ? '1 frase' : '${frases.length} frases',
                  style: TextStyle(
                    color: p.oscuro
                        ? const Color(0xFFB4C9FF)
                        : const Color(0xFF2A5FD6),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: frases.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Aún no hay frases en esta sesión.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.tenue, fontSize: 15),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 110 + inferior),
                      itemCount: frases.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) =>
                          TarjetaHistorial(frase: frases[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
