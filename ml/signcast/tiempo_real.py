from __future__ import annotations

import argparse
import time
from collections import Counter, deque
from pathlib import Path

import cv2
import numpy as np

from . import config as C
from .dataset import quitar_rostro
from .decisor import Decisor
from .frases import construir_frase
from .grabar import dibujar, texto
from .puntos_clave import Extractor, apilar, caracteristicas_mano, caracteristicas_secuencia, mano_principal


class ModeloTFLite:
    def __init__(self, carpeta: Path):
        import tensorflow as tf

        self.interp = tf.lite.Interpreter(model_path=str(carpeta / "modelo.tflite"))
        self.interp.allocate_tensors()
        self.ent = self.interp.get_input_details()[0]
        self.sal = self.interp.get_output_details()[0]
        self.etiquetas = (carpeta / "etiquetas.txt").read_text(encoding="utf-8").split()

    def __call__(self, x: np.ndarray) -> tuple[str, float, float]:
        t = time.perf_counter()
        self.interp.set_tensor(self.ent["index"], x[None].astype(np.float32))
        self.interp.invoke()
        p = self.interp.get_tensor(self.sal["index"])[0]
        i = int(p.argmax())
        return self.etiquetas[i], float(p[i]), (time.perf_counter() - t) * 1000


def main():
    a = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("--modelo", type=Path, required=True)
    a.add_argument("--alfabeto", type=Path)
    a.add_argument("--umbral", type=float, default=0.8)
    a.add_argument("--cada", type=int, default=2, help="Inferir cada N cuadros")
    a.add_argument("--estables", type=int, default=3, help="Predicciones iguales seguidas para aceptar")
    a.add_argument("--pausa-frase", type=float, default=1.2, help="Segundos de reposo que cierran la frase")
    a.add_argument("--camara", type=int, default=0)
    a = a.parse_args()

    senas = ModeloTFLite(a.modelo)
    alfabeto = ModeloTFLite(a.alfabeto) if a.alfabeto else None

    cap = cv2.VideoCapture(a.camara)
    cap.set(cv2.CAP_PROP_FPS, C.FPS_OBJETIVO)
    ventana: deque = deque(maxlen=C.LONGITUD_SECUENCIA)
    decisor = Decisor(a.umbral, a.estables, a.pausa_frase)
    letras: deque = deque(maxlen=12)
    subtitulo = ""
    deletreo, n, lat = False, 0, 0.0
    t0 = time.monotonic()

    with Extractor(modo="video") as ext:
        while True:
            ok, img = cap.read()
            if not ok:
                break
            ahora = time.monotonic()
            cuadro = ext.procesar(img, int((ahora - t0) * 1000))
            ventana.append(cuadro)
            n += 1

            if deletreo and alfabeto:
                mano = mano_principal(cuadro)
                if not np.isnan(mano).all():
                    letra, prob, lat = alfabeto(caracteristicas_mano(mano))
                    letras.append(letra if prob >= a.umbral else None)
                    comun, veces = Counter(letras).most_common(1)[0]
                    if comun and veces >= 10 and comun != decisor.ultima_glosa:
                        decisor.glosas.append(comun)
                        decisor.ultima_glosa = comun
                        letras.clear()
            elif len(ventana) == C.LONGITUD_SECUENCIA and n % a.cada == 0:
                x = quitar_rostro(caracteristicas_secuencia(apilar(list(ventana))))
                glosa, prob, lat = senas(x)
                decisor.predecir(glosa, prob, ahora)

            # Cerrar la frase tras una pausa
            cerrada = decisor.cerrar_si_pausa(ahora)
            if cerrada:
                subtitulo = construir_frase(cerrada)
                print(f"{' '.join(cerrada):40s} -> {subtitulo}")

            vista = img.copy()
            dibujar(vista, cuadro)
            vista = cv2.flip(vista, 1)
            h = vista.shape[0]
            texto(vista, ("DELETREO  " if deletreo else "") + " ".join(decisor.glosas), 40, (0, 255, 255))
            texto(vista, f"{lat:.1f} ms", 75, escala=0.6)
            texto(vista, subtitulo, h - 30, escala=1.0)
            cv2.imshow("SignCast", vista)

            tecla = cv2.waitKey(1) & 0xFF
            if tecla == ord("q"):
                break
            if tecla == ord("c"):
                decisor.glosas, subtitulo = [], ""
            if tecla == ord("a") and alfabeto:
                deletreo = not deletreo
                letras.clear()
                if not deletreo:
                    decisor.inicio_reposo = ahora

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
