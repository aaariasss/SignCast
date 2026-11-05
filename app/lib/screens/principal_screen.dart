import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/barra_inferior.dart';
import 'ajustes_screen.dart';
import 'historial_screen.dart';
import 'traductor_screen.dart';

/// Contenedor con las tres pestañas (Traductor, Historial, Ajustes).
///
/// Usa [IndexedStack] para que la cámara no se vuelva a abrir cada vez que se
/// cambia de pestaña.
class PrincipalScreen extends StatefulWidget {
  const PrincipalScreen({super.key});

  @override
  State<PrincipalScreen> createState() => _PrincipalScreenState();
}

class _PrincipalScreenState extends State<PrincipalScreen> {
  int _indice = 0;
  late final AppState _app;

  @override
  void initState() {
    super.initState();
    _app = AppScope.leer(context);
    _app.iniciarReconocimiento();
  }

  @override
  void dispose() {
    _app.detenerReconocimiento();
    super.dispose();
  }

  /// Solo el traductor reconoce y habla; en las otras pestañas se pausa.
  void _cambiarPestana(int i) {
    if (i == _indice) return;
    if (i == 0) {
      _app.reanudarReconocimiento();
    } else if (_indice == 0) {
      _app.pausarReconocimiento();
    }
    setState(() => _indice = i);
  }

  @override
  Widget build(BuildContext context) {
    final inferior = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      // En web el video de la cámara va detrás de Flutter: el fondo del
      // traductor debe ser transparente para que se vea.
      backgroundColor: kIsWeb && _indice == 0 ? Colors.transparent : null,
      body: Stack(
        children: [
          IndexedStack(
            index: _indice,
            children: const [
              TraductorScreen(),
              HistorialScreen(),
              AjustesScreen(),
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16 + inferior,
            child: BarraInferior(
              indice: _indice,
              onCambio: _cambiarPestana,
            ),
          ),
        ],
      ),
    );
  }
}
