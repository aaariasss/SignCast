// Prepara una versión nueva del modelo de señas para publicarla sin
// reinstalar la app:
//
//   node tool/publicar_modelo.mjs <modelo.tflite> <etiquetas.txt> <version>
//
// Copia los archivos a web/modelos/<version>/ y apunta web/modelos/version.json
// a esa versión. Si ya hay un build (build/web), también lo actualiza ahí, así
// basta con `firebase deploy --only hosting` (o tool/publicar_modelo.ps1).
import { copyFileSync, existsSync, mkdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const aqui = dirname(fileURLToPath(import.meta.url));
const [modelo, etiquetas, version] = process.argv.slice(2);

if (!modelo || !etiquetas || !version) {
  console.error('Uso: node tool/publicar_modelo.mjs <modelo.tflite> <etiquetas.txt> <version>');
  process.exit(1);
}
if (!/^[\w.-]+$/.test(version)) {
  console.error('La versión solo puede tener letras, números, punto, guion y guion bajo (por ejemplo v2).');
  process.exit(1);
}
for (const ruta of [modelo, etiquetas]) {
  if (!existsSync(ruta) || statSync(ruta).size === 0) {
    console.error(`No existe o está vacío: ${ruta}`);
    process.exit(1);
  }
}

const destinos = [join(aqui, '..', 'web')];
const build = join(aqui, '..', 'build', 'web');
if (existsSync(join(build, 'index.html'))) destinos.push(build);

for (const raiz of destinos) {
  const carpeta = join(raiz, 'modelos', version);
  mkdirSync(carpeta, { recursive: true });
  copyFileSync(modelo, join(carpeta, 'modelo.tflite'));
  copyFileSync(etiquetas, join(carpeta, 'etiquetas.txt'));
  writeFileSync(join(raiz, 'modelos', 'version.json'), JSON.stringify({ version }, null, 2) + '\n');
  console.log(`Modelo ${version} listo en ${resolve(raiz, 'modelos')}`);
}
