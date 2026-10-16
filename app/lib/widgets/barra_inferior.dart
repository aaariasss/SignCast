import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/paleta.dart';
import 'vidrio.dart';

/// Barra inferior flotante con las tres pestañas de la app.
class BarraInferior extends StatelessWidget {
  const BarraInferior({
    super.key,
    required this.indice,
    required this.onCambio,
  });

  final int indice;
  final ValueChanged<int> onCambio;

  static const _pestanas = [
    (Icons.translate, 'Traductor'),
    (Icons.history, 'Historial'),
    (Icons.settings_outlined, 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return SizedBox(
      height: 72,
      child: Vidrio(
        radio: 999,
        desenfoque: 28,
        color: p.fondoBarra,
        borde: p.oscuro ? const Color(0x1FFFFFFF) : const Color(0x170E1A33),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < _pestanas.length; i++)
              _Pestana(
                icono: _pestanas[i].$1,
                etiqueta: _pestanas[i].$2,
                activa: i == indice,
                onTap: () => onCambio(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.icono,
    required this.etiqueta,
    required this.activa,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final colorInactivo = p.oscuro
        ? const Color(0xFF77829A)
        : const Color(0xFF69748A);
    final color = activa ? (p.oscuro ? Colors.white : p.tinta) : colorInactivo;
    return Semantics(
      button: true,
      selected: activa,
      label: etiqueta,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 88,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activa ? Paleta.azul : Colors.transparent,
                  boxShadow: activa
                      ? [
                          BoxShadow(
                            color: Paleta.azul.withValues(alpha: .55),
                            blurRadius: 22,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icono,
                  size: 20,
                  color: activa ? Colors.white : colorInactivo,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                etiqueta,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
