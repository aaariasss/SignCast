// Service worker de SignCast: deja la app lista para usarse sin
// internet después de la primera carga.
//
// Este archivo es una plantilla. tool/generar_sw.mjs la copia a build/web/sw.js
// después de `flutter build web` y reemplaza CONFIG con la lista real de
// archivos y sus versiones. Mientras CONFIG sea null (por ejemplo con
// `flutter run`), el service worker se desinstala solo y no guarda nada.
//
// Estrategia: primero la caché, luego la red. Hay dos cachés:
//  - "pesados": WASM y modelos .task de MediaPipe (~25 MB). Su nombre solo
//    cambia si esos archivos cambian, así una versión nueva de la app no los
//    vuelve a descargar.
//  - "app": todo lo demás (Flutter, assets, modelo de señas). Cambia con
//    cada publicación.
const CONFIG = /*__CONFIG__*/ null;
const PREFIJO = 'signcast-';

if (!CONFIG) {
  self.addEventListener('install', () => self.skipWaiting());
  self.addEventListener('activate', (e) => {
    e.waitUntil(
      (async () => {
        for (const n of await caches.keys()) {
          if (n.startsWith(PREFIJO)) await caches.delete(n);
        }
        await self.registration.unregister();
      })()
    );
  });
} else {
  const nombreApp = PREFIJO + 'app-' + CONFIG.versionApp;
  const nombrePesados = PREFIJO + 'pesados-' + CONFIG.versionPesados;
  const vigentes = [nombreApp, nombrePesados];
  const alcance = self.registration.scope;
  const url = (ruta) => new URL(ruta, alcance).href;

  // Descarga a la caché lo que todavía no está, de a pocos a la vez.
  async function llenar(nombre, rutas) {
    const cache = await caches.open(nombre);
    const faltan = [];
    for (const r of rutas) {
      if (!(await cache.match(url(r)))) faltan.push(r);
    }
    for (let i = 0; i < faltan.length; i += 4) {
      await Promise.all(
        faltan.slice(i, i + 4).map(async (r) => {
          // `reload` salta la caché HTTP del navegador para no guardar algo viejo.
          const resp = await fetch(new Request(url(r), { cache: 'reload' }));
          if (!resp.ok) throw new Error(resp.status + ' ' + r);
          await cache.put(url(r), resp);
        })
      );
    }
  }

  self.addEventListener('install', (e) => {
    // Si algo falla (por ejemplo se fue el internet) la instalación se
    // cancela y sigue la versión anterior, sin dejar la caché a medias.
    e.waitUntil(
      (async () => {
        await llenar(nombrePesados, CONFIG.pesados);
        await llenar(nombreApp, CONFIG.app);
        await self.skipWaiting();
      })()
    );
  });

  self.addEventListener('activate', (e) => {
    e.waitUntil(
      (async () => {
        for (const n of await caches.keys()) {
          if (n.startsWith(PREFIJO) && !vigentes.includes(n)) await caches.delete(n);
        }
        await self.clients.claim();
      })()
    );
  });

  self.addEventListener('fetch', (e) => {
    const req = e.request;
    if (req.method !== 'GET') return;
    if (new URL(req.url).origin !== self.location.origin) return;

    e.respondWith(
      (async () => {
        // ignoreSearch: main.dart.js?v=... y la página con ?concara salen de la caché.
        const guardado = await caches.match(req, { ignoreSearch: true });
        if (guardado) return guardado;
        try {
          const resp = await fetch(req);
          // Lo que no estaba en la lista (fuentes, partes diferidas) se guarda al usarse.
          if (resp.status === 200 && resp.type === 'basic') {
            const copia = resp.clone();
            caches.open(nombreApp).then((c) => c.put(req, copia)).catch(() => {});
          }
          return resp;
        } catch (err) {
          if (req.mode === 'navigate') {
            const inicio = await caches.match(url('index.html'));
            if (inicio) return inicio;
          }
          throw err;
        }
      })()
    );
  });
}
