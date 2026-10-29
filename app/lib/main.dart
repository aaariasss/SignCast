import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'screens/bienvenida_screen.dart';
import 'services/predictor_plataforma.dart';
import 'services/reconocedor.dart';
import 'services/reconocedor_falso.dart';
import 'services/reconocedor_modelo.dart';
import 'state/app_state.dart';
import 'theme/paleta.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final estado = await AppState.crear(reconocedor: _crearReconocedor());
  runApp(SignCastApp(estado: estado));
}

/// Frases inventadas, sin modelo: `flutter run -d chrome --dart-define=DEMO=true`.
const bool _demo = bool.fromEnvironment('DEMO');

/// El modelo real corre solo en el navegador; en las demás plataformas (y en
/// modo demo) se usan frases de prueba.
Reconocedor _crearReconocedor() => kIsWeb && !_demo
    ? ReconocedorModelo(predictor: crearPredictorPlataforma())
    : ReconocedorFalso();

class SignCastApp extends StatelessWidget {
  const SignCastApp({super.key, required this.estado});

  final AppState estado;

  @override
  Widget build(BuildContext context) => AppScope(
    estado: estado,
    // Builder: así el tema se reconstruye cuando cambian los ajustes.
    child: Builder(
      builder: (context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SignCast',
        theme: _tema(AppScope.of(context).paleta),
        home: const BienvenidaScreen(),
      ),
    ),
  );
}

ThemeData _tema(Paleta p) {
  final brillo = p.oscuro ? Brightness.dark : Brightness.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brillo,
    // Para usar Plus Jakarta Sans, ver el comentario en pubspec.yaml.
    fontFamily: 'PlusJakartaSans',
    scaffoldBackgroundColor: p.lienzo,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Paleta.azul,
      brightness: brillo,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected)
            ? Paleta.azul
            : p.tenue.withValues(alpha: .35),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
  // El color del texto se aplica sobre el textTheme que ya trae la fuente.
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.tinta, displayColor: p.tinta),
  );
}
