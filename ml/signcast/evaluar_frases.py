"""Mide qué porcentaje de frases continuas se traduce bien.

Cada toma de frase grabada (`data/raw`, varias glosas) se pasa cuadro por cuadro por la misma
lógica que `tiempo_real.py`: ventana de 30 cuadros, el modelo cada N cuadros y el `Decisor`
(umbral, predicciones estables y pausa). La frase generada con `construir_frase` se compara con
la esperada, que es `construir_frase` aplicado a las glosas grabadas. Una toma que cierra varias
frases (por la pausa de `_REPOSO`) se compara con las frases unidas por un espacio. Al terminar
la toma se cierra la frase pendiente, como si la persona bajara las manos.

Para no medir con trampa, cada persona debe evaluarse con un modelo que no la haya visto:

    python -m signcast.entrenar --tarea senas --persona-prueba valeria --salida ../modelos/loo_valeria
    python -m signcast.exportar_tflite --modelo ../modelos/loo_valeria
    python -m signcast.evaluar_frases --modelo valeria=../modelos/loo_valeria carlo=... aarian=...

Las tomas se grabaron a velocidades distintas (de ~10 a ~25 cuadros por segundo según la
persona), pero el modelo ve ventanas de 30 cuadros reales. Por eso se remuestrean a `--fps`
(20 por defecto, el tope de la app web) tomando el cuadro más cercano; `--fps 0` las deja como se
grabaron.

Las frases con deletreo (como `HOLA YO A N A`) se omiten: en vivo se activan con la tecla `a`.
Con `--ajustar` prueba combinaciones de umbral, estables y pausa-frase.
"""
from __future__ import annotations

import argparse
import itertools
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

import numpy as np

from . import config as C
from .dataset import quitar_rostro
from .decisor import Decisor
from .frases import LETRAS, construir_frase
from .muestras import cargar, listar
from .puntos_clave import caracteristicas_secuencia

Modelo = Callable[[np.ndarray], tuple]   # x (30, 270) -> (glosa, probabilidad, ms)

RESULTADOS = C.RAIZ_REPO / "docs" / "resultados.md"
MARCA = "frases-continuas"
ANTERIORES = {"umbral": 0.75, "cada": 3, "estables": 3, "pausa_frase": 1.2}    # con lo que se empezó
RECOMENDADOS = {"umbral": 0.8, "cada": 2, "estables": 3, "pausa_frase": 1.2}   # los de tiempo_real.py y la app
REJILLA = {
    "umbral": [0.5, 0.6, 0.7, 0.75, 0.8, 0.85, 0.9],
    "estables": [1, 2, 3, 4],
    "pausa_frase": [0.6, 0.8, 1.0, 1.2, 1.5],
    "cada": [2, 3],
}


@dataclass
class Toma:
    persona: str
    glosas: list[str]
    esperada: str
    n_cuadros: int
    fps: float
    preds: dict[int, tuple[str, float]] = field(default_factory=dict)   # n cuadros vistos -> (glosa, prob)


def normalizar(texto: str) -> str:
    return " ".join(texto.split())


def frase_esperada(glosas: list[str]) -> str:
    """Una frase por cada grupo separado por `_REPOSO`, unidas por un espacio."""
    grupos, actual = [], []
    for g in glosas:
        if g == C.CLASE_REPOSO:
            if actual:
                grupos.append(actual)
            actual = []
        else:
            actual.append(g)
    if actual:
        grupos.append(actual)
    return normalizar(" ".join(construir_frase(g) for g in grupos))


def tiene_deletreo(glosas: list[str]) -> bool:
    return any(g in LETRAS for g in glosas)


def predicciones(modelo: Modelo, raw: dict[str, np.ndarray], ventanas: set[int]) -> dict[int, tuple[str, float]]:
    """Predicción del modelo en cada `n` (cuadros vistos) de `ventanas`, con la ventana de 30 cuadros."""
    T = len(raw["mano_izq"])
    salida = {}
    for n in sorted(ventanas):
        if C.LONGITUD_SECUENCIA <= n <= T:
            ventana = {k: v[n - C.LONGITUD_SECUENCIA:n] for k, v in raw.items()}
            glosa, prob, *_ = modelo(quitar_rostro(caracteristicas_secuencia(ventana)))
            salida[n] = (glosa, float(prob))
    return salida


def a_fps(raw: dict[str, np.ndarray], fps: float, objetivo: float) -> dict[str, np.ndarray]:
    """Deja la toma a `objetivo` cuadros por segundo, tomando el cuadro más cercano en el tiempo."""
    T = len(raw["mano_izq"])
    n = max(int(round(T / fps * objetivo)), 1)
    indices = np.minimum(np.floor(np.arange(n) * fps / objetivo).astype(int), T - 1)
    return {k: v[indices] for k, v in raw.items()}


def cargar_tomas(modelos: dict[str, Modelo], cadas: list[int], raiz: Path = C.DIR_RAW,
                 fuentes: list[str] | None = None, por_defecto: Modelo | None = None,
                 fps: float = 0) -> tuple[list[Toma], list[str]]:
    """Tomas de frase con las predicciones del modelo de su persona. Devuelve (tomas, omitidas)."""
    tomas, omitidas = [], set()
    for ruta in listar(raiz, fuentes):
        m = cargar(ruta)
        if not m.es_frase:
            continue
        if tiene_deletreo(m.glosas):
            omitidas.add(m.glosa)
            continue
        modelo = modelos.get(m.persona, por_defecto)
        if modelo is None:
            continue
        raw, fps_toma = (a_fps(m.raw, m.fps, fps), fps) if fps else (m.raw, m.fps)
        T = len(raw["mano_izq"])
        ns = {n for n in range(C.LONGITUD_SECUENCIA, T + 1) if any(n % c == 0 for c in cadas)}
        tomas.append(Toma(m.persona, m.glosas, frase_esperada(m.glosas), T, fps_toma,
                          predicciones(modelo, raw, ns)))
    return tomas, sorted(omitidas)


def simular_grupos(toma: Toma, umbral: float, cada: int, estables: int,
                   pausa_frase: float) -> list[list[str]]:
    """Glosas de cada frase que cerraría `tiempo_real.py` con estos parámetros sobre la toma."""
    decisor = Decisor(umbral, estables, pausa_frase)
    grupos: list[list[str]] = []
    for n in range(1, toma.n_cuadros + 1):
        ahora = n / toma.fps
        if n % cada == 0 and n in toma.preds:
            decisor.predecir(*toma.preds[n], ahora)
        cerrada = decisor.cerrar_si_pausa(ahora)
        if cerrada:
            grupos.append(cerrada)
    if decisor.glosas:
        grupos.append(decisor.vaciar())
    return grupos


def a_texto(grupos: list[list[str]]) -> str:
    return normalizar(" ".join(construir_frase(g) for g in grupos))


def simular(toma: Toma, **parametros) -> str:
    """Frase que daría `tiempo_real.py` con estos parámetros sobre la toma grabada."""
    return a_texto(simular_grupos(toma, **parametros))


def glosas_en_orden(esperadas: list[str], detectadas: list[str]) -> int:
    """Cuántas glosas esperadas aparecen en orden entre las detectadas (subsecuencia común)."""
    previa = [0] * (len(detectadas) + 1)
    for e in esperadas:
        actual = [0]
        for j, d in enumerate(detectadas):
            actual.append(previa[j] + 1 if e == d else max(previa[j + 1], actual[j]))
        previa = actual
    return previa[-1]


@dataclass
class Resultado:
    parametros: dict
    correctas: int
    total: int
    por_persona: dict[str, tuple[int, int]]
    por_frase: dict[str, tuple[int, int]]
    errores: dict[str, Counter]
    glosas: dict[str, tuple[int, int]] = field(default_factory=dict)   # frase -> (reconocidas, esperadas)

    @property
    def porcentaje(self) -> float:
        return self.correctas / self.total if self.total else 0.0

    @property
    def peor_persona(self) -> float:
        return min((c / t for c, t in self.por_persona.values() if t), default=0.0)


def evaluar(tomas: list[Toma], **parametros) -> Resultado:
    por_persona: dict[str, list[int]] = {}
    por_frase: dict[str, list[int]] = {}
    errores: dict[str, Counter] = {}
    glosas: dict[str, list[int]] = {}
    correctas = 0
    for t in tomas:
        grupos = simular_grupos(t, **parametros)
        generada = a_texto(grupos)
        ok = generada == t.esperada
        esperadas = [g for g in t.glosas if g != C.CLASE_REPOSO]
        g = glosas.setdefault(" ".join(t.glosas), [0, 0])
        g[0] += glosas_en_orden(esperadas, [x for grupo in grupos for x in grupo])
        g[1] += len(esperadas)
        correctas += ok
        for tabla, clave in ((por_persona, t.persona), (por_frase, " ".join(t.glosas))):
            c = tabla.setdefault(clave, [0, 0])
            c[0] += ok
            c[1] += 1
        if not ok:
            detectadas = " | ".join(" ".join(grupo) for grupo in grupos)
            errores.setdefault(" ".join(t.glosas), Counter())[detectadas or "(nada)"] += 1
    return Resultado(parametros, correctas, len(tomas),
                     {k: tuple(v) for k, v in por_persona.items()},
                     {k: tuple(v) for k, v in por_frase.items()}, errores,
                     {k: tuple(v) for k, v in glosas.items()})


def ajustar(tomas: list[Toma], rejilla: dict[str, list] = REJILLA) -> list[Resultado]:
    """Todas las combinaciones, de mejor a peor: más frases correctas, luego la peor persona,
    luego menor retraso (cada * estables + pausa) para no escoger un valor lento sin necesidad."""
    claves = list(rejilla)
    resultados = [evaluar(tomas, **dict(zip(claves, valores)))
                  for valores in itertools.product(*rejilla.values())]
    return sorted(resultados, key=lambda r: (-r.correctas, -r.peor_persona,
                                             r.parametros["cada"] * r.parametros["estables"]
                                             + r.parametros["pausa_frase"]))


def _fila(r: Resultado) -> str:
    p = r.parametros
    return (f"| {p['umbral']} | {p['cada']} | {p['estables']} | {p['pausa_frase']} "
            f"| {r.correctas}/{r.total} | {r.porcentaje:.1%} |")


def seccion(r: Resultado, omitidas: list[str], mejores: list[Resultado] | None = None,
            base: Resultado | None = None, fps: float = 0) -> str:
    p = r.parametros
    lineas = ["## Frases continuas", "",
              f"Frases correctas: **{r.porcentaje:.1%}** ({r.correctas} de {r.total} tomas) con "
              f"`--umbral {p['umbral']} --cada {p['cada']} --estables {p['estables']} "
              f"--pausa-frase {p['pausa_frase']}`. Meta: 80 %.", "",
              "Cada persona se evalúa con un modelo que no la vio entrenar. "
              "Se compara con `construir_frase` sobre las glosas grabadas"
              + (f"; las tomas se remuestrean a {fps:g} cuadros por segundo." if fps else ".") , "",
              "| Persona | Correctas |", "|---|---:|"]
    lineas += [f"| {k} | {c}/{t} ({c / t:.0%}) |" for k, (c, t) in sorted(r.por_persona.items())]
    if r.glosas:
        rec, esp = (sum(v[i] for v in r.glosas.values()) for i in (0, 1))
        lineas += ["", f"Glosas reconocidas en orden: {rec / esp:.1%} ({rec} de {esp})."]
    lineas += ["", "| Frase | Correctas | Glosas reconocidas | Glosas detectadas más común al fallar |",
               "|---|---:|---:|---|"]
    for k, (c, t) in r.por_frase.items():
        mal = r.errores.get(k)
        rec, esp = r.glosas.get(k, (0, 0))
        lineas.append(f"| {k} | {c}/{t} | {rec / esp if esp else 0:.0%} | "
                      f"{mal.most_common(1)[0][0] if mal else ''} |")
    if base is not None:
        r_ = RECOMENDADOS
        lineas += ["", f"Con los valores anteriores (`--umbral {ANTERIORES['umbral']} --cada {ANTERIORES['cada']} "
                       f"--estables {ANTERIORES['estables']} --pausa-frase {ANTERIORES['pausa_frase']}`): "
                       f"{base.porcentaje:.1%} ({base.correctas} de {base.total}).",
                   "", f"Valores recomendados: umbral {r_['umbral']}, el modelo cada {r_['cada']} cuadros, "
                       f"{r_['estables']} predicciones estables y pausa de {r_['pausa_frase']} s (entre 0.8 y 1.5 s "
                       "da el mismo resultado). `tiempo_real.py` y la app usan estos valores."]
    if mejores:
        lineas += ["", "Mejores combinaciones de la búsqueda:", "",
                   "| Umbral | Cada | Estables | Pausa (s) | Correctas | % |", "|---:|---:|---:|---:|---:|---:|"]
        lineas += [_fila(x) for x in mejores]
    if omitidas:
        lineas += ["", f"Omitidas por llevar deletreo (en vivo se activa con `a`): {', '.join(omitidas)}."]
    return "\n".join(lineas)


def cargar_modelos(especificaciones: list[str]) -> tuple[dict[str, Modelo], Modelo | None]:
    """`persona=carpeta` -> modelo de esa persona; `carpeta` sola -> modelo para todas."""
    from .tiempo_real import ModeloTFLite

    por_persona, general = {}, None
    for e in especificaciones:
        persona, sep, ruta = e.partition("=")
        carpeta = Path(ruta if sep else e)
        if not (carpeta / "modelo.tflite").exists():
            raise SystemExit(f"Falta {carpeta / 'modelo.tflite'}. Entrena con --persona-prueba y "
                             f"--salida {carpeta}, y luego corre exportar_tflite --modelo {carpeta}.")
        if sep:
            por_persona[persona.lower()] = ModeloTFLite(Path(ruta))
        else:
            general = ModeloTFLite(Path(e))
    return por_persona, general


def main():
    a = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("--modelo", nargs="+", required=True,
                   help="`persona=carpeta` (modelo que no vio a esa persona) o una carpeta para todas")
    a.add_argument("--fuentes", nargs="+", default=["equipo"])
    a.add_argument("--umbral", type=float, default=RECOMENDADOS["umbral"])
    a.add_argument("--cada", type=int, default=RECOMENDADOS["cada"])
    a.add_argument("--estables", type=int, default=RECOMENDADOS["estables"])
    a.add_argument("--pausa-frase", type=float, default=RECOMENDADOS["pausa_frase"])
    a.add_argument("--fps", type=float, default=20,
                   help="Cuadros por segundo a los que se remuestrean las tomas (0 = como se grabaron)")
    a.add_argument("--ajustar", action="store_true", help="Probar combinaciones de parámetros")
    a.add_argument("--escribir", action="store_true", help=f"Escribir la sección en {RESULTADOS.name}")
    a.add_argument("--salida", type=Path, default=RESULTADOS)
    a = a.parse_args()

    por_persona, general = cargar_modelos(a.modelo)
    cadas = REJILLA["cada"] + [a.cada] if a.ajustar else [a.cada]
    print("Calculando predicciones por ventana...")
    tomas, omitidas = cargar_tomas(por_persona, sorted(set(cadas)), fuentes=a.fuentes, por_defecto=general,
                               fps=a.fps)
    if not tomas:
        raise SystemExit("No hay tomas de frase para evaluar (¿personas sin modelo?).")

    pedidos = dict(umbral=a.umbral, cada=a.cada, estables=a.estables, pausa_frase=a.pausa_frase)
    base = evaluar(tomas, **(ANTERIORES if a.ajustar else pedidos))
    mejores = ajustar(tomas) if a.ajustar else None
    elegido = mejores[0] if mejores else base
    print(seccion(elegido, omitidas, mejores[:8] if mejores else None, base if mejores else None, a.fps))
    if a.escribir:
        from .comparar_aumento import escribir_seccion
        escribir_seccion(a.salida, MARCA, seccion(elegido, omitidas, mejores[:8] if mejores else None,
                                                  base if mejores else None))
        print(f"\nEscrito en {a.salida}")


if __name__ == "__main__":
    main()
