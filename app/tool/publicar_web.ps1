# Compila la app web y la publica en Firebase Hosting.
#
# Uso, desde la carpeta app/ (necesita Flutter, Node.js y firebase-tools:
# `npm install -g firebase-tools` y luego `firebase login`):
#
#   powershell -ExecutionPolicy Bypass -File tool\publicar_web.ps1                 # canal de vista previa (7 días)
#   powershell -ExecutionPolicy Bypass -File tool\publicar_web.ps1 -Produccion     # sitio principal (demo)
#   powershell -ExecutionPolicy Bypass -File tool\publicar_web.ps1 -SoloConstruir  # sin publicar
#
# Antes de la primera vez, correr tool\preparar_mediapipe_web.ps1 y
# tool\preparar_litert_web.ps1 (esos archivos no están en el repo), y copiar
# modelo.tflite y etiquetas.txt a assets\modelos\.
param(
    [switch]$Produccion,
    [switch]$SoloConstruir,
    [string]$Canal = 'preview'
)

$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    if (-not (Test-Path 'web\mediapipe\wasm') -or -not (Test-Path 'web\mediapipe\modelos')) {
        Write-Error 'Faltan los archivos de MediaPipe. Corre primero tool\preparar_mediapipe_web.ps1'
        exit 1
    }

    if (-not (Test-Path 'web\litert\litert.js')) {
        Write-Error 'Faltan los archivos de LiteRT. Corre primero tool\preparar_litert_web.ps1'
        exit 1
    }
    if (-not (Test-Path 'assets\modelos\modelo.tflite') -or -not (Test-Path 'assets\modelos\etiquetas.txt')) {
        Write-Error 'Falta el modelo. Copia modelo.tflite y etiquetas.txt a app\assets\modelos\'
        exit 1
    }

    # --no-web-resources-cdn: CanvasKit sale del propio sitio y no de internet,
    # si no la app no abre sin conexión.
    flutter build web --release --no-web-resources-cdn
    if ($LASTEXITCODE -ne 0) { Write-Error 'flutter build web falló'; exit 1 }

    node tool/generar_sw.mjs build/web
    if ($LASTEXITCODE -ne 0) { Write-Error 'No se pudo generar sw.js'; exit 1 }

    if ($SoloConstruir) {
        Write-Host 'Listo en build\web (no se publicó).'
        return
    }

    if ($Produccion) {
        firebase deploy --only hosting
    } else {
        firebase hosting:channel:deploy $Canal --expires 7d
    }
    if ($LASTEXITCODE -ne 0) { Write-Error 'firebase falló. ¿Hiciste firebase login?'; exit 1 }
} finally {
    Pop-Location
}
