# Resultados

<!-- aumento-alfabeto:inicio -->
## Aumento de datos: Alfabeto

Prueba: valeria. Media ± desviación de 3 semillas.

| Copias de aumento | Exactitud | F1 macro | Cumple meta |
|---:|---:|---:|:---:|
| 0 | 0.917 ± 0.045 | 0.916 ± 0.044 | sí |
| 3 | 0.949 ± 0.022 | 0.945 ± 0.026 | sí |

Clases con más cambio de F1 entre 0 y 3 copias:

- S: 0.97 → 0.54
- C: 0.75 → 1.00
- I: 0.69 → 0.88
- T: 0.94 → 0.76
- Y: 0.71 → 0.89

Mejor: 3 copias.
<!-- aumento-alfabeto:fin -->

<!-- aumento-senas:inicio -->
## Aumento de datos: Señas (lstm)

Prueba: valeria. Media ± desviación de 3 semillas.

| Copias de aumento | Exactitud | F1 macro | Cumple meta |
|---:|---:|---:|:---:|
| 0 | 0.428 ± 0.024 | 0.384 ± 0.032 | no |
| 3 | 0.532 ± 0.017 | 0.487 ± 0.020 | no |

Clases con más cambio de F1 entre 0 y 3 copias:

- PODER: 0.28 → 0.80
- SI: 0.13 → 0.51
- Z: 0.00 → 0.35
- CLASE: 0.34 → 0.64
- NO: 0.18 → 0.41

Mejor: 3 copias.
<!-- aumento-senas:fin -->

## Clasificador del alfabeto

`python -m signcast.entrenar --tarea alfabeto --persona-prueba valeria` (3 copias de aumento, semilla 42). Prueba: valeria.

| Exactitud | F1 macro | Cumple meta |
|---:|---:|:---:|
| 0.945 | 0.943 | sí |

Letras más débiles (F1): S 0.57, T 0.78, R 0.87, I 0.88, U 0.89.

Confusiones más frecuentes (real → predicha): S → T (15), R → U (6), Y → I (5). Solo 10 de 25 ejemplos de S se clasifican bien; T se reconoce siempre, pero recibe las S.

Limitación: S y T son las más afectadas por el aumento de datos (ver la comparación de arriba), y el resultado depende de la persona de prueba.

## Señas: LSTM vs Transformer

Exactitud y F1: 3 copias de aumento, 3 semillas, sin opciones extra. El promedio es de las tres personas de prueba (`valeria`, `carlo`, `aarian`). Tamaño y latencia: `.tflite` cuantizado de los modelos finales (`--sin-prueba --reducir-columnas`), medidos con `exportar_tflite.py` en la misma PC (mediana de 100).

| Arquitectura | Exactitud (`valeria`) | F1 macro (`valeria`) | Exactitud promedio | Tamaño `.tflite` | Latencia en PC |
|---|---:|---:|---:|---:|---:|
| LSTM | 0.532 | 0.487 | 0.629 | 302 KB | 5.1 ms |
| Transformer | 0.604 | 0.563 | 0.705 | 229 KB | 2.3 ms |

Recomendación: Transformer. Es mejor en exactitud y F1, pesa menos y tarda la mitad. Con `--reducir-columnas` sube a 0.625 de exactitud y 0.600 de F1 con `valeria` (0.730 de promedio), y es el modelo que usa la app. Ninguno llega a la meta (85 % y 0.80).

## Latencia en iPhone

iPhone 14 Pro, iOS 26.6.1, Safari, modo de bajo consumo apagado y cargando. App web con el Transformer final (`senas_transformer`, 229 KB). 35 señas aisladas.

| Medida | Promedio | Máximo |
|---|---:|---:|
| Seña → subtítulo | 412 ms | 541 ms |
| Modelo (LiteRT.js, por predicción) | 2 ms | 3 ms |
| MediaPipe (por cuadro) | 31 ms | 122 ms |
| Cuadros por segundo | 20 | |

Meta de menos de 500 ms: se cumple en promedio; los casos más lentos la pasan por poco (541 ms).

Cómo se midió: con un recuadro temporal en la app (`?medir=1`, rama `medicion/29-no-mergear`, que no se mergea). "Seña → subtítulo" va desde el cuadro más reciente de la primera ventana en que el modelo ya reconoce la seña (probabilidad ≥ 0.75) hasta que la glosa aparece en pantalla, más lo que tardó MediaPipe en ese cuadro. No incluye el tiempo que tarda la seña en entrar a la ventana de 30 cuadros.

La mayor parte de la latencia viene del decisor, no del cómputo: el modelo corre cada 3 cuadros y una glosa se acepta con 3 predicciones iguales seguidas, así que después de la primera predicción correcta faltan 6 cuadros (300 ms a 20 cuadros por segundo). El modelo tarda 2 ms y MediaPipe 31 ms. Los 20 cuadros por segundo son el tope que pone la app (`INTERVALO_MIN_MS = 50` en `web/mediapipe/puntos.js`).

Si hace falta bajarla (#20): aceptar con 2 predicciones estables en lugar de 3 (unos 150 ms menos) o correr el modelo cada 2 cuadros (unos 100 ms menos). Las dos cosas pueden aumentar los falsos positivos, así que hay que revisarlas con las pruebas en aula (#30).

## Notas

- Se mantiene el espejo en el alfabeto: con espejo la exactitud es 0.949 y sin él 0.932.
- Con rotación de ±5° en lugar de ±10°, el alfabeto baja a 0.923 de exactitud, así que se deja en ±10°.
- Con aumento, S y T bajan en el alfabeto (S: 0.97 → 0.54, T: 0.94 → 0.76).
- Las señas con LSTM quedan por debajo de la meta (0.532 de exactitud y 0.487 de F1 con 3 copias).
- Con el rostro en cero, como lo recibe la app web, el LSTM da 0.521 de exactitud (sin cambio).
- El transformer mejora las señas con 3 copias: 0.604 de exactitud y 0.563 de F1 (3 semillas, prueba `valeria`), y queda como arquitectura predeterminada. Sigue por debajo de la meta.
- Transformer con 3 copias (3 semillas), según la persona de prueba: `valeria` 0.604 de exactitud y 0.563 de F1, `carlo` 0.768 y 0.713, `aarian` 0.744 y 0.669. Con una persona nueva acierta alrededor del 70 %; las señas que más fallan son K, TU, DONDE, X y J.
- Transformer con 3 copias y 3 semillas, exactitud (F1 macro) por persona de prueba `valeria` / `carlo` / `aarian`: sin opciones 0.604 (0.563) / 0.768 (0.713) / 0.744 (0.669); con `--velocidad` 0.607 (0.574) / 0.786 (0.758) / 0.724 (0.650); con `--reducir-columnas` 0.625 (0.600) / 0.779 (0.732) / 0.786 (0.728); con ambas 0.630 (0.604) / 0.818 (0.775) / 0.750 (0.675). Promedio de las tres personas: 0.705 sin opciones, 0.706 con velocidad, 0.730 con columnas reducidas y 0.733 con ambas. Se usa `--reducir-columnas`, que mejora con las tres personas.
- Probando con otra persona de prueba, el LSTM da 0.688 (`carlo`) y 0.667 (`aarian`): falla con cualquier persona nueva, no solo con `valeria`.
