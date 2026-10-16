import 'package:flutter/material.dart';

import '../models/estado_deteccion.dart';
import '../theme/paleta.dart';
import 'vidrio.dart';

/// Píldora de estado de detección ("Sin manos", "Detectando…", "Traduciendo").
/// Va sobre la cámara, así que siempre usa texto claro.
class PildoraEstado extends StatefulWidget {
  const PildoraEstado({super.key, required this.estado});

  final EstadoDeteccion estado;

  @override
  State<PildoraEstado> createState() => _PildoraEstadoState();
}

class _PildoraEstadoState extends State<PildoraEstado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  Color get _colorPunto => switch (widget.estado) {
    EstadoDeteccion.sinManos => Paleta.grisEstado,
    EstadoDeteccion.detectando => Paleta.azul,
    EstadoDeteccion.traduciendo => Paleta.cian,
  };

  @override
  Widget build(BuildContext context) {
    final activo = widget.estado != EstadoDeteccion.sinManos;
    final colorTexto = widget.estado == EstadoDeteccion.traduciendo
        ? Paleta.cian
        : Colors.white;
    return Semantics(
      label: 'Estado: ${widget.estado.etiqueta}',
      child: Vidrio(
        radio: 999,
        desenfoque: 22,
        color: const Color(0x14FFFFFF),
        borde: const Color(0x1FFFFFFF),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulso,
              builder: (context, _) {
                final t = activo ? _pulso.value : 0.0;
                return Opacity(
                  opacity: 1 - .4 * t,
                  child: Transform.scale(
                    scale: 1 + .45 * t,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _colorPunto,
                        boxShadow: activo
                            ? [
                                BoxShadow(
                                  color: _colorPunto.withValues(alpha: .9),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 9),
            Text(
              widget.estado.etiqueta,
              style: TextStyle(
                color: colorTexto,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
