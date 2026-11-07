import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/paleta.dart';
import '../widgets/boton_primario.dart';
import '../widgets/logo.dart';
import '../widgets/mano_landmarks.dart';
import '../widgets/ruta_suave.dart';
import '../services/permiso_camara.dart';
import 'permiso_screen.dart';
import 'principal_screen.dart';

/// Primera pantalla: marca, mano con puntos clave y botón "Comenzar". Se
/// muestra siempre al entrar a la app.
///
/// Mientras se ve, la app descarga los modelos; con "Comenzar" espera a que
/// todo esté listo (y deja la voz desbloqueada con ese toque) antes de pasar a
/// la cámara.
class BienvenidaScreen extends StatefulWidget {
  const BienvenidaScreen({super.key});

  @override
  State<BienvenidaScreen> createState() => _BienvenidaScreenState();
}

class _BienvenidaScreenState extends State<BienvenidaScreen> {
  /// Tiempo máximo que se espera la carga antes de pasar de todos modos.
  static const Duration _espera = Duration(seconds: 40);

  Future<void>? _precarga;
  bool _preparando = false;

  @override
  void initState() {
    super.initState();
    _precarga = AppScope.leer(context).precargar();
  }

  /// Con "Comenzar": espera a que los modelos estén cargados y la voz lista y
  /// recién entonces sigue. Si la cámara ya está permitida se salta la pantalla
  /// del permiso.
  Future<void> _continuar(BuildContext context) async {
    if (_preparando) return;
    final app = context.app;
    final navegador = Navigator.of(context);
    setState(() => _preparando = true);
    // `voz.preparar()` va sin `await` antes: tiene que ocurrir dentro del toque.
    final voz = app.voz.preparar();
    await Future.wait([
      (_precarga ?? Future<void>.value()).timeout(_espera, onTimeout: () {}),
      voz,
    ]);
    final estado = await app.permisoCamara.estado();
    if (!mounted) return;
    final destino = estado == EstadoPermiso.concedido
        ? const PrincipalScreen()
        : const PermisoScreen();
    navegador.pushReplacement(rutaSuave<void>(destino));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final colores = p.oscuro
        ? const [Color(0xFF0D1A3A), Color(0xFF091226), Color(0xFF070B16)]
        : const [Color(0xFFE8EFFF), Color(0xFFF5F8FC), Color(0xFFFFFFFF)];
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colores,
            stops: const [0, .47, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Logo(),
                    const SizedBox(width: 10),
                    Text(
                      'SignCast',
                      style: TextStyle(
                        color: p.tinta,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Semantics(
                      label: 'Mano haciendo la seña de hola',
                      child: ManoLandmarks(paleta: p),
                    ),
                  ),
                ),
                Text(
                  'Tus señas,',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.tinta,
                    fontSize: 34,
                    height: 1.16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (rect) =>
                      const LinearGradient(colors: [Paleta.azul, Paleta.cian])
                          .createShader(rect),
                  child: const Text(
                    'en palabras',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 335),
                  child: Text(
                    'Traduce Lengua de Señas Mexicana a texto y voz en tiempo real.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.tenue,
                      fontSize: 16,
                      height: 1.48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  label: 'Paso 1 de 3',
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Punto(activo: true),
                      SizedBox(width: 7),
                      _Punto(),
                      SizedBox(width: 7),
                      _Punto(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_preparando)
                  SizedBox(
                    height: 56,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Paleta.azul2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Preparando…',
                          style: TextStyle(color: p.tenue, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                else
                  BotonPrimario(
                    texto: 'Comenzar',
                    icono: Icons.chevron_right,
                    onPressed: () => _continuar(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({this.activo = false});

  final bool activo;

  @override
  Widget build(BuildContext context) => Container(
    width: activo ? 22 : 6,
    height: 6,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      color: activo ? Paleta.azul : const Color(0x38FFFFFF),
      boxShadow: activo
          ? [
              BoxShadow(
                color: Paleta.azul.withValues(alpha: .45),
                blurRadius: 10,
              ),
            ]
          : null,
    ),
  );
}
