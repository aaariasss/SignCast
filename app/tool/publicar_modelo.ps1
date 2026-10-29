# Publica una versión nueva del modelo de señas sin recompilar la app.
#
# Uso, desde la carpeta app/ (después de haber compilado la app al menos una
# vez con tool\publicar_web.ps1):
#
#   powershell -ExecutionPolicy Bypass -File tool\publicar_modelo.ps1 -Version v2 -Modelo ruta\modelo.tflite -Etiquetas ruta\etiquetas.txt
#   ... -Produccion     # sitio principal; sin esto, canal de vista previa (7 días)
#   ... -SoloPreparar   # copia los archivos pero no publica
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Modelo,
    [Parameter(Mandatory = $true)][string]$Etiquetas,
    [switch]$Produccion,
    [switch]$SoloPreparar,
    [string]$Canal = 'preview'
)

$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    if (-not (Test-Path 'build\web\index.html')) {
        Write-Error 'No hay build. Corre primero tool\publicar_web.ps1 -SoloConstruir'
        exit 1
    }

    node tool/publicar_modelo.mjs $Modelo $Etiquetas $Version
    if ($LASTEXITCODE -ne 0) { Write-Error 'No se pudo preparar el modelo'; exit 1 }

    if ($SoloPreparar) {
        Write-Host 'Listo (no se publicó).'
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
