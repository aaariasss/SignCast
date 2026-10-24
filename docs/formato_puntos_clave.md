# Formato del vector de puntos clave

Este documento describe **exactamente** cómo se convierten los puntos de MediaPipe en el vector que consume el modelo. La app (Dart) debe producir los mismos números que Python; si no coinciden, el modelo funciona en la compu y falla en el teléfono.

Código en el que se basa este documento:

- `ml/signcast/config.py`: índices y constantes
- `ml/signcast/puntos_clave.py`: `Extractor`, `caracteristicas_secuencia`, `caracteristicas_mano`, `mano_principal`
- `ml/signcast/dataset.py`: `recortar_activo`, `remuestrear`

## 1. Resumen

| Concepto | Valor |
|---|---|
| Puntos por cuadro | 90 (21 mano izq + 21 mano der + 9 pose + 39 rostro) |
| Valores por punto | 3 (x, y, z) |
| Vector por cuadro (señas) | **270** valores (`N_CARACTERISTICAS`) |
| Vector de una mano (alfabeto estático) | **63** valores (`N_CARACTERISTICAS_MANO`) |
| Secuencia para el modelo de señas | **30 cuadros** × 270 (`LONGITUD_SECUENCIA`) |
| FPS objetivo | 30 |
| Tipo numérico | `float32` |

## 2. Qué se extrae de MediaPipe (por cuadro)

Se usan tres tareas de MediaPipe Tasks (los `.task` se descargan con `python -m signcast.descargar_modelos`):

| Tarea | Modelo | Configuración |
|---|---|---|
| Manos | `hand_landmarker.task` | `num_hands=2`, detección/presencia/seguimiento = 0.5 |
| Pose | `pose_landmarker_lite.task` | `num_poses=1`, 33 puntos |
| Rostro | `face_landmarker.task` | `num_faces=1`, se conservan los primeros 478 puntos |

- Modo video, con marcas de tiempo en milisegundos estrictamente crecientes.
- Las coordenadas son las **normalizadas** de MediaPipe: `x` y `y` en [0, 1] respecto al ancho y alto de la imagen, `z` es profundidad relativa (misma escala que `x`). No se usan píxeles.
- La imagen se convierte de BGR a RGB y se entrega **sin voltear**. El espejo (`cv2.flip`) solo se aplica a lo que se dibuja en pantalla.
- Un punto o parte del cuerpo no detectado queda como `NaN` en los datos crudos.

### Asignación de manos

Para cada mano detectada se usa la etiqueta `handedness` tal como la devuelve MediaPipe:

1. Si la etiqueta es `"Left"` y `mano_izq` está libre, va a `mano_izq`.
2. Si no, si `mano_der` está libre, va a `mano_der`.
3. Si no (las dos ocupadas), sobrescribe `mano_izq`.

## 3. Orden de los 90 puntos

El vector de un cuadro es la concatenación, en este orden, de:

| Bloque | Puntos | Índices de punto (0-89) | Columnas del vector (0-269) |
|---|---|---|---|
| Mano izquierda | 21 (índices MediaPipe 0-20, 0 = muñeca) | 0-20 | 0-62 |
| Mano derecha | 21 (0-20) | 21-41 | 63-125 |
| Pose | 9 | 42-50 | 126-152 |
| Rostro | 39 | 51-89 | 153-269 |

El punto `i` ocupa las columnas `3i`, `3i+1`, `3i+2` = `x`, `y`, `z` (el vector es el resultado de aplanar `(90, 3)` por filas).

### Pose (`INDICES_POSE`, 9 puntos)

| Punto | Índice MediaPipe pose | Parte del cuerpo |
|---|---|---|
| 42 | 0 | nariz |
| 43 | 11 | hombro izquierdo (`HOMBRO_IZQ`) |
| 44 | 12 | hombro derecho (`HOMBRO_DER`) |
| 45 | 13 | codo izquierdo |
| 46 | 14 | codo derecho |
| 47 | 15 | muñeca izquierda |
| 48 | 16 | muñeca derecha |
| 49 | 23 | cadera izquierda |
| 50 | 24 | cadera derecha |

### Rostro (`INDICES_CARA`, 39 puntos, índices del face landmarker de 478)

| Puntos | Zona | Índices MediaPipe (en este orden) |
|---|---|---|
| 51-70 | labios (20) | 61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409, 270, 269, 267, 0, 37, 39, 40, 185 |
| 71-80 | cejas (10) | 70, 63, 105, 66, 107, 336, 296, 334, 293, 300 |
| 81-88 | ojos (8) | 33, 133, 159, 145, 362, 263, 386, 374 |
| 89 | nariz (1) | 1 |

## 4. Normalización por hombros (`caracteristicas_secuencia`)

Entrada: puntos crudos de una ventana de `T` cuadros. Salida: matriz `(T, 270)`.

Para **cada cuadro** `t`:

1. `h_izq = pose[t, 11, :2]` y `h_der = pose[t, 12, :2]` (solo `x`, `y`).
2. `centro[t] = (h_izq + h_der) / 2`
3. `escala[t] = ||h_izq - h_der||` (distancia euclidiana en `x`, `y`)

Relleno de huecos (ver sección 5) sobre `centro` y `escala`, y luego:

- Si `centro` sigue con `NaN` (nunca se vieron los hombros) → `centro = (0.5, 0.5)` en todos los cuadros.
- Si `escala` es `NaN` **o menor que 0.001** → `escala = 0.3` (se aplica cuadro por cuadro).

Cada punto `(x, y, z)` de los 90 se transforma así:

```
x' = (x - centro_x) / escala
y' = (y - centro_y) / escala
z' = z / escala            # z NO se centra, solo se escala
```

Los valores que sigan en `NaN` (mano o punto no detectado) se reemplazan por **0.0** después de normalizar. Es decir, una mano ausente da 63 ceros; no se rellena con otro cuadro.

## 5. Relleno de huecos

Solo se rellenan `centro` y `escala` (los hombros). Los puntos de manos, pose y rostro **no** se rellenan: lo faltante termina en 0.0.

`_rellenar` actúa sobre el eje del tiempo y por columna (por separado `x`, `y` del centro y la escala):

1. **Hacia adelante:** para `t = 1 … T-1`, si el valor de `t` es `NaN`, copia el de `t-1`.
2. **Hacia atrás:** para `t = T-2 … 0`, si el valor de `t` es `NaN`, copia el de `t+1`.

Un hueco al inicio se llena con el primer valor válido posterior; uno en medio o al final, con el último válido anterior.

El relleno se calcula sobre la ventana que recibe la función: toda la grabación al entrenar y los últimos 30 cuadros en vivo.

## 6. Vector de una mano (`caracteristicas_mano`)

Para el clasificador del alfabeto estático. Entrada: una mano `(21, 3)`. Salida: `(63,)`.

1. Si **cualquier** valor es `NaN` → 63 ceros.
2. `rel = mano - mano[0]` (todo relativo a la muñeca, en `x`, `y` y `z`).
3. `escala = max_i sqrt(rel[i].x² + rel[i].y²)` (solo `x`, `y`).
4. Si `escala < 1e-6` → 63 ceros.
5. Resultado = `rel / escala`, aplanado por filas (`x0, y0, z0, x1, y1, z1, …`). Los primeros tres valores siempre son 0 (la muñeca).

### Qué mano se usa (`mano_principal`)

De las dos manos del cuadro se descartan las que están completamente en `NaN`. De las restantes se elige la de **mayor área de caja**: `ptp(x) * ptp(y)`. Si no hay ninguna, devuelve una mano toda en `NaN` (y `caracteristicas_mano` da ceros).

Para el dataset público (CICESE) la conversión usa imágenes en modo imagen, una sola mano, sin pose ni rostro.

## 7. De cuadros a secuencia de 30

**Entrenamiento** (`cargar_senas`), por cada grabación de una seña aislada:

1. `caracteristicas_secuencia` sobre **toda** la grabación → `(T, 270)`.
2. `recortar_activo` (salvo `_REPOSO`): quita al inicio y al final los cuadros sin manos (suma de los primeros 126 valores = 0), dejando un margen de 3 cuadros.
3. `remuestrear` a 30 cuadros con interpolación lineal en el tiempo: `origen = linspace(0, T-1, 30)`, entre los cuadros vecinos.

**En vivo** (`tiempo_real.py`): se guardan los últimos 30 cuadros crudos, se calcula `caracteristicas_secuencia` sobre esa ventana y se infiere cada 3 cuadros.

## 8. Formato de las grabaciones (`.npz`)

`grabar.py` guarda un `.npz` comprimido en `data/raw/<fuente>/<persona>/<GLOSA>/<fecha>.npz`:

| Clave | Forma | Notas |
|---|---|---|
| `mano_izq` | `(T, 21, 3)` | `float16`, `NaN` si no se detectó |
| `mano_der` | `(T, 21, 3)` | igual |
| `pose` | `(T, 33, 3)` | los 33 puntos; el vector solo usa 9 |
| `cara` | `(T, 478, 3)` | los 478 puntos; el vector solo usa 39 |
| `glosas` | lista de texto | una = seña aislada; varias = frase |
| `persona`, `fuente` | texto | |
| `fps` | número | fps real de la grabación |

Al cargar, se convierte a `float32` (`muestras.cargar`). Los puntos crudos se guardan en `float16`, por lo que las coordenadas ya vienen redondeadas.

## 9. Notas para la app (#23 y #25)

1. **Relación de aspecto.** `x` está normalizada por el ancho y `y` por el alto. Si la app procesa una imagen vertical (p. ej. 3:4 o 9:16) y el entrenamiento se hizo con webcam horizontal (4:3 o 16:9), la proporción entre `x` y `y` del vector cambia y puede degradar el modelo. Hay que definir qué resolución y orientación se usó al grabar y hacer que la app entregue una imagen equivalente (o corregir por la relación de aspecto). Hoy el `.npz` no guarda la resolución.
2. **Sin espejo y etiqueta de mano.** Python entrega a MediaPipe la imagen sin voltear y usa la etiqueta `Left`/`Right` tal cual. La app debe seguir la misma convención. Para comprobarlo: en la compu, grabar moviendo solo la mano derecha y revisar cuál arreglo se llena (`mano_izq` o `mano_der`); la app debe llenar el mismo.
3. **Ventana de 30 cuadros distinta en entrenamiento y en vivo.** Al entrenar, una seña de ~1.5 s se recorta y se estira/comprime a 30 cuadros; en vivo son 30 cuadros reales (~1 s a 30 fps) sin recortar. Su efecto se evalúa en #16 y #25.
4. **Ceros como "ausente".** El modelo ve 0.0 cuando falta una mano; la app no debe usar otro valor ni repetir el último cuadro en manos o rostro.

## 10. Cómo comprobar que Dart coincide con Python

Generar un vector de referencia a partir de una grabación real, desde `ml/`:

```python
import numpy as np
from signcast.muestras import cargar
from signcast.puntos_clave import caracteristicas_secuencia, caracteristicas_mano, mano_principal, Cuadro

m = cargar("RUTA/A/GRABACION.npz")           # raw ya en float32 (venía en float16)
x = caracteristicas_secuencia(m.raw)         # (T, 270): referencia para la secuencia
mano = m.raw["mano_izq"][0]                  # (21, 3)
v = caracteristicas_mano(mano)               # (63,): referencia para la mano
np.savetxt("ref_secuencia.csv", x, delimiter=",")
np.savetxt("ref_mano.csv", v, delimiter=",")
```

En el test de Dart:

- Usar como entrada los **mismos puntos crudos** del `.npz` (ya redondeados a `float16`) y comparar con `ref_*.csv`.
- Tolerancia: `1e-4` en `float32`.
- Casos mínimos: grabación con ambas manos, con una mano, sin manos, y con hombros ausentes en algunos cuadros (para probar el relleno y los valores por defecto 0.5 y 0.3).
