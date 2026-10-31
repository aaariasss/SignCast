import numpy as np

from signcast import config as C
from signcast.decisor import Decisor
from signcast.evaluar_frases import (Toma, a_fps, ajustar, glosas_en_orden, cargar_tomas, evaluar, frase_esperada,
                                     predicciones, simular)
from signcast.muestras import guardar

FPS = 30.0
R = C.CLASE_REPOSO


def segmentos(*tramos, n_cuadros=300, prob=0.95):
    """tramos: (glosa, cuadro_inicial, cuadro_final) -> predicciones por cuadros vistos (n)."""
    preds = {}
    for n in range(C.LONGITUD_SECUENCIA, n_cuadros + 1):
        for glosa, ini, fin in tramos:
            if ini <= n < fin:
                preds[n] = (glosa, prob)
    return preds


def toma(glosas, preds, n_cuadros=300, persona="ana"):
    return Toma(persona, glosas, frase_esperada(glosas), n_cuadros, FPS, preds)


YO_NO_ENTENDER = [("YO", 30, 70), ("NO", 70, 110), ("ENTENDER", 110, 160), (R, 160, 301)]


def test_decisor_acepta_con_estables_y_cierra_con_pausa():
    d = Decisor(umbral=0.75, estables=3, pausa_frase=1.0)
    for i, g in enumerate(["HOLA", "HOLA", "HOLA", R, R, R]):
        d.predecir(g, 0.9, i * 0.1)
    assert d.glosas == ["HOLA"]
    assert d.cerrar_si_pausa(0.5 + 0.9) is None      # reposo desde 0.5 s, aún no pasa 1 s
    assert d.cerrar_si_pausa(0.5 + 1.0) == ["HOLA"]
    assert d.glosas == [] and d.inicio_reposo is None


def test_decisor_ignora_poca_probabilidad_y_parpadeos():
    d = Decisor(umbral=0.75, estables=3)
    for g, p in [("HOLA", 0.9), ("HOLA", 0.5), ("HOLA", 0.9), ("HOLA", 0.9), ("NO", 0.9), ("HOLA", 0.9)]:
        d.predecir(g, p, 0)
    assert d.glosas == []


def test_simular_frase_simple():
    assert simular(toma(["YO", "NO", "ENTENDER"], segmentos(*YO_NO_ENTENDER)),
                   umbral=0.75, cada=3, estables=3, pausa_frase=1.2) == "No entiendo."


def test_simular_necesita_pausa_o_fin_de_toma():
    # sin reposo, la frase se cierra al terminar la toma
    t = toma(["YO", "NO", "ENTENDER"], segmentos(("YO", 30, 70), ("NO", 70, 110), ("ENTENDER", 110, 301)))
    assert simular(t, umbral=0.75, cada=3, estables=3, pausa_frase=1.2) == "No entiendo."


def test_simular_dos_frases_separadas_por_reposo():
    glosas = ["HOLA", "HOLA", R, "YO", "NO", "ENTENDER", "GRACIAS"]
    t = toma(glosas, segmentos(("HOLA", 30, 60), (R, 60, 110), ("YO", 110, 140), ("NO", 140, 170),
                               ("ENTENDER", 170, 210), ("GRACIAS", 210, 250), (R, 250, 301)))
    assert t.esperada == "Hola. No entiendo. Gracias."
    # Con una pausa corta se ven dos frases; el texto unido es el mismo
    assert simular(t, umbral=0.75, cada=3, estables=3, pausa_frase=1.0) == "Hola. No entiendo. Gracias."


def test_umbral_alto_rechaza_predicciones_dudosas():
    t = toma(["YO", "NO", "ENTENDER"], segmentos(*YO_NO_ENTENDER, prob=0.8))
    assert simular(t, umbral=0.75, cada=3, estables=3, pausa_frase=1.2) == "No entiendo."
    assert simular(t, umbral=0.9, cada=3, estables=3, pausa_frase=1.2) == ""


def test_una_glosa_mal_clasificada_falla_la_frase():
    preds = segmentos(("YO", 30, 70), ("SI", 70, 110), ("ENTENDER", 110, 160), (R, 160, 301))
    t = toma(["YO", "NO", "ENTENDER"], preds)
    assert simular(t, umbral=0.75, cada=3, estables=3, pausa_frase=1.2) != t.esperada


def test_evaluar_cuenta_por_persona_y_frase():
    bien = toma(["YO", "NO", "ENTENDER"], segmentos(*YO_NO_ENTENDER), persona="ana")
    mal = toma(["YO", "NO", "ENTENDER"], segmentos(("YO", 30, 70), (R, 70, 301)), persona="luis")
    r = evaluar([bien, mal], umbral=0.75, cada=3, estables=3, pausa_frase=1.2)
    assert (r.correctas, r.total, r.porcentaje) == (1, 2, 0.5)
    assert r.por_persona == {"ana": (1, 1), "luis": (0, 1)}
    assert r.por_frase == {"YO NO ENTENDER": (1, 2)}
    assert r.errores["YO NO ENTENDER"]["(nada)"] == 1 or r.errores["YO NO ENTENDER"]


def test_ajustar_ordena_por_frases_correctas():
    tomas = [toma(["YO", "NO", "ENTENDER"], segmentos(*YO_NO_ENTENDER, prob=0.8))]
    rejilla = {"umbral": [0.7, 0.9], "estables": [3], "pausa_frase": [1.2], "cada": [3]}
    mejores = ajustar(tomas, rejilla)
    assert mejores[0].parametros["umbral"] == 0.7 and mejores[0].correctas == 1
    assert mejores[-1].correctas == 0


def crudo(T):
    return {"mano_izq": np.zeros((T, 21, 3)), "mano_der": np.zeros((T, 21, 3)),
            "pose": np.zeros((T, 33, 3)), "cara": np.zeros((T, 478, 3))}


def test_predicciones_usa_ventanas_de_30_cuadros():
    vistos = []

    def modelo(x):
        vistos.append(x.shape)
        return "HOLA", 0.9, 0.0

    p = predicciones(modelo, crudo(40), {29, 30, 33, 40, 41})
    assert sorted(p) == [30, 33, 40]
    assert set(vistos) == {(C.LONGITUD_SECUENCIA, C.N_CARACTERISTICAS)}


def test_cargar_tomas_solo_frases_y_omite_deletreo(tmp_path):
    guardar(crudo(40), "equipo", "ana", ["HOLA"], raiz=tmp_path)                     # seña aislada
    guardar(crudo(40), "equipo", "ana", ["YO", "NO", "ENTENDER"], raiz=tmp_path)     # frase
    guardar(crudo(40), "equipo", "ana", ["HOLA", "YO", "A", "N", "A"], raiz=tmp_path)  # deletreo
    guardar(crudo(40), "equipo", "luis", ["YO", "NO", "ENTENDER"], raiz=tmp_path)    # sin modelo
    modelo = lambda x: ("YO", 0.9, 0.0)  # noqa: E731
    tomas, omitidas = cargar_tomas({"ana": modelo}, [3], raiz=tmp_path)
    assert [(t.persona, t.esperada) for t in tomas] == [("ana", "No entiendo.")]
    assert omitidas == ["HOLA YO A N A"]
    assert tomas[0].fps == C.FPS_OBJETIVO and tomas[0].n_cuadros == 40


def test_a_fps_sube_y_baja_la_velocidad():
    raw = {"mano_izq": np.arange(10, dtype=float).reshape(10, 1, 1), "mano_der": np.zeros((10, 1, 1))}
    arriba = a_fps(raw, fps=10, objetivo=20)
    assert len(arriba["mano_izq"]) == 20
    assert arriba["mano_izq"][:4, 0, 0].tolist() == [0, 0, 1, 1]
    abajo = a_fps(raw, fps=20, objetivo=10)
    assert abajo["mano_izq"][:, 0, 0].tolist() == [0, 2, 4, 6, 8]


def test_cargar_tomas_remuestrea_a_fps(tmp_path):
    guardar(crudo(50), "equipo", "ana", ["YO", "NO", "ENTENDER"], fps=10.0, raiz=tmp_path)
    modelo = lambda x: ("YO", 0.9, 0.0)  # noqa: E731
    tomas, _ = cargar_tomas({"ana": modelo}, [3], raiz=tmp_path, fps=20)
    assert tomas[0].n_cuadros == 100 and tomas[0].fps == 20
    tomas, _ = cargar_tomas({"ana": modelo}, [3], raiz=tmp_path)
    assert tomas[0].n_cuadros == 50 and tomas[0].fps == 10.0


def test_glosas_en_orden():
    assert glosas_en_orden(["YO", "NO", "ENTENDER"], ["YO", "NO", "ENTENDER"]) == 3
    assert glosas_en_orden(["YO", "NO", "ENTENDER"], ["YO", "ENTENDER"]) == 2
    assert glosas_en_orden(["YO", "NO", "ENTENDER"], ["ENTENDER", "NO", "YO"]) == 1
    assert glosas_en_orden(["YO"], []) == 0


def test_evaluar_reporta_glosas_reconocidas():
    mal = toma(["YO", "NO", "ENTENDER"], segmentos(("YO", 30, 70), (R, 70, 110), ("ENTENDER", 110, 160), (R, 160, 301)))
    r = evaluar([mal], umbral=0.75, cada=3, estables=3, pausa_frase=1.2)
    assert r.glosas["YO NO ENTENDER"] == (2, 3)
    assert r.errores["YO NO ENTENDER"]["YO | ENTENDER"] == 1
