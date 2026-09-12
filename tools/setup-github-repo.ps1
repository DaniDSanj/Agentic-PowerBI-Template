<#
.SYNOPSIS
    Configura por completo la parte de GitHub de un repo (esta plantilla, o
    un repo cliente creado a partir de ella): opcionalmente crea el repo
    desde la plantilla, crea/protege dev+main, y activa secret scanning
    nativo si el repo es publico.

.DESCRIPTION
    GitHub NO copia branch protection ni ninguna otra configuracion del repo
    al crear uno con "Use this template" -- copia ficheros, y de las ramas
    solo la rama por defecto (main), no dev. Este script existe para dejar
    un repo (esta plantilla, o cualquier repo cliente creado a partir de
    ella) correctamente configurado del lado de GitHub de un solo golpe.
    Ejecutarlo una vez tras el primer push del repo cliente es obligatorio,
    no opcional. Es idempotente -- puede volver a ejecutarse sin efectos
    distintos de "queda igual".

    Dos modos, segun se pase -ClientName o no:

    - Con -ClientName: crea el repo nuevo desde esta plantilla (autodetecta
      de que plantilla, leyendo el remoto 'origin' del directorio actual --
      hay que ejecutar este modo desde un clon local de la plantilla, nunca
      desde un repo cliente ya creado), lo clona, y aplica todo lo de abajo
      dentro de el.
    - Sin -ClientName: actua sobre el repo del directorio actual (autodetecta
      Owner/Repo de su remoto 'origin') -- para aplicar/reaplicar esto sobre
      un repo que ya existe (la propia plantilla, o un repo cliente ya
      clonado).

    Alcance deliberado (acordado explicitamente): este script solo toca
    configuracion de GitHub. NO instala nada en el equipo local (Tabular
    Editor 2, DAX Studio, gitleaks) -- esos pasos quedan impresos al final
    como pendientes manuales, ver files/context/limites-duros.md.

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
    'main' si todavia no existe, asi que no hace falta que "Use this
    template" la traiga consigo.

    Requiere: gh CLI autenticado con permisos de administrador del repo
    (scope 'repo' como minimo, y para crear repos nuevos). No gestiona
    secretos ni tokens -- usa la sesion de gh ya autenticada en la maquina
    de quien lo ejecuta.

    IMPORTANTE (confirmado empiricamente, no documentacion generica de
    GitHub): en un repo PRIVADO con plan Free, la API de branch protection
    (tanto la clasica como los rulesets) devuelve 403 "Upgrade to GitHub Pro
    or make this repository public to enable this feature". No hay
    workaround gratuito -- o el repo es publico, o el owner tiene GitHub Pro
    (de pago, requiere autorizacion explicita del cliente por
    files/context/limites-duros.md). Este script falla explicitamente (no
    reporta "OK" con un 403 de fondo) si se topa con ese bloqueo -- decide
    la visibilidad ANTES de ejecutarlo, con esta consecuencia ya conocida.

.PARAMETER ClientName
    Si se pasa, activa el modo "crear repo nuevo". Admite "Nombre" (se crea
    bajo la cuenta autenticada de gh) o "Owner/Nombre" (se crea bajo esa
    cuenta/organizacion) -- gh repo create interpreta ambos formatos.

.PARAMETER Visibility
    'Public' (por defecto) o 'Private'. Solo se usa si se pasa -ClientName
    (decide con que visibilidad se crea el repo nuevo). Si es 'Private',
    branch protection puede fallar con 403 en plan Free -- el script lo
    explica y para, no lo oculta.

.EXAMPLE
    # Repo cliente nuevo, publico, bajo la cuenta autenticada:
    pwsh -File tools/setup-github-repo.ps1 -ClientName Informe-ClienteX

.EXAMPLE
    # Repo cliente nuevo, privado, bajo una organizacion:
    pwsh -File tools/setup-github-repo.ps1 -ClientName MiOrg/Informe-ClienteX -Visibility Private

.EXAMPLE
    # Reaplicar sobre el repo del directorio actual (esta plantilla, o un cliente ya creado):
    pwsh -File tools/setup-github-repo.ps1
#>
[CmdletBinding()]
param(
    [string]$ClientName,
    [ValidateSet('Public', 'Private')]
    [string]$Visibility = 'Public'
)

$ErrorActionPreference = 'Stop'

function Get-OriginOwnerRepo {
    $url = git remote get-url origin 2>$null
    if (-not $url) {
        throw "No se pudo leer el remoto 'origin' del directorio actual."
    }
    # Soporta https://github.com/Owner/Repo.git y git@github.com:Owner/Repo.git
    if ($url -match 'github\.com[:/]+([^/]+)/([^/]+?)(\.git)?$') {
        return @{ Owner = $Matches[1]; Repo = $Matches[2] }
    }
    throw "No se pudo interpretar el remoto 'origin' ('$url') como repo de GitHub."
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "No se encuentra 'gh' (GitHub CLI) en el PATH. Instalalo y autenticate (gh auth login) antes de continuar."
}
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host ($authStatus | Out-String) -ForegroundColor Red
    throw "gh no esta autenticado en esta maquina. Ejecuta 'gh auth login' antes de continuar."
}

if ($ClientName) {
    Write-Host "Modo: crear repo nuevo '$ClientName' desde esta plantilla." -ForegroundColor Cyan

    $template = Get-OriginOwnerRepo
    $templateSlug = "$($template.Owner)/$($template.Repo)"
    Write-Host "Plantilla detectada (remoto 'origin' de este directorio): $templateSlug" -ForegroundColor Cyan

    $visibilityFlag = if ($Visibility -eq 'Private') { '--private' } else { '--public' }
    if ($Visibility -eq 'Private') {
        Write-Host "Visibilidad: Private -- branch protection y secret scanning nativo requieren GitHub Pro en plan Free (devolveran 403 si no lo tienes). Este script fallara explicitamente si ocurre, en vez de reportar exito falso." -ForegroundColor Yellow
    }

    gh repo create $ClientName --template $templateSlug $visibilityFlag
    if ($LASTEXITCODE -ne 0) {
        throw "gh repo create fallo (exit code $LASTEXITCODE). Revisa el mensaje de gh arriba."
    }

    # OJO: NO se usa --clone aqui. Se vio "failed to run git: exit status 128"
    # con --clone en pruebas, pero investigado a fondo la causa real en ese
    # caso concreto fue una ruta de Windows demasiado larga (MAX_PATH) en el
    # directorio desde el que se ejecutaba el script -- no una condicion de
    # carrera de propagacion de GitHub (una prueba repetida desde una ruta
    # corta funciono a la primera, sin reintentos). Aun asi, separar create y
    # clone con un pequeno reintento es una defensa razonable y barata por si
    # existiera alguna demora real de propagacion en otros escenarios -- no
    # se ha confirmado que la haya, pero tampoco que no pueda darse nunca.
    $cloneDir = ($ClientName -split '/')[-1]
    Write-Host "Repo creado. Clonando en '$cloneDir' (con reintentos por si acaso)..." -ForegroundColor Cyan
    $maxAttempts = 6
    $cloned = $false
    for ($attempt = 1; $attempt -le $maxAttempts -and -not $cloned; $attempt++) {
        if (Test-Path $cloneDir) { Remove-Item -Recurse -Force $cloneDir }
        gh repo clone $ClientName $cloneDir 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $cloned = $true } else { Start-Sleep -Seconds 5 }
    }
    if (-not $cloned) {
        throw "No se pudo clonar '$ClientName' tras $maxAttempts intentos. El repo SI se creo en GitHub -- reintenta manualmente en unos segundos: gh repo clone $ClientName"
    }

    Write-Host "Clonado en '$cloneDir'. Continuando configuracion dentro de esa carpeta..." -ForegroundColor Cyan
    Set-Location $cloneDir
    $detected = Get-OriginOwnerRepo
    $Owner = $detected.Owner
    $Repo = $detected.Repo
}
else {
    $detected = Get-OriginOwnerRepo
    $Owner = $detected.Owner
    $Repo = $detected.Repo
}

Write-Host "Repo objetivo: $Owner/$Repo" -ForegroundColor Cyan

function Test-BranchExists {
    param([string]$Branch)
    # OJO: gh api escribe el cuerpo JSON del error (p.ej. 404 "Branch not
    # found") en STDOUT, no solo en STDERR -- comprobar solo si $result es
    # no-vacio da un falso positivo (un 404 real parece "existe"). Hay que
    # mirar el exit code, no el contenido de la salida.
    gh api "repos/$Owner/$Repo/branches/$Branch" 2>$null 1>$null
    return ($LASTEXITCODE -eq 0)
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
            strict = $true
            checks = @($RequiredChecks | ForEach-Object { @{ context = $_ } })
        }
        enforce_admins                = $true
        required_pull_request_reviews = @{
            required_approving_review_count = $RequiredApprovingReviews
            dismiss_stale_reviews           = $true
        }
        restrictions                     = $null
        allow_force_pushes               = $false
        allow_deletions                  = $false
        required_linear_history          = $false
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

Write-Host "Comprobando visibilidad para el secret scanning nativo de GitHub..." -ForegroundColor Cyan
$repoVisibility = gh api "repos/$Owner/$Repo" --jq '.visibility'
if ($repoVisibility -eq 'public') {
    try {
        gh api "repos/$Owner/$Repo" -X PATCH `
            -F 'security_and_analysis[secret_scanning][status]=enabled' `
            -F 'security_and_analysis[secret_scanning_push_protection][status]=enabled' | Out-Null
        Write-Host "OK: secret scanning + push protection nativos de GitHub activados (repo publico, gratis)." -ForegroundColor Green
    }
    catch {
        Write-Host "Aviso: no se pudo activar el secret scanning nativo ($($_.Exception.Message)). No es bloqueante -- gitleaks en CI sigue siendo la capa autoritativa." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Repo privado: no se activa secret scanning nativo (requiere GitHub Advanced Security, de pago, en repos privados). La capa autoritativa sigue siendo el job 'gitleaks' de CI + el hook local best-effort." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Listo. Verifica con:" -ForegroundColor Cyan
Write-Host "  gh api repos/$Owner/$Repo/branches/main/protection"
Write-Host "  gh api repos/$Owner/$Repo/branches/dev/protection"
Write-Host ""
Write-Host "Pendiente -- pasos manuales que este script NO automatiza (ver files/context/limites-duros.md):" -ForegroundColor Cyan
Write-Host "  1. Abre este repo con Claude Code desde su propia carpeta (no desde otra sesion)."
Write-Host "  2. Instala la toolchain local: Power BI Desktop, Tabular Editor 2 (>= 2.20.0), DAX Studio, y gitleaks si quieres que el hook local de secretos bloquee de verdad."
Write-Host "  3. Invoca (o deja que se dispare) el skill 'requirements-intake' para el bootstrap del proyecto."
