import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/estado_deteccion.dart';
import '../screens/mostrar_screen.dart';
import '../state/app_state.dart';
import '../theme/paleta.dart';
import 'vidrio.dart';

/// Hoja de subtítulos sobre la cámara (pantalla del traductor).
///
/// Según el estado muestra: un aviso, puntos de "reconociendo" o la frase
/// traducida con sus acciones. El tamaño de la frase sale de los ajustes.
class HojaSubtitulos extends StatefulWidget {
  const HojaSubtitulos({super.key});

  @override
  State<HojaSubtitulos> createState() => _HojaSubtitulosState();
}

class _HojaSubtitulosState extends State<HojaSubtitulos> {
  bool _repitiendo = false;
  Timer? _timer;

  void _repetir(AppState app) {
    app.repetir();
    setState(() => _repitiendo = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _repitiendo = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = context.paleta;
    final estado = app.estado;
    final glosas = [
      for (final g in app.glosas)
        if (!g.startsWith('_')) g,
    ];

    return SizedBox(
      height: 252,
      child: Vidrio(
        radio: 28,
        desenfoque: 30,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        borde: p.oscuro ? const Color(0x1FFFFFFF) : const Color(0x94FFFFFF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: p.oscuro
                      ? const Color(0x3DFFFFFF)
                      : const Color(0x2E0E1A33),
                ),
              ),
            ),
            const SizedBox(height: 17),
            if (estado != EstadoDeteccion.sinManos && glosas.isNotEmpty) ...[
              _Chips(glosas: glosas, paleta: p),
              const SizedBox(height: 4),
            ],
            Expanded(child: _contenido(app, p, estado)),
          ],
        ),
      ),
    );
  }

  Widget _contenido(AppState app, Paleta p, EstadoDeteccion estado) {
    switch (estado) {
      case EstadoDeteccion.sinManos:
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              'Coloca tus manos dentro del recuadro',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.tenue,
                fontSize: 17,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      case EstadoDeteccion.detectando:
        return const Center(child: _PuntosDetectando());
      case EstadoDeteccion.traduciendo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 13, bottom: 8),
                child: Text(
                  app.fraseActual,
                  style: TextStyle(
                    color: p.tinta,
                    fontSize: app.ajustes.tamano,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AccionRedonda(
                  icono: app.ajustes.vozActiva
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                  etiqueta: app.ajustes.vozActiva ? 'Voz activa' : 'Sin voz',
                  activa: app.ajustes.vozActiva,
                  onTap: app.alternarVoz,
                ),
                _AccionRedonda(
                  icono: Icons.repeat,
                  etiqueta: 'Repetir',
                  activa: _repitiendo,
                  onTap: () => _repetir(app),
                ),
                _AccionRedonda(
                  icono: Icons.open_in_full,
                  etiqueta: 'Mostrar',
                  activa: false,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MostrarScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.glosas, required this.paleta});

  final List<String> glosas;
  final Paleta paleta;

  @override
  Widget build(BuildContext context) {
    final hijos = <Widget>[];
    for (var i = 0; i < glosas.length; i++) {
      if (i > 0) {
        hijos.add(
          Text(
            '·',
            style: TextStyle(color: paleta.tenue.withValues(alpha: .55)),
          ),
        );
      }
      hijos.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Paleta.azul.withValues(alpha: .09),
            border: Border.all(color: Paleta.azul.withValues(alpha: .55)),
          ),
          child: Text(
            glosas[i],
            style: TextStyle(
              color: paleta.oscuro
                  ? const Color(0xFF9BBAFF)
                  : const Color(0xFF2A5FD6),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .9,
            ),
          ),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: hijos,
    );
  }
}

class _AccionRedonda extends StatelessWidget {
  const _AccionRedonda({
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
    final color = activa ? (p.oscuro ? Colors.white : p.tinta) : p.tenue;
    return Semantics(
      button: true,
      label: etiqueta,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 92,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activa ? Paleta.azul : const Color(0x0DFFFFFF),
                  border: Border.all(
                    color: activa
                        ? const Color(0x29FFFFFF)
                        : (p.oscuro
                              ? const Color(0x21FFFFFF)
                              : const Color(0xFFDBE2EE)),
                  ),
                  boxShadow: activa
                      ? [
                          BoxShadow(
                            color: Paleta.azul.withValues(alpha: .44),
                            blurRadius: 22,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icono,
                  size: 22,
                  color: activa ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                etiqueta,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
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

/// Tres puntos que suben y bajan mientras se reconocen señas.
class _PuntosDetectando extends StatefulWidget {
  const _PuntosDetectando();

  @override
  State<_PuntosDetectando> createState() => _PuntosDetectandoState();
}

class _PuntosDetectandoState extends State<_PuntosDetectando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Reconociendo señas',
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            _punto((_c.value + i * .125) % 1),
          ],
        ],
      ),
    ),
  );

  Widget _punto(double fase) {
    final sube = (math.sin(fase * 2 * math.pi) + 1) / 2;
    return Transform.translate(
      offset: Offset(0, -5 * sube),
      child: Opacity(
        opacity: 1 - .65 * sube,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Paleta.azul,
            boxShadow: [
              BoxShadow(
                color: Paleta.azul.withValues(alpha: .55),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
