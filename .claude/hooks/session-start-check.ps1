<#
.SYNOPSIS
    Hook SessionStart: comprueba si .claude/project-config.json existe. Si no
    existe, este repo no ha pasado por el bootstrap (skill requirements-intake)
    y no deberia asumirse ningun escenario de licencia ni convencion de proyecto.

    Hallazgo confirmado en dogfooding real (2 sesiones de Claude Code
    reales, distintas): el aviso de este hook NO llegó de forma visible al
    agente en ninguna de las dos, pese a que project-config.json no existía
    y el script (probado también en aislado) sí escribe a stderr y sale con
    exit 2 correctamente. A diferencia de los hooks PostToolUse (que sí
    propagan su exit 2 como system-reminder de bloqueo, confirmado en el
    mismo dogfooding), SessionStart no parece propagarse igual -- o al
    menos no en las condiciones probadas. Trátalo como un mecanismo de
    mejor esfuerzo que puede no llegar nunca al agente, no como una
    garantía: files/context/flujo-trabajo.md ya instruye al agente a
    comprobar este mismo fichero al principio de sesión como mecanismo
    independiente, y esto confirma que ese mecanismo independiente es
    necesario, no opcional.
#>

$ErrorActionPreference = 'Stop'

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { $projectDir = (Get-Location).Path }

$configPath = Join-Path $projectDir '.claude\project-config.json'

if (Test-Path $configPath) {
    exit 0
}

[Console]::Error.WriteLine("[session-start-check] No existe .claude/project-config.json: este proyecto no ha pasado por el bootstrap. Invoca el skill requirements-intake (incluye la deteccion obligatoria del escenario de licencia A/B) antes de asumir ninguna capacidad de automatizacion.")
exit 2
