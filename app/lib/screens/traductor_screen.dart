import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/detector_plataforma.dart';
import '../services/detector_puntos.dart';
import '../state/app_state.dart';
import '../widgets/camara_fondo.dart';
import '../widgets/hoja_subtitulos.dart';
import '../widgets/logo.dart';
import '../widgets/pildora_estado.dart';

/// Muestra los FPS de la detección.
/// Para medir: `flutter run -d chrome --dart-define=PUNTOS=true`.
const bool _mostrarFps = bool.fromEnvironment('PUNTOS');

/// Pantalla principal: cámara, estado de detección y subtítulos.
class TraductorScreen extends StatefulWidget {
  const TraductorScreen({super.key});

  @override
  State<TraductorScreen> createState() => _TraductorScreenState();
}

class _TraductorScreenState extends State<TraductorScreen> {
  // La detección de puntos solo existe en el navegador.
  late final DetectorPuntos? _detector = kIsWeb ? crearDetectorPlataforma() : null;

  @override
  void initState() {
    super.initState();
    final detector = _detector;
    if (detector != null) {
      AppScope.leer(context).reconocedor.conectarCuadros(detector.cuadros);
    }
  }

  @override
  void dispose() {
    _detector?.liberar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final inferior = MediaQuery.of(context).viewPadding.bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        CamaraFondo(
          detector: _detector,
          pausarMientras: app.voz.hablando,
          mostrarFps: _mostrarFps && _detector != null,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Logo(),
                      SizedBox(width: 8),
                      Text(
                        'SignCast',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  PildoraEstado(estado: app.estado),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 104 + inferior,
          child: const HojaSubtitulos(),
        ),
      ],
    );
  }
}
