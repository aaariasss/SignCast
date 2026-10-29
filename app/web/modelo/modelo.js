// Corre el modelo de señas (.tflite) en el navegador con LiteRT.js.
//
// Recibe una ventana de 30 cuadros × 270 valores (el mismo vector que usa
// Python) y devuelve las probabilidades de cada glosa. Los archivos de LiteRT
// (web/litert/) no están en el repo: se copian con app/tool/preparar_litert_web.ps1
// y se sirven desde el propio sitio para que funcione sin internet.
//
// Dart lo usa a través de `window.signcastModelo`.

const CUADROS = 30;
const CARACTERISTICAS = 270;

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

  return {
    get etiquetas() {
      return etiquetas.join(" ");
    },

    async cargar({ urlModelo, urlEtiquetas, urlWasm }) {
      if (modelo) return;
      const [texto] = await Promise.all([
        fetch(urlEtiquetas).then((r) => {
          if (!r.ok) throw new Error(r.status + " " + urlEtiquetas);
          return r.text();
        }),
        litert.loadLiteRt(urlWasm),
      ]);
      etiquetas = leerEtiquetas(texto);
      modelo = await litert.loadAndCompile(urlModelo, { accelerator: "wasm" });
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
  window.signcastModelo = {
    async cargar() {
      if (!motor) {
        const litert = await import(BASE + "litert/litert.js");
        motor = crearMotor(litert);
      }
      await motor.cargar({
        urlModelo: BASE + "assets/assets/modelos/modelo.tflite",
        urlEtiquetas: BASE + "assets/assets/modelos/etiquetas.txt",
        urlWasm: BASE + "litert/wasm/",
      });
    },
    predecir: (ventana) => motor.predecir(ventana),
    get etiquetas() {
      return motor ? motor.etiquetas : "";
    },
  };
}
