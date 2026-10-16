import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/paleta.dart';
import '../widgets/boton_icono.dart';

/// Frase en pantalla completa, para enseñársela a otra persona.
/// Siempre en claro, con letra grande (68 px con el tamaño por defecto).
class MostrarScreen extends StatelessWidget {
  const MostrarScreen({super.key});

  static const Color _tinta = Color(0xFF0B1020);

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final frase = app.fraseActual;
    // 26 px de ajuste -> ~68 px aquí; crece y baja junto con el ajuste.
    final tamano = (app.ajustes.tamano * 2.6).clamp(44.0, 96.0).toDouble();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left, color: _tinta),
                    label: const Text(
                      'Volver',
                      style: TextStyle(
                        color: _tinta,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  BotonIcono(
                    icono: app.ajustes.vozActiva
                        ? Icons.volume_up_outlined
                        : Icons.volume_off_outlined,
                    etiqueta: app.ajustes.vozActiva
                        ? 'Reproducir frase'
                        : 'Voz desactivada',
                    onPressed: app.ajustes.vozActiva ? app.repetir : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SIGNCAST',
                        style: TextStyle(
                          color: Paleta.azul,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.9,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        frase.isEmpty ? 'Sin traducción' : frase,
                        style: TextStyle(
                          color: _tinta,
                          fontSize: tamano,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        width: 62,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Paleta.azul,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Traducción lista para mostrar',
                        style: TextStyle(
                          color: Color(0xFF69748A),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: frase.isEmpty ? null : app.repetir,
                  style: FilledButton.styleFrom(
                    backgroundColor: _tinta,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.repeat, size: 20),
                  label: const Text('Repetir en voz alta'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
