# SignCast — app móvil (Flutter)

Traduce Lengua de Señas Mexicana a texto y voz, sin internet.

## Correr la app

```bash
cd app
flutter pub get
flutter run          # con un teléfono conectado o un emulador
flutter test         # pruebas
```

## Estructura de `lib/`

| Carpeta | Qué hay |
|---|---|
| `theme/` | `paleta.dart`: colores del diseño de Figma (oscuro y claro) |
| `models/` | `Ajustes`, `EstadoDeteccion`, `FraseHistorial` |
| `services/` | `frases.dart` (constructor de frases), `reconocedor.dart` (interfaz) y `reconocedor_falso.dart`, `voz.dart` (interfaz del TTS) |
| `state/` | `app_state.dart`: ajustes guardados, historial y reconocimiento; `AppScope` lo reparte a los widgets |
| `widgets/` | Piezas reutilizables: hoja de subtítulos, píldora de estado, barra inferior, etc. |
| `screens/` | Bienvenida, permiso, principal (3 pestañas), traductor, historial, ajustes, mostrar |

## Piezas que otros issues conectan

- **#25 (modelo TFLite):** crear una clase que implemente `Reconocedor` y pasarla
  en `AppState.crear(reconocedor: ...)` en `main.dart`. Las pantallas no cambian.
- **#26 (voz):** crear una clase que implemente `Voz` con `flutter_tts` y pasarla
  en `AppState.crear(voz: ...)`.

## Tipografía

El diseño usa Plus Jakarta Sans. Para incluirla sin depender de internet, ver el
comentario `fonts:` en `pubspec.yaml`.


