"""Exporta el clasificador del alfabeto para la app web.

La app calcula el MLP directo en Dart (no usa `.tflite`), así que solo necesita
los pesos y las etiquetas:

    python -m signcast.exportar_alfabeto --modelo ..\\modelos\\alfabeto_final

Escribe en `app/assets/modelos/`:
- `alfabeto.bin`: float32 little-endian; por capa, primero la matriz
  `(entradas, salidas)` por filas y luego el sesgo.
- `alfabeto_etiquetas.txt`: las letras en el orden de la salida.
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np

from . import config as C

DESTINO = C.RAIZ_REPO / "app" / "assets" / "modelos"


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--modelo", type=Path, required=True, help="Carpeta con modelo.keras y etiquetas.txt")
    p.add_argument("--destino", type=Path, default=DESTINO)
    a = p.parse_args()

    import keras

    from . import modelos  # noqa: F401

    modelo = keras.models.load_model(a.modelo / "modelo.keras")
    pesos = modelo.get_weights()  # kernel1, sesgo1, kernel2, sesgo2, ...
    datos = np.concatenate([w.astype("<f4").ravel() for w in pesos])

    a.destino.mkdir(parents=True, exist_ok=True)
    (a.destino / "alfabeto.bin").write_bytes(datos.tobytes())
    shutil.copy(a.modelo / "etiquetas.txt", a.destino / "alfabeto_etiquetas.txt")

    # Verificación: el mismo cálculo que hace la app, contra Keras.
    x = np.random.default_rng(0).normal(0, 0.5, (8, pesos[0].shape[0])).astype(np.float32)
    h = x
    for k in range(0, len(pesos), 2):
        h = h @ pesos[k] + pesos[k + 1]
        if k < len(pesos) - 2:
            h = np.maximum(h, 0)
    h = np.exp(h - h.max(axis=1, keepdims=True))
    h /= h.sum(axis=1, keepdims=True)
    diferencia = np.abs(h - modelo(x, training=False).numpy()).max()
    print(f"✓ {a.destino / 'alfabeto.bin'} ({datos.nbytes / 1024:.0f} KB, {len(datos)} pesos)")
    print(f"  diferencia máxima vs Keras: {diferencia:.6f}")


if __name__ == "__main__":
    main()
