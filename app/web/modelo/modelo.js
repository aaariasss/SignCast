// Corre el modelo de señas (.tflite) en el navegador con LiteRT.js.
//
// Recibe una ventana de 30 cuadros × 270 valores (el mismo vector que usa
// Python) y devuelve las probabilidades de cada glosa. Los archivos de LiteRT
// (web/litert/) no están en el repo: se copian con app/tool/preparar_litert_web.ps1
// y se sirven desde el propio sitio para que funcione sin internet.
//
// Qué modelo se carga (publicado, guardado o incluido) lo decide actualizador.js.
//
// Dart lo usa a través de `window.signcastModelo`.

const CUADROS = 30;
const CARACTERISTICAS = 270;

import { elegirModelo, leerIncluido, olvidarGuardado } from "./actualizador.js";

/** `etiquetas.txt` -> lista de glosas (una por línea o separadas por espacios). */
export function leerEtiquetas(texto) {
  return texto.split(/\s+/).filter(Boolean);
}

/** Primer tensor de la salida de `run`, que puede ser lista u objeto. */
function primeraSalida(salida) {
  return Array.isArray(salida) ? salida[0] : Object.values(salida)[0];
}

/**
 * Crea el motor sobre el módulo de LiteRT ya importado. Se separa del
 * `import` para poder probarlo con un módulo falso (app/test_js).
 */
export function crearMotor(litert) {
  let modelo = null;
  let etiquetas = [];
  let litertListo = false;

  return {
    get etiquetas() {
      return etiquetas.join(" ");
    },

    /**
     * `modelo`: bytes del `.tflite` (Uint8Array) o su URL.
     * `etiquetas`: contenido de `etiquetas.txt`.
     */
    async cargar({ modelo: origen, etiquetas: texto, urlWasm }) {
      if (modelo) return;
      if (!litertListo) {
        await litert.loadLiteRt(urlWasm);
        litertListo = true;
      }
      // Si el modelo es inservible, `modelo` y `etiquetas` quedan como estaban.
      const compilado = await litert.loadAndCompile(origen, { accelerator: "wasm" });
      etiquetas = leerEtiquetas(texto);
      modelo = compilado;
    },

    /** `ventana`: Float32Array de 30 × 270. Devuelve un Float32Array de probabilidades. */
    async predecir(ventana) {
      if (!modelo) throw new Error("El modelo todavía no se carga.");
      if (ventana.length !== CUADROS * CARACTERISTICAS) {
        throw new Error(`Se esperaban ${CUADROS * CARACTERISTICAS} valores y llegaron ${ventana.length}.`);
      }
      const entrada = new litert.Tensor(ventana, [1, CUADROS, CARACTERISTICAS]);
      let salida = null;
      try {
        salida = await modelo.run(entrada);
        const tensor = primeraSalida(salida);
        const cpu = await tensor.moveTo("wasm");
        // Se copia porque el tensor se libera enseguida.
        return Float32Array.from(cpu.toTypedArray());
      } finally {
        entrada.delete();
        const lista = salida == null ? [] : Array.isArray(salida) ? salida : Object.values(salida);
        for (const t of lista) t.delete?.();
      }
    },
  };
}

// En el navegador: importa LiteRT.js desde web/litert/ y se expone a Dart.
if (typeof window !== "undefined") {
  const BASE = new URL("../", import.meta.url).href;
  let motor = null;
  let version = "";
  window.signcastModelo = {
    async cargar() {
      if (!motor) {
        const litert = await import(BASE + "litert/litert.js");
        motor = crearMotor(litert);
      }
      const urlWasm = BASE + "litert/wasm/";
      let eleccion = await elegirModelo({ base: BASE });
      try {
        await motor.cargar({ ...eleccion, urlWasm });
      } catch (e) {
        if (eleccion.origen === "incluido") throw e;
        // El modelo publicado o guardado no sirve: se vuelve al incluido.
        console.warn("El modelo " + eleccion.version + " no cargó; se usa el incluido.", e);
        await olvidarGuardado();
        eleccion = await leerIncluido({ base: BASE });
        await motor.cargar({ ...eleccion, urlWasm });
      }
      version = eleccion.version;
      console.info("Modelo de señas: " + version + " (" + eleccion.origen + ")");
    },
    /** Versión del modelo en uso: la publicada o "incluido". */
    get version() {
      return version;
    },
    predecir: (ventana) => motor.predecir(ventana),
    get etiquetas() {
      return motor ? motor.etiquetas : "";
    },
  };
}
