from __future__ import annotations

import argparse
import time
from pathlib import Path

import numpy as np


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--modelo", type=Path, required=True, help="Carpeta con modelo.keras")
    p.add_argument("--sin-cuantizar", action="store_true")
    a = p.parse_args()

    import keras
    import tensorflow as tf

    from . import modelos  # noqa: F401  

    modelo = keras.models.load_model(a.modelo / "modelo.keras")
    forma = (1, *modelo.input_shape[1:])   

    @tf.function(input_signature=[tf.TensorSpec(forma, tf.float32, name="entrada")])
    def inferir(x):
        return modelo(x, training=False)

    conv = tf.lite.TFLiteConverter.from_concrete_functions([inferir.get_concrete_function()], modelo)
    if not a.sin_cuantizar:
        conv.optimizations = [tf.lite.Optimize.DEFAULT]   
    contenido = conv.convert()
    destino = a.modelo / "modelo.tflite"
    destino.write_bytes(contenido)

    # Verificación y latencia
    interp = tf.lite.Interpreter(model_content=contenido)
    interp.allocate_tensors()
    ent, sal = interp.get_input_details()[0], interp.get_output_details()[0]
    x = np.random.default_rng(0).normal(0, 0.5, forma).astype(np.float32)
    interp.set_tensor(ent["index"], x)
    interp.invoke()
    diferencia = np.abs(interp.get_tensor(sal["index"]) - modelo(x, training=False).numpy()).max()

    tiempos = []
    for _ in range(100):
        t = time.perf_counter()
        interp.set_tensor(ent["index"], x)
        interp.invoke()
        tiempos.append((time.perf_counter() - t) * 1000)

    print(f"✓ {destino} ({len(contenido) / 1024:.0f} KB)")
    print(f"  entrada {ent['shape'].tolist()}  salida {sal['shape'].tolist()}")
    print(f"  diferencia máxima vs Keras: {diferencia:.4f}")
    print(f"  latencia en esta PC: {np.median(tiempos):.2f} ms (mediana de 100)")
    print("  Copia modelo.tflite y etiquetas.txt a app/assets/modelos/")


if __name__ == "__main__":
    main()
