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

Cómo se midió: con un recuadro temporal en la app (`?medir=1`), que no está en la versión publicada. "Seña → subtítulo" va desde el cuadro más reciente de la primera ventana en que el modelo ya reconoce la seña (probabilidad ≥ 0.75) hasta que la glosa aparece en pantalla, más lo que tardó MediaPipe en ese cuadro. No incluye el tiempo que tarda la seña en entrar a la ventana de 30 cuadros.

La mayor parte de la latencia viene del decisor, no del cómputo: el modelo corre cada 3 cuadros y una glosa se acepta con 3 predicciones iguales seguidas, así que después de la primera predicción correcta faltan 6 cuadros (300 ms a 20 cuadros por segundo). El modelo tarda 2 ms y MediaPipe 31 ms. Los 20 cuadros por segundo son el tope que pone la app (`INTERVALO_MIN_MS = 50` en `web/mediapipe/puntos.js`).

La medición es con umbral 0.75 y el modelo cada 3 cuadros. La app ahora corre el modelo cada 2 cuadros (umbral 0.8, ver Frases continuas), con lo que la espera baja unos 100 ms; no se volvió a medir en iPhone.

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

<!-- frases-continuas:inicio -->
## Frases continuas

Frases correctas: **23.6%** (86 de 364 tomas) con `--umbral 0.8 --cada 2 --estables 3 --pausa-frase 0.8`. Meta: 80 %.

Cada persona se evalúa con un modelo que no la vio entrenar. Se compara con `construir_frase` sobre las glosas grabadas.

| Persona | Correctas |
|---|---:|
| aarian | 10/120 (8%) |
| carlo | 46/124 (37%) |
| valeria | 30/120 (25%) |

Glosas reconocidas en orden: 54.9% (590 de 1074).

| Frase | Correctas | Glosas reconocidas | Glosas detectadas más común al fallar |
|---|---:|---:|---|
| AYUDAR YO POR-FAVOR | 0/30 | 58% | AYUDAR POR-FAVOR |
| BANO DONDE | 13/30 | 70% | BANO |
| ENTENDER NO | 0/30 | 48% | ENTENDER |
| HOLA HOLA _REPOSO YO NO ENTENDER GRACIAS | 2/34 | 40% | HOLA ENTENDER |
| MAESTRO REPETIR | 22/30 | 93% | MAESTRO K |
| MANANA EXAMEN | 16/30 | 82% | ADIOS EXAMEN |
| MANANA YO IR CLASE | 1/30 | 38% | ADIOS CLASE |
| REPETIR POR-FAVOR | 11/30 | 77% | REPETIR |
| TAREA CUANDO | 11/30 | 77% | TAREA MANANA |
| YO NO ENTENDER | 0/30 | 47% | ENTENDER |
| YO PODER IR BANO | 0/30 | 52% | YO PODER BANO |
| YO TENER PREGUNTA | 10/30 | 42% | (nada) |

Con los valores anteriores (`--umbral 0.75 --cada 3 --estables 3 --pausa-frase 1.2`): 20.9% (76 de 364).

Valores recomendados: umbral 0.8, el modelo cada 2 cuadros, 3 predicciones estables y pausa de 1.2 s (entre 0.8 y 1.5 s da el mismo resultado). `tiempo_real.py` y la app usan estos valores.

Mejores combinaciones de la búsqueda:

| Umbral | Cada | Estables | Pausa (s) | Correctas | % |
|---:|---:|---:|---:|---:|---:|
| 0.8 | 2 | 3 | 0.8 | 86/364 | 23.6% |
| 0.8 | 2 | 3 | 1.0 | 86/364 | 23.6% |
| 0.8 | 2 | 3 | 1.2 | 86/364 | 23.6% |
| 0.8 | 2 | 3 | 1.5 | 86/364 | 23.6% |
| 0.8 | 2 | 3 | 0.6 | 85/364 | 23.4% |
| 0.85 | 2 | 3 | 0.8 | 85/364 | 23.4% |
| 0.85 | 2 | 3 | 1.0 | 85/364 | 23.4% |
| 0.85 | 2 | 3 | 1.2 | 85/364 | 23.4% |

Omitidas por llevar deletreo (en vivo se activa con `a`): HOLA YO A N A.
<!-- frases-continuas:fin -->

<!-- prueba-aula:inicio -->
## Evaluación en aula

Prueba del 7 de noviembre de 2026 con la app web en un iPhone 14 Pro, hecha por una persona externa al equipo. Se cuenta el acierto al primer intento, en señas y en frases.

| Métrica | Resultado | Meta | Cumple |
|---|---:|---:|:---:|
| Exactitud en señas aisladas (letras y palabras) | 81.5 % (44/54) | ≥ 85 % | no |
| Letras | 88.9 % (24/27) | ≥ 85 % | sí |
| Palabras | 74.1 % (20/27) | ≥ 85 % | no |
| F1 promedio por clase (letras) | ≈ 0.90 | ≥ 0.80 | sí |
| Frases correctas | 92.3 % (12/13) | ≥ 80 % | sí |

Letras con más de un intento: J (14), K (4) y X (2). Palabras con más de un intento: EXAMEN (7), QUE (4), REPETIR (3), y AYUDAR, PODER, BANO y CUANDO (2 cada una).

El F1 es una estimación solo de las letras, hecha con las confusiones observadas (J → X, K → Z, X → Q). No se midió el F1 de las palabras.

Las letras que más fallaron (J, K y X) son las mismas que más fallan en la evaluación del modelo (ver Notas).

Las frases en aula (92.3 %) no se comparan directamente con Frases continuas (23.6 %). Esa medición es más estricta: usa videos grabados de corrido, sin ver el subtítulo, y cada persona se prueba con un modelo que no la vio entrenar. En el aula se usa el modelo final, la persona ve el resultado en vivo y son 13 frases de una sola persona.
<!-- prueba-aula:fin -->
