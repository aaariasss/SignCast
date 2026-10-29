from signcast.comparar_aumento import escribir_seccion, mejor, resumir, seccion


def corrida(exac, f1, por_clase):
    return {"exactitud": exac, "f1_macro": f1, "f1_por_clase": por_clase}


def resumen_falso():
    return {
        0: resumir([corrida(0.80, 0.70, {"A": 0.9, "B": 0.5}), corrida(0.82, 0.72, {"A": 0.9, "B": 0.5})]),
        3: resumir([corrida(0.88, 0.84, {"A": 0.9, "B": 0.8}), corrida(0.90, 0.86, {"A": 0.9, "B": 0.8})]),
    }


def test_resumir_media_y_desviacion():
    r = resumen_falso()[0]
    assert abs(r["exactitud"][0] - 0.81) < 1e-9 and abs(r["exactitud"][1] - 0.01) < 1e-9
    assert r["f1_por_clase"] == {"A": 0.9, "B": 0.5}


def test_mejor_prefiere_menos_copias_en_empate():
    igual = {2: resumir([corrida(0.9, 0.8, {"A": 1.0})]), 0: resumir([corrida(0.9, 0.8, {"A": 1.0})])}
    assert mejor(igual) == 0
    assert mejor(resumen_falso()) == 3


def test_seccion_tiene_tabla_y_clases_que_cambian():
    texto = seccion("Aumento de datos: Alfabeto", ["valeria"], 2, resumen_falso())
    assert "| 0 | 0.810 ± 0.010 | 0.710 ± 0.010 | no |" in texto
    assert "| 3 | 0.890 ± 0.010 | 0.850 ± 0.010 | sí |" in texto
    assert "- B: 0.50 → 0.80" in texto and "Mejor: 3 copias." in texto


def test_escribir_seccion_reemplaza_solo_su_bloque(tmp_path):
    ruta = tmp_path / "resultados.md"
    ruta.write_text("# Resultados\n\nTexto previo\n", encoding="utf-8")
    escribir_seccion(ruta, "aumento-senas", "uno")
    escribir_seccion(ruta, "aumento-alfabeto", "otro")
    escribir_seccion(ruta, "aumento-senas", "dos")
    texto = ruta.read_text(encoding="utf-8")
    assert "Texto previo" in texto and "dos" in texto and "otro" in texto and "uno" not in texto
