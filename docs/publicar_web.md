# Publicar la app web (PWA)

La app corre en el navegador del iPhone, se instala en la pantalla de inicio y, después de la primera carga con internet, funciona sin conexión. Se publica en Firebase Hosting (proyecto `signcast-01`, plan Spark).

## Publicar

Una sola vez:

```
npm install -g firebase-tools
firebase login
cd app
powershell -ExecutionPolicy Bypass -File tool\preparar_mediapipe_web.ps1
powershell -ExecutionPolicy Bypass -File tool\preparar_litert_web.ps1
```

Y copiar `modelo.tflite` y `etiquetas.txt` del modelo entrenado a `app/assets/modelos/` (ver [modelo_navegador.md](modelo_navegador.md)).

Desde `app/`:

```
powershell -ExecutionPolicy Bypass -File tool\publicar_web.ps1               # vista previa
powershell -ExecutionPolicy Bypass -File tool\publicar_web.ps1 -Produccion   # sitio principal
powershell -ExecutionPolicy Bypass -File tool\publicar_web.ps1 -SoloConstruir
```

El script compila con `flutter build web --release --no-web-resources-cdn` (CanvasKit sale del propio sitio), genera la lista de archivos de `build/web/sw.js` con `tool/generar_sw.mjs` y publica. La vista previa dura 7 días y su URL se imprime al final.

## Sin internet

`web/sw.js` es un service worker que guarda la app, MediaPipe, LiteRT y el modelo (`modelo.tflite` y `etiquetas.txt`). Cada publicación genera una versión nueva y borra las cachés viejas. Con `flutter run` no se usa.

## Instalar en el iPhone

1. Abrir la URL en Safari con internet y esperar a que cargue.
2. Compartir > Agregar a pantalla de inicio.
3. Abrir SignCast desde el ícono y aceptar el permiso de la cámara.

Si se cambia el ícono, borrar el acceso directo y los datos del sitio (Ajustes > Apps > Safari > Avanzado > Datos de sitios web) antes de agregarlo otra vez.
