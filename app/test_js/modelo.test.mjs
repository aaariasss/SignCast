// Prueba del motor del modelo con un LiteRT falso.  Correr: node --test test_js
import { test } from "node:test";
import assert from "node:assert/strict";
import { crearMotor, leerEtiquetas } from "../web/modelo/modelo.js";

function litertFalso(probs) {
  const borrados = [];
  class Tensor {
    constructor(datos, forma) {
      this.datos = datos;
      this.forma = forma;
    }
    async moveTo() {
      return this;
    }
    toTypedArray() {
      return this.datos;
    }
    delete() {
      borrados.push(this);
    }
  }
  const llamadas = [];
  return {
    borrados,
    llamadas,
    Tensor,
    async loadLiteRt(url) {
      llamadas.push(["loadLiteRt", url]);
    },
    async loadAndCompile(url, opciones) {
      llamadas.push(["loadAndCompile", url, opciones]);
      return {
        async run(entrada) {
          llamadas.push(["run", entrada.forma]);
          return [new Tensor(Float32Array.from(probs), [1, probs.length])];
        },
      };
    },
  };
}

test("leerEtiquetas acepta saltos de línea y espacios", () => {
  assert.deepEqual(leerEtiquetas("A B\r\n_REPOSO\nHOLA\n"), ["A", "B", "_REPOSO", "HOLA"]);
});

test("carga, predice y libera los tensores", async () => {
  const lt = litertFalso([0.1, 0.7, 0.2]);
  const globalFetch = globalThis.fetch;
  globalThis.fetch = async () => ({ ok: true, text: async () => "A\n_REPOSO\nHOLA\n" });
  try {
    const motor = crearMotor(lt);
    await motor.cargar({ urlModelo: "m.tflite", urlEtiquetas: "e.txt", urlWasm: "wasm/" });
    assert.equal(motor.etiquetas, "A _REPOSO HOLA");
    assert.deepEqual(lt.llamadas[0], ["loadLiteRt", "wasm/"]);
    assert.deepEqual(lt.llamadas[1], ["loadAndCompile", "m.tflite", { accelerator: "wasm" }]);

    const probs = await motor.predecir(new Float32Array(30 * 270));
    assert.equal(probs.length, 3);
    assert.ok(Math.abs(probs[1] - 0.7) < 1e-6);
    assert.deepEqual(lt.llamadas[2], ["run", [1, 30, 270]]);
    assert.equal(lt.borrados.length, 2); // la entrada y la salida
  } finally {
    globalThis.fetch = globalFetch;
  }
});

test("rechaza ventanas de tamaño incorrecto y llamadas antes de cargar", async () => {
  const motor = crearMotor(litertFalso([1]));
  await assert.rejects(() => motor.predecir(new Float32Array(30 * 270)), /todavía no se carga/);
  const globalFetch = globalThis.fetch;
  globalThis.fetch = async () => ({ ok: true, text: async () => "A" });
  try {
    await motor.cargar({ urlModelo: "m", urlEtiquetas: "e", urlWasm: "w" });
    await assert.rejects(() => motor.predecir(new Float32Array(10)), /Se esperaban 8100/);
  } finally {
    globalThis.fetch = globalFetch;
  }
});
