import numpy as np

from signcast.contar_publico import contar_dinamicas, contar_estaticas, tabla
from signcast.muestras import guardar


def raw(con_mano):
    mano = np.zeros((5, 21, 3), np.float32) if con_mano else np.full((5, 21, 3), np.nan, np.float32)
    vacio = np.full((5, 21, 3), np.nan, np.float32)
    return {"mano_izq": mano, "mano_der": vacio, "pose": np.zeros((5, 9, 3), np.float32),
            "cara": np.zeros((5, 37, 3), np.float32)}


def test_dinamicas_cuenta_por_letra_y_sin_mano(tmp_path):
    guardar(raw(True), "publico", "pub_s01", ["J"], raiz=tmp_path, nombre="a")
    guardar(raw(False), "publico", "pub_s02", ["J"], raiz=tmp_path, nombre="b")
    guardar(raw(True), "publico", "pub_s01", ["Z"], raiz=tmp_path, nombre="c")
    ok, sin = contar_dinamicas(tmp_path / "publico")
    assert ok["J"] == 2 and ok["Z"] == 1
    assert sin["J"] == 1 and sin["Z"] == 0


def test_estaticas_y_tabla(tmp_path):
    ruta = tmp_path / "alfabeto_publico.npz"
    np.savez_compressed(ruta, X=np.zeros((3, 63), np.float32), y=np.array(["A", "A", "B"]),
                        sin_mano_letras=np.array(["A"]), sin_mano_valores=np.array([4], np.int32))
    ok, sin = contar_estaticas(ruta)
    assert ok["A"] == 2 and sin["A"] == 4
    md = tabla((ok, sin), contar_dinamicas(tmp_path / "no_existe"))
    assert "| A | estática | 2 | 4 |" in md
    assert md.count("\n") >= 27   # encabezado + 27 letras + total


def test_sin_archivos_no_falla(tmp_path):
    assert contar_estaticas(tmp_path / "nada.npz") == ({}, {})
