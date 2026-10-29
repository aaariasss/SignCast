"""Compara el entrenamiento con distintas cantidades de copias de aumento de datos.

Entrena con las mismas semillas y parámetros, cambiando solo `--copias-aumento`, evalúa en la
persona de prueba y escribe la tabla en `docs/resultados.md`.

Desde `ml/`:
    python -m signcast.comparar_aumento --tarea senas --persona-prueba valeria
    python -m signcast.comparar_aumento --tarea alfabeto --persona-prueba valeria
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

from . import config as C
from .entrenar import META_EXACTITUD, META_F1

RESULTADOS = C.RAIZ_REPO / "docs" / "resultados.md"


def entrenar(tarea: str, copias: int, semilla: int, persona_prueba: list[str], epocas: int,
             arquitectura: str) -> dict:
    """Corre `signcast.entrenar` y devuelve las métricas de prueba."""
    with tempfile.TemporaryDirectory() as tmp:
        orden = [sys.executable, "-m", "signcast.entrenar", "--tarea", tarea,
                 "--copias-aumento", str(copias), "--semilla", str(semilla),
                 "--epocas", str(epocas), "--salida", tmp,
                 "--persona-prueba", *persona_prueba]
        if tarea == "senas":
            orden += ["--arquitectura", arquitectura]
        subprocess.run(orden, check=True, cwd=C.DIR_ML)
        metricas = json.loads((Path(tmp) / "metricas.json").read_text(encoding="utf-8"))
    if "prueba" not in metricas:
        raise SystemExit("Sin conjunto de prueba: indica --persona-prueba con alguien que esté en los datos.")
    return metricas["prueba"]


def resumir(corridas: list[dict]) -> dict:
    """Media y desviación entre semillas; F1 medio por clase."""
    exac = np.array([c["exactitud"] for c in corridas])
    f1 = np.array([c["f1_macro"] for c in corridas])
    clases = corridas[0]["f1_por_clase"].keys()
    return {
        "exactitud": (float(exac.mean()), float(exac.std())),
        "f1_macro": (float(f1.mean()), float(f1.std())),
        "f1_por_clase": {k: float(np.mean([c["f1_por_clase"].get(k, 0.0) for c in corridas]))
                         for k in clases},
    }


def mejor(resumen: dict[int, dict]) -> int:
    """Copias con mayor F1 macro medio; en empate, las menos."""
    return min(resumen, key=lambda n: (-round(resumen[n]["f1_macro"][0], 3), n))


def clases_que_cambian(base: dict, otro: dict, n: int = 5) -> list[tuple[str, float, float]]:
    cambios = [(k, base[k], otro.get(k, 0.0)) for k in base]
    return sorted(cambios, key=lambda t: -abs(t[2] - t[1]))[:n]


def seccion(titulo: str, persona_prueba: list[str], n_semillas: int, resumen: dict[int, dict]) -> str:
    copias = sorted(resumen)
    lineas = [f"## {titulo}", "",
              f"Prueba: {', '.join(persona_prueba)}. Media ± desviación de {n_semillas} semillas.", "",
              "| Copias de aumento | Exactitud | F1 macro | Cumple meta |", "|---:|---:|---:|:---:|"]
    for n in copias:
        r = resumen[n]
        cumple = "sí" if r["exactitud"][0] >= META_EXACTITUD and r["f1_macro"][0] >= META_F1 else "no"
        lineas.append(f"| {n} | {r['exactitud'][0]:.3f} ± {r['exactitud'][1]:.3f} "
                      f"| {r['f1_macro'][0]:.3f} ± {r['f1_macro'][1]:.3f} | {cumple} |")
    base, ultimo = copias[0], copias[-1]
    if base != ultimo:
        lineas += ["", f"Clases con más cambio de F1 entre {base} y {ultimo} copias:", ""]
        for k, a, b in clases_que_cambian(resumen[base]["f1_por_clase"], resumen[ultimo]["f1_por_clase"]):
            lineas.append(f"- {k}: {a:.2f} → {b:.2f}")
    lineas += ["", f"Mejor: {mejor(resumen)} copias."]
    return "\n".join(lineas)


def escribir_seccion(ruta: Path, marca: str, contenido: str) -> None:
    """Reemplaza (o agrega) el bloque `marca` de `ruta`, sin tocar el resto del archivo."""
    inicio, fin = f"<!-- {marca}:inicio -->", f"<!-- {marca}:fin -->"
    bloque = f"{inicio}\n{contenido}\n{fin}"
    texto = ruta.read_text(encoding="utf-8") if ruta.exists() else "# Resultados\n"
    if inicio in texto and fin in texto:
        antes, resto = texto.split(inicio, 1)
        despues = resto.split(fin, 1)[1]
        texto = antes + bloque + despues
    else:
        texto = texto.rstrip("\n") + "\n\n" + bloque + "\n"
    ruta.write_text(texto, encoding="utf-8")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--tarea", choices=["senas", "alfabeto"], required=True)
    p.add_argument("--arquitectura", choices=["lstm", "transformer"], default="lstm")
    p.add_argument("--persona-prueba", nargs="+", required=True)
    p.add_argument("--copias", nargs="+", type=int, default=[0, 3])
    p.add_argument("--semillas", nargs="+", type=int, default=[42, 43, 44])
    p.add_argument("--epocas", type=int, default=100)
    p.add_argument("--salida", type=Path, default=RESULTADOS)
    a = p.parse_args()

    resumen = {}
    for n in a.copias:
        corridas = [entrenar(a.tarea, n, s, a.persona_prueba, a.epocas, a.arquitectura)
                    for s in a.semillas]
        resumen[n] = resumir(corridas)
        print(f"copias={n}: exactitud {resumen[n]['exactitud'][0]:.3f} "
              f"| F1 macro {resumen[n]['f1_macro'][0]:.3f}")

    titulo = "Señas (" + a.arquitectura + ")" if a.tarea == "senas" else "Alfabeto"
    escribir_seccion(a.salida, f"aumento-{a.tarea}",
                     seccion(f"Aumento de datos: {titulo}", a.persona_prueba, len(a.semillas), resumen))
    print(f"Mejor: {mejor(resumen)} copias. Tabla en {a.salida}")


if __name__ == "__main__":
    main()
