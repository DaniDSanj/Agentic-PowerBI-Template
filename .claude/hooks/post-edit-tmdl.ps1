<#
.SYNOPSIS
    Hook PostToolUse: tras cada Edit/Write, si el fichero tocado es .tmdl, ejecuta
    Tabular Editor 2 CLI con las reglas BPA del proyecto y bloquea (exit 2) si hay
    violaciones de severidad Error. Warnings/Info no bloquean aquí -- eso lo
    interpreta el subagente bpa-reviewer cuando se invoca explícitamente antes de
    cerrar la unidad de trabajo (ver files/context/flujo-trabajo.md).

    Verificado de extremo a extremo en dogfooding real (sesión de Claude Code
    real, TE2 2.28.0, PowerShell 5.1 vía powershell.exe): el contrato
    stdin/exit-code de los hooks SÍ funciona -- un exit 2 aquí llega al agente
    como system-reminder de bloqueo literal con el texto que se escribe a
    stderr. IMPORTANTE: ese bloqueo es informativo, no preventivo -- el
    Edit/Write ya se aplicó al fichero antes de que este hook corra; exit 2
    no lo revierte, solo obliga a que el agente lo corrija en una edición
    posterior.

    Dos bugs reales encontrados y corregidos en ese mismo dogfooding:
    - TE2 CLI (probado en 2.18.2 y 2.28.0) carga un modelo TMDL apuntando a
      la subcarpeta "definition" de "*.SemanticModel" (donde vive
      model.tmdl), NO a la carpeta "*.SemanticModel" en sí -- esta última
      da "File not found". Exige además TE2 >= 2.20.0 (sep-2023): versiones
      anteriores usaban la extensión .tmd y no reconocen los ficheros .tmdl
      que genera Power BI Desktop hoy (fallan con un error de parseo JSON).
    - Invocar el CLI con "& $teExe ... 2>&1" no captura de forma fiable
      stdout/stderr/exit-code cuando este script corre como subproceso no
      interactivo del harness de hooks (devuelve todo vacío). Usar la API
      de Process (.NET) con redirección explícita sí funciona en ese mismo
      contexto -- ver más abajo.

    TABULAR_EDITOR_PATH: definir esta variable a nivel de SO (setx) no basta
    -- una sesión de Claude Code ya abierta no la hereda, y ni siquiera una
    sesión nueva la recoge de forma fiable en todos los casos observados.
    El mecanismo verificado que sí funciona (incluso en caliente, sin
    reiniciar sesión) es el campo "env" de nivel raíz en settings.json:
      { "env": { "TABULAR_EDITOR_PATH": "C:\\ruta\\a\\TabularEditor.exe" } }
    Documenta esto en el README del proyecto instalado en vez de pedir al
    usuario que use setx.
#>

$ErrorActionPreference = 'Stop'

# Log opcional a fichero para depurar qué vio este hook (TE2 encontrado,
# exit code, salida cruda) sin depender de lo que el harness le muestre al
# agente -- crucial porque un exit 0 no propaga su stderr de forma visible.
# Añade ".claude/hook-debug.log" al .gitignore del proyecto instalado.
$debugLog = Join-Path $env:CLAUDE_PROJECT_DIR '.claude\hook-debug.log'
function Write-HookLog {
    param([string]$msg)
    try { Add-Content -Path $debugLog -Value "$(Get-Date -Format o) $msg" -Encoding utf8 } catch {}
}

function Exit-Quiet {
    exit 0
}

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { Exit-Quiet }
    $data = $raw | ConvertFrom-Json
} catch {
    # Si no podemos parsear el payload del hook, no rompemos el flujo del agente.
    Exit-Quiet
}

$filePath = $null
if ($data.tool_input) {
    if ($data.tool_input.file_path) { $filePath = $data.tool_input.file_path }
    elseif ($data.tool_input.path) { $filePath = $data.tool_input.path }
}

if (-not $filePath -or ($filePath -notmatch '\.tmdl$')) {
    Exit-Quiet
}

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { $projectDir = (Get-Location).Path }

Write-HookLog "=== post-edit-tmdl invoked for '$filePath'. TABULAR_EDITOR_PATH='$env:TABULAR_EDITOR_PATH'"

# Localiza el ejecutable de Tabular Editor 2.
$teExe = $env:TABULAR_EDITOR_PATH
if (-not $teExe) {
    $found = Get-Command TabularEditor.exe -ErrorAction SilentlyContinue
    if ($found) { $teExe = $found.Source }
}

if (-not $teExe -or -not (Test-Path $teExe)) {
    Write-HookLog "TE2 NOT FOUND. teExe='$teExe'"
    [Console]::Error.WriteLine("[post-edit-tmdl] Aviso: no se encontro Tabular Editor 2 (define TABULAR_EDITOR_PATH, preferiblemente vía el campo 'env' de settings.json). BPA no se ha ejecutado tras editar '$filePath'.")
    Exit-Quiet
}
Write-HookLog "TE2 found at '$teExe'"

$bpaRules = Join-Path $projectDir 'tools\BPARules.json'
if (-not (Test-Path $bpaRules)) {
    Write-HookLog "BPARules.json NOT FOUND at '$bpaRules'"
    [Console]::Error.WriteLine("[post-edit-tmdl] Aviso: no existe tools/BPARules.json. BPA no se ha ejecutado tras editar '$filePath'.")
    Exit-Quiet
}

$semanticModelDir = Get-ChildItem -Path $projectDir -Directory -Filter '*.SemanticModel' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $semanticModelDir) {
    Write-HookLog "SemanticModel dir NOT FOUND under '$projectDir'"
    [Console]::Error.WriteLine("[post-edit-tmdl] Aviso: no se encontro ninguna carpeta *.SemanticModel bajo '$projectDir'.")
    Exit-Quiet
}

# El modelo TMDL vive en la subcarpeta "definition" -- ver nota de cabecera.
$tmdlDefinitionDir = Join-Path $semanticModelDir.FullName 'definition'
if (-not (Test-Path (Join-Path $tmdlDefinitionDir 'model.tmdl'))) {
    Write-HookLog "model.tmdl NOT FOUND under '$tmdlDefinitionDir'"
    [Console]::Error.WriteLine("[post-edit-tmdl] Aviso: no se encontro '$tmdlDefinitionDir\model.tmdl'. BPA no se ha ejecutado tras editar '$filePath'.")
    Exit-Quiet
}
Write-HookLog "TMDL definition dir found: '$tmdlDefinitionDir'"

# Ver nota de cabecera: NO usar "& $teExe ... 2>&1" aquí, no captura de
# forma fiable stdout/stderr/exit-code en este contexto no interactivo.
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $teExe
$psi.Arguments = "`"$tmdlDefinitionDir`" -A `"$bpaRules`" -V"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$teProc = New-Object System.Diagnostics.Process
$teProc.StartInfo = $psi
$teProc.Start() | Out-Null
$stdout = $teProc.StandardOutput.ReadToEnd()
$stderr = $teProc.StandardError.ReadToEnd()
$teProc.WaitForExit()
$exitCode = $teProc.ExitCode
$output = ($stdout + "`n" + $stderr) -split "`r?`n"
Write-HookLog "TE2 exit code: $exitCode"
Write-HookLog "TE2 raw output:`n$($output | Out-String)"

# -V (VSTS logging commands) etiqueta cada violación como
# "##vso[task.logissue type=error;]..." o "type=warning;..." según su
# severidad en BPARules.json (Error / Warning respectivamente; Info no se
# etiqueta). El regex de abajo por tanto captura fiablemente solo las
# violaciones de severidad Error -- confirmado con reglas reales
# (ej. META_AVOID_FLOAT, severidad 3) en dogfooding.
$errorLines = $output | Where-Object { $_ -match '(?i)\berror\b' }
Write-HookLog "Lines matching /error/i: $($errorLines.Count)"

if ($errorLines) {
    [Console]::Error.WriteLine("[post-edit-tmdl] BPA encontro violaciones de severidad Error tras editar '$filePath':")
    $errorLines | ForEach-Object { [Console]::Error.WriteLine("  $_") }
    [Console]::Error.WriteLine("Corrige estas violaciones antes de continuar, o invoca el skill bpa-validate para un analisis completo.")
    exit 2
}

exit 0
