import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/frase_historial.dart';
import '../state/app_state.dart';
import 'boton_icono.dart';
import 'vidrio.dart';

/// Tarjeta de una frase en el historial: hora, texto, reproducir y copiar.
class TarjetaHistorial extends StatefulWidget {
  const TarjetaHistorial({super.key, required this.frase});

  final FraseHistorial frase;

  @override
  State<TarjetaHistorial> createState() => _TarjetaHistorialState();
}

class _TarjetaHistorialState extends State<TarjetaHistorial> {
  bool _copiado = false;
  Timer? _timer;

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.frase.texto));
    if (!mounted) return;
    setState(() => _copiado = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _copiado = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final app = context.app;
    return Vidrio(
      radio: 28,
      padding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 88),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: p.tenue),
                      const SizedBox(width: 6),
                      Text(
                        widget.frase.horaTexto,
                        style: TextStyle(color: p.tenue, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    widget.frase.texto,
                    style: TextStyle(
                      color: p.tinta,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            BotonIcono(
              icono: Icons.play_arrow_rounded,
              etiqueta: 'Reproducir',
              onPressed: () => app.reproducir(widget.frase.texto),
            ),
            const SizedBox(width: 8),
            BotonIcono(
              icono: _copiado ? Icons.check : Icons.content_copy,
              etiqueta: 'Copiar',
              activo: _copiado,
              onPressed: _copiar,
            ),
          ],
        ),
      ),
    );
  }
}
