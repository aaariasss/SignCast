import assert from "node:assert/strict";
import test from "node:test";

import { CACHE, elegirModelo, leerGuardado } from "../web/modelo/actualizador.js";

const BASE = "https://sitio.test/";

/** CacheStorage mínimo en memoria. */
function almacenFalso() {
  const cachés = new Map();
  const abrir = (nombre) => {
    if (!cachés.has(nombre)) cachés.set(nombre, new Map());
    const datos = cachés.get(nombre);
    return {
      async match(u) {
        const r = datos.get(u);
        return r ? r.clone() : undefined;
      },
      async put(u, r) {
        datos.set(u, r);
      },
      async keys() {
        return [...datos.keys()].map((u) => ({ url: u }));
      },
      async delete(clave) {
        return datos.delete(typeof clave === "string" ? clave : clave.url);
      },
    };
  };
  return {
    cachés,
    async open(n) {
      return abrir(n);
    },
    async delete(n) {
      return cachés.delete(n);
    },
  };
}

/** `sitio`: mapa ruta -> contenido. Sin internet si `sitio` es null. */
function redFalsa(sitio) {
  const pedidos = [];
  const red = async (u) => {
    pedidos.push(u);
    if (!sitio) throw new TypeError("Failed to fetch");
    const ruta = u.replace(BASE, "");
    if (!(ruta in sitio)) return new Response("no existe", { status: 404 });
    return new Response(sitio[ruta]);
  };
  red.pedidos = pedidos;
  return red;
}

const INCLUIDO = {
  "assets/assets/modelos/modelo.tflite": new Uint8Array([1, 1, 1]),
  "assets/assets/modelos/etiquetas.txt": "A B",
};
const publicado = (version, bytes, etiquetas) => ({
  "modelos/version.json": JSON.stringify({ version }),
  [`modelos/${version}/modelo.tflite`]: new Uint8Array(bytes),
  [`modelos/${version}/etiquetas.txt`]: etiquetas,
  ...INCLUIDO,
});
const bytes = (m) => [...m.modelo];

test("sin nada publicado ni guardado usa el modelo incluido", async () => {
  const m = await elegirModelo({ base: BASE, red: redFalsa(INCLUIDO), almacen: almacenFalso() });
  assert.equal(m.origen, "incluido");
  assert.deepEqual(bytes(m), [1, 1, 1]);
  assert.equal(m.etiquetas, "A B");
});

test("con internet descarga el modelo publicado y lo guarda", async () => {
  const almacen = almacenFalso();
  const m = await elegirModelo({ base: BASE, red: redFalsa(publicado("v2", [2, 2], "X Y Z")), almacen });
  assert.equal(m.origen, "publicado");
  assert.equal(m.version, "v2");
  assert.deepEqual(bytes(m), [2, 2]);
  const g = await leerGuardado({ base: BASE, almacen });
  assert.equal(g.version, "v2");
  assert.deepEqual([...g.modelo], [2, 2]);
  assert.equal(g.etiquetas, "X Y Z");
});

test("sin internet sigue usando el último modelo guardado", async () => {
  const almacen = almacenFalso();
  await elegirModelo({ base: BASE, red: redFalsa(publicado("v2", [2, 2], "X Y")), almacen });
  const m = await elegirModelo({ base: BASE, red: redFalsa(null), almacen });
  assert.equal(m.origen, "guardado");
  assert.equal(m.version, "v2");
  assert.deepEqual(bytes(m), [2, 2]);
});

test("si la versión vigente ya está guardada no descarga el modelo otra vez", async () => {
  const almacen = almacenFalso();
  const sitio = publicado("v2", [2, 2], "X Y");
  await elegirModelo({ base: BASE, red: redFalsa(sitio), almacen });
  const red = redFalsa(sitio);
  const m = await elegirModelo({ base: BASE, red, almacen });
  assert.equal(m.origen, "guardado");
  assert.deepEqual(red.pedidos, [BASE + "modelos/version.json"]);
});

test("una versión nueva reemplaza a la guardada y borra la anterior", async () => {
  const almacen = almacenFalso();
  await elegirModelo({ base: BASE, red: redFalsa(publicado("v2", [2], "A")), almacen });
  const m = await elegirModelo({ base: BASE, red: redFalsa(publicado("v3", [3, 3], "B C")), almacen });
  assert.equal(m.version, "v3");
  const claves = [...almacen.cachés.get(CACHE).keys()];
  assert.ok(claves.every((c) => !c.includes("/v2/")));
  assert.equal((await leerGuardado({ base: BASE, almacen })).version, "v3");
});

test("si falla la descarga conserva el modelo guardado", async () => {
  const almacen = almacenFalso();
  await elegirModelo({ base: BASE, red: redFalsa(publicado("v2", [2], "A")), almacen });
  const sitio = publicado("v3", [3], "B");
  delete sitio["modelos/v3/modelo.tflite"]; // version.json ya apunta a v3 pero falta el archivo
  const m = await elegirModelo({ base: BASE, red: redFalsa(sitio), almacen });
  assert.equal(m.version, "v2");
  assert.equal(m.origen, "guardado");
});

test("ignora versiones con caracteres raros y descargas vacías", async () => {
  const sitio = { ...INCLUIDO, "modelos/version.json": JSON.stringify({ version: "../x" }) };
  let m = await elegirModelo({ base: BASE, red: redFalsa(sitio), almacen: almacenFalso() });
  assert.equal(m.origen, "incluido");

  m = await elegirModelo({ base: BASE, red: redFalsa(publicado("v2", [], "A")), almacen: almacenFalso() });
  assert.equal(m.origen, "incluido");
});

test("sin CacheStorage igual funciona", async () => {
  const m = await elegirModelo({ base: BASE, red: redFalsa(publicado("v2", [2], "A")), almacen: undefined });
  assert.equal(m.origen, "publicado");
});
