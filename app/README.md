# SignCast — app web (PWA)

Traduce Lengua de Señas Mexicana a texto y voz, sin internet.

## Correr la app

```bash
cd app
powershell -ExecutionPolicy Bypass -File tool\preparar_mediapipe_web.ps1   # solo la primera vez (MediaPipe no está en el repo)
flutter pub get
flutter run -d chrome   # desarrollo
flutter test            # pruebas
```

Para ver los FPS de la detección: `flutter run -d chrome --dart-define=PUNTOS=true`.

## Publicar

`powershell -ExecutionPolicy Bypass -File tool\publicar_web.ps1`. Detalles en [../docs/publicar_web.md](../docs/publicar_web.md).

## Estructura de `lib/`

| Carpeta | Qué hay |
|---|---|
| `theme/` | `paleta.dart`: colores del diseño de Figma (oscuro y claro) |
| `models/` | `Ajustes`, `EstadoDeteccion`, `FraseHistorial` |
| `services/` | `frases.dart` (constructor de frases), `detector_puntos.dart` y `detector_plataforma_web.dart` (MediaPipe web), `permiso_camara*.dart`, `reconocedor.dart` y `reconocedor_falso.dart`, `voz.dart` |
| `state/` | `app_state.dart`: ajustes guardados, historial y reconocimiento; `AppScope` lo reparte a los widgets |
| `widgets/` | Piezas reutilizables: hoja de subtítulos, píldora de estado, barra inferior, etc. |
| `screens/` | Bienvenida, permiso, principal (3 pestañas), traductor, historial, ajustes, mostrar |

Fuera de `lib/`: `web/` (página, manifest, `sw.js` y `mediapipe/`) y `tool/` (scripts de MediaPipe y de publicación).

## Piezas por conectar

- **Modelo en el navegador:** crear una clase que implemente `Reconocedor` y pasarla en `AppState.crear(reconocedor: ...)` en `main.dart`. Las pantallas no cambian.
- **Voz:** crear una clase que implemente `Voz` con la síntesis de voz del navegador y pasarla en `AppState.crear(voz: ...)`.

## Tipografía

El diseño usa Plus Jakarta Sans. Para incluirla sin depender de internet, ver el comentario `fonts:` en `pubspec.yaml`.
