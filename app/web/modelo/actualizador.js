// Elige qué modelo de señas usar, para poder cambiarlo sin reinstalar la app.
//
// Orden de preferencia:
//  1. El modelo publicado en el sitio (`modelos/version.json`), si hay internet.
//     Se descarga una sola vez y se guarda en el caché del navegador.
//  2. El último modelo guardado, si no hay internet o la descarga falla.
//  3. El modelo incluido con la app (`assets/modelos/`).
//
// Un modelo publicado vive en `modelos/<version>/modelo.tflite` y
// `modelos/<version>/etiquetas.txt`; `modelos/version.json` es
// `{ "version": "<version>" }` e indica cuál está vigente.

export const CACHE = "modelo-signcast";
const MARCA = "modelo-guardado/vigente";
const VERSION_VALIDA = /^[\w.-]+$/;
const ESPERA_VERSION = 4000;
const ESPERA_DESCARGA = 30000;

const url = (base, ruta) => new URL(ruta, base).href;

/** fetch con tiempo límite; rechaza si responde con error. */
async function pedir(red, direccion, esperaMs, opciones = {}) {
  const control = new AbortController();
  const reloj = setTimeout(() => control.abort(), esperaMs);
  try {
    const r = await red(direccion, { ...opciones, signal: control.signal });
    if (!r.ok) throw new Error(r.status + " " + direccion);
    return r;
  } finally {
    clearTimeout(reloj);
  }
}

/** Último modelo guardado, o null si no hay (o está incompleto). */
export async function leerGuardado({ base, almacen = globalThis.caches }) {
  try {
    const cache = await almacen.open(CACHE);
    const marca = await cache.match(url(base, MARCA));
    if (!marca) return null;
    const version = (await marca.text()).trim();
    const [modelo, etiquetas] = await Promise.all([
      cache.match(url(base, `modelo-guardado/${version}/modelo.tflite`)),
      cache.match(url(base, `modelo-guardado/${version}/etiquetas.txt`)),
    ]);
    if (!modelo || !etiquetas) return null;
    return {
      version,
      origen: "guardado",
      modelo: new Uint8Array(await modelo.arrayBuffer()),
      etiquetas: await etiquetas.text(),
    };
  } catch {
    return null;
  }
}

/**
 * Guarda un modelo y lo marca como vigente. La marca se escribe al final: si
 * algo falla a la mitad, el modelo anterior sigue siendo el vigente.
 */
async function guardar({ base, almacen = globalThis.caches }, { version, modelo, etiquetas }) {
  const cache = await almacen.open(CACHE);
  await cache.put(url(base, `modelo-guardado/${version}/modelo.tflite`), new Response(modelo));
  await cache.put(url(base, `modelo-guardado/${version}/etiquetas.txt`), new Response(etiquetas));
  await cache.put(url(base, MARCA), new Response(version));
  for (const clave of await cache.keys()) {
    const ruta = clave.url;
    if (ruta !== url(base, MARCA) && !ruta.includes(`/modelo-guardado/${version}/`)) {
      await cache.delete(clave);
    }
  }
}

/** Borra el modelo guardado (por ejemplo si resulta inservible). */
export async function olvidarGuardado({ almacen = globalThis.caches } = {}) {
  try {
    await almacen.delete(CACHE);
  } catch {
    // Sin caché no hay nada que borrar.
  }
}

/** Modelo incluido con la app. */
export async function leerIncluido({ base, red = globalThis.fetch.bind(globalThis) }) {
  const [modelo, etiquetas] = await Promise.all([
    pedir(red, url(base, "assets/assets/modelos/modelo.tflite"), ESPERA_DESCARGA).then((r) => r.arrayBuffer()),
    pedir(red, url(base, "assets/assets/modelos/etiquetas.txt"), ESPERA_DESCARGA).then((r) => r.text()),
  ]);
  return { version: "incluido", origen: "incluido", modelo: new Uint8Array(modelo), etiquetas };
}

/**
 * Devuelve `{ version, origen, modelo: Uint8Array, etiquetas: string }` con el
 * modelo que hay que usar. `base` es la URL raíz del sitio.
 */
export async function elegirModelo({
  base,
  red = globalThis.fetch.bind(globalThis),
  almacen = globalThis.caches,
}) {
  const guardado = await leerGuardado({ base, almacen });

  try {
    const respuesta = await pedir(red, url(base, "modelos/version.json"), ESPERA_VERSION, { cache: "no-store" });
    const { version } = await respuesta.json();
    if (typeof version !== "string" || !VERSION_VALIDA.test(version)) {
      throw new Error("version.json no tiene una versión válida");
    }
    if (guardado && guardado.version === version) return guardado;

    const carpeta = `modelos/${version}/`;
    const [modelo, etiquetas] = await Promise.all([
      pedir(red, url(base, carpeta + "modelo.tflite"), ESPERA_DESCARGA).then((r) => r.arrayBuffer()),
      pedir(red, url(base, carpeta + "etiquetas.txt"), ESPERA_DESCARGA).then((r) => r.text()),
    ]);
    if (modelo.byteLength === 0 || etiquetas.trim() === "") throw new Error("descarga vacía");

    const nuevo = { version, origen: "publicado", modelo: new Uint8Array(modelo), etiquetas };
    try {
      await guardar({ base, almacen }, { version, modelo: nuevo.modelo, etiquetas });
    } catch (e) {
      console.warn("No se pudo guardar el modelo nuevo; se usa solo en esta sesión.", e);
    }
    return nuevo;
  } catch (e) {
    // Sin internet, sin publicar o descarga fallida: se sigue con lo que haya.
    console.info("Sin modelo nuevo:", e?.message ?? e);
  }

  return guardado ?? leerIncluido({ base, red });
}
