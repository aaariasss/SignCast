from __future__ import annotations

import argparse
import random
import re
import unicodedata
from collections import defaultdict
from pathlib import Path

import numpy as np

from . import config as C
from .muestras import etiquetas, guardar
from .puntos_clave import Extractor, apilar, caracteristicas_mano

PATRON_VIDEO = re.compile(r"S(\d+)-(.+?)-(frontal|profile)[-.](\d+)", re.IGNORECASE)
PATRON_PERSONA = re.compile(r"(?:^|[^A-Za-z])S(\d{1,3})(?:[^0-9]|$)")
EXT_IMAGEN = {".jpg", ".jpeg", ".png"}


def normalizar_letra(nombre: str) -> str:
    n = unicodedata.normalize("NFC", nombre).upper()
    return {"NN": "Ñ", "N~": "Ñ", "NI": "Ñ", "ENIE": "Ñ", "ENE": "Ñ"}.get(n, n)


def dinamicas(origen: Path, vista: str, limite: int | None):
    import cv2

    validas = set(etiquetas("senas"))
    videos = sorted(origen.rglob("*.mp4"))
    print(f"{len(videos)} videos encontrados")
    hechos = 0
    for ruta in videos:
        m = PATRON_VIDEO.search(ruta.stem)
        if not m or m.group(3).lower() != vista:
            continue
        sujeto, letra, _, rep = m.groups()
        letra = normalizar_letra(letra)
        if letra not in validas:
            print(f"  ? letra no reconocida en {ruta.name} ({letra}), se omite")
            continue
        persona = f"pub_s{int(sujeto):02d}"
        cap = cv2.VideoCapture(str(ruta))
        fps = cap.get(cv2.CAP_PROP_FPS) or 30
        cuadros = []
        with Extractor(modo="video") as ext:
            i = 0
            while True:
                ok, img = cap.read()
                if not ok:
                    break
                cuadros.append(ext.procesar(img, int(i * 1000 / fps)))
                i += 1
        cap.release()
        if not cuadros:
            continue
        guardar(apilar(cuadros), "publico", persona, [letra], fps=fps, nombre=f"{vista}-{rep}")
        hechos += 1
        print(f"  ✓ {ruta.name}: {len(cuadros)} cuadros")
        if limite and hechos >= limite:
            break
    print(f"Listo: {hechos} videos convertidos en {C.DIR_RAW / 'publico'}")


def estaticas(origen: Path, max_por_letra: int, semilla: int):
    import cv2

    validas = set(etiquetas("alfabeto"))
    grupos: dict[tuple[str, str], list[Path]] = defaultdict(list)
    for ruta in origen.rglob("*"):
        if ruta.suffix.lower() not in EXT_IMAGEN:
            continue
        letra = next((normalizar_letra(p) for p in reversed(ruta.parts[:-1])
                      if normalizar_letra(p) in validas), None)
        if letra is None:
            continue
        division = "prueba" if any("test" in p.lower() for p in ruta.parts) else "entrenamiento"
        grupos[(letra, division)].append(ruta)

    if not grupos:
        raise SystemExit("No se encontraron imágenes dentro de carpetas con nombre de letra.")

    rng = random.Random(semilla)
    X, y, personas, divisiones = [], [], [], []
    sin_mano = 0
    sin_mano_letra: dict[str, int] = defaultdict(int)
    with Extractor(modo="imagen", con_pose=False, con_cara=False, num_manos=1) as ext:
        for (letra, division), rutas in sorted(grupos.items()):
            rng.shuffle(rutas)
            for ruta in rutas[:max_por_letra]:
                img = cv2.imread(str(ruta))
                if img is None:
                    continue
                cuadro = ext.procesar(img)
                mano = cuadro.mano_izq if not np.isnan(cuadro.mano_izq).all() else cuadro.mano_der
                if np.isnan(mano).all():
                    sin_mano += 1
                    sin_mano_letra[letra] += 1
                    continue
                m = PATRON_PERSONA.search(ruta.stem)
                X.append(caracteristicas_mano(mano))
                y.append(letra)
                personas.append(f"pub_s{int(m.group(1)):02d}" if m else f"pub_{division}")
                divisiones.append(division)
            print(f"  ✓ {letra} ({division}): {min(len(rutas), max_por_letra)} imágenes")

    C.DIR_PROCESADO.mkdir(parents=True, exist_ok=True)
    destino = C.DIR_PROCESADO / "alfabeto_publico.npz"
    np.savez_compressed(destino, X=np.array(X, np.float32), y=np.array(y),
                        personas=np.array(personas), divisiones=np.array(divisiones),
                        sin_mano_letras=np.array(list(sin_mano_letra)),
                        sin_mano_valores=np.array(list(sin_mano_letra.values()), np.int32))
    print(f"Listo: {len(X)} ejemplos ({sin_mano} sin mano detectada) -> {destino}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("dinamicas")
    d.add_argument("--origen", type=Path, required=True)
    d.add_argument("--vista", choices=["frontal", "profile"], default="frontal")
    d.add_argument("--limite", type=int, help="Convertir solo N videos (para probar)")
    e = sub.add_parser("estaticas")
    e.add_argument("--origen", type=Path, required=True)
    e.add_argument("--max-por-letra", type=int, default=3000)
    e.add_argument("--semilla", type=int, default=42)
    a = p.parse_args()
    if a.cmd == "dinamicas":
        dinamicas(a.origen, a.vista, a.limite)
    else:
        estaticas(a.origen, a.max_por_letra, a.semilla)


if __name__ == "__main__":
    main()
