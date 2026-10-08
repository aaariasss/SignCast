import pytest

from signcast.frases import construir_frase, limpiar, unir_deletreo

CASOS = [
    (["YO", "NO", "ENTENDER"], "No entiendo."),
    (["ENTENDER", "NO"], "No entiendo."),
    (["REPETIR", "POR-FAVOR"], "¿Puede repetir, por favor?"),
    (["AYUDAR", "YO", "POR-FAVOR"], "¿Me puede ayudar, por favor?"),
    (["YO", "PODER", "IR", "BANO"], "¿Puedo ir al baño?"),
    (["TAREA", "CUANDO"], "¿Cuándo es la tarea?"),
    (["BANO", "DONDE"], "¿Dónde está el baño?"),
    (["MANANA", "EXAMEN"], "Mañana hay examen."),
    (["YO", "TENER", "PREGUNTA"], "Tengo una pregunta."),
    (["MAESTRO", "REPETIR"], "El maestro repite."),
    (["MANANA", "YO", "IR", "CLASE"], "Mañana voy a la clase."),
    (["HOLA", "YO", "A", "N", "A"], "Hola. Soy Ana."),
    (["SI"], "Sí."),
    (["GRACIAS"], "Gracias."),
    (["HOLA", "HOLA", "_REPOSO", "YO", "NO", "ENTENDER", "GRACIAS"], "Hola. No entiendo. Gracias."),
]


@pytest.mark.parametrize("glosas,esperado", CASOS)
def test_construir_frase(glosas, esperado):
    assert construir_frase(glosas) == esperado


def test_limpiar_quita_repeticiones():
    assert limpiar(["HOLA", "HOLA", "HOLA", "TAREA"]) == ["HOLA", "TAREA"]


def test_deletreo_separado_por_reposo():
    assert unir_deletreo(["A", "N", "A", "_REPOSO", "L", "U", "Z"]) == ["#Ana", "#Luz"]


def test_vacio():
    assert construir_frase([]) == ""
    assert construir_frase(["_REPOSO"]) == ""
