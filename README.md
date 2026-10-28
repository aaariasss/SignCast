# SignCast

Traduce Lengua de Señas Mexicana (LSM) a texto y voz en tiempo real, sin internet. Es una aplicación web (PWA) hecha con Flutter web: corre en el navegador del iPhone, se instala en la pantalla de inicio y, después de la primera carga, funciona sin conexión. La cámara y MediaPipe detectan manos, pose y gestos en el propio dispositivo; el video nunca sale de él.

## Estructura

| Carpeta | Qué hay |
|---|---|
| `app/` | La aplicación (Flutter web, PWA): pantallas, constructor de frases, MediaPipe web y service worker. Ver [app/README.md](app/README.md) |
| `ml/` | Python: grabación de señas, extracción de puntos clave, entrenamiento y exportación a TensorFlow Lite |
| `data/` | Datos de entrenamiento (no van al repo, ver [data/README.md](data/README.md)) |
| `docs/` | Vocabulario y frases, formato del vector de puntos clave, nube y publicación |

## Diseño de la interfaz

Prototipo de la app en Figma (cámara con subtítulos, estado de detección, ajustes e historial de frases):
https://prism-mace-81782658.figma.site

## Publicar la app web

Cómo compilar, publicar en Firebase Hosting, instalar en el iPhone y usarla sin internet: [docs/publicar_web.md](docs/publicar_web.md).

## Nube

Los datos se comparten en una carpeta de Google Drive y el modelo se distribuye con Firebase (plan Spark). Estructura de la carpeta, accesos, cómo subir y bajar archivos y dónde se entrena: [docs/nube.md](docs/nube.md).
