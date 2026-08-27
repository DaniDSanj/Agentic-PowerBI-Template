<#
.SYNOPSIS
    Hook PostToolUse: tras cada Edit/Write sobre un fichero de definicion PBIR
    (visual.json, page.json, report.json, bookmarks/*.json), valida:
      1) que el JSON resultante sea sintacticamente valido (bloqueante, exit 2)
      2) que declare "$schema" (aviso, no bloqueante)
      3) si hay red disponible, un chequeo ligero de propiedades "required" del
         $schema declarado (aviso si no se puede resolver; NO es una validacion
         completa de JSON Schema -- eso lo hace el subagente pbir-schema-validator
         cuando se invoca explicitamente, con capacidad de razonar sobre el schema).

    Verificado de extremo a extremo en dogfooding real (sesión de Claude Code
    real): tanto el bloqueo por JSON inválido como el bloqueo por
    propiedad "required" ausente del $schema llegan al agente como
    system-reminder de bloqueo literal, incluyendo la resolución real por
    red del $schema público. Recuerda (ver cabecera de post-edit-tmdl.ps1)
    que ese bloqueo es informativo: el Edit/Write ya se aplicó, exit 2 no
    lo revierte.
#>

$ErrorActionPreference = 'Stop'

function Exit-Quiet {
    exit 0
}

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { Exit-Quiet }
    $data = $raw | ConvertFrom-Json
} catch {
    Exit-Quiet
}

$filePath = $null
if ($data.tool_input) {
    if ($data.tool_input.file_path) { $filePath = $data.tool_input.file_path }
    elseif ($data.tool_input.path) { $filePath = $data.tool_input.path }
}

$isPbir = $filePath -and (
    $filePath -match 'definition[\\/]pages[\\/].*\.json$' -or
    $filePath -match '[\\/]bookmarks[\\/].*\.json$' -or
    $filePath -match 'report\.json$'
)

if (-not $isPbir) {
    Exit-Quiet
}

if (-not (Test-Path $filePath)) {
    # El fichero pudo haber sido borrado en la misma operacion; nada que validar.
    Exit-Quiet
}

$content = Get-Content -Raw -Path $filePath -ErrorAction SilentlyContinue

try {
    $json = $content | ConvertFrom-Json
} catch {
    [Console]::Error.WriteLine("[post-edit-pbir] JSON invalido tras editar '$filePath': $($_.Exception.Message)")
    [Console]::Error.WriteLine("Un PBIR con JSON invalido puede impedir que Desktop abra el informe. Corrigelo antes de continuar.")
    exit 2
}

if (-not $json.'$schema') {
    [Console]::Error.WriteLine("[post-edit-pbir] Aviso: '$filePath' no declara la propiedad `"`$schema`". No se puede validar contra el schema oficial de PBIR.")
    exit 0
}

$schemaUrl = $json.'$schema'
try {
    $schemaRaw = Invoke-WebRequest -Uri $schemaUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $schema = $schemaRaw.Content | ConvertFrom-Json

    if ($schema.required) {
        $missing = @()
        foreach ($prop in $schema.required) {
            if (-not ($json.PSObject.Properties.Name -contains $prop)) {
                $missing += $prop
            }
        }
        if ($missing.Count -gt 0) {
            [Console]::Error.WriteLine("[post-edit-pbir] '$filePath' no cumple con propiedades requeridas por su `$schema ($schemaUrl): $($missing -join ', ')")
            [Console]::Error.WriteLine("Esta es una comprobacion superficial (solo top-level 'required'), no una validacion completa de JSON Schema. Invoca el subagente pbir-schema-validator para un analisis completo antes de dar el cambio por bueno.")
            exit 2
        }
    }
} catch {
    [Console]::Error.WriteLine("[post-edit-pbir] Aviso: no se pudo resolver/leer el `$schema declarado ($schemaUrl) para validar '$filePath'. Invoca el subagente pbir-schema-validator antes de dar el cambio por bueno.")
    exit 0
}

exit 0
