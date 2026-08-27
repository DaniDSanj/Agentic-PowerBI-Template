<#
.SYNOPSIS
    Hook PostToolUse (matcher: Bash): si el comando ejecutado fue un "git commit"
    y ese commit toco ficheros de modelo (*.tmdl) o de informe (definition/pages),
    recuerda invocar al subagente docs-writer (o el skill docs-sync) para
    regenerar data dictionary / linaje / README de consumidor.

    No bloquea nada que ya haya ocurrido (el commit ya esta hecho); usa exit 2
    solo como mecanismo para que el mensaje llegue de forma fiable al agente en
    el siguiente turno, no como rechazo de la accion.

    Verificado de extremo a extremo en dogfooding real (sesión de Claude Code
    real): tras un "git commit" que tocaba modelo/informe, el agente recibió
    el system-reminder de bloqueo con este mensaje literal, en el turno
    siguiente al commit -- el commit en sí no se ve afectado (ya estaba
    hecho cuando el hook corrió).
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

$command = $null
if ($data.tool_input -and $data.tool_input.command) {
    $command = $data.tool_input.command
}

if (-not $command -or ($command -notmatch 'git\s+commit')) {
    Exit-Quiet
}

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { $projectDir = (Get-Location).Path }

Push-Location $projectDir
try {
    $changedFiles = git show --name-only --pretty=format: HEAD 2>$null
} catch {
    Pop-Location
    Exit-Quiet
}
Pop-Location

if (-not $changedFiles) {
    Exit-Quiet
}

$touchesModelOrReport = $changedFiles | Where-Object {
    $_ -match '\.tmdl$' -or $_ -match 'definition[\\/]pages[\\/]'
}

if (-not $touchesModelOrReport) {
    Exit-Quiet
}

[Console]::Error.WriteLine("[post-commit-docs] El ultimo commit toca modelo/informe. Invoca ahora el subagente docs-writer (o el skill docs-sync) para regenerar docs/data-dictionary.md, docs/linaje-medidas.md y docs/README-consumidor.md antes de abrir/actualizar el PR.")
exit 2
