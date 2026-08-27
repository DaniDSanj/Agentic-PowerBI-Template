<#
.SYNOPSIS
    Validacion de CI: para cada fichero PBIR (visual.json, page.json,
    report.json, bookmarks/*.json) tocado en el PR, valida que sea JSON
    sintacticamente correcto y, si declara "$schema", que cumpla el array
    "required" de nivel superior del schema publico. Es la contraparte de
    servidor del hook local `post-edit-pbir.ps1` -- misma logica, pero
    aplicada a todo el diff del PR en vez de a un solo fichero tocado por un
    Edit/Write, y con exit 1 (falla de job) en vez de exit 2 (bloqueo de
    hook).

    Es una comprobacion SUPERFICIAL (solo top-level "required"), no una
    validacion completa de JSON Schema -- mismo alcance que el hook local,
    documentado ahi como limitacion deliberada. El subagente
    `pbir-schema-validator` sigue siendo necesario para un analisis completo
    dentro de una sesion de Claude Code; este script cubre el caso en el que
    no hay ningun agente ejecutando el PR (CI puro).

.PARAMETER RepoRoot
    Raiz del repo. Por defecto, el directorio de trabajo actual.

.PARAMETER BaseRef
    Referencia git contra la que diffear para encontrar ficheros tocados
    (normalmente el SHA/rama base del PR).
#>
param(
    [string]$RepoRoot = (Get-Location).Path,
    [Parameter(Mandatory = $true)][string]$BaseRef
)

$ErrorActionPreference = 'Stop'
Set-Location $RepoRoot

$changedFiles = git diff --name-only --diff-filter=ACMR "$BaseRef...HEAD"
if (-not $changedFiles) {
    Write-Output "Sin ficheros modificados frente a '$BaseRef'."
    exit 0
}

$pbirFiles = $changedFiles | Where-Object {
    ($_ -match 'definition[\\/]pages[\\/].*\.json$') -or
    ($_ -match '[\\/]bookmarks[\\/].*\.json$') -or
    ($_ -match 'report\.json$')
} | Where-Object { Test-Path (Join-Path $RepoRoot $_) }

if (-not $pbirFiles) {
    Write-Output "Ningun fichero PBIR (visual.json/page.json/report.json/bookmarks) tocado en este PR."
    exit 0
}

$anyError = $false

foreach ($relPath in $pbirFiles) {
    $fullPath = Join-Path $RepoRoot $relPath
    Write-Output "=== Validando '$relPath' ==="

    $content = Get-Content -Raw -Path $fullPath -ErrorAction SilentlyContinue
    try {
        $json = $content | ConvertFrom-Json
    } catch {
        Write-Output "::error file=$relPath::JSON invalido: $($_.Exception.Message)"
        $anyError = $true
        continue
    }

    if (-not $json.'$schema') {
        Write-Output "::warning file=$relPath::No declara la propiedad `"`$schema`"; no se puede validar contra el schema oficial de PBIR."
        continue
    }

    $schemaUrl = $json.'$schema'
    try {
        $schemaRaw = Invoke-WebRequest -Uri $schemaUrl -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        $schema = $schemaRaw.Content | ConvertFrom-Json
    } catch {
        Write-Output "::warning file=$relPath::No se pudo resolver/leer el `$schema declarado ($schemaUrl); solo se valido sintaxis JSON."
        continue
    }

    if ($schema.required) {
        $missing = @()
        foreach ($prop in $schema.required) {
            if (-not ($json.PSObject.Properties.Name -contains $prop)) {
                $missing += $prop
            }
        }
        if ($missing.Count -gt 0) {
            Write-Output "::error file=$relPath::No cumple propiedades requeridas por su `$schema ($schemaUrl): $($missing -join ', ')"
            $anyError = $true
        }
    }
}

if ($anyError) {
    exit 1
}

Write-Output "Validacion PBIR: sin errores."
exit 0
