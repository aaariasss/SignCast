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


def crear_lstm(n_clases: int, longitud: int = C.LONGITUD_SECUENCIA,
               n_caract: int = C.N_CARACTERISTICAS) -> keras.Model:
    ent = keras.Input((longitud, n_caract), name="puntos")
    x = layers.Dense(128, activation="relu")(ent)
    x = layers.Dropout(0.2)(x)
    x = layers.LSTM(128, return_sequences=True)(x)
    x = layers.LSTM(96)(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(64, activation="relu")(x)
    sal = layers.Dense(n_clases, activation="softmax", name="clase")(x)
    return keras.Model(ent, sal, name="senas_lstm")


def crear_transformer(n_clases: int, longitud: int = C.LONGITUD_SECUENCIA,
                      n_caract: int = C.N_CARACTERISTICAS, dim: int = 96,
                      cabezas: int = 4, bloques: int = 2) -> keras.Model:
    ent = keras.Input((longitud, n_caract), name="puntos")
    x = layers.Dense(dim)(ent)
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
