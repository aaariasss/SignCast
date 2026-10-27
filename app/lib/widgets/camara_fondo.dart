import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/detector_puntos.dart';
import 'esquinas.dart';
import 'puntos_en_vivo.dart';

/// Cámara frontal a pantalla completa, con degradados arriba y abajo para que
/// se lea el texto encima, y el recuadro "Encuadra tus manos y torso".
///
/// Si la cámara no abre (permiso negado, escritorio sin cámara) muestra el
/// fondo oscuro del diseño con un aviso.
///
/// Si se da un [detector], la cámara le entrega sus imágenes y se dibujan los
/// puntos de manos, pose y rostro encima (issue #23). Sin detector se
/// comporta igual que antes.
class CamaraFondo extends StatefulWidget {
  const CamaraFondo({super.key, this.detector, this.mostrarFps = false});

  final DetectorPuntos? detector;

  /// Muestra los cuadros por segundo de la detección (para medir el #23).
  final bool mostrarFps;

  @override
  State<CamaraFondo> createState() => _CamaraFondoState();
}

class _CamaraFondoState extends State<CamaraFondo> {
  CameraController? _controller;
  String? _error;
  bool _transmitiendo = false;

  @override
  void initState() {
    super.initState();
    // Se espera a que la pantalla ya esté dibujada (y a que se cierre el
    // diálogo del permiso) antes de abrir la cámara.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) _iniciarCamara();
    });
  }

  /// Abre la cámara frontal. Al aceptar el permiso por primera vez, Android a
  /// veces rechaza la primera apertura (la superficie de la vista previa aún no
  /// está lista), así que se reintenta unas veces antes de mostrar el error.
  Future<void> _iniciarCamara({int intentos = 3}) async {
    for (var i = 1; i <= intentos; i++) {
      CameraController? controller;
      try {
        final camaras = await availableCameras();
        final frontal = camaras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => camaras.first,
        );
        controller = CameraController(
          frontal,
          ResolutionPreset.medium,
          enableAudio: false,
          // Solo se pide YUV cuando hay detector; sin él la cámara queda como estaba.
          imageFormatGroup:
              widget.detector != null ? ImageFormatGroup.yuv420 : null,
        );
        await controller.initialize();
        if (!mounted) {
          await controller.dispose();
          return;
        }
        await _iniciarDeteccion(controller, frontal.sensorOrientation);
        if (!mounted) {
          await controller.dispose();
          return;
        }
        setState(() {
          _controller = controller;
          _error = null;
        });
        return;
      } catch (e) {
        debugPrint('Cámara: intento $i de $intentos falló: $e');
        try {
          await controller?.dispose();
        } catch (_) {}
        if (!mounted) return;
        if (i == intentos) {
          setState(() => _error = e.toString());
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 800));
        }
      }
    }
  }

  /// Conecta la cámara con el detector. Si falla (por ejemplo faltan los
  /// modelos en los assets) la cámara sigue funcionando, sin puntos.
  Future<void> _iniciarDeteccion(CameraController controller, int rotacion) async {
    final detector = widget.detector;
    if (detector == null) return;
    try {
      await detector.iniciar();
      var medido = false;
      await controller.startImageStream((imagen) {
        if (!medido) {
          medido = true;
          debugPrint(
            'Puntos: imagen ${imagen.width}x${imagen.height}, '
            'vista previa ${controller.value.previewSize}, rotación $rotacion',
          );
        }
        detector.procesar(imagen, rotacion: rotacion);
      });
      _transmitiendo = true;
    } catch (e) {
      debugPrint('Puntos: no se pudo iniciar la detección: $e');
    }
  }

  void _reintentar() {
    setState(() => _error = null);
    _iniciarCamara();
  }

  @override
  void dispose() {
    if (_transmitiendo) {
      _controller?.stopImageStream().catchError((Object _) {});
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final Widget fondo;
    if (controller != null && controller.value.isInitialized) {
      fondo = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize!.height,
            height: controller.value.previewSize!.width,
            child: widget.detector == null
                ? CameraPreview(controller)
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(controller),
                      PuntosEnVivo(cuadros: widget.detector!.cuadros),
                    ],
                  ),
          ),
        ),
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
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    'Encuadra tus manos y torso',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xA6FFFFFF),
                    ),
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
