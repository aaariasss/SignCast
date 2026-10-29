"""Arma los conjuntos de entrenamiento a partir de las muestras crudas."""
from __future__ import annotations

from pathlib import Path

import numpy as np

from . import config as C
from .muestras import cargar, listar
from .puntos_clave import Cuadro, caracteristicas_mano, caracteristicas_secuencia, mano_principal

COLUMNAS_MANOS = slice(0, 2 * C.PUNTOS_MANO * 3) 

# Secuencias
def remuestrear(x: np.ndarray, n: int = C.LONGITUD_SECUENCIA) -> np.ndarray:
    """(T, F) -> (n, F) por interpolación lineal en el tiempo."""
    T = len(x)
    if T == n:
        return x.astype(np.float32)
    if T == 1:
        return np.repeat(x, n, axis=0).astype(np.float32)
    origen = np.linspace(0, T - 1, n)
    i0 = np.floor(origen).astype(int)
    i1 = np.minimum(i0 + 1, T - 1)
    w = (origen - i0)[:, None]
    return ((1 - w) * x[i0] + w * x[i1]).astype(np.float32)


def recortar_activo(x: np.ndarray, margen: int = 3) -> np.ndarray:
    """Quita los cuadros del inicio y final donde no hay manos."""
    activos = np.where(np.abs(x[:, COLUMNAS_MANOS]).sum(axis=1) > 0)[0]
    if len(activos) < 2:
        return x
    a = max(activos[0] - margen, 0)
    b = min(activos[-1] + margen + 1, len(x))
    return x[a:b]


def quitar_rostro(x: np.ndarray) -> np.ndarray:
    """Pone en cero las columnas del rostro, igual que las manda la app web."""
    x = x.copy()
    x[..., C.COLUMNAS_ROSTRO] = 0
    return x


def cargar_senas(clases: list[str], raiz: Path = C.DIR_RAW, fuentes: list[str] | None = None):
    """Señas aisladas -> X (N, 30, 270), y (N,), personas (N,)."""
    indice = {c: i for i, c in enumerate(clases)}
    X, y, personas = [], [], []
    omitidas: dict[str, int] = {}
    for ruta in listar(raiz, fuentes):
        m = cargar(ruta)
        if m.es_frase:
            continue
        if m.glosa not in indice:
            omitidas[m.glosa] = omitidas.get(m.glosa, 0) + 1
            continue
        x = quitar_rostro(caracteristicas_secuencia(m.raw))
        if m.glosa != C.CLASE_REPOSO:
            x = recortar_activo(x)
        X.append(remuestrear(x))
        y.append(indice[m.glosa])
        personas.append(m.persona)
    if omitidas:
        print(f"Aviso: glosas sin clase en este modelo (se omiten): {omitidas}")
    if not X:
        raise SystemExit(f"No hay muestras de señas en {raiz}. Graba o convierte datos primero.")
    return np.stack(X), np.array(y), np.array(personas)


# Alfabeto estático
def cargar_alfabeto(clases: list[str], raiz: Path = C.DIR_RAW,
                    publico: Path = C.DIR_PROCESADO / "alfabeto_publico.npz"):
    indice = {c: i for i, c in enumerate(clases)}
    X, y, personas = [], [], []

    if publico.exists():
        d = np.load(publico)
        for xi, yi, pi in zip(d["X"], d["y"], d["personas"]):
            if str(yi) in indice:
                X.append(xi)
                y.append(indice[str(yi)])
                personas.append(str(pi))
        print(f"Conjunto público: {len(X)} ejemplos")

    for ruta in listar(raiz):
        m = cargar(ruta)
        if m.es_frase or m.glosa not in indice:
            continue
        T = len(m.raw["mano_izq"])
        for t in range(T // 3, 2 * T // 3):
            cuadro = Cuadro(mano_izq=m.raw["mano_izq"][t], mano_der=m.raw["mano_der"][t])
            mano = mano_principal(cuadro)
            if not np.isnan(mano).all():
                X.append(caracteristicas_mano(mano))
                y.append(indice[m.glosa])
                personas.append(m.persona)

    if not X:
        raise SystemExit("No hay ejemplos del alfabeto. Convierte el conjunto público o graba letras.")
    return np.stack(X).astype(np.float32), np.array(y), np.array(personas)


# División por persona
def dividir_por_persona(personas: np.ndarray, val: float = 0.15, prueba: float = 0.15,
                        personas_prueba: list[str] | None = None, semilla: int = 42):
    unicas = sorted(set(personas.tolist()))
    rng = np.random.default_rng(semilla)
    rng.shuffle(unicas)

    if personas_prueba:
        faltan = set(personas_prueba) - set(unicas)
        if faltan:
            raise ValueError(f"Estas personas no están en los datos: {sorted(faltan)}")
        en_prueba = list(personas_prueba)
        resto = [p for p in unicas if p not in en_prueba]
    else:
        n = max(1, round(prueba * len(unicas))) if len(unicas) >= 3 else 0
        en_prueba, resto = unicas[:n], unicas[n:]

    n_val = max(1, round(val * len(unicas))) if len(resto) >= 2 else 0
    en_val, en_ent = resto[:n_val], resto[n_val:]

    idx = np.arange(len(personas))
    sel = lambda grupo: idx[np.isin(personas, grupo)]  # noqa: E731
    return sel(en_ent), sel(en_val), sel(en_prueba)


def separar_validacion_por_toma(y: np.ndarray, indices: np.ndarray, fraccion: float = 0.15,
                                semilla: int = 42):
    """Aparta una fracción de `indices` para validar, estratificada por clase.

    Sirve cuando hay pocas personas: la validación por persona dejaría fuera clases
    enteras. La prueba sigue siendo por persona; esto solo guía el entrenamiento.
    Devuelve (entrenamiento, validación).
    """
    rng = np.random.default_rng(semilla)
    val = []
    for clase in np.unique(y[indices]):
        de_clase = indices[y[indices] == clase]
        n = int(round(fraccion * len(de_clase))) if len(de_clase) >= 2 else 0
        val.extend(rng.choice(de_clase, size=n, replace=False))
    val = np.array(sorted(val), dtype=indices.dtype)
    return np.setdiff1d(indices, val), val


# Aumento de datos
def _transformar_xy(puntos: np.ndarray, rng: np.random.Generator, espejo: bool = False,
                    trasladar: bool = True):
    mascara = np.abs(puntos).sum(axis=-1, keepdims=True) > 0
    ang = np.deg2rad(rng.uniform(-10, 10))
    rot = np.array([[np.cos(ang), -np.sin(ang)], [np.sin(ang), np.cos(ang)]], np.float32)
    salida = puntos.copy()
    salida[..., :2] = salida[..., :2] @ rot.T * rng.uniform(0.9, 1.1)
    if trasladar:
        salida[..., :2] += rng.uniform(-0.1, 0.1, size=2)
    salida += rng.normal(0, 0.01, size=salida.shape).astype(np.float32)
    if espejo:
        salida[..., 0] *= -1
    return np.where(mascara, salida, 0).astype(np.float32)


def aumentar_secuencias(X: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    N, T, F = X.shape
    salida = np.empty_like(X)
    for i in range(N):
        pts = _transformar_xy(X[i].reshape(T, F // 3, 3), rng).reshape(T, F)
        # cambio de velocidad: recorta o estira entre 80 % y 120 %
        largo = int(T * rng.uniform(0.8, 1.2))
        if largo < T:
            ini = rng.integers(0, T - largo + 1)
            pts = pts[ini:ini + largo]
        salida[i] = remuestrear(pts, T)
    return salida


def aumentar_manos(X: np.ndarray, rng: np.random.Generator, prob_espejo: float = 0.5) -> np.ndarray:
    salida = np.empty_like(X)
    for i in range(len(X)):
        salida[i] = _transformar_xy(X[i].reshape(C.PUNTOS_MANO, 3), rng,
                                    espejo=rng.random() < prob_espejo,
                                    trasladar=False).reshape(-1)
    return salida
