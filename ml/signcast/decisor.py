"""Decide qué glosas se aceptan y cuándo se cierra una frase, a partir de las predicciones del modelo.

Es la lógica que usa `tiempo_real.py` en vivo. `evaluar_frases.py` la reutiliza para medir
cuántas frases se traducen bien, así que cualquier cambio aquí cambia las dos cosas.

Parámetros (los mismos que debe usar la app):
- umbral: probabilidad mínima para tomar una predicción; si no la alcanza cuenta como "nada".
- estables: predicciones iguales seguidas que hacen falta para aceptar una glosa.
- pausa_frase: segundos seguidos de `_REPOSO` que cierran la frase.
"""
from __future__ import annotations

from collections import deque

from . import config as C


class Decisor:
    def __init__(self, umbral: float = 0.8, estables: int = 3, pausa_frase: float = 1.2):
        self.umbral = umbral
        self.estables = estables
        self.pausa_frase = pausa_frase
        self.recientes: deque = deque(maxlen=estables)
        self.glosas: list[str] = []
        self.ultima_glosa: str | None = None
        self.inicio_reposo: float | None = None

    def predecir(self, glosa: str, prob: float, ahora: float) -> None:
        """Registra una predicción del modelo de señas hecha en el instante `ahora` (s)."""
        self.recientes.append(glosa if prob >= self.umbral else None)
        estable = len(self.recientes) == self.estables and len(set(self.recientes)) == 1
        actual = self.recientes[0]
        if estable and actual == C.CLASE_REPOSO:
            self.ultima_glosa = C.CLASE_REPOSO
            if self.inicio_reposo is None:
                self.inicio_reposo = ahora
        elif estable and actual and actual != self.ultima_glosa:
            self.glosas.append(actual)
            self.ultima_glosa = actual
            self.inicio_reposo = None

    def cerrar_si_pausa(self, ahora: float) -> list[str] | None:
        """Si ya pasó la pausa de reposo, devuelve las glosas de la frase y la reinicia."""
        if self.glosas and self.inicio_reposo is not None and ahora - self.inicio_reposo >= self.pausa_frase:
            return self.vaciar()
        return None

    def vaciar(self) -> list[str]:
        glosas, self.glosas, self.inicio_reposo = self.glosas, [], None
        return glosas
