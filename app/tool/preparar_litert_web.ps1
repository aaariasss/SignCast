# Prepara LiteRT.js (corre el modelo .tflite en el navegador) para la app:
# copia el paquete npm @litertjs/core a app/web/litert/. No se sube al repo (está
# en .gitignore). Se sirve desde el propio sitio para que funcione sin internet.
#
# Uso, desde la carpeta app/ (necesita Node.js; tar viene con Windows 10 o 11):
#   powershell -ExecutionPolicy Bypass -File tool\preparar_litert_web.ps1
#   powershell -ExecutionPolicy Bypass -File tool\preparar_litert_web.ps1 -Version 0.2.1
#
# Sin -Version usa la última. El script imprime la que quedó; anótala si quieres
# fijarla.
param([string]$Version = 'latest')

$ErrorActionPreference = 'Stop'
$destino = Join-Path $PSScriptRoot '..\web\litert'

$tmp = Join-Path ([IO.Path]::GetTempPath()) 'signcast_litert'
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force $tmp | Out-Null

Push-Location $tmp
try {
    $tgz = (npm pack "@litertjs/core@$Version" --silent | Select-Object -Last 1).Trim()
    New-Item -ItemType Directory -Force core | Out-Null
    tar -xzf $tgz -C core
    # Dependencia de @litertjs/core; web/index.html la mapea con un import map.
    $tgzUtils = (npm pack "@litertjs/wasm-utils@$Version" --silent | Select-Object -Last 1).Trim()
    New-Item -ItemType Directory -Force utils | Out-Null
    tar -xzf $tgzUtils -C utils
} finally {
    Pop-Location
}

$paquete = Join-Path $tmp 'core\package'
$paqueteUtils = Join-Path $tmp 'utils\package'
$pkg = Get-Content (Join-Path $paquete 'package.json') -Raw | ConvertFrom-Json

# Archivo de entrada de un paquete (módulo ES).
function Get-Entrada($p) {
$entrada = $p.module
if (-not $entrada -and $p.exports -and $p.exports.'.') {
    $e = $p.exports.'.'
    $entrada = if ($e -is [string]) { $e } elseif ($e.import) { $e.import } else { $e.default }
}
if (-not $entrada) { $entrada = $p.main }
if (-not $entrada) {
    Write-Error "No se encontró el archivo de entrada en el package.json de $($p.name)"
    exit 1
}
return ($entrada -replace '^\./', '')
}
$entrada = Get-Entrada $pkg
$pkgUtils = Get-Content (Join-Path $paqueteUtils 'package.json') -Raw | ConvertFrom-Json
$entradaUtils = Get-Entrada $pkgUtils

# Carpeta con los .wasm.
$wasm = Get-ChildItem $paquete -Recurse -Filter '*.wasm' | Select-Object -First 1
if (-not $wasm) {
    Write-Error 'El paquete @litertjs/core no trae archivos .wasm'
    exit 1
}

if (Test-Path $destino) { Remove-Item -Recurse -Force $destino }
New-Item -ItemType Directory -Force (Join-Path $destino 'wasm') | Out-Null
Copy-Item (Join-Path $wasm.DirectoryName '*') (Join-Path $destino 'wasm') -Recurse -Force
Copy-Item $paquete (Join-Path $destino 'paquete') -Recurse -Force
# Los .wasm ya están en wasm/; la copia dentro del paquete solo duplicaría el tamaño.
Remove-Item -Recurse -Force (Join-Path $destino 'paquete\wasm') -ErrorAction SilentlyContinue
Copy-Item $paqueteUtils (Join-Path $destino 'wasm-utils') -Recurse -Force

# web/modelo/modelo.js importa "litert/litert.js".
Set-Content (Join-Path $destino 'litert.js') "export * from './paquete/$entrada';" -Encoding ASCII
Set-Content (Join-Path $destino 'wasm_utils.js') "export * from './wasm-utils/$entradaUtils';" -Encoding ASCII
Set-Content (Join-Path $destino 'VERSION.txt') "@litertjs/core $($pkg.version)" -Encoding ASCII

Write-Host "Copiado LiteRT.js $($pkg.version) (entrada: $entrada)"
Remove-Item -Recurse -Force $tmp
