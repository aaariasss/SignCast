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

  @override
  Widget build(BuildContext context) {
    final inferior = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
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
              onCambio: (i) => setState(() => _indice = i),
            ),
          ),
        ],
      ),
    );
  }
}
