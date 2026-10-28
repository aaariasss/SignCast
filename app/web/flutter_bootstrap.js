{{flutter_js}}
{{flutter_build_config}}

// Sin `serviceWorkerSettings`: Flutter no registra su propio service worker.
// La app usa web/sw.js, que guarda en caché la app, MediaPipe y el
// modelo para funcionar sin internet. Se registra desde index.html.
_flutter.loader.load();
