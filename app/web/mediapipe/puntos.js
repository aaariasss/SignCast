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

// El rostro es el modelo más pesado y el modelo de señas no lo usa (el entrenamiento
// pone sus columnas en cero): por defecto ni se carga y sus valores quedan en NaN.
// Con ?concara se activa solo para pruebas.
const SIN_CARA = !new URLSearchParams(location.search).has("concara");
// Máximo ~20 cuadros por segundo: sin tope el iPhone se calienta y baja solo.
const INTERVALO_MIN_MS = 50;

// Pose y rostro no se calculan en todos los cuadros; se conserva el último.
const ultimaPose = new Float32Array(PUNTOS_POSE * 3).fill(NaN);
const ultimoRostro = new Float32Array(PUNTOS_CARA * 3).fill(NaN);

/** Carga los tres modelos. Usa la GPU y, si falla, la CPU. */
async function cargarModelosReal() {
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

let cargaModelos = null;

/** Igual que `cargarModelosReal`, pero si ya está cargando espera la misma carga. */
function cargarModelos() {
  if (detectores) return Promise.resolve();
  if (!cargaModelos) {
    cargaModelos = cargarModelosReal().catch((e) => {
      cargaModelos = null;
      throw e;
    });
  }
  return cargaModelos;
}

// Safari no deja consultar el permiso de la cámara sin pedirlo, así que además
// se recuerda en este navegador que ya se concedió una vez.
const CLAVE_CAMARA = "signcast.camara";

function recordarCamara(concedida) {
  try {
    if (concedida) localStorage.setItem(CLAVE_CAMARA, "1");
    else localStorage.removeItem(CLAVE_CAMARA);
  } catch (_) {
    // Sin almacenamiento (modo privado): simplemente no se recuerda.
  }
}

function camaraRecordada() {
  try {
    return localStorage.getItem(CLAVE_CAMARA) === "1";
  } catch (_) {
    return false;
  }
}

/**
 * Estado del permiso sin mostrar ningún aviso: "granted", "denied" o "prompt".
 * Usa la API de permisos si el navegador la tiene y, si no, lo que se recordó.
 */
async function estadoPermiso() {
  try {
    if (navigator.permissions && navigator.permissions.query) {
      const r = await navigator.permissions.query({ name: "camera" });
      if (r.state === "granted") return "granted";
      if (r.state === "denied") {
        recordarCamara(false);
        return "denied";
      }
    }
  } catch (_) {
    // Safari viejo: no conoce el permiso "camera".
  }
  return camaraRecordada() ? "granted" : "prompt";
}

// iOS dibuja un botón de play/pausa encima de un video pausado (pasa unos
// instantes al abrir o reabrir la cámara). Se oculta con CSS.
const estiloVideo = document.createElement("style");
estiloVideo.textContent =
  "video::-webkit-media-controls," +
  "video::-webkit-media-controls-panel," +
  "video::-webkit-media-controls-play-button," +
  "video::-webkit-media-controls-start-playback-button," +
  "video::-webkit-media-controls-overlay-play-button" +
  "{display:none!important;opacity:0!important;pointer-events:none!important;-webkit-appearance:none}";
document.head.appendChild(estiloVideo);

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
    recordarCamara(true);
    return true;
  } catch (e) {
    if (e && e.name === "NotAllowedError") recordarCamara(false);
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
  try {
    flujo = await navigator.mediaDevices.getUserMedia({
      video: {
        facingMode: "user",
        width: { ideal: 480 },
        height: { ideal: 360 },
        frameRate: { ideal: 30 },
      },
      audio: false,
    });
  } catch (e) {
    // Si el permiso ya no está, la próxima vez se vuelve a pasar por la pantalla del permiso.
    if (e && e.name === "NotAllowedError") recordarCamara(false);
    throw e;
  }
  recordarCamara(true);
  video = document.createElement("video");
  video.setAttribute("playsinline", "");
  video.controls = false;
  video.disablePictureInPicture = true;
  video.setAttribute("disableRemotePlayback", "");
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
    // Oculto hasta que el tamaño del video se estabilice (ver más abajo).
    opacity: "0",
    transition: "opacity .25s ease-out",
  });
  video.addEventListener("pause", () => {
    if (flujo) video.play().catch(() => {});
  });
  document.body.appendChild(video);
  ajustarVideo();
  await new Promise((resolve) => {
    if (video.readyState >= 1) resolve();
    else video.addEventListener("loadedmetadata", () => resolve(), { once: true });
  });
  try {
    await video.play();
  } catch (_) {
    // Safari puede negarse; el evento `pause` de arriba lo reanuda.
  }
  // Al abrir, Safari a veces entrega el video con otro tamaño u orientación y
  // lo corrige unos segundos después, y con `object-fit: cover` eso se ve como
  // un acercamiento enorme. Se espera a que el tamaño deje de cambiar y
  // entonces se muestra con una transición suave.
  await esperarTamanoEstable(video, 500, 4000);
  video.style.opacity = "1";
}

/**
 * Hace que el video llene toda la ventana visible. `dvh` sigue a la barra de
 * Safari y al cambio de tamaño; el valor se reasigna a propósito para obligar a
 * recalcular el diseño (al desbloquear el iPhone a veces quedaba con franjas
 * negras arriba y abajo).
 */
function ajustarVideo() {
  if (!video) return;
  const dvh = window.CSS && CSS.supports && CSS.supports("height", "100dvh");
  video.style.height = "0";
  void video.offsetHeight;
  video.style.width = "100vw";
  video.style.height = dvh ? "100dvh" : "100%";
}

/** Espera a que `video` lleve `quietoMs` sin cambiar de tamaño (máximo `maxMs`). */
function esperarTamanoEstable(v, quietoMs, maxMs) {
  return new Promise((resolve) => {
    let reloj = null;
    const listo = () => {
      clearTimeout(reloj);
      clearTimeout(tope);
      v.removeEventListener("resize", reiniciar);
      resolve();
    };
    const reiniciar = () => {
      clearTimeout(reloj);
      reloj = setTimeout(listo, quietoMs);
    };
    const tope = setTimeout(listo, maxMs);
    v.addEventListener("resize", reiniciar);
    reiniciar();
  });
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
 * que Python (`Extractor` en ml/signcast).
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

/** Vuelve a abrir la cámara conservando la detección en marcha. */
async function reabrirCamara() {
  const callback = alCuadro;
  try {
    await abrirCamara();
  } catch (e) {
    console.warn("SignCast: no se pudo reabrir la cámara", e);
    return;
  }
  if (callback) suscribir(callback);
}

/**
 * Quita cualquier zoom de la página: Safari a veces la deja acercada al volver
 * a la app. Cambiar y restaurar el viewport lo obliga a recalcular la escala.
 */
function reiniciarVista() {
  const meta = document.querySelector('meta[name="viewport"]');
  if (meta) {
    const original = meta.getAttribute("content");
    meta.setAttribute("content", "width=device-width, initial-scale=1.0");
    requestAnimationFrame(() => meta.setAttribute("content", original));
  }
  window.scrollTo(0, 0);
  ajustarVideo();
}

// Al salir de la app o bloquear el iPhone, Safari detiene la cámara; al volver
// puede entregar el video con otro tamaño u orientación y se ve con zoom. Si
// estuvo oculta más de un instante, se reinicia la vista y se abre la cámara de
// nuevo para empezar con un flujo limpio (la detección sigue, y el video entra
// con el mismo desvanecimiento del inicio). Efecto: iOS puede volver a pedir el
// permiso de la cámara cada vez que se regresa a la app.
//
// Safari no siempre manda `visibilitychange` al regresar (según cómo se salga de
// la app), por eso también se escuchan `pageshow` y `focus`.
let ocultaDesde = 0;
let seOculto = false;
let ultimaVuelta = 0;

function alVolver(origen) {
  if (!video || !flujo) return;
  const ahora = performance.now();
  // Los tres eventos suelen llegar juntos: se atiende uno solo.
  if (ahora - ultimaVuelta < 1500) return;
  ultimaVuelta = ahora;
  const pista = flujo.getVideoTracks()[0];
  // `focus` también llega sin haber salido de la app (por ejemplo al cerrar el
  // aviso del permiso); solo cuenta si antes hubo un `hidden` o `pagehide`.
  const estuvoOculta = seOculto && ahora - ocultaDesde > 800;
  seOculto = false;
  console.log("SignCast: de vuelta en la app (" + origen + "), oculta " +
    Math.round(ahora - ocultaDesde) + " ms, cámara " + (pista ? pista.readyState : "sin pista"));
  reiniciarVista();
  if (!pista || pista.readyState === "ended" || estuvoOculta) {
    reabrirCamara();
  } else if (video.paused) {
    video.play().catch(() => {});
  }
}

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "hidden") {
    ocultaDesde = performance.now();
    seOculto = true;
  } else {
    alVolver("visibilitychange");
  }
});
window.addEventListener("pagehide", () => {
  ocultaDesde = performance.now();
  seOculto = true;
});
window.addEventListener("pageshow", () => alVolver("pageshow"));
window.addEventListener("focus", () => alVolver("focus"));
window.addEventListener("resize", ajustarVideo);
window.addEventListener("orientationchange", ajustarVideo);

window.signcastPuntos = {
  cargarModelos,
  estadoPermiso,
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
