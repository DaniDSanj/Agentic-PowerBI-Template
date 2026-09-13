<#
.SYNOPSIS
    Git hook NATIVO pre-commit (no confundir con .claude/hooks/pre-commit-secrets-check.ps1,
    que es un hook de Claude Code). Bloquea cualquier commit con un posible
    secreto en lo staged -- sin importar quien lo haga: el agente, un
    humano desde su propia terminal, o cualquier IDE. Se activa via
    'git config core.hooksPath tools/git-hooks'
    ('tools/setup-github.ps1 -LocalGuardOnly'), config LOCAL de cada clon
    -- no viaja con el repo, hay que instalarlo en cada clon nuevo.

.DESCRIPTION
    Motivo de existir (ver files/context/control-versiones.md, seccion
    "Escenario privado (Free) -- capa de gobernanza local"): en un repo
    PRIVADO con plan GitHub Free no hay secret scanning nativo (requiere
    GitHub Advanced Security, de pago) ni forma de que un hook de
    '.claude/settings.json' proteja a nadie que no sea el propio agente de
    Claude Code -- ese hook (pre-commit-secrets-check.ps1) simplemente no
    se dispara si quien commitea es un humano desde su terminal. Este
    fichero SI se dispara siempre, porque es un mecanismo de git, no de
    Claude Code.

    Diferencia deliberada de comportamiento frente al hook de Claude Code
    equivalente cuando 'gitleaks' no esta instalado en la maquina:
    - Repo publico (o '.claude/project-config.json' inexistente/sin el
      campo 'visibilidad'): avisa y deja pasar (igual que hoy) -- el
      secret scanning nativo de GitHub sigue cubriendo esa capa gratis.
    - Repo privado ('visibilidad: "privado"'): BLOQUEA el commit (fail
      closed). No hay red de seguridad equivalente en un repo privado
      Free, asi que dejar pasar sin gitleaks equivaldria a no proteger
      nada en absoluto -- se prefiere forzar la instalacion a fabricar una
      verificacion que no se hizo (files/context/comportamiento-critico.md).

    Limite honesto que este hook NO cierra (documentado, no ocultado):
    solo protege commits hechos en un clon donde alguien ya ejecuto
    'tools/setup-github.ps1 -LocalGuardOnly'. Un clon nuevo sin ese paso, o
    una edicion de fichero hecha desde la propia web de GitHub, quedan
    fuera de su alcance por completo.
#>

$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    $root = git rev-parse --show-toplevel 2>$null
    if (-not $root) { throw "No se pudo determinar la raiz del repo (git rev-parse --show-toplevel)." }
    return $root
}

$repoRoot = Get-RepoRoot

$visibilidad = 'publico'
$configPath = Join-Path $repoRoot '.claude\project-config.json'
if (Test-Path $configPath) {
    try {
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
        if ($config.visibilidad) { $visibilidad = $config.visibilidad }
    }
    catch {
        Write-Host "[pre-commit] No se pudo leer '.claude/project-config.json' ($($_.Exception.Message)) -- se asume visibilidad 'publico' para esta comprobacion." -ForegroundColor Yellow
    }
}

$gitleaks = Get-Command gitleaks -ErrorAction SilentlyContinue
if (-not $gitleaks) {
    if ($visibilidad -eq 'privado') {
        Write-Host "[pre-commit] Este repo esta marcado como 'privado' en .claude/project-config.json y 'gitleaks' no esta instalado en esta maquina." -ForegroundColor Red
        Write-Host "En un repo privado de GitHub Free no hay secret scanning nativo ni branch protection -- gitleaks local es la unica red real. Instalalo (https://github.com/gitleaks/gitleaks) antes de commitear." -ForegroundColor Red
        exit 1
    }
    Write-Host "[pre-commit] 'gitleaks' no esta instalado -- no se escanea localmente. En un repo publico el secret scanning nativo de GitHub sigue cubriendo esto; instala gitleaks para tener tambien la capa local." -ForegroundColor Yellow
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
    Write-Host "[pre-commit] gitleaks ha detectado un posible secreto en los cambios staged. Commit bloqueado." -ForegroundColor Red
    Write-Host ($output | Out-String)
    Write-Host "Revisa el hallazgo arriba, quita el secreto del staged (git restore --staged <fichero> o edita el fichero) y vuelve a intentar el commit." -ForegroundColor Red
    exit 1
}

exit 0
