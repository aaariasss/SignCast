from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from . import config as C

N_POSE_TOTAL = 33
N_CARA_TOTAL = 478


# Puntos crudos
@dataclass
class Cuadro:
    mano_izq: np.ndarray = field(default_factory=lambda: _vacio(C.PUNTOS_MANO))
    mano_der: np.ndarray = field(default_factory=lambda: _vacio(C.PUNTOS_MANO))
    pose: np.ndarray = field(default_factory=lambda: _vacio(N_POSE_TOTAL))
    cara: np.ndarray = field(default_factory=lambda: _vacio(N_CARA_TOTAL))

    @property
    def hay_mano(self) -> bool:
        return not (np.isnan(self.mano_izq).all() and np.isnan(self.mano_der).all())


def _vacio(n: int) -> np.ndarray:
    return np.full((n, 3), np.nan, dtype=np.float32)


def _a_arreglo(landmarks) -> np.ndarray:
    return np.array([[p.x, p.y, p.z] for p in landmarks], dtype=np.float32)


def apilar(cuadros: list[Cuadro]) -> dict[str, np.ndarray]:
    return {
        "mano_izq": np.stack([c.mano_izq for c in cuadros]),
        "mano_der": np.stack([c.mano_der for c in cuadros]),
        "pose": np.stack([c.pose for c in cuadros]),
        "cara": np.stack([c.cara for c in cuadros]),
    }


class Extractor:

    def __init__(self, modo: str = "video", con_pose: bool = True, con_cara: bool = True,
                 num_manos: int = 2):
        import mediapipe as mp
        from mediapipe.tasks import python as mp_python
        from mediapipe.tasks.python import vision

        self._mp = mp
        self.modo = modo
        rm = vision.RunningMode.VIDEO if modo == "video" else vision.RunningMode.IMAGE

        def base(nombre: str):
            ruta = C.DIR_MEDIAPIPE / nombre
            if not ruta.exists():
                raise FileNotFoundError(
                    f"Falta {ruta}. Corre primero: python -m signcast.descargar_modelos")
            return mp_python.BaseOptions(model_asset_path=str(ruta))

        self._manos = vision.HandLandmarker.create_from_options(vision.HandLandmarkerOptions(
            base_options=base("hand_landmarker.task"), running_mode=rm, num_hands=num_manos,
            min_hand_detection_confidence=0.5, min_hand_presence_confidence=0.5,
            min_tracking_confidence=0.5))
        self._pose = vision.PoseLandmarker.create_from_options(vision.PoseLandmarkerOptions(
            base_options=base("pose_landmarker_lite.task"), running_mode=rm, num_poses=1)
        ) if con_pose else None
        self._cara = vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
            base_options=base("face_landmarker.task"), running_mode=rm, num_faces=1)
        ) if con_cara else None
        self._ultimo_ts = -1

    def procesar(self, cuadro_bgr: np.ndarray, timestamp_ms: int | None = None) -> Cuadro:
        import cv2

        rgb = cv2.cvtColor(cuadro_bgr, cv2.COLOR_BGR2RGB)
        imagen = self._mp.Image(image_format=self._mp.ImageFormat.SRGB, data=rgb)

        if self.modo == "video":
            ts = timestamp_ms if timestamp_ms is not None else self._ultimo_ts + 33
            ts = max(int(ts), self._ultimo_ts + 1)   # MediaPipe exige tiempos crecientes
            self._ultimo_ts = ts
            detectar = lambda tarea: tarea.detect_for_video(imagen, ts)  # noqa: E731
        else:
            detectar = lambda tarea: tarea.detect(imagen)  # noqa: E731

        salida = Cuadro()
        r = detectar(self._manos)
        for landmarks, lado in zip(r.hand_landmarks, r.handedness):
            puntos = _a_arreglo(landmarks)
            etiqueta = lado[0].category_name
            # Si MediaPipe etiqueta dos manos igual, la segunda va al hueco libre
            if etiqueta == "Left" and np.isnan(salida.mano_izq).all():
                salida.mano_izq = puntos
            elif np.isnan(salida.mano_der).all():
                salida.mano_der = puntos
            else:
                salida.mano_izq = puntos

        if self._pose is not None:
            r = detectar(self._pose)
            if r.pose_landmarks:
                salida.pose = _a_arreglo(r.pose_landmarks[0])
        if self._cara is not None:
            r = detectar(self._cara)
            if r.face_landmarks:
                salida.cara = _a_arreglo(r.face_landmarks[0])[:N_CARA_TOTAL]
        return salida

    def cerrar(self):
        for tarea in (self._manos, self._pose, self._cara):
            if tarea is not None:
                tarea.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.cerrar()


# Vectores para el modelo
def _rellenar(valores: np.ndarray) -> np.ndarray:
    """Rellena NaN hacia adelante y luego hacia atrás sobre el eje 0."""
    v = valores.copy()
    for t in range(1, len(v)):
        malos = np.isnan(v[t])
        v[t][malos] = v[t - 1][malos]
    for t in range(len(v) - 2, -1, -1):
        malos = np.isnan(v[t])
        v[t][malos] = v[t + 1][malos]
    return v


def caracteristicas_secuencia(raw: dict[str, np.ndarray]) -> np.ndarray:
    """Puntos crudos (T, N, 3) -> vector (T, 270) para el modelo de señas."""
    izq, der, pose, cara = raw["mano_izq"], raw["mano_der"], raw["pose"], raw["cara"]
    T = izq.shape[0]

    puntos = np.concatenate(
        [izq, der, pose[:, C.INDICES_POSE], cara[:, C.INDICES_CARA]], axis=1
    ).astype(np.float32)                                   # (T, 90, 3)

    h_izq, h_der = pose[:, C.HOMBRO_IZQ, :2], pose[:, C.HOMBRO_DER, :2]
    centro = (h_izq + h_der) / 2                           # (T, 2)
    escala = np.linalg.norm(h_izq - h_der, axis=1)         # (T,)

    centro = _rellenar(centro)
    escala = _rellenar(escala[:, None])[:, 0]
    if np.isnan(centro).any():                             # nunca se vio el cuerpo
        centro = np.full((T, 2), 0.5, dtype=np.float32)
    escala = np.where(np.isnan(escala) | (escala < 1e-3), 0.3, escala).astype(np.float32)

    salida = np.empty_like(puntos)
    salida[..., :2] = (puntos[..., :2] - centro[:, None, :]) / escala[:, None, None]
    salida[..., 2] = puntos[..., 2] / escala[:, None]
    salida = np.nan_to_num(salida, nan=0.0)
    return salida.reshape(T, C.N_CARACTERISTICAS)


def caracteristicas_mano(mano: np.ndarray) -> np.ndarray:
    """Una mano (21, 3) -> vector (63,) para el clasificador del alfabeto estático."""
    if np.isnan(mano).any():
        return np.zeros(C.N_CARACTERISTICAS_MANO, dtype=np.float32)
    rel = mano - mano[0]
    escala = np.linalg.norm(rel[:, :2], axis=1).max()
    if escala < 1e-6:
        return np.zeros(C.N_CARACTERISTICAS_MANO, dtype=np.float32)
    return (rel / escala).astype(np.float32).reshape(-1)


def mano_principal(cuadro: Cuadro) -> np.ndarray:
    candidatas = [m for m in (cuadro.mano_izq, cuadro.mano_der) if not np.isnan(m).all()]
    if not candidatas:
        return _vacio(C.PUNTOS_MANO)
    area = lambda m: np.ptp(m[:, 0]) * np.ptp(m[:, 1])  # noqa: E731
    return max(candidatas, key=area)
