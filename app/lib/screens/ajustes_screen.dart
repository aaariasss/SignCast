import 'package:flutter/material.dart';

import '../models/ajustes.dart';
import '../state/app_state.dart';
import '../theme/paleta.dart';
import '../widgets/control_deslizante.dart';
import '../widgets/encabezado_pagina.dart';
import '../widgets/vidrio.dart';

/// Ajustes: tamaño del texto, voz y apariencia (todo se guarda en el dispositivo).
class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = context.paleta;
    final a = app.ajustes;
    final inferior = MediaQuery.of(context).viewPadding.bottom;
    return DecoratedBox(
      decoration: p.fondo,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EncabezadoPagina(
              sobretitulo: 'PERSONALIZA',
              titulo: 'Ajustes',
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 110 + inferior),
                children: [
                  _Seccion(
                    titulo: 'Subtítulos',
                    hijos: [
                      _EncabezadoControl(
                        titulo: 'Tamaño del texto',
                        valor: '${a.tamano.round()} px',
                      ),
                      ControlDeslizante(
                        valor: a.tamano,
                        min: Ajustes.tamanoMin,
                        max: Ajustes.tamanoMax,
                        divisiones: (Ajustes.tamanoMax - Ajustes.tamanoMin)
                            .round(),
                        etiquetaValor: '${a.tamano.round()} px',
                        etiquetaInicio: 'A',
                        etiquetaFin: 'A',
                        extremosDeTexto: true,
                        onChanged: app.cambiarTamano,
                      ),
                      const SizedBox(height: 18),
                      Container(
                        height: 90,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0x9903060D),
                          border: Border.all(color: const Color(0x12FFFFFF)),
                        ),
                        child: Text(
                          'No entiendo.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: a.tamano,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _Seccion(
                    titulo: 'Voz',
                    hijos: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              color: p.azulSuave,
                            ),
                            child: Icon(
                              Icons.volume_up_outlined,
                              size: 22,
                              color: p.oscuro
                                  ? const Color(0xFFA9C1FF)
                                  : Paleta.azul,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Leer traducciones',
                                  style: TextStyle(
                                    color: p.tinta,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Reproduce cada frase',
                                  style: TextStyle(
                                    color: p.tenue,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: a.vozActiva,
                            onChanged: (_) => app.alternarVoz(),
                          ),
                        ],
                      ),
                      Divider(height: 36, color: p.linea),
                      _EncabezadoControl(
                        titulo: 'Velocidad de voz',
                        valor: '${a.velocidadVoz.toStringAsFixed(1)}×',
                      ),
                      ControlDeslizante(
                        valor: a.velocidadVoz,
                        min: Ajustes.velocidadMin,
                        max: Ajustes.velocidadMax,
                        divisiones: 10,
                        etiquetaValor: '${a.velocidadVoz.toStringAsFixed(1)}×',
                        etiquetaInicio: 'Lenta',
                        etiquetaFin: 'Rápida',
                        onChanged: app.cambiarVelocidad,
                      ),
                    ],
                  ),
                  _Seccion(
                    titulo: 'Apariencia',
                    hijos: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: p.oscuro
                              ? const Color(0x2E000000)
                              : const Color(0xFFEEF2F8),
                          border: Border.all(
                            color: p.oscuro ? const Color(0x0FFFFFFF) : p.linea,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _OpcionTema(
                                icono: Icons.light_mode_outlined,
                                texto: 'Claro',
                                activa: !a.oscuro,
                                onTap: () => app.cambiarOscuro(false),
                              ),
                            ),
                            Expanded(
                              child: _OpcionTema(
                                icono: Icons.dark_mode_outlined,
                                texto: 'Oscuro',
                                activa: a.oscuro,
                                onTap: () => app.cambiarOscuro(true),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.hijos});

  final String titulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Vidrio(
        radio: 28,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(
                color: p.tenue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ...hijos,
          ],
        ),
      ),
    );
  }
}

class _EncabezadoControl extends StatelessWidget {
  const _EncabezadoControl({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: p.tinta,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(valor, style: TextStyle(color: p.tenue, fontSize: 11)),
      ],
    );
  }
}

class _OpcionTema extends StatelessWidget {
  const _OpcionTema({
    required this.icono,
    required this.texto,
    required this.activa,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final color = activa ? Colors.white : p.tenue;
    return Semantics(
      button: true,
      selected: activa,
      label: texto,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: activa ? Paleta.azul : Colors.transparent,
            boxShadow: activa
                ? [
                    BoxShadow(
                      color: Paleta.azul.withValues(alpha: .3),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                texto,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
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
