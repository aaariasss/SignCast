// Completa build/web/sw.js con la lista de archivos que se guardan para usar
// la app sin internet. Correr después de `flutter build web`:
//
//   node tool/generar_sw.mjs [carpeta] [--con-cara]
//
// `carpeta` es build/web por defecto. Sin dependencias: solo Node.js.
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync, statSync, writeFileSync, existsSync } from 'node:fs';
import { join, relative, resolve, dirname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const aqui = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const conCara = args.includes('--con-cara');
const carpeta = resolve(args.find((a) => !a.startsWith('--')) ?? join(aqui, '..', 'build', 'web'));
const plantilla = join(aqui, '..', 'web', 'sw.js');

if (!existsSync(join(carpeta, 'index.html'))) {
  console.error(`No hay index.html en ${carpeta}. Corre primero: flutter build web --release`);
  process.exit(1);
}

// Qué NO se guarda de antemano (si la app lo pide, se guarda al usarse).
const excluir = [
  /^sw\.js$/,
  /\.map$/,
  /\.symbols$/,
  /(^|\/)\./, // archivos ocultos
  /^firebase\.json$/,
  /^flutter_service_worker\.js$/,
  /^canvaskit\/chromium\//, // solo lo usa Chrome de escritorio
  /^canvaskit\/skwasm/, // iPhone usa canvaskit.wasm
  /^mediapipe\/wasm\/.*nosimd/, // solo para navegadores sin SIMD; iOS 16.4+ lo tiene
];
if (!conCara) excluir.push(/^mediapipe\/modelos\/face_landmarker\.task$/); // el rostro no se usa

function archivos(dir) {
  const salida = [];
  for (const nombre of readdirSync(dir)) {
    const ruta = join(dir, nombre);
    if (statSync(ruta).isDirectory()) salida.push(...archivos(ruta));
    else salida.push(ruta);
  }
  return salida;
}

const todos = archivos(carpeta)
  .map((ruta) => ({ ruta, rel: relative(carpeta, ruta).split(sep).join('/') }))
  .filter(({ rel }) => !excluir.some((re) => re.test(rel)))
  .sort((a, b) => a.rel.localeCompare(b.rel));

const esPesado = (rel) => /^mediapipe\/(wasm|modelos)\//.test(rel);
const huella = (lista) => {
  const h = createHash('sha256');
  for (const { rel, ruta } of lista) h.update(rel).update(readFileSync(ruta));
  return h.digest('hex').slice(0, 12);
};

const pesados = todos.filter(({ rel }) => esPesado(rel));
const app = todos.filter(({ rel }) => !esPesado(rel));
const config = {
  versionApp: huella(app),
  versionPesados: huella(pesados),
  // "./" es la página de inicio (la ruta "/" del sitio).
  app: ['./', ...app.map(({ rel }) => rel)],
  pesados: pesados.map(({ rel }) => rel),
};

const texto = readFileSync(plantilla, 'utf8');
if (!texto.includes('/*__CONFIG__*/ null')) {
  console.error('web/sw.js ya no tiene el marcador /*__CONFIG__*/ null');
  process.exit(1);
}
writeFileSync(join(carpeta, 'sw.js'), texto.replace('/*__CONFIG__*/ null', JSON.stringify(config, null, 2)));

const mb = (lista) => (lista.reduce((s, { ruta }) => s + statSync(ruta).size, 0) / 1048576).toFixed(1);
console.log(`sw.js listo: ${app.length} archivos de la app (${mb(app)} MB) + ${pesados.length} de MediaPipe (${mb(pesados)} MB)`);

// Avisos de cosas que dejarían la app sin funcionar sin internet.
if (!existsSync(join(carpeta, 'canvaskit', 'canvaskit.wasm'))) {
  console.warn('AVISO: no hay canvaskit/ en el build. Compila con --no-web-resources-cdn para que no se descargue de internet.');
}
if (!pesados.some(({ rel }) => rel.endsWith('hand_landmarker.task'))) {
  console.warn('AVISO: faltan los modelos de MediaPipe. Corre tool/preparar_mediapipe_web.ps1 y vuelve a compilar.');
}
if (!app.some(({ rel }) => /modelo\.tflite$/.test(rel))) {
  console.warn('AVISO: todavía no hay modelo.tflite en el build. Se agregará solo cuando exista en app/assets/modelos/.');
}
