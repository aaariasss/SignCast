import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/paleta.dart';

/// Control deslizante con las etiquetas de los extremos (tamaño y velocidad).
class ControlDeslizante extends StatelessWidget {
  const ControlDeslizante({
    super.key,
    required this.valor,
    required this.min,
    required this.max,
    required this.divisiones,
    required this.onChanged,
    required this.etiquetaInicio,
    required this.etiquetaFin,
    this.etiquetaValor,
    this.extremosDeTexto = false,
  });

  final double valor;
  final double min;
  final double max;
  final int divisiones;
  final ValueChanged<double> onChanged;
  final String etiquetaInicio;
  final String etiquetaFin;

  /// Texto que aparece sobre la perilla mientras se arrastra.
  final String? etiquetaValor;

  /// Si es true, la "A" del inicio es chica y la del final grande
  /// (control del tamaño del texto).
  final bool extremosDeTexto;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final estiloBase = TextStyle(color: p.tenue, fontSize: 10);
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: Paleta.azul,
            inactiveTrackColor: p.oscuro
                ? const Color(0x1FFFFFFF)
                : const Color(0xFFD8E0EC),
            thumbColor: Colors.white,
            overlayColor: Paleta.azul.withValues(alpha: .22),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            trackShape: const RoundedRectSliderTrackShape(),
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
          ),
          child: Slider(
            value: valor.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisiones,
            label: etiquetaValor,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                etiquetaInicio,
                style: extremosDeTexto
                    ? estiloBase.copyWith(fontSize: 12)
                    : estiloBase,
              ),
              Text(
                etiquetaFin,
                style: extremosDeTexto
                    ? estiloBase.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: .8,
                      )
                    : estiloBase,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
