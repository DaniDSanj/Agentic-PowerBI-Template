<#
.SYNOPSIS
    Aplica la branch protection de este repo (main + dev) via GitHub API (gh api).

.DESCRIPTION
    GitHub NO copia branch protection ni ninguna otra configuracion del repo
    al crear uno con "Use this template" -- copia ficheros, y de las ramas
    solo la rama por defecto (main), no dev. Este script existe para
    reaplicar la proteccion (y crear dev si falta) en cualquier repo (esta
    plantilla, o cualquier repo cliente creado a partir de ella): ejecutarlo
    una vez tras el primer push es obligatorio, no opcional. Es idempotente
    -- puede volver a ejecutarse sin efectos distintos de "queda igual".

    Modelo de ramas (ver files/context/control-versiones.md):
    - dev: rama de integracion. Todo feature/fix pasa por PR contra dev,
      revisada + CI en verde. Sin push directo.
    - main: solo se promueve desde dev o release/* (PR explicita). Sin push
      directo, sin fuerza, sin borrado. El job de CI "source-branch-gate"
      (definido en .github/workflows/validate-pr.yml) es el que realmente
      hace cumplir "solo desde dev/release/*" -- GitHub no tiene un
      mecanismo nativo de branch protection para restringir la rama origen
      de una PR, asi que se fuerza como required status check.

    IMPORTANTE: este script NUNCA cambia el default_branch del repo -- debe
    seguir siendo 'main' siempre, en la plantilla y en cada repo cliente.
    "Use this template" (boton web o gh repo create) solo copia el
    default_branch salvo que se marque explicitamente "Include all
    branches" -- si el default_branch fuera 'dev', un repo cliente nuevo
    naceria con una sola rama y sin 'main' en absoluto. 'dev' es solo la
    rama de trabajo/integracion; no debe marcarse "Include all branches" al
    crear el repo cliente -- este mismo script es quien crea 'dev' desde
    'main' si todavia no existe (ver mas abajo), asi que no hace falta que
    "Use this template" la traiga consigo.

    Requiere: gh CLI autenticado con permisos de administrador del repo
    (scope 'repo' como minimo). No gestiona secretos ni tokens -- usa la
    sesion de gh ya autenticada en la maquina de quien lo ejecuta.

    IMPORTANTE (confirmado empiricamente, no documentacion generica de
    GitHub): en un repo PRIVADO con plan Free, la API de branch protection
    (tanto la clasica como los rulesets) devuelve 403 "Upgrade to GitHub Pro
    or make this repository public to enable this feature". No hay
    workaround gratuito -- o el repo es publico, o el owner tiene GitHub Pro
    (de pago, requiere autorizacion explicita del cliente por
    files/context/limites-duros.md). Este script falla explicitamente (no
    reporta "OK" con un 403 de fondo) si se topa con ese bloqueo.

.PARAMETER Owner
    Owner/organizacion del repo en GitHub. Por defecto se detecta del remoto 'origin'.

.PARAMETER Repo
    Nombre del repo en GitHub. Por defecto se detecta del remoto 'origin'.

.EXAMPLE
    pwsh -File tools/setup-branch-protection.ps1

.EXAMPLE
    pwsh -File tools/setup-branch-protection.ps1 -Owner MiCliente -Repo Informe-Ventas
#>
[CmdletBinding()]
param(
    [string]$Owner,
    [string]$Repo
)

$ErrorActionPreference = 'Stop'

function Get-OriginOwnerRepo {
    $url = git remote get-url origin 2>$null
    if (-not $url) {
        throw "No se pudo leer el remoto 'origin'. Pasa -Owner y -Repo explicitamente."
    }
    # Soporta https://github.com/Owner/Repo.git y git@github.com:Owner/Repo.git
    if ($url -match 'github\.com[:/]+([^/]+)/([^/]+?)(\.git)?$') {
        return @{ Owner = $Matches[1]; Repo = $Matches[2] }
    }
    throw "No se pudo interpretar el remoto 'origin' ('$url') como repo de GitHub."
}

if (-not $Owner -or -not $Repo) {
    $detected = Get-OriginOwnerRepo
    if (-not $Owner) { $Owner = $detected.Owner }
    if (-not $Repo) { $Repo = $detected.Repo }
}

Write-Host "Repo objetivo: $Owner/$Repo" -ForegroundColor Cyan

function Test-BranchExists {
    param([string]$Branch)
    $result = gh api "repos/$Owner/$Repo/branches/$Branch" 2>$null
    return [bool]$result
}

if (-not (Test-BranchExists -Branch 'dev')) {
    Write-Host "La rama 'dev' no existe todavia en el remoto: creandola desde 'main'." -ForegroundColor Yellow
    $mainSha = gh api "repos/$Owner/$Repo/git/ref/heads/main" --jq '.object.sha'
    gh api "repos/$Owner/$Repo/git/refs" -X POST -f ref='refs/heads/dev' -f sha="$mainSha" | Out-Null
}

function Set-BranchProtection {
    param(
        [string]$Branch,
        [string[]]$RequiredChecks,
        [int]$RequiredApprovingReviews
    )

    Write-Host "Aplicando proteccion sobre '$Branch' (checks: $($RequiredChecks -join ', '))..." -ForegroundColor Cyan

    $payload = @{
        required_status_checks       = @{
            strict   = $true
            checks   = @($RequiredChecks | ForEach-Object { @{ context = $_ } })
        }
        enforce_admins               = $true
        required_pull_request_reviews = @{
            required_approving_review_count = $RequiredApprovingReviews
            dismiss_stale_reviews            = $true
        }
        restrictions                 = $null
        allow_force_pushes           = $false
        allow_deletions             = $false
        required_linear_history      = $false
        required_conversation_resolution = $true
    }

    $tmpFile = New-TemporaryFile
    $output = $null
    try {
        $payload | ConvertTo-Json -Depth 10 | Set-Content -Path $tmpFile -Encoding utf8
        $output = gh api "repos/$Owner/$Repo/branches/$Branch/protection" -X PUT --input $tmpFile -H "Accept: application/vnd.github+json" 2>&1
    }
    finally {
        Remove-Item $tmpFile -ErrorAction SilentlyContinue
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host ($output | Out-String) -ForegroundColor Red
        throw "No se pudo aplicar branch protection sobre '$Branch' (gh api devolvio exit code $LASTEXITCODE). Si el mensaje menciona 'Upgrade to GitHub Pro or make this repository public', es un bloqueo real de plan de GitHub: la branch protection (clasica y rulesets) requiere GitHub Pro o repo publico en repos privados de plan Free. No hay workaround gratuito por API -- decide con el usuario si se hace publico el repo, se pasa a GitHub Pro, o se acepta un enforcement solo por convencion (hooks + CI gate, sin bloqueo real de push/merge a nivel de GitHub)."
    }

    Write-Host "OK: '$Branch' protegida." -ForegroundColor Green
}

# dev: PR obligatoria + CI en verde. Sin minimo de aprobaciones (revisor
# unico == autor; GitHub no cuenta la propia aprobacion del autor como
# revision, asi que exigir 1 bloquearia siempre al propio autor).
Set-BranchProtection -Branch 'dev' -RequiredChecks @('validate', 'gitleaks') -RequiredApprovingReviews 0

# main: igual, mas el gate que obliga a que la PR venga de dev/release/*.
Set-BranchProtection -Branch 'main' -RequiredChecks @('validate', 'gitleaks', 'source-branch-gate') -RequiredApprovingReviews 0

# Deliberadamente NO se toca default_branch: debe seguir siendo 'main' (ver
# IMPORTANTE en la cabecera del fichero) para que "Use this template" siga
# copiando 'main' y no 'dev'.

Write-Host ""
Write-Host "Listo. Verifica con:" -ForegroundColor Cyan
Write-Host "  gh api repos/$Owner/$Repo/branches/main/protection"
Write-Host "  gh api repos/$Owner/$Repo/branches/dev/protection"
