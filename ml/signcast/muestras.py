from __future__ import annotations

import csv
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import numpy as np

from . import config as C


@dataclass
class Muestra:
    ruta: Path
    fuente: str
    persona: str
    glosas: list[str]           # 1 glosa = seña aislada; varias = frase
    raw: dict[str, np.ndarray]  # mano_izq, mano_der, pose, cara: (T, N, 3)
    fps: float = C.FPS_OBJETIVO

    @property
    def glosa(self) -> str:
        return " ".join(self.glosas)

    @property
    def es_frase(self) -> bool:
        return len(self.glosas) > 1


def guardar(raw: dict[str, np.ndarray], fuente: str, persona: str, glosas: list[str],
            fps: float = C.FPS_OBJETIVO, raiz: Path = C.DIR_RAW, nombre: str | None = None) -> Path:
    carpeta = raiz / fuente / persona / "_".join(glosas)
    carpeta.mkdir(parents=True, exist_ok=True)
    nombre = nombre or datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    ruta = carpeta / f"{nombre}.npz"
    np.savez_compressed(ruta, **{k: v.astype(np.float16) for k, v in raw.items()},
                        glosas=np.array(glosas), persona=persona, fuente=fuente, fps=fps)
    return ruta


def cargar(ruta: Path) -> Muestra:
    with np.load(ruta, allow_pickle=False) as d:
        raw = {k: d[k].astype(np.float32) for k in ("mano_izq", "mano_der", "pose", "cara")}
        return Muestra(ruta=ruta, fuente=str(d["fuente"]), persona=str(d["persona"]),
                       glosas=[str(g) for g in d["glosas"]], raw=raw,
                       fps=float(d["fps"]) if "fps" in d.files else C.FPS_OBJETIVO)


def listar(raiz: Path = C.DIR_RAW, fuentes: list[str] | None = None) -> list[Path]:
    rutas = sorted(raiz.rglob("*.npz"))
    if fuentes:
        rutas = [r for r in rutas if r.relative_to(raiz).parts[0] in fuentes]
    return rutas


# Vocabulario
@dataclass
class Entrada:
    glosa: str
    espanol: str
    tipo: str
    modelo: str
    categoria: str


def leer_vocabulario(ruta: Path = C.VOCABULARIO) -> list[Entrada]:
    with open(ruta, encoding="utf-8") as f:
        return [Entrada(**fila) for fila in csv.DictReader(f)]


def etiquetas(modelo: str, ruta: Path = C.VOCABULARIO) -> list[str]:
    """Clases (en orden fijo) de un modelo: 'senas' o 'alfabeto'."""
    return [e.glosa for e in leer_vocabulario(ruta) if e.modelo == modelo]
