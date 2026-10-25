from signcast import config as C
from signcast.progreso import contar, leer_frases, objetivos, reporte


def test_objetivos_cubren_todo():
    lista = objetivos()
    por_seccion = {s: [o for o in lista if o.seccion == s] for s in ("Señas", "Reposo", "Letras", "Frases")}
    assert len(por_seccion["Señas"]) == 27
    assert len(por_seccion["Reposo"]) == 1
    assert len(por_seccion["Letras"]) == 27
    assert len(por_seccion["Frases"]) == 13
    assert sum(o.meta for o in lista) == 27 * 20 + 20 + 27 * 5 + 13 * 10


def test_frases_md():
    frases = leer_frases()
    assert frases[0] == ["YO", "NO", "ENTENDER"]
    assert ["HOLA", "HOLA", C.CLASE_REPOSO, "YO", "NO", "ENTENDER", "GRACIAS"] in frases


def test_conteo_y_reporte(tmp_path):
    for carpeta, n in (("HOLA", 20), ("ADIOS", 3), ("YO_NO_ENTENDER", 10), ("HOLAA", 1)):
        (tmp_path / carpeta).mkdir()
        for i in range(n):
            (tmp_path / carpeta / f"{i}.npz").touch()

    conteo = contar(tmp_path)
    assert conteo["HOLA"] == 20 and conteo["ADIOS"] == 3

    texto = reporte("valeria", conteo, objetivos())
    assert "✓ HOLA " in texto
    assert "· ADIOS " in texto
    assert "HOLAA" in texto  # carpeta desconocida
    assert "--glosa ADIOS --repeticiones 17" in texto


def test_persona_sin_datos(tmp_path):
    assert contar(tmp_path / "nadie") == {}
