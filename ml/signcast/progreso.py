"""Muestra cuántas tomas lleva cada persona y cuáles le faltan (issues #10, #11 y #12).

    python -m signcast.progreso --persona valeria
    python -m signcast.progreso            # todas las personas del equipo
"""
from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

from . import config as C
from .muestras import leer_vocabulario

FRASES_MD = C.RAIZ_REPO / "docs" / "frases.md"

META_SENA = 20
META_LETRA = 5
META_REPOSO = 20
META_FRASE = 10


@dataclass
class Objetivo:
    seccion: str
    glosas: list[str]
    meta: int

    @property
    def carpeta(self) -> str:
        return "_".join(self.glosas)

    @property
    def comando(self) -> str:
        if len(self.glosas) > 1:
            return f'--frase "{" ".join(self.glosas)}"'
        return f"--glosa {self.glosas[0]}"


def leer_frases(ruta: Path = FRASES_MD) -> list[list[str]]:
    """Glosas de la tabla 'Frases a grabar' de docs/frases.md."""
    frases, dentro = [], False
    for linea in ruta.read_text(encoding="utf-8").splitlines():
        if linea.startswith("## "):
            dentro = linea.startswith("## Frases a grabar")
            continue
        m = re.match(r"^\|\s*\d+\s*\|\s*([^|]+?)\s*\|", linea)
        if dentro and m:
            frases.append(m.group(1).split())
    if not frases:
        raise SystemExit(f"No se encontró la tabla 'Frases a grabar' en {ruta}")
    return frases


def objetivos(frases_md: Path = FRASES_MD, vocabulario: Path = C.VOCABULARIO) -> list[Objetivo]:
    vocab = leer_vocabulario(vocabulario)
    lista = [Objetivo("Señas", [e.glosa], META_SENA) for e in vocab if e.tipo == "sena"]
    lista += [Objetivo("Reposo", [C.CLASE_REPOSO], META_REPOSO)]
    lista += [Objetivo("Letras", [e.glosa], META_LETRA) for e in vocab if e.tipo.startswith("letra")]
    lista += [Objetivo("Frases", g, META_FRASE) for g in leer_frases(frases_md)]
    return lista


def contar(carpeta_persona: Path) -> dict[str, int]:
    """Tomas (.npz) por carpeta de glosa."""
    if not carpeta_persona.is_dir():
        return {}
    return {d.name: len(list(d.glob("*.npz"))) for d in carpeta_persona.iterdir() if d.is_dir()}


def reporte(persona: str, conteo: dict[str, int], lista: list[Objetivo]) -> str:
    lineas = [f"=== {persona} ==="]
    total = hechas = 0
    for seccion in dict.fromkeys(o.seccion for o in lista):
        grupo = [o for o in lista if o.seccion == seccion]
        listos = sum(conteo.get(o.carpeta, 0) >= o.meta for o in grupo)
        lineas.append(f"\n{seccion} ({listos}/{len(grupo)} completas)")
        for o in grupo:
            n = conteo.get(o.carpeta, 0)
            marca = "✓" if n >= o.meta else ("·" if n else "✗")
            lineas.append(f"  {marca} {' '.join(o.glosas):<45} {n:>3}/{o.meta}")
            total += o.meta
            hechas += min(n, o.meta)

    conocidas = {o.carpeta for o in lista}
    extra = sorted(c for c in conteo if c not in conocidas)
    if extra:
        lineas.append(f"\n⚠ Carpetas que no están en la lista (¿nombre mal escrito?): {', '.join(extra)}")

    faltan = [o for o in lista if conteo.get(o.carpeta, 0) < o.meta]
    lineas.append(f"\nTotal: {hechas}/{total} tomas ({100 * hechas / total:.0f} %)")
    if faltan:
        lineas.append("Siguientes comandos:")
        for o in faltan[:5]:
            resto = o.meta - conteo.get(o.carpeta, 0)
            lineas.append(f"  python -m signcast.grabar --persona {persona} {o.comando} --repeticiones {resto}")
    else:
        lineas.append("¡Todo grabado!")
    return "\n".join(lineas)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--persona", help="Sin esta opción muestra a todas las personas")
    p.add_argument("--fuente", default="equipo")
    a = p.parse_args()

    raiz = C.DIR_RAW / a.fuente
    if a.persona:
        personas = [a.persona.lower()]
    else:
        personas = sorted(d.name for d in raiz.iterdir() if d.is_dir()) if raiz.is_dir() else []
        if not personas:
            raise SystemExit(f"Todavía no hay grabaciones en {raiz}")

    lista = objetivos()
    print("\n\n".join(reporte(p, contar(raiz / p), lista) for p in personas))


if __name__ == "__main__":
    main()
