import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../services/detector_puntos.dart';
import 'esquinas.dart';
import 'logo.dart';
import 'puntos_en_vivo.dart';

/// Cámara frontal a pantalla completa, con degradados arriba y abajo para que
/// se lea el texto encima, y las esquinas que marcan dónde encuadrar manos y torso.
///
/// Si la cámara no abre (permiso negado, equipo sin cámara) muestra el fondo
/// oscuro del diseño con un aviso.
///
/// El [detector] (MediaPipe web) abre la cámara por su cuenta y muestra el
/// video detrás de Flutter; aquí solo se dibujan los puntos de manos, pose y
/// rostro encima.
class CamaraFondo extends StatefulWidget {
  const CamaraFondo({
    super.key,
    this.detector,
    this.mostrarFps = false,
    this.pausarMientras,
  });

  final DetectorPuntos? detector;

  /// Mientras valga `true` la detección se pausa (la cámara sigue encendida).
  final ValueListenable<bool>? pausarMientras;

  /// Muestra los cuadros por segundo de la detección.
  final bool mostrarFps;

  @override
  State<CamaraFondo> createState() => _CamaraFondoState();
}

class _CamaraFondoState extends State<CamaraFondo> {
  String? _error;
  bool _videoWebListo = false;
  bool _visible = true;
  Size? _tamanoVisto;
  StreamSubscription<dynamic>? _vigilaTamano;

  /// En un `IndexedStack` la pestaña oculta tiene los ticker apagados; así se
  /// sabe cuándo pausar la detección.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      _actualizarPausa();
    }
  }

  /// La detección corre solo si la pestaña se ve y no hay una pausa pedida.
  void _actualizarPausa() {
    final pausaPedida = widget.pausarMientras?.value ?? false;
    widget.detector?.pausar(!_visible || pausaPedida);
  }

  @override
  void initState() {
    super.initState();
    widget.pausarMientras?.addListener(_actualizarPausa);
    // Se espera a que la pantalla ya esté dibujada (y a que se cierre el
    // diálogo del permiso) antes de abrir la cámara.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) _iniciarWeb();
    });
  }

  Future<void> _iniciarWeb() async {
    try {
      await widget.detector!.iniciar();
      if (!mounted) return;
      setState(() {
        _videoWebListo = true;
        _tamanoVisto = widget.detector!.tamanoVideo;
        _error = null;
      });
      // Si el navegador cambia la resolución o la orientación del video, se
      // vuelve a calcular el encuadre para que no se deforme.
      _vigilaTamano?.cancel();
      _vigilaTamano = widget.detector!.cuadros.listen((_) {
        final actual = widget.detector?.tamanoVideo;
        if (mounted && actual != null && actual != _tamanoVisto) {
          setState(() => _tamanoVisto = actual);
        }
      });
    } catch (e) {
      debugPrint('Cámara web: no se pudo iniciar: $e');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _reintentar() {
    setState(() => _error = null);
    _iniciarWeb();
  }

  @override
  void dispose() {
    widget.pausarMientras?.removeListener(_actualizarPausa);
    _vigilaTamano?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tamanoWeb = widget.detector?.tamanoVideo;
    final Widget fondo;
    if (_videoWebListo &&
        tamanoWeb != null &&
        tamanoWeb.width > 0 &&
        tamanoWeb.height > 0) {
      // El video HTML va detrás de Flutter, recortado con `object-fit: cover`.
      // Los puntos se colocan con el mismo cálculo de recorte.
      fondo = LayoutBuilder(
        builder: (context, caja) {
          final escala = math.max(
            caja.maxWidth / tamanoWeb.width,
            caja.maxHeight / tamanoWeb.height,
          );
          final ancho = tamanoWeb.width * escala;
          final alto = tamanoWeb.height * escala;
          return ClipRect(
            child: OverflowBox(
              maxWidth: ancho,
              maxHeight: alto,
              child: SizedBox(
                width: ancho,
                height: alto,
                child: PuntosEnVivo(cuadros: widget.detector!.cuadros),
              ),
            ),
          );
        },
      );
    } else {
      fondo = GestureDetector(
        onTap: _error == null ? null : _reintentar,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(.8, -.85),
              radius: 1.3,
              colors: [Color(0xFF162039), Color(0xFF090E1C), Color(0xFF070B16)],
              stops: [0, .5, 1],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _error == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Logo(tamano: 72),
                        SizedBox(height: 22),
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF6C9BFF),
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Iniciando cámara…',
                          style: TextStyle(
                            color: Color(0xFF9AA6BF),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'No se pudo abrir la cámara.\nToca para reintentar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF9AA6BF), fontSize: 13),
                    ),
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        fondo,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66070B16),
                Color(0x00070B16),
                Color(0x00070B16),
                Color(0xBF070B16),
              ],
              stops: [0, .2, .57, 1],
            ),
          ),
        ),
        const _GuiaEncuadre(),
        if (widget.mostrarFps && widget.detector != null)
          SafeArea(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _ContadorFps(cuadros: widget.detector!.cuadros),
              ),
            ),
          ),
      ],
    );
  }
}

class _GuiaEncuadre extends StatelessWidget {
  const _GuiaEncuadre();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: LayoutBuilder(
          builder: (context, caja) => Padding(
            padding: EdgeInsets.fromLTRB(
              42,
              caja.maxHeight * .16,
              42,
              caja.maxHeight * .35,
            ),
            child: const Stack(
              children: [
                Positioned.fill(
                  child: Esquinas(
                    color: Color(0x99FFFFFF),
                    largo: 42,
                    radio: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Cuenta cuántos cuadros con puntos llegan por segundo. Va fuera de la
/// vista previa escalada para que el texto no se recorte.
class _ContadorFps extends StatefulWidget {
  const _ContadorFps({required this.cuadros});

  final Stream<dynamic> cuadros;

  @override
  State<_ContadorFps> createState() => _ContadorFpsState();
}

class _ContadorFpsState extends State<_ContadorFps> {
  StreamSubscription<dynamic>? _suscripcion;
  Timer? _reloj;
  int _contados = 0;
  int _fps = 0;

  @override
  void initState() {
    super.initState();
    _suscripcion = widget.cuadros.listen((_) => _contados++);
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _fps = _contados;
        _contados = 0;
      });
    });
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '$_fps FPS',
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}
