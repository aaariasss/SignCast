from __future__ import annotations

import argparse
import time

import cv2
import numpy as np

from . import config as C
from .muestras import etiquetas, guardar
from .puntos_clave import Cuadro, Extractor, apilar

SEGUNDOS_SENA = 1.5
SEGUNDOS_FRASE = 5.0
CUENTA_REGRESIVA = 2.0


def dibujar(img: np.ndarray, cuadro: Cuadro):
    h, w = img.shape[:2]
    for puntos, color in ((cuadro.mano_izq, (0, 200, 255)), (cuadro.mano_der, (255, 120, 0))):
        for x, y, _ in puntos:
            if not np.isnan(x):
                cv2.circle(img, (int(x * w), int(y * h)), 3, color, -1)
    for i in C.INDICES_POSE:
        x, y, _ = cuadro.pose[i]
        if not np.isnan(x):
            cv2.circle(img, (int(x * w), int(y * h)), 4, (0, 255, 0), -1)


def texto(img, msg, y=40, color=(255, 255, 255), escala=0.9):
    cv2.putText(img, msg, (20, y), cv2.FONT_HERSHEY_SIMPLEX, escala, (0, 0, 0), 4, cv2.LINE_AA)
    cv2.putText(img, msg, (20, y), cv2.FONT_HERSHEY_SIMPLEX, escala, color, 2, cv2.LINE_AA)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--persona", required=True)
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--glosa", help="Seña aislada, p. ej. HOLA")
    g.add_argument("--frase", help='Frase en glosas, p. ej. "YO NO ENTENDER"')
    p.add_argument("--repeticiones", type=int, default=20)
    p.add_argument("--camara", type=int, default=0)
    p.add_argument("--fuente", default="equipo")
    a = p.parse_args()

    glosas = [a.glosa] if a.glosa else a.frase.upper().split()
    validas = set(etiquetas("senas")) | set(etiquetas("alfabeto"))
    desconocidas = [x for x in glosas if x not in validas]
    if desconocidas:
        raise SystemExit(f"Glosas fuera de vocabulario.csv: {desconocidas}. Agrégalas primero.")

    persona = a.persona.lower()
    duracion = SEGUNDOS_FRASE if len(glosas) > 1 else SEGUNDOS_SENA
    cap = cv2.VideoCapture(a.camara)
    cap.set(cv2.CAP_PROP_FPS, C.FPS_OBJETIVO)
    if not cap.isOpened():
        raise SystemExit("No se pudo abrir la cámara.")

    estado, inicio, buffer, hechas = "espera", 0.0, [], 0
    sin_mano = 0
    t0 = time.monotonic()

    with Extractor(modo="video") as ext:
        while hechas < a.repeticiones:
            ok, img = cap.read()
            if not ok:
                break
            ahora = time.monotonic()
            cuadro = ext.procesar(img, int((ahora - t0) * 1000))

            vista = img.copy()
            dibujar(vista, cuadro)
            vista = cv2.flip(vista, 1)  
            etiqueta = " ".join(glosas)

            if estado == "espera":
                texto(vista, f"{etiqueta}  [{hechas}/{a.repeticiones}]")
                texto(vista, "ESPACIO: grabar   Q: salir", 80, escala=0.7)
                if np.isnan(cuadro.pose[C.HOMBRO_IZQ]).any():
                    texto(vista, "No se ven los hombros: alejate de la camara", 120, (0, 0, 255), 0.7)
            elif estado == "cuenta":
                faltan = CUENTA_REGRESIVA - (ahora - inicio)
                texto(vista, f"Preparate... {faltan:.1f}", color=(0, 255, 255))
                if faltan <= 0:
                    estado, inicio, buffer, sin_mano = "grabando", ahora, [], 0
            elif estado == "grabando":
                buffer.append(cuadro)
                sin_mano += 0 if cuadro.hay_mano else 1
                texto(vista, f"GRABANDO {etiqueta}", color=(0, 0, 255))
                if ahora - inicio >= duracion:
                    fps = len(buffer) / max(ahora - inicio, 1e-6)
                    if glosas != [C.CLASE_REPOSO] and sin_mano > 0.5 * len(buffer):
                        print("✗ Descartada: no se detectaron manos en la mayoría de los cuadros")
                    else:
                        ruta = guardar(apilar(buffer), a.fuente, persona, glosas, fps=fps)
                        hechas += 1
                        print(f"✓ {hechas}/{a.repeticiones}  {len(buffer)} cuadros @ {fps:.0f} fps -> {ruta.name}")
                    estado = "espera"

            cv2.imshow("SignCast - grabacion", vista)
            tecla = cv2.waitKey(1) & 0xFF
            if tecla == ord("q"):
                break
            if tecla == ord(" ") and estado == "espera":
                estado, inicio = "cuenta", ahora

    cap.release()
    cv2.destroyAllWindows()
    print(f"Listo: {hechas} repeticiones de {' '.join(glosas)} para {persona}.")


if __name__ == "__main__":
    main()
