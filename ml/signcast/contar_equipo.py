"""Cuenta las tomas del equipo por clase y por persona.

Uso (desde ml/):
    python -m signcast.contar_equipo            # imprime las tablas en Markdown
    python -m signcast.contar_equipo --salida ../data/README.md
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

from . import config as C
from .muestras import cargar, leer_vocabulario, listar


def contar(raiz: Path = C.DIR_RAW, fuente: str = "equipo"):
    """(tomas[persona][glosa], fps medio por persona) de las grabaciones del equipo."""
    tomas: dict[str, Counter] = defaultdict(Counter)
    fps: dict[str, list[float]] = defaultdict(list)
    for ruta in listar(raiz, [fuente]):
        m = cargar(ruta)
        tomas[m.persona][m.glosa] += 1
        with np.load(ruta, allow_pickle=False) as d:
            fps[m.persona].append(float(d["fps"]))
    return tomas, {p: float(np.mean(v)) for p, v in fps.items()}


def tabla(tomas: dict[str, Counter], fps: dict[str, float]) -> str:
    personas = sorted(tomas)
    vocabulario = [e.glosa for e in leer_vocabulario()]
    frases = sorted({g for p in personas for g in tomas[p] if " " in g})
    cabecera = ["Clase", *personas, "Total"]
    filas = ["| " + " | ".join(cabecera) + " |", "|---|" + "---:|" * (len(cabecera) - 1)]
    for glosa in [*vocabulario, *frases]:
        n = [tomas[p][glosa] for p in personas]
        filas.append(f"| {glosa} | " + " | ".join(map(str, n)) + f" | {sum(n)} |")
    total = [sum(tomas[p].values()) for p in personas]
    filas.append("| **Total** | " + " | ".join(f"**{n}**" for n in total) + f" | **{sum(total)}** |")
    filas.append("| FPS medio | " + " | ".join(f"{fps[p]:.0f}" for p in personas) + " | |")
    return "\n".join(filas)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--salida", type=Path, help="Reemplaza la tabla entre las marcas <!-- equipo --> de este README")
    a = p.parse_args()
    t = tabla(*contar())
    if not a.salida:
        print(t)
        return
    texto = a.salida.read_text(encoding="utf-8")
    ini, fin = "<!-- equipo:inicio -->", "<!-- equipo:fin -->"
    if ini not in texto or fin not in texto:
        raise SystemExit(f"Faltan las marcas {ini} / {fin} en {a.salida}")
    antes, resto = texto.split(ini, 1)
    _, despues = resto.split(fin, 1)
    a.salida.write_text(f"{antes}{ini}\n{t}\n{fin}{despues}", encoding="utf-8")
    print(f"Tabla actualizada en {a.salida}")


if __name__ == "__main__":
    main()
