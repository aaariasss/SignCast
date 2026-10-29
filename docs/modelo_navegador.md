# Modelo de señas en el navegador

La app corre el `.tflite` con [LiteRT.js](https://ai.google.dev/edge/litert/web) (WebAssembly) y no necesita internet después de la primera carga.

## Flujo

1. `web/mediapipe/puntos.js` entrega los puntos de cada cuadro (hasta ~20 por segundo).
2. `ReconocedorModelo` los guarda en una `VentanaTemporal` y arma 30 cuadros repartidos en el último segundo (el entrenamiento es a 30 por segundo; así el ritmo de la cámara no cambia la velocidad aparente de la seña).
3. `caracteristicas.dart` los convierte al vector de 270 valores (el rostro va en ceros, igual que en el entrenamiento).
4. Cada 3 cuadros, `web/modelo/modelo.js` corre el modelo y devuelve las probabilidades.
5. `DecisorSenas` aplica la misma lógica que `ml/signcast/tiempo_real.py`: umbral 0.75, 3 predicciones iguales seguidas, sin repetir la misma glosa hasta que haya reposo u otra seña, y frase cerrada tras 1.2 s de reposo.
6. Las glosas pasan por `construirFrase` y la frase llega a `AppState` (subtítulos, historial y voz).

La inferencia es asíncrona y se salta un turno si la anterior sigue corriendo, así la interfaz no se congela.

## Archivos del modelo

Después de entrenar y exportar (ver [resultados.md](resultados.md)), copiar a `app/assets/modelos/`:

- `modelo.tflite`
- `etiquetas.txt`

No se suben al repo. Si cambia el modelo, el service worker lo actualiza en la siguiente publicación.

## LiteRT.js

`app/tool/preparar_litert_web.ps1` copia el paquete `@litertjs/core` a `app/web/litert/` (tampoco se sube). `web/modelo/modelo.js` lo importa desde ahí, con el WASM servido por el propio sitio.

## Pruebas

- `node --test test_js/modelo.test.mjs` (desde `app/`): carga y predicción con un LiteRT falso.
- `flutter test`: ventana temporal, decisor y reconocedor con un predictor falso.

Para ver la interfaz sin modelo: `flutter run -d chrome --dart-define=DEMO=true`.
