from __future__ import annotations

from . import config as C

LETRAS = set("ABCDEFGHIJKLMNOPQRSTUVWXYZÑ")

SALUDOS = {"HOLA": "hola", "ADIOS": "adiós", "GRACIAS": "gracias"}
RESPUESTAS = {"SI": "sí", "NO": "no"}
INTERROGATIVOS = {"QUE": "qué", "DONDE": "dónde", "CUANDO": "cuándo", "COMO": "cómo"}
TIEMPO = {"HOY": "hoy", "MANANA": "mañana"}
SUJETOS = {"YO": 1, "TU": 2, "MAESTRO": 3, "COMPANERO": 3}
CLITICOS = {"YO": "me", "TU": "te"}

VERBOS = {
    "ENTENDER": ("entender", "entiendo", "entiendes", "entiende"),
    "REPETIR": ("repetir", "repito", "repites", "repite"),
    "AYUDAR": ("ayudar", "ayudo", "ayudas", "ayuda"),
    "PODER": ("poder", "puedo", "puedes", "puede"),
    "IR": ("ir", "voy", "vas", "va"),
    "TENER": ("tener", "tengo", "tienes", "tiene"),
}
PETICIONES = {"REPETIR", "AYUDAR"}

SUSTANTIVOS = {
    "MAESTRO": ("maestro", "m"), "COMPANERO": ("compañero", "m"), "CLASE": ("clase", "f"),
    "TAREA": ("tarea", "f"), "EXAMEN": ("examen", "m"), "PREGUNTA": ("pregunta", "f"),
    "BANO": ("baño", "m"),
}


def limpiar(glosas: list[str]) -> list[str]:
    salida: list[str] = []
    for g in glosas:
        if g == C.CLASE_REPOSO:
            salida.append(g)          
            continue
        if salida and salida[-1] == g:
            continue
        salida.append(g)
    return salida


def unir_deletreo(glosas: list[str]) -> list[str]:
    salida, palabra = [], ""
    for g in glosas + [C.CLASE_REPOSO]:
        if g in LETRAS:
            palabra += g
            continue
        if palabra:
            salida.append("#" + palabra.capitalize())
            palabra = ""
        if g != C.CLASE_REPOSO:
            salida.append(g)
    return salida


def _articulo(glosa: str, indefinido: bool = False) -> str:
    palabra, genero = SUSTANTIVOS[glosa]
    if indefinido:
        return f"{'un' if genero == 'm' else 'una'} {palabra}"
    return f"{'el' if genero == 'm' else 'la'} {palabra}"


def _capitalizar(texto: str) -> str:
    for i, ch in enumerate(texto):
        if ch.isalpha():
            return texto[:i] + ch.upper() + texto[i + 1:]
    return texto


def construir_frase(glosas: list[str]) -> str:
    tokens = unir_deletreo(limpiar(glosas))
    if not tokens:
        return ""

    inicio = []
    while tokens and tokens[0] in SALUDOS:
        inicio.append(SALUDOS[tokens.pop(0)])
    por_favor = "POR-FAVOR" in tokens
    tokens = [t for t in tokens if t != "POR-FAVOR"]
    cierre = []
    while tokens and tokens[-1] in SALUDOS:
        cierre.insert(0, SALUDOS[tokens.pop()])

    if len(tokens) == 1 and tokens[0] in RESPUESTAS:
        return _unir(inicio, _cerrar([RESPUESTAS[tokens[0]]], por_favor=por_favor), cierre)
    if not tokens:
        return _unir([], _cerrar(inicio + cierre, por_favor=por_favor), [])

    interrogativo = next((t for t in tokens if t in INTERROGATIVOS), None)
    negacion = "NO" in tokens
    tiempo = [TIEMPO[t] for t in tokens if t in TIEMPO]
    verbos = [t for t in tokens if t in VERBOS]
    nombres = [t[1:] for t in tokens if t.startswith("#")]

    sujeto = None
    cliticos = []
    sustantivos = []
    for i, t in enumerate(tokens):
        if t in SUJETOS and sujeto is None and (not verbos or i < tokens.index(verbos[0])):
            sujeto = t
        elif t in CLITICOS and verbos and i > tokens.index(verbos[0]):
            cliticos.append(CLITICOS[t])
        elif t in SUSTANTIVOS:
            sustantivos.append(t)

    persona = SUJETOS.get(sujeto, 0)
    es_pregunta = interrogativo is not None
    partes: list[str] = []

    if sujeto in SUSTANTIVOS:                       
        partes.append(_articulo(sujeto))

    # 3. Verbo
    if verbos:
        principal, resto = verbos[0], verbos[1:]
        if principal in PETICIONES and persona == 0:
            es_pregunta = True
            nucleo = ["puede", VERBOS[principal][0]]
        elif principal == "PODER" and resto:
            nucleo = [VERBOS["PODER"][persona or 1], VERBOS[resto[0]][0]]
            es_pregunta = es_pregunta or persona in (0, 1)   # pedir permiso
        else:
            nucleo = [VERBOS[principal][persona or 1]]
        if negacion:
            partes.append("no")
        partes += cliticos + nucleo
        indefinido = principal == "TENER"
        for s in sustantivos:
            frase_nominal = _articulo(s, indefinido=indefinido)
            if "IR" in verbos:                        
                frase_nominal = ("al" + frase_nominal[2:]) if frase_nominal.startswith("el ") \
                    else "a " + frase_nominal
            partes.append(frase_nominal)
    else:
        if sujeto == "YO" and nombres:
            partes.append("soy")
        elif interrogativo:
            partes.append("está" if interrogativo == "DONDE" else "es")
        elif tiempo and sustantivos:
            partes.append("hay")
        if negacion:
            partes.insert(0, "no")
        for s in sustantivos:
            partes.append(SUSTANTIVOS[s][0] if (tiempo and not interrogativo) else _articulo(s))

    partes += nombres
    if interrogativo:
        partes.insert(0, INTERROGATIVOS[interrogativo])
    partes = tiempo + partes if tiempo else partes

    return _unir(inicio, _cerrar([" ".join(partes)], es_pregunta, por_favor), cierre)


def _unir(inicio: list[str], cuerpo: str, cierre: list[str]) -> str:
    """'Hola.' + cuerpo + 'Gracias.'"""
    piezas = [_cerrar(inicio)] if inicio else []
    piezas.append(cuerpo)
    if cierre:
        piezas.append(_cerrar(cierre))
    return " ".join(piezas)


def _cerrar(partes: list[str], pregunta: bool = False, por_favor: bool = False) -> str:
    texto = ", ".join(p for p in partes if p)
    if por_favor:
        texto = f"{texto}, por favor" if texto else "por favor"
    texto = _capitalizar(texto)
    return f"¿{texto}?" if pregunta else f"{texto}."
