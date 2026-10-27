import json

import numpy as np

from signcast import config as C
from signcast.referencia_dart import SALIDA, generar


def test_referencia_dart_esta_al_dia():
    """Si cambia puntos_clave.py o config.py hay que regenerar el JSON de la app
    (`python -m signcast.referencia_dart`); si no, la prueba de Dart compararía
    contra números viejos."""
    nueva = generar()
    guardada = json.loads(SALIDA.read_text(encoding="utf-8"))
    assert [s["nombre"] for s in nueva["secuencias"]] == [s["nombre"] for s in guardada["secuencias"]]
    for a, b in zip(nueva["secuencias"], guardada["secuencias"]):
        assert a["cuadros"] == b["cuadros"], f"entradas distintas en {a['nombre']}"
        np.testing.assert_allclose(np.array(a["esperado"]), np.array(b["esperado"]), atol=1e-5)
    for clave in ("manos", "mano_principal"):
        for a, b in zip(nueva[clave], guardada[clave]):
            np.testing.assert_allclose(np.array(a["esperado"]), np.array(b["esperado"]), atol=1e-5)


def test_referencia_dart_forma():
    d = json.loads(SALIDA.read_text(encoding="utf-8"))
    for s in d["secuencias"]:
        assert all(len(f) == C.N_CARACTERISTICAS for f in s["esperado"])
        assert len(s["cuadros"]) == len(s["esperado"])
    assert all(len(m["esperado"]) == C.N_CARACTERISTICAS_MANO for m in d["manos"])
