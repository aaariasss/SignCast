# Prepara los archivos de MediaPipe web para la app:
#  - vision_bundle.js y la carpeta wasm/ salen del paquete npm @mediapipe/tasks-vision
#  - los modelos .task son los mismos que usa Python (python -m signcast.descargar_modelos)
# Todo va a app/web/mediapipe/ y no se sube al repo (está en .gitignore). Se sirve
# desde el propio sitio para que la app funcione sin internet.
#
# Uso, desde la carpeta app/ (necesita Node.js; tar viene con Windows 10 o 11):
#   powershell -ExecutionPolicy Bypass -File tool\preparar_mediapipe_web.ps1

$ErrorActionPreference = 'Stop'
$version = '0.10.21'   # la misma que se probó en iPhone

$destino = Join-Path $PSScriptRoot '..\web\mediapipe'
$origenModelos = Join-Path $PSScriptRoot '..\..\ml\mediapipe_modelos'
$modelos = 'hand_landmarker.task', 'pose_landmarker_lite.task', 'face_landmarker.task'

foreach ($m in $modelos) {
    if (-not (Test-Path (Join-Path $origenModelos $m))) {
        Write-Error "Falta $m en $origenModelos. Corre primero, desde ml/: python -m signcast.descargar_modelos"
        exit 1
    }
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) "signcast_mediapipe_$version"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force $tmp | Out-Null

Push-Location $tmp
try {
    npm pack "@mediapipe/tasks-vision@$version" --silent | Out-Null
    tar -xzf "mediapipe-tasks-vision-$version.tgz"
} finally {
    Pop-Location
}

$paquete = Join-Path $tmp 'package'
$bundle = Join-Path $paquete 'vision_bundle.mjs'
if (-not (Test-Path $bundle)) {
    Write-Error "No se encontró vision_bundle.mjs en el paquete @mediapipe/tasks-vision@$version"
    exit 1
}

New-Item -ItemType Directory -Force (Join-Path $destino 'wasm') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $destino 'modelos') | Out-Null

# Se renombra a .js para que cualquier servidor lo entregue como JavaScript.
Copy-Item $bundle (Join-Path $destino 'vision_bundle.js') -Force
Copy-Item (Join-Path $paquete 'wasm\*') (Join-Path $destino 'wasm') -Force
Write-Host "Copiado vision_bundle.js y wasm/ (MediaPipe $version)"

foreach ($m in $modelos) {
    Copy-Item (Join-Path $origenModelos $m) (Join-Path $destino 'modelos') -Force
    Write-Host "Copiado $m"
}
Remove-Item -Recurse -Force $tmp
