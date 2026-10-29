import numpy as np

from signcast import config as C
from signcast.dataset import (aumentar_manos, aumentar_secuencias, cargar_senas,
                              dividir_por_persona, quitar_rostro, remuestrear,
                              separar_validacion_por_toma)
from signcast.muestras import cargar, guardar
from signcast.puntos_clave import caracteristicas_mano, caracteristicas_secuencia


def raw_falso(T=40, con_manos=True, semilla=0):
    rng = np.random.default_rng(semilla)
    pose = rng.uniform(0.3, 0.7, (T, 33, 3)).astype(np.float32)
    pose[:, C.HOMBRO_IZQ, :2] = [0.6, 0.5]
    pose[:, C.HOMBRO_DER, :2] = [0.4, 0.5]
    mano = rng.uniform(0.3, 0.7, (T, 21, 3)).astype(np.float32)
    vacio = np.full((T, 21, 3), np.nan, np.float32)
    return {"mano_izq": mano if con_manos else vacio, "mano_der": vacio, "pose": pose,
            "cara": rng.uniform(0.4, 0.6, (T, 478, 3)).astype(np.float32)}


def test_forma_y_normalizacion():
    x = caracteristicas_secuencia(raw_falso())
    assert x.shape == (40, C.N_CARACTERISTICAS)
    assert not np.isnan(x).any()
    pts = x.reshape(40, C.N_PUNTOS, 3)
    i_hombro = 2 * C.PUNTOS_MANO + C.INDICES_POSE.index(C.HOMBRO_IZQ)
    np.testing.assert_allclose(pts[0, i_hombro, :2], [0.5, 0.0], atol=1e-5)  
    assert (pts[:, C.PUNTOS_MANO:2 * C.PUNTOS_MANO] == 0).all()             


def test_invariante_a_posicion():
    a = raw_falso()
    b = {k: v.copy() for k, v in a.items()}
    for k in b:
        b[k][..., 0] += 0.1                                     
    np.testing.assert_allclose(caracteristicas_secuencia(a), caracteristicas_secuencia(b), atol=1e-5)


def test_mano_centrada_en_muneca():
    v = caracteristicas_mano(raw_falso()["mano_izq"][0])
    assert v.shape == (63,)
    np.testing.assert_allclose(v[:3], 0)


def test_remuestrear():
    x = np.arange(10, dtype=np.float32)[:, None]
    y = remuestrear(x, 30)
    assert y.shape == (30, 1) and y[0, 0] == 0 and y[-1, 0] == 9


def test_division_sin_fugas():
    personas = np.array([p for p in "abcdefghij" for _ in range(5)])
    e, v, p = dividir_por_persona(personas)
    grupos = [set(personas[i]) for i in (e, v, p)]
    assert grupos[0].isdisjoint(grupos[1]) and grupos[0].isdisjoint(grupos[2])
    assert len(e) + len(v) + len(p) == len(personas)
    _, _, p = dividir_por_persona(personas, personas_prueba=["c"])
    assert set(personas[p]) == {"c"}


def test_aumento_conserva_forma_y_ceros():
    X = np.stack([remuestrear(caracteristicas_secuencia(raw_falso(semilla=i))) for i in range(3)])
    A = aumentar_secuencias(X, np.random.default_rng(0))
    assert A.shape == X.shape
    manos = np.stack([caracteristicas_mano(raw_falso(semilla=i)["mano_izq"][0]) for i in range(3)])
    M = aumentar_manos(manos, np.random.default_rng(0))
    assert M.shape == manos.shape
    np.testing.assert_allclose(M[:, :3], 0)          


def test_guardar_y_cargar(tmp_path):
    ruta = guardar(raw_falso(), "equipo", "aarian", ["HOLA"], raiz=tmp_path)
    m = cargar(ruta)
    assert m.persona == "aarian" and m.glosas == ["HOLA"] and not m.es_frase
    guardar(raw_falso(), "equipo", "aarian", ["YO", "NO", "ENTENDER"], raiz=tmp_path)
    X, y, personas = cargar_senas(["_REPOSO", "HOLA"], raiz=tmp_path)
    assert X.shape == (1, C.LONGITUD_SECUENCIA, C.N_CARACTERISTICAS)   
    assert y.tolist() == [1]


def test_validacion_por_toma_cubre_todas_las_clases():
    y = np.repeat(np.arange(4), 20)
    indices = np.arange(len(y))
    ent, val = separar_validacion_por_toma(y, indices, 0.15)
    assert len(val) == 12 and len(ent) == 68
    assert set(y[val]) == {0, 1, 2, 3}
    assert not set(ent) & set(val)


def test_quitar_rostro_deja_solo_las_columnas_del_rostro_en_cero():
    x = caracteristicas_secuencia(raw_falso())
    assert np.abs(x[:, C.COLUMNAS_ROSTRO]).sum() > 0
    y = quitar_rostro(x)
    assert (y[:, C.COLUMNAS_ROSTRO] == 0).all()
    np.testing.assert_array_equal(y[:, :C.COLUMNAS_ROSTRO.start], x[:, :C.COLUMNAS_ROSTRO.start])
    assert C.COLUMNAS_ROSTRO.stop == C.N_CARACTERISTICAS and C.COLUMNAS_ROSTRO.start == 153


def test_cargar_senas_sin_rostro_y_aumento_lo_mantiene(tmp_path):
    guardar(raw_falso(), "equipo", "aarian", ["HOLA"], raiz=tmp_path)
    X, _, _ = cargar_senas(["_REPOSO", "HOLA"], raiz=tmp_path)
    assert (X[..., C.COLUMNAS_ROSTRO] == 0).all() and np.abs(X[..., :153]).sum() > 0
    A = aumentar_secuencias(X, np.random.default_rng(0))
    assert (A[..., C.COLUMNAS_ROSTRO] == 0).all()


def test_columnas_reducidas_son_manos_nariz_y_codos():
    cols = [c for a, b in C.COLUMNAS_REDUCIDAS for c in range(a, b)]
    assert len(cols) == 135 and cols == sorted(set(cols))
    assert max(cols) < C.COLUMNAS_ROSTRO.start
