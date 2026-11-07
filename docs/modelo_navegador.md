# Modelo de señas en el navegador

La app corre el `.tflite` con [LiteRT.js](https://ai.google.dev/edge/litert/web) (WebAssembly) y no necesita internet después de la primera carga.

## Flujo

1. `web/mediapipe/puntos.js` entrega los puntos de cada cuadro (hasta ~20 por segundo).
2. `ReconocedorModelo` los guarda en una `VentanaTemporal` y arma 30 cuadros repartidos en el último segundo (el entrenamiento es a 30 por segundo; así el ritmo de la cámara no cambia la velocidad aparente de la seña).
3. `caracteristicas.dart` los convierte al vector de 270 valores (el rostro va en ceros, igual que en el entrenamiento).
4. Cada 2 cuadros, `web/modelo/modelo.js` corre el modelo y devuelve las probabilidades.
5. `DecisorSenas` aplica la misma lógica que `ml/signcast/tiempo_real.py`: umbral 0.8, 3 predicciones iguales seguidas, sin repetir la misma glosa hasta que haya reposo u otra seña, y frase cerrada tras 1.2 s de reposo.
6. Las glosas pasan por `construirFrase` y la frase llega a `AppState` (subtítulos, historial y voz).

La inferencia es asíncrona y se salta un turno si la anterior sigue corriendo, así la interfaz no se congela.

## Deletreo (alfabeto)

Del alfabeto, el modelo de señas solo conoce las letras con movimiento (J, K, Ñ, Q, X, Z). Las 21 letras estáticas las reconoce el clasificador del alfabeto, un MLP de 63 → 256 → 128 → 21 que `clasificador_alfabeto.dart` calcula directo en Dart (unos 200 KB, sin LiteRT).

- El botón **abc** de la pantalla del traductor activa el deletreo. Las letras quietas las reconoce el clasificador del alfabeto y las que llevan movimiento (J, K, Ñ, Q, X, Z) el modelo de señas, y solo si la mano se mueve; las palabras se ignoran mientras está activo.
- Cada cuadro, la mano más grande pasa por `caracteristicasMano` y el clasificador. Una letra se acepta cuando la mano la sostiene 0.6 s (en al menos el 85 % de las lecturas de los últimos 0.7 s, cada una con probabilidad ≥ 0.8), para que las posturas intermedias al cambiar de letra no cuenten.
- Sin manos, la frase se cierra tras la pausa; al desactivar el deletreo también.

Archivos en `app/assets/modelos/` (no se suben al repo): `alfabeto.bin` y `alfabeto_etiquetas.txt`. Se generan con:

```
cd ml
python -m signcast.exportar_alfabeto --modelo ..\modelos\alfabeto_final
```

## Archivos del modelo

Después de entrenar y exportar (ver [resultados.md](resultados.md)), copiar a `app/assets/modelos/`:

- `modelo.tflite`
- `etiquetas.txt`

No se suben al repo. Este es el modelo incluido con la app: se usa si todavía no se ha descargado uno publicado y no hay internet.

## Actualizar el modelo sin reinstalar

Un modelo nuevo se publica aparte de la app, en `modelos/<version>/` (`modelo.tflite` y `etiquetas.txt`), y `modelos/version.json` (`{ "version": "v2" }`) indica cuál está vigente. Desde `app/`:

```
powershell -ExecutionPolicy Bypass -File tool\publicar_modelo.ps1 -Version v2 -Modelo ruta\modelo.tflite -Etiquetas ruta\etiquetas.txt
```

Agregar `-Produccion` para el sitio principal. Necesita un build previo (`tool\publicar_web.ps1 -SoloConstruir`); no recompila la app. Para volver a una versión anterior se publica otra vez con su número.

Al abrir la app, `web/modelo/actualizador.js`:

1. Pide `modelos/version.json` (4 s de espera máximo).
2. Si la versión es distinta de la guardada, descarga el modelo y las etiquetas, los guarda en el caché del navegador (`modelo-signcast`) y borra la versión anterior.
3. Sin internet, o si la descarga falla, usa el último modelo guardado; si no hay, el incluido.
4. Si el modelo no se puede cargar, borra lo guardado y usa el incluido.

El service worker no toca `modelos/`. La versión en uso se ve en la consola con `signcastModelo.version` (`incluido` o la versión publicada).

## LiteRT.js

`app/tool/preparar_litert_web.ps1` copia el paquete `@litertjs/core` a `app/web/litert/` (tampoco se sube). `web/modelo/modelo.js` lo importa desde ahí, con el WASM servido por el propio sitio.

## Pruebas

- `node --test test_js/*.test.mjs` (desde `app/`): carga y predicción con un LiteRT falso, y elección entre modelo publicado, guardado e incluido.
- `flutter test`: ventana temporal, decisor y reconocedor con un predictor falso.

Para ver la interfaz sin modelo: `flutter run -d chrome --dart-define=DEMO=true`.
