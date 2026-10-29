import numpy as np

from signcast.contar_equipo import contar, tabla
from signcast.muestras import guardar


def raw():
    vacio = np.zeros((5, 21, 3), np.float32)
    return {"mano_izq": vacio, "mano_der": vacio, "pose": np.zeros((5, 9, 3), np.float32),
            "cara": np.zeros((5, 37, 3), np.float32)}


def test_cuenta_por_persona_y_clase(tmp_path):
    guardar(raw(), "equipo", "ana", ["HOLA"], fps=10, raiz=tmp_path, nombre="a")
    guardar(raw(), "equipo", "ana", ["HOLA"], fps=20, raiz=tmp_path, nombre="b")
    guardar(raw(), "equipo", "luis", ["YO", "NO"], fps=30, raiz=tmp_path, nombre="c")
    guardar(raw(), "publico", "pub_s01", ["HOLA"], raiz=tmp_path, nombre="d")
    tomas, fps = contar(tmp_path)
    assert sorted(tomas) == ["ana", "luis"]
    assert tomas["ana"]["HOLA"] == 2 and tomas["luis"]["YO NO"] == 1
    assert fps["ana"] == 15 and fps["luis"] == 30


def test_tabla_incluye_frases_y_totales(tmp_path):
    guardar(raw(), "equipo", "ana", ["HOLA"], fps=10, raiz=tmp_path, nombre="a")
    guardar(raw(), "equipo", "luis", ["YO", "NO"], fps=30, raiz=tmp_path, nombre="c")
    md = tabla(*contar(tmp_path))
    assert "| Clase | ana | luis | Total |" in md
    assert "| HOLA | 1 | 0 | 1 |" in md
    assert "| YO NO | 0 | 1 | 1 |" in md
    assert "| **Total** | **1** | **1** | **2** |" in md
