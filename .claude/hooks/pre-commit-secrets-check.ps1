<#
.SYNOPSIS
    Hook PreToolUse (Bash) -- bloquea 'git commit' si gitleaks detecta un
    secreto en lo que hay staged.

.DESCRIPTION
    Capa local del escaneo de secretos, pero SOLO ata al agente de Claude
    Code -- este hook es un mecanismo de '.claude/settings.json', no de git,
    asi que no se dispara si quien commitea es un humano desde su propia
    terminal/IDE. Para esa proteccion (y para repos privados, ver mas abajo)
    existe ademas el hook nativo tools/git-hooks/pre-commit.ps1, que si ata a
    cualquiera en un clon donde se haya ejecutado
    'tools/setup-github.ps1 -LocalGuardOnly' -- este fichero y aquel
    comparten el mismo criterio de bloqueo deliberadamente, para no
    mantener dos fuentes de verdad divergentes.

    Comportamiento cuando 'gitleaks' no esta instalado en esta maquina,
    segun '.claude/project-config.json'.visibilidad:
    - "privado" (o repo privado confirmado por tools/setup-github.ps1):
      BLOQUEA (exit 2). Un repo privado en GitHub Free no tiene secret
      scanning nativo ni branch protection -- sin gitleaks local no queda
      ninguna red real, así que se prefiere forzar la instalación a
      reportar una verificación que no se hizo.
    - "publico" (o campo ausente/config inexistente, valor por defecto):
      avisa y deja pasar -- la capa autoritativa en ese caso es el job
      'gitleaks' de .github/workflows/validate-pr.yml (required status
      check en main/dev via tools/setup-github.ps1) mas el secret
      scanning nativo de GitHub, gratis en repos publicos.

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

$repoRoot = $env:CLAUDE_PROJECT_DIR
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

$visibilidad = 'publico'
$configPath = Join-Path $repoRoot '.claude\project-config.json'
if (Test-Path $configPath) {
    try {
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
        if ($config.visibilidad) { $visibilidad = $config.visibilidad }
    }
    catch { }
}

$gitleaks = Get-Command gitleaks -ErrorAction SilentlyContinue
if (-not $gitleaks) {
    if ($visibilidad -eq 'privado') {
        Write-Error "[pre-commit-secrets-check] Este repo esta marcado como 'privado' y gitleaks no esta instalado en esta maquina -- en un repo privado de GitHub Free no hay ninguna red de secretos si esta capa tambien falta. Instala gitleaks (https://github.com/gitleaks/gitleaks) antes de commitear."
        exit 2
    }
    Write-Host "[pre-commit-secrets-check] gitleaks no esta instalado en esta maquina -- no se escanea localmente. La capa autoritativa es el job 'gitleaks' de CI, que si bloqueara el merge si hay un secreto. Instala gitleaks (https://github.com/gitleaks/gitleaks) para tener tambien la capa local." -ForegroundColor Yellow
    exit 0
}

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
