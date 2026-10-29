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
  {
    const motor = crearMotor(lt);
    await motor.cargar({ modelo: "m.tflite", etiquetas: "A\n_REPOSO\nHOLA\n", urlWasm: "wasm/" });
    assert.equal(motor.etiquetas, "A _REPOSO HOLA");
    assert.deepEqual(lt.llamadas[0], ["loadLiteRt", "wasm/"]);
    assert.deepEqual(lt.llamadas[1], ["loadAndCompile", "m.tflite", { accelerator: "wasm" }]);

    const probs = await motor.predecir(new Float32Array(30 * 270));
    assert.equal(probs.length, 3);
    assert.ok(Math.abs(probs[1] - 0.7) < 1e-6);
    assert.deepEqual(lt.llamadas[2], ["run", [1, 30, 270]]);
    assert.equal(lt.borrados.length, 2); // la entrada y la salida
  }
});

test("un modelo inservible no deja el motor a medias y LiteRT se carga una vez", async () => {
  const lt = litertFalso([1]);
  const compilar = lt.loadAndCompile;
  let falla = true;
  lt.loadAndCompile = async (...args) => {
    if (falla) throw new Error("modelo corrupto");
    return compilar(...args);
  };
  const motor = crearMotor(lt);
  await assert.rejects(() => motor.cargar({ modelo: new Uint8Array(1), etiquetas: "X", urlWasm: "w" }), /corrupto/);
  assert.equal(motor.etiquetas, "");
  falla = false;
  await motor.cargar({ modelo: new Uint8Array(1), etiquetas: "A B", urlWasm: "w" });
  assert.equal(motor.etiquetas, "A B");
  assert.equal(lt.llamadas.filter(([n]) => n === "loadLiteRt").length, 1);
});

test("rechaza ventanas de tamaño incorrecto y llamadas antes de cargar", async () => {
  const motor = crearMotor(litertFalso([1]));
  await assert.rejects(() => motor.predecir(new Float32Array(30 * 270)), /todavía no se carga/);
  await motor.cargar({ modelo: "m", etiquetas: "A", urlWasm: "w" });
  await assert.rejects(() => motor.predecir(new Float32Array(10)), /Se esperaban 8100/);
});
