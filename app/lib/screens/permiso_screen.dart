import 'package:flutter/material.dart';

import '../services/permiso_camara.dart';
import '../state/app_state.dart';
import '../theme/paleta.dart';
import '../widgets/boton_primario.dart';
import '../widgets/esquinas.dart';
import '../widgets/logo.dart';
import '../widgets/vidrio.dart';
import 'principal_screen.dart';

/// Explica por qué se necesita la cámara y pide el permiso. No avanza hasta que
/// el usuario lo concede; si lo bloqueó, lo manda a los ajustes del sistema.
class PermisoScreen extends StatefulWidget {
  const PermisoScreen({super.key});

  @override
  State<PermisoScreen> createState() => _PermisoScreenState();
}

class _PermisoScreenState extends State<PermisoScreen>
    with WidgetsBindingObserver {
  EstadoPermiso _estado = EstadoPermiso.denegado;
  bool _intentado = false;
  bool _ocupado = false;
  bool _entro = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de los ajustes del sistema se revisa si ya lo permitió.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed && _intentado) _revisar();
  }

  Future<void> _revisar() async {
    final estado = await context.app.permisoCamara.estado();
    if (!mounted) return;
    estado == EstadoPermiso.concedido
        ? _entrar()
        : setState(() => _estado = estado);
  }

  Future<void> _pedir() async {
    if (_ocupado) return;
    final permiso = context.app.permisoCamara;
    setState(() => _ocupado = true);
    if (_estado == EstadoPermiso.denegadoPermanente) {
      await permiso.abrirAjustes();
      if (mounted) setState(() => _ocupado = false);
      return;
    }
    final resultado = await permiso.solicitar();
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _intentado = true;
      _estado = resultado;
    });
    if (resultado == EstadoPermiso.concedido) _entrar();
  }

  /// Solo entra una vez: al aceptar el permiso pueden dispararse a la vez el
  /// resultado del diálogo y el aviso de "volví a la app", y sin este seguro
  /// se abrirían dos pantallas principales (dos cámaras y un reconocedor que
  /// se detiene al cerrar la primera).
  void _entrar() {
    if (_entro) return;
    _entro = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const PrincipalScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Scaffold(
      body: DecoratedBox(
        decoration: p.fondo,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    const Logo(),
                    const SizedBox(width: 10),
                    Text(
                      'SignCast',
                      style: TextStyle(
                        color: p.tinta,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 12),
                  child: Column(
                    children: [
                      const _IlustracionCamara(),
                      const SizedBox(height: 24),
                      const Text(
                        'UN PASO MÁS',
                        style: TextStyle(
                          color: Paleta.azul2,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.9,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Activa tu cámara',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.tinta,
                          fontSize: 36,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 315),
                        child: Text(
                          'SignCast necesita ver tus señas para traducirlas mientras conversas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: p.tenue,
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Vidrio(
                        radio: 22,
                        padding: const EdgeInsets.all(17),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 22,
                              color: Paleta.azul2,
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tu privacidad está protegida',
                                    style: TextStyle(
                                      color: p.tinta,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'El video se procesa en tu dispositivo y nunca sale de tu teléfono.',
                                    style: TextStyle(
                                      color: p.tenue,
                                      fontSize: 11,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_intentado)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          _estado == EstadoPermiso.denegadoPermanente
                              ? 'La cámara está bloqueada. Actívala en los ajustes de la app para continuar.'
                              : 'Sin la cámara no podemos traducir tus señas. Permítela para continuar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: p.tenue,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    BotonPrimario(
                      texto: _estado == EstadoPermiso.denegadoPermanente
                          ? 'Abrir ajustes'
                          : 'Permitir cámara',
                      onPressed: _pedir,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IlustracionCamara extends StatelessWidget {
  const _IlustracionCamara();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 190,
        child: Center(
          child: SizedBox(
            width: 174,
            height: 144,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Vidrio(
                    radio: 28,
                    desenfoque: 22,
                    child: const Center(
                      child: Icon(
                        Icons.photo_camera_outlined,
                        size: 42,
                        color: Paleta.azul2,
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Esquinas(color: Paleta.azul2, largo: 24, radio: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
