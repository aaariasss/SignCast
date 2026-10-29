from __future__ import annotations

import keras
from keras import layers

from . import config as C


@keras.saving.register_keras_serializable(package="signcast")
class PosicionAprendida(layers.Layer):

    def __init__(self, longitud: int, dim: int, **kwargs):
        super().__init__(**kwargs)
        self.longitud, self.dim = longitud, dim
        self.emb = layers.Embedding(longitud, dim)

    def call(self, x):
        posiciones = keras.ops.arange(self.longitud)
        return x + self.emb(posiciones)

    def get_config(self):
        return {**super().get_config(), "longitud": self.longitud, "dim": self.dim}


@keras.saving.register_keras_serializable(package="signcast")
class SeleccionarColumnas(layers.Layer):
    """Conserva solo las columnas de los rangos [ini, fin)."""

    def __init__(self, rangos, **kwargs):
        super().__init__(**kwargs)
        self.rangos = [[int(a), int(b)] for a, b in rangos]

    def call(self, x):
        return keras.ops.concatenate([x[:, :, a:b] for a, b in self.rangos], axis=-1)

    def compute_output_shape(self, input_shape):
        return (*input_shape[:-1], sum(b - a for a, b in self.rangos))

    def get_config(self):
        return {**super().get_config(), "rangos": self.rangos}


@keras.saving.register_keras_serializable(package="signcast")
class Velocidad(layers.Layer):
    """Agrega a cada cuadro la diferencia con el cuadro anterior (el primero lleva ceros)."""

    def __init__(self, escala: float = 10.0, **kwargs):
        super().__init__(**kwargs)
        self.escala = float(escala)

    def call(self, x):
        ops = keras.ops
        d = (x[:, 1:, :] - x[:, :-1, :]) * self.escala
        d = ops.concatenate([ops.zeros_like(x[:, :1, :]), d], axis=1)
        return ops.concatenate([x, d], axis=-1)

    def compute_output_shape(self, input_shape):
        return (*input_shape[:-1], input_shape[-1] * 2)

    def get_config(self):
        return {**super().get_config(), "escala": self.escala}


def _preparar(ent, velocidad: bool, reducir: bool):
    """Preprocesa dentro del modelo; la entrada de la app sigue siendo (30, 270)."""
    x = ent
    if reducir:
        x = SeleccionarColumnas(C.COLUMNAS_REDUCIDAS)(x)
    if velocidad:
        x = Velocidad()(x)
    return x


def crear_lstm(n_clases: int, longitud: int = C.LONGITUD_SECUENCIA,
               n_caract: int = C.N_CARACTERISTICAS, velocidad: bool = False,
               reducir: bool = False) -> keras.Model:
    ent = keras.Input((longitud, n_caract), name="puntos")
    x = layers.Dense(128, activation="relu")(_preparar(ent, velocidad, reducir))
    x = layers.Dropout(0.2)(x)
    x = layers.LSTM(128, return_sequences=True)(x)
    x = layers.LSTM(96)(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(64, activation="relu")(x)
    sal = layers.Dense(n_clases, activation="softmax", name="clase")(x)
    return keras.Model(ent, sal, name="senas_lstm")


def crear_transformer(n_clases: int, longitud: int = C.LONGITUD_SECUENCIA,
                      n_caract: int = C.N_CARACTERISTICAS, dim: int = 96,
                      cabezas: int = 4, bloques: int = 2, velocidad: bool = False,
                      reducir: bool = False) -> keras.Model:
    ent = keras.Input((longitud, n_caract), name="puntos")
    x = layers.Dense(dim)(_preparar(ent, velocidad, reducir))
    x = PosicionAprendida(longitud, dim)(x)
    for _ in range(bloques):
        a = layers.LayerNormalization(epsilon=1e-6)(x)
        a = layers.MultiHeadAttention(cabezas, key_dim=dim // cabezas, dropout=0.1)(a, a)
        x = layers.Add()([x, a])
        f = layers.LayerNormalization(epsilon=1e-6)(x)
        f = layers.Dense(dim * 2, activation="gelu")(f)
        f = layers.Dense(dim)(f)
        x = layers.Add()([x, layers.Dropout(0.1)(f)])
    x = layers.LayerNormalization(epsilon=1e-6)(x)
    x = layers.GlobalAveragePooling1D()(x)
    x = layers.Dropout(0.3)(x)
    sal = layers.Dense(n_clases, activation="softmax", name="clase")(x)
    return keras.Model(ent, sal, name="senas_transformer")


def crear_mlp_alfabeto(n_clases: int, n_caract: int = C.N_CARACTERISTICAS_MANO) -> keras.Model:
    ent = keras.Input((n_caract,), name="mano")
    x = layers.Dense(256, activation="relu")(ent)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(128, activation="relu")(x)
    x = layers.Dropout(0.3)(x)
    sal = layers.Dense(n_clases, activation="softmax", name="letra")(x)
    return keras.Model(ent, sal, name="alfabeto_mlp")


ARQUITECTURAS = {"lstm": crear_lstm, "transformer": crear_transformer}
