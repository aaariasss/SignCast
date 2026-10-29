import numpy as np
import pytest

keras = pytest.importorskip("keras")

from signcast import config as C  # noqa: E402
from signcast.modelos import crear_lstm, crear_mlp_alfabeto, crear_transformer  # noqa: E402


@pytest.mark.parametrize("crear", [crear_lstm, crear_transformer])
def test_modelos_de_senas(crear, tmp_path):
    m = crear(5)
    x = np.random.default_rng(0).normal(size=(4, C.LONGITUD_SECUENCIA, C.N_CARACTERISTICAS))
    m.compile("adam", "sparse_categorical_crossentropy")
    m.fit(x, np.array([0, 1, 2, 3]), epochs=1, verbose=0)
    p = m.predict(x, verbose=0)
    assert p.shape == (4, 5)
    np.testing.assert_allclose(p.sum(axis=1), 1, rtol=1e-4)
    m.save(tmp_path / "m.keras")
    m2 = keras.models.load_model(tmp_path / "m.keras")
    np.testing.assert_allclose(m2.predict(x, verbose=0), p, rtol=1e-4, atol=1e-5)


def test_alfabeto():
    m = crear_mlp_alfabeto(21)
    assert m.predict(np.zeros((2, C.N_CARACTERISTICAS_MANO)), verbose=0).shape == (2, 21)


@pytest.mark.parametrize("crear", [crear_lstm, crear_transformer])
@pytest.mark.parametrize("velocidad,reducir", [(True, False), (False, True), (True, True)])
def test_modelos_con_velocidad_y_columnas_reducidas(crear, velocidad, reducir, tmp_path):
    m = crear(5, velocidad=velocidad, reducir=reducir)
    assert m.input_shape == (None, C.LONGITUD_SECUENCIA, C.N_CARACTERISTICAS)
    x = np.random.default_rng(0).normal(size=(4, C.LONGITUD_SECUENCIA, C.N_CARACTERISTICAS))
    p = m.predict(x, verbose=0)
    assert p.shape == (4, 5) and not np.isnan(p).any()
    m.save(tmp_path / "m.keras")
    m2 = keras.models.load_model(tmp_path / "m.keras")
    np.testing.assert_allclose(m2.predict(x, verbose=0), p, rtol=1e-4, atol=1e-5)


def test_capas_de_preprocesado():
    from signcast.modelos import SeleccionarColumnas, Velocidad
    x = np.arange(2 * 4 * 6, dtype="float32").reshape(2, 4, 6)
    v = keras.ops.convert_to_numpy(Velocidad(escala=1.0)(x))
    assert v.shape == (2, 4, 12)
    np.testing.assert_allclose(v[:, :, :6], x)
    np.testing.assert_allclose(v[:, 0, 6:], 0)
    np.testing.assert_allclose(v[:, 1:, 6:], x[:, 1:] - x[:, :-1])
    s = keras.ops.convert_to_numpy(SeleccionarColumnas([[0, 2], [4, 6]])(x))
    np.testing.assert_allclose(s, x[:, :, [0, 1, 4, 5]])
