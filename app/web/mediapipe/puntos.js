// Detección de manos, pose y rostro con MediaPipe Tasks Vision (web). Entrega
// el mismo arreglo plano que recibe `CuadroPuntos.desdePlano` en Dart y usa la
// misma configuración que `Extractor(modo="video")` de ml/signcast.
//
// Los archivos de MediaPipe (vision_bundle.js, wasm/ y modelos/) no están en el
// repo: se copian con app/tool/preparar_mediapipe_web.ps1. Se sirven desde el
// propio sitio, no desde un CDN, para que la app funcione sin internet.
//
// Dart lo usa a través de `window.signcastPuntos`.
import {
  FilesetResolver,
  HandLandmarker,
  PoseLandmarker,
  FaceLandmarker,
} from "./vision_bundle.js";

const BASE = new URL("./", import.meta.url).href;

const PUNTOS_MANO = 21;
const PUNTOS_POSE = 33;
const PUNTOS_CARA = 478;
const OFFSET_POSE = 2 * PUNTOS_MANO * 3;
const OFFSET_CARA = OFFSET_POSE + PUNTOS_POSE * 3;
// 1659, igual que CuadroPuntos.longitudPlano en Dart.
const LONGITUD = OFFSET_CARA + PUNTOS_CARA * 3;

let detectores = null;
let delegadoActual = "CPU";
let video = null;
let flujo = null;
let alCuadro = null;
let corriendo = false;
let ultimoTiempoVideo = -1;
let numeroCuadro = 0;
let ultimoProceso = 0;

// El rostro es el modelo más pesado y el entrenamiento no lo usa: por defecto
// ni se carga (sus valores quedan en NaN). Con ?concara se vuelve a activar.
const SIN_CARA = !new URLSearchParams(location.search).has("concara");
// Máximo ~20 cuadros por segundo: sin tope el iPhone se calienta y baja solo.
const INTERVALO_MIN_MS = 50;

// Pose y rostro no se calculan en todos los cuadros; se conserva el último.
const ultimaPose = new Float32Array(PUNTOS_POSE * 3).fill(NaN);
const ultimoRostro = new Float32Array(PUNTOS_CARA * 3).fill(NaN);

/** Carga los tres modelos. Usa la GPU y, si falla, la CPU. */
async function cargarModelos() {
  if (detectores) return;
  const vision = await FilesetResolver.forVisionTasks(BASE + "wasm");
  const crear = async (gpu) => {
    const base = (archivo) => ({
      modelAssetPath: BASE + "modelos/" + archivo,
      delegate: gpu ? "GPU" : "CPU",
    });
    const manos = await HandLandmarker.createFromOptions(vision, {
      baseOptions: base("hand_landmarker.task"),
      runningMode: "VIDEO",
      numHands: 2,
      minHandDetectionConfidence: 0.5,
      minHandPresenceConfidence: 0.5,
      minTrackingConfidence: 0.5,
    });
    const pose = await PoseLandmarker.createFromOptions(vision, {
      baseOptions: base("pose_landmarker_lite.task"),
      runningMode: "VIDEO",
      numPoses: 1,
    });
    const rostro = SIN_CARA
      ? null
      : await FaceLandmarker.createFromOptions(vision, {
          baseOptions: base("face_landmarker.task"),
          runningMode: "VIDEO",
          numFaces: 1,
        });
    return { manos, pose, rostro };
  };
  try {
    detectores = await crear(true);
    delegadoActual = "GPU";
  } catch (e) {
    console.warn("SignCast: la GPU no está disponible, se usa la CPU", e);
    detectores = await crear(false);
    delegadoActual = "CPU";
  }
}

/**
 * Pide el permiso de la cámara y lo suelta enseguida. Hay que llamarlo desde
 * un toque del usuario (Safari lo exige) y devuelve si se concedió.
 */
async function pedirPermiso() {
  try {
    const prueba = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: "user" },
      audio: false,
    });
    prueba.getTracks().forEach((t) => t.stop());
    return true;
  } catch (e) {
    console.warn("SignCast: permiso de cámara no concedido", e);
    return false;
  }
}

/**
 * Abre la cámara frontal y muestra el video a pantalla completa. Se ve como
 * espejo, pero la detección usa la imagen sin voltear, como en Python.
 */
async function abrirCamara() {
  detener();
  flujo = await navigator.mediaDevices.getUserMedia({
    video: {
      facingMode: "user",
      width: { ideal: 480 },
      height: { ideal: 360 },
      frameRate: { ideal: 30 },
    },
    audio: false,
  });
  video = document.createElement("video");
  video.setAttribute("playsinline", "");
  video.muted = true;
  video.autoplay = true;
  video.srcObject = flujo;
  // El video va directo en la página, detrás del lienzo de Flutter (que es
  // transparente en la pestaña del traductor). Una vista incrustada de Flutter
  // fallaba al cambiar de pestaña.
  Object.assign(video.style, {
    position: "fixed",
    left: "0",
    top: "0",
    right: "0",
    bottom: "0",
    width: "100%",
    height: "100%",
    zIndex: "-1",
    objectFit: "cover",
    transform: "scaleX(-1)",
    background: "#000",
  });
  video.addEventListener("pause", () => {
    if (flujo) video.play().catch(() => {});
  });
  document.body.appendChild(video);
  await new Promise((resolve) => {
    if (video.readyState >= 1) resolve();
    else video.addEventListener("loadedmetadata", () => resolve(), { once: true });
  });
  try {
    await video.play();
  } catch (_) {
    // Safari puede negarse; el evento `pause` de arriba lo reanuda.
  }
}

function copiar(puntos, salida, inicio, maximo) {
  const n = Math.min(puntos.length, maximo);
  for (let i = 0; i < n; i++) {
    salida[inicio + i * 3] = puntos[i].x;
    salida[inicio + i * 3 + 1] = puntos[i].y;
    salida[inicio + i * 3 + 2] = puntos[i].z;
  }
}

/**
 * Arma el cuadro: mano izquierda, mano derecha, pose y rostro (NaN si falta).
 * La etiqueta Left/Right se usa tal cual la da MediaPipe, con la misma regla
 * que Python y DetectorPuntos.kt.
 */
function procesar() {
  const ts = performance.now();
  const salida = new Float32Array(LONGITUD).fill(NaN);

  const rm = detectores.manos.detectForVideo(video, ts);
  let izqLibre = true;
  let derLibre = true;
  rm.landmarks.forEach((puntos, i) => {
    const etiqueta = rm.handedness[i][0].categoryName;
    let destino;
    if (etiqueta === "Left" && izqLibre) destino = 0;
    else if (derLibre) destino = 1;
    else destino = 0;
    if (destino === 0) izqLibre = false;
    else derLibre = false;
    copiar(puntos, salida, destino * PUNTOS_MANO * 3, PUNTOS_MANO);
  });

  numeroCuadro++;
  // La pose solo aporta hombros y nariz (lo demás sale de las manos).
  if (numeroCuadro % 3 === 0) {
    const rp = detectores.pose.detectForVideo(video, ts);
    ultimaPose.fill(NaN);
    if (rp.landmarks.length > 0) {
      copiar(rp.landmarks[0], ultimaPose, 0, PUNTOS_POSE);
    }
  } else if (!SIN_CARA) {
    const rc = detectores.rostro.detectForVideo(video, ts);
    ultimoRostro.fill(NaN);
    if (rc.faceLandmarks.length > 0) {
      copiar(rc.faceLandmarks[0], ultimoRostro, 0, PUNTOS_CARA);
    }
  }
  salida.set(ultimaPose, OFFSET_POSE);
  salida.set(ultimoRostro, OFFSET_CARA);
  return salida;
}

function ciclo() {
  if (!corriendo) return;
  if (
    video &&
    performance.now() - ultimoProceso >= INTERVALO_MIN_MS &&
    video.readyState >= 2 &&
    !video.paused &&
    video.currentTime !== ultimoTiempoVideo
  ) {
    ultimoTiempoVideo = video.currentTime;
    ultimoProceso = performance.now();
    try {
      alCuadro(procesar());
    } catch (e) {
      console.warn("SignCast: error al procesar el cuadro", e);
    }
  }
  requestAnimationFrame(ciclo);
}

/** Empieza a mandar un arreglo de 1659 valores por cada imagen procesada. */
function suscribir(callback) {
  alCuadro = callback;
  if (corriendo) return;
  corriendo = true;
  requestAnimationFrame(ciclo);
}

/** Pausa o reanuda la detección sin apagar la cámara. */
function pausar(pausado) {
  if (pausado) {
    corriendo = false;
  } else if (alCuadro && !corriendo) {
    if (video && video.paused) video.play().catch(() => {});
    corriendo = true;
    requestAnimationFrame(ciclo);
  }
}

/** Detiene la detección y apaga la cámara. */
function detener() {
  corriendo = false;
  alCuadro = null;
  if (flujo) {
    flujo.getTracks().forEach((t) => t.stop());
    flujo = null;
  }
  if (video) {
    video.srcObject = null;
    video.remove();
    video = null;
  }
}

window.signcastPuntos = {
  cargarModelos,
  pedirPermiso,
  abrirCamara,
  suscribir,
  pausar,
  detener,
  get ancho() {
    return video ? video.videoWidth : 0;
  },
  get alto() {
    return video ? video.videoHeight : 0;
  },
  get delegado() {
    return delegadoActual;
  },
};
