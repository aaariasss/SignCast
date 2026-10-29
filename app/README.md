# SignCast — app web (PWA)

Traduce Lengua de Señas Mexicana a texto y voz, sin internet.

## Correr la app

```bash
cd app
powershell -ExecutionPolicy Bypass -File tool\preparar_mediapipe_web.ps1   # solo la primera vez (MediaPipe no está en el repo)
powershell -ExecutionPolicy Bypass -File tool\preparar_litert_web.ps1      # solo la primera vez (LiteRT)
flutter pub get
flutter run -d chrome   # desarrollo
flutter test            # pruebas
```

Para ver los FPS de la detección: `flutter run -d chrome --dart-define=PUNTOS=true`.

Sin modelo, o para probar la interfaz con frases inventadas: `flutter run -d chrome --dart-define=DEMO=true`. El modelo real necesita `modelo.tflite` y `etiquetas.txt` en `assets/modelos/` ([detalles](../docs/modelo_navegador.md)). Las pruebas del motor JS: `node --test test_js/modelo.test.mjs`.

## Publicar

`powershell -ExecutionPolicy Bypass -File tool\publicar_web.ps1`. Detalles en [../docs/publicar_web.md](../docs/publicar_web.md).

## Estructura de `lib/`

| Carpeta | Qué hay |
|---|---|
| `theme/` | `paleta.dart`: colores del diseño de Figma (oscuro y claro) |
| `models/` | `Ajustes`, `EstadoDeteccion`, `FraseHistorial` |
| `services/` | `frases.dart` (constructor de frases), `detector_puntos.dart` y `detector_plataforma_web.dart` (MediaPipe web), `permiso_camara*.dart`, `reconocedor.dart`, `reconocedor_modelo.dart` (modelo real), `reconocedor_falso.dart`, `decisor_senas.dart`, `ventana_temporal.dart`, `predictor_*.dart` y `modelo_js.dart` (LiteRT.js), `voz.dart` y `voz_navegador.dart` (síntesis de voz del navegador) |
| `state/` | `app_state.dart`: ajustes guardados, historial y reconocimiento; `AppScope` lo reparte a los widgets |
| `widgets/` | Piezas reutilizables: hoja de subtítulos, píldora de estado, barra inferior, etc. |
| `screens/` | Bienvenida, permiso, principal (3 pestañas), traductor, historial, ajustes, mostrar |

Fuera de `lib/`: `web/` (página, manifest, `sw.js`, `mediapipe/` y `modelo/`) y `tool/` (scripts de MediaPipe, LiteRT y de publicación).


## Tipografía

El diseño usa Plus Jakarta Sans. Para incluirla sin depender de internet, ver el comentario `fonts:` en `pubspec.yaml`.
