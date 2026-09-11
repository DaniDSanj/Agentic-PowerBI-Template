<#
.SYNOPSIS
    Hook PreToolUse (Bash) -- bloquea 'git commit' si gitleaks detecta un
    secreto en lo que hay staged.

.DESCRIPTION
    Capa local, best-effort, del escaneo de secretos. La capa autoritativa y
    bloqueante de verdad es el job 'gitleaks' de .github/workflows/validate-pr.yml
    (required status check en main/dev via tools/setup-branch-protection.ps1).
    Este hook solo evita que el secreto llegue a crearse como commit local en
    primer lugar -- pero si gitleaks no esta instalado en esta maquina, avisa
    y deja pasar sin bloquear (no se fabrica una verificacion que no se hizo;
    ver files/context/comportamiento-critico.md).

    Contrato Claude Code: recibe el payload de la tool call por stdin (JSON),
    exit 2 bloquea la ejecucion de la tool y su stderr se muestra al agente
    como motivo del bloqueo. Solo actua si el comando Bash es (o contiene)
    'git commit'; para cualquier otro comando, sale en 0 sin hacer nada.
#>

$ErrorActionPreference = 'Stop'

try {
    $stdin = [Console]::In.ReadToEnd()
    $payload = $stdin | ConvertFrom-Json
}
catch {
    exit 0
}

$command = $payload.tool_input.command
if (-not $command -or $command -notmatch 'git\s+commit') {
    exit 0
}

$gitleaks = Get-Command gitleaks -ErrorAction SilentlyContinue
if (-not $gitleaks) {
    Write-Host "[pre-commit-secrets-check] gitleaks no esta instalado en esta maquina -- no se escanea localmente. La capa autoritativa es el job 'gitleaks' de CI, que si bloqueara el merge si hay un secreto. Instala gitleaks (https://github.com/gitleaks/gitleaks) para tener tambien la capa local." -ForegroundColor Yellow
    exit 0
}

$repoRoot = $env:CLAUDE_PROJECT_DIR
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

Push-Location $repoRoot
try {
    $output = & gitleaks protect --staged --redact --verbose 2>&1
    $exitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($exitCode -ne 0) {
    Write-Host "[pre-commit-secrets-check] gitleaks ha detectado un posible secreto en los cambios staged. Commit bloqueado." -ForegroundColor Red
    Write-Host ($output | Out-String)
    Write-Error "Revisa el hallazgo de gitleaks arriba, quita el secreto del staged (git restore --staged <fichero> o edita el fichero) y vuelve a intentar el commit."
    exit 2
}

exit 0
