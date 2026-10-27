"""Cuenta los ejemplos por letra del dataset público ya convertido.

Uso (desde ml/):
    python -m signcast.contar_publico            # imprime la tabla en Markdown
    python -m signcast.contar_publico --salida ../data/README.md
"""
from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path

import numpy as np

from . import config as C
from .muestras import etiquetas, leer_vocabulario


def contar_estaticas(ruta: Path) -> tuple[Counter, Counter]:
    """(ejemplos por letra, imágenes sin mano por letra) de alfabeto_publico.npz."""
    if not ruta.exists():
        return Counter(), Counter()
    with np.load(ruta, allow_pickle=False) as d:
        ok = Counter(str(l) for l in d["y"])
        sin = Counter()
        if "sin_mano_letras" in d.files:
            sin = Counter(dict(zip((str(l) for l in d["sin_mano_letras"]),
                                   (int(v) for v in d["sin_mano_valores"]))))
    return ok, sin


def contar_dinamicas(raiz: Path) -> tuple[Counter, Counter]:
    """(videos por letra, videos donde nunca se detectó una mano) en raw/publico."""
    ok, sin = Counter(), Counter()
    for ruta in sorted(raiz.rglob("*.npz")):
        letra = ruta.parent.name
        with np.load(ruta, allow_pickle=False) as d:
            sin_mano = np.isnan(d["mano_izq"].astype(np.float32)).all() and \
                np.isnan(d["mano_der"].astype(np.float32)).all()
        ok[letra] += 1
        if sin_mano:
            sin[letra] += 1
    return ok, sin


def tabla(estaticas: tuple[Counter, Counter], dinamicas: tuple[Counter, Counter]) -> str:
    letras_est = etiquetas("alfabeto")
    letras_din = [e.glosa for e in leer_vocabulario() if e.modelo == "senas" and e.categoria == "alfabeto"]
    filas = ["| Letra | Tipo | Ejemplos | Sin mano detectada |", "|---|---|---:|---:|"]
    total = total_sin = 0
    for letras, tipo, (ok, sin) in ((letras_est, "estática", estaticas), (letras_din, "dinámica", dinamicas)):
        for letra in letras:
            filas.append(f"| {letra} | {tipo} | {ok[letra]} | {sin[letra]} |")
            total += ok[letra]
            total_sin += sin[letra]
    filas.append(f"| **Total** | | **{total}** | **{total_sin}** |")
    return "\n".join(filas)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--salida", type=Path, help="Reemplaza la tabla entre las marcas <!-- conteo --> de este README")
    a = p.parse_args()
    t = tabla(contar_estaticas(C.DIR_PROCESADO / "alfabeto_publico.npz"),
              contar_dinamicas(C.DIR_RAW / "publico"))
    if not a.salida:
        print(t)
        return
    texto = a.salida.read_text(encoding="utf-8")
    ini, fin = "<!-- conteo:inicio -->", "<!-- conteo:fin -->"
    if ini not in texto or fin not in texto:
        raise SystemExit(f"Faltan las marcas {ini} / {fin} en {a.salida}")
    antes, resto = texto.split(ini, 1)
    _, despues = resto.split(fin, 1)
    a.salida.write_text(f"{antes}{ini}\n{t}\n{fin}{despues}", encoding="utf-8")
    print(f"Tabla actualizada en {a.salida}")


if __name__ == "__main__":
    main()
