from pathlib import Path

RAIZ_REPO = Path(__file__).resolve().parents[2]
DIR_ML = RAIZ_REPO / "ml"
DIR_DATOS = RAIZ_REPO / "data"
DIR_RAW = DIR_DATOS / "raw"
DIR_PROCESADO = DIR_DATOS / "procesado"
DIR_MODELOS = RAIZ_REPO / "modelos"
DIR_MEDIAPIPE = DIR_ML / "mediapipe_modelos"
VOCABULARIO = DIR_ML / "vocabulario.csv"

# Secuencias
LONGITUD_SECUENCIA = 30          # cuadros por muestra (~1 s a 30 fps)
FPS_OBJETIVO = 30

# Puntos clave usados
PUNTOS_MANO = 21

# Pose: nariz, hombros, codos, muñecas, caderas
INDICES_POSE = [0, 11, 12, 13, 14, 15, 16, 23, 24]
HOMBRO_IZQ, HOMBRO_DER = 11, 12

# Rostro
INDICES_CARA = [
    # labios
    61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409, 270, 269, 267, 0, 37, 39, 40, 185,
    # cejas
    70, 63, 105, 66, 107, 336, 296, 334, 293, 300,
    # ojos
    33, 133, 159, 145, 362, 263, 386, 374,
    # nariz
    1,
]

N_PUNTOS = 2 * PUNTOS_MANO + len(INDICES_POSE) + len(INDICES_CARA)   # 90
N_CARACTERISTICAS = N_PUNTOS * 3                                       # 270
N_CARACTERISTICAS_MANO = PUNTOS_MANO * 3                               # 63

# Columnas del rostro dentro del vector. El modelo de señas no las usa: la app web no carga
# el modelo de rostro y las manda en cero, así que el entrenamiento también las pone en cero.
COLUMNAS_ROSTRO = slice(2 * PUNTOS_MANO * 3 + len(INDICES_POSE) * 3, N_CARACTERISTICAS)

# Columnas que conserva la opción de modelo reducido: manos, nariz y codos (rangos [ini, fin)).
_INI_POSE = 2 * PUNTOS_MANO * 3
COLUMNAS_REDUCIDAS = [(0, _INI_POSE), (_INI_POSE, _INI_POSE + 3), (_INI_POSE + 9, _INI_POSE + 15)]

# Modelos de MediaPipe Tasks
URLS_MEDIAPIPE = {
    "hand_landmarker.task": "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/latest/hand_landmarker.task",
    "pose_landmarker_lite.task": "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task",
    "face_landmarker.task": "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task",
}

CLASE_REPOSO = "_REPOSO"
