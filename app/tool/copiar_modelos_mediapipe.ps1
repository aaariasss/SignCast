# Copia los modelos de MediaPipe (.task) que descarga `python -m signcast.descargar_modelos`
# a los assets de Android. Son los mismos modelos que usa Python para el entrenamiento.
# No se suben al repo (están en .gitignore).
#
# Uso, desde la carpeta app/:
#   powershell -ExecutionPolicy Bypass -File tool\copiar_modelos_mediapipe.ps1

$origen = Join-Path $PSScriptRoot '..\..\ml\mediapipe_modelos'
$destino = Join-Path $PSScriptRoot '..\android\app\src\main\assets'

$modelos = 'hand_landmarker.task', 'pose_landmarker_lite.task', 'face_landmarker.task'
foreach ($m in $modelos) {
    if (-not (Test-Path (Join-Path $origen $m))) {
        Write-Error "Falta $m en $origen. Corre primero, desde ml/: python -m signcast.descargar_modelos"
        exit 1
    }
}

New-Item -ItemType Directory -Force $destino | Out-Null
foreach ($m in $modelos) {
    Copy-Item (Join-Path $origen $m) $destino -Force
    Write-Host "Copiado $m"
}
