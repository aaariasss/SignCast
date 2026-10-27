"""Genera los datos de referencia para la prueba en Dart.

La app (Dart) debe producir el mismo vector que Python. Este script crea
puntos crudos *sintéticos* (sin datos de personas) con casos borde, calcula con
`puntos_clave.py` el vector esperado y lo guarda como JSON. La prueba
`app/test/caracteristicas_test.dart` lee ese archivo y compara.

Uso (desde ml/):
    python -m signcast.referencia_dart
    python -m signcast.referencia_dart --salida ../app/test/fixtures/referencia_vector.json

Si cambias `puntos_clave.py` o `config.py`, vuelve a correrlo y sube el JSON.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from . import config as C
from .puntos_clave import Cuadro, caracteristicas_mano, caracteristicas_secuencia, mano_principal

SALIDA = C.RAIZ_REPO / "app" / "test" / "fixtures" / "referencia_vector.json"
CUADROS = 6          # cuadros por caso
DECIMALES = 3        # las entradas se redondean para que el JSON sea pequeño


def _redondear(a: np.ndarray) -> np.ndarray:
    return np.round(a, DECIMALES).astype(np.float32)


def _vacio(*forma) -> np.ndarray:
    return np.full(forma, np.nan, np.float32)


def _puntos(rng, t: int, n: int) -> np.ndarray:
    p = np.empty((t, n, 3), np.float32)
    p[..., :2] = rng.uniform(0.3, 0.7, (t, n, 2))
    p[..., 2] = rng.uniform(-0.1, 0.1, (t, n))
    return _redondear(p)


def _pose(rng, t: int) -> np.ndarray:
    p = _puntos(rng, t, 33)
    p[:, C.HOMBRO_IZQ, :2] = _redondear(np.array([0.6, 0.5]) + rng.uniform(-0.01, 0.01, (t, 2)))
    p[:, C.HOMBRO_DER, :2] = _redondear(np.array([0.4, 0.5]) + rng.uniform(-0.01, 0.01, (t, 2)))
    return p


def _json_puntos(a: np.ndarray):
    """(N, 3) -> None si todo es NaN; si no, lista de puntos (None si falta alguno)."""
    if np.isnan(a).all():
        return None
    return [None if np.isnan(p).any() else [round(float(v), DECIMALES) for v in p] for p in a]


def _json_cuadro(raw: dict[str, np.ndarray], t: int) -> dict:
    return {"mano_izq": _json_puntos(raw["mano_izq"][t]), "mano_der": _json_puntos(raw["mano_der"][t]),
            "pose": _json_puntos(raw["pose"][t])}


def _caso(nombre: str, descripcion: str, raw: dict[str, np.ndarray]) -> dict:
    esperado = caracteristicas_secuencia(raw)
    assert esperado.shape == (raw["mano_izq"].shape[0], C.N_CARACTERISTICAS)
    return {"nombre": nombre, "descripcion": descripcion,
            "cuadros": [_json_cuadro(raw, t) for t in range(raw["mano_izq"].shape[0])],
            "esperado": [[round(float(v), 6) for v in fila] for fila in esperado]}


def generar(semilla: int = 7) -> dict:
    rng = np.random.default_rng(semilla)
    cara = _puntos(rng, CUADROS, 478)        # el rostro es el mismo en todos los casos

    def base(t=CUADROS):
        return {"mano_izq": _puntos(rng, t, 21), "mano_der": _puntos(rng, t, 21),
                "pose": _pose(rng, t), "cara": cara[:t]}

    secuencias = []

    secuencias.append(_caso("ambas_manos", "Todo detectado.", base()))

    r = base(); r["mano_der"] = _vacio(CUADROS, 21, 3)
    secuencias.append(_caso("una_mano", "Mano derecha ausente: 63 ceros.", r))

    r = base(); r["mano_izq"] = _vacio(CUADROS, 21, 3); r["mano_der"] = _vacio(CUADROS, 21, 3)
    secuencias.append(_caso("sin_manos", "Ninguna mano.", r))

    r = base(); r["mano_izq"][2:4] = np.nan
    secuencias.append(_caso("mano_intermitente", "Mano izquierda ausente en los cuadros 2 y 3 (no se rellena).", r))

    r = base(); r["pose"][[0, 3]] = np.nan
    secuencias.append(_caso("hombros_con_huecos", "Sin hombros en los cuadros 0 y 3 (relleno hacia adelante y atrás).", r))

    r = base(); r["pose"][:] = np.nan
    secuencias.append(_caso("sin_cuerpo", "Nunca se ven los hombros: centro 0.5 y escala 0.3.", r))

    r = base(); r["pose"][2, C.HOMBRO_DER, :2] = r["pose"][2, C.HOMBRO_IZQ, :2]
    secuencias.append(_caso("hombros_juntos", "Hombros en el mismo punto en el cuadro 2: escala menor a 0.001 -> 0.3.", r))

    r = base(2)
    secuencias.append(_caso("dos_cuadros", "Ventana corta.", r))

    manos = []
    def mano_caso(nombre, mano):
        manos.append({"nombre": nombre, "mano": _json_puntos(mano), "esperado": [round(float(v), 6) for v in caracteristicas_mano(mano)]})

    m = _puntos(rng, 1, 21)[0]
    mano_caso("completa", m)
    m2 = m.copy(); m2[5] = np.nan
    mano_caso("punto_faltante", m2)
    mano_caso("toda_nan", _vacio(21, 3))
    mano_caso("sin_tamano", np.tile(m[0], (21, 1)))

    principal = []
    def principal_caso(nombre, izq, der):
        c = Cuadro(); 
        if izq is not None: c.mano_izq = izq
        if der is not None: c.mano_der = der
        esperado = caracteristicas_mano(mano_principal(c))
        principal.append({"nombre": nombre,
                          "mano_izq": None if izq is None else _json_puntos(izq),
                          "mano_der": None if der is None else _json_puntos(der),
                          "esperado": [round(float(v), 6) for v in esperado]})

    chica = _redondear(m[:, :] * np.array([0.5, 0.5, 1], np.float32))
    principal_caso("izquierda_mas_grande", m, chica)
    principal_caso("derecha_mas_grande", chica, m)
    principal_caso("solo_derecha", None, m)
    principal_caso("ninguna", None, None)
    principal_caso("izquierda_con_nan_gana", m2, m)       # con NaN el área no es mayor y se queda la primera

    return {"version": 1, "tolerancia": 1e-4, "cuadros_cara": CUADROS,
            "cara": [_json_puntos(cara[t]) for t in range(CUADROS)],
            "secuencias": secuencias, "manos": manos, "mano_principal": principal}


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--salida", type=Path, default=SALIDA)
    a = p.parse_args()
    datos = generar()
    a.salida.parent.mkdir(parents=True, exist_ok=True)
    a.salida.write_text(json.dumps(datos, separators=(",", ":")), encoding="utf-8")
    print(f"Referencia escrita en {a.salida} ({a.salida.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
