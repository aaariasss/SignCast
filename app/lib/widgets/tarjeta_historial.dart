import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/frase_historial.dart';
import '../screens/mostrar_screen.dart';
import '../state/app_state.dart';
import 'boton_icono.dart';
import 'vidrio.dart';

/// Tarjeta de una frase en el historial: hora, texto, reproducir, mostrar en
/// grande y copiar.
class TarjetaHistorial extends StatefulWidget {
  const TarjetaHistorial({super.key, required this.frase});

  final FraseHistorial frase;

  @override
  State<TarjetaHistorial> createState() => _TarjetaHistorialState();
}

class _TarjetaHistorialState extends State<TarjetaHistorial> {
  bool _copiado = false;
  bool _sonando = false;
  Timer? _timer;
  ValueListenable<bool>? _hablando;

  /// Se queda marcado mientras suena la frase; si la voz no llega a sonar,
  /// al menos se ve el toque un instante.
  Future<void> _reproducir() async {
    final app = context.app;
    final hablando = app.voz.hablando;
    _quitarAviso();
    setState(() => _sonando = true);
    final minimo = Future<void>.delayed(const Duration(milliseconds: 600));
    await app.reproducir(widget.frase.texto);
    await minimo;
    if (!mounted) return;
    if (!hablando.value) {
      setState(() => _sonando = false);
      return;
    }
    _hablando = hablando..addListener(_alCambiarVoz);
  }

  void _alCambiarVoz() {
    if (_hablando?.value ?? false) return;
    _quitarAviso();
    if (mounted) setState(() => _sonando = false);
  }

  void _quitarAviso() {
    _hablando?.removeListener(_alCambiarVoz);
    _hablando = null;
  }

  void _mostrarGrande() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MostrarScreen(texto: widget.frase.texto),
      ),
    );
  }

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
    _quitarAviso();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
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
              activo: _sonando,
              onPressed: _reproducir,
            ),
            const SizedBox(width: 8),
            BotonIcono(
              icono: Icons.fullscreen,
              etiqueta: 'Mostrar en grande',
              onPressed: _mostrarGrande,
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
