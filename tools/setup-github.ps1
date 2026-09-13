<#
.SYNOPSIS
    Script unico de gobernanza de repo: configura la parte de GitHub (esta
    plantilla, o un repo cliente creado a partir de ella) -- opcionalmente
    crea el repo desde la plantilla, crea/protege dev+main, activa secret
    scanning nativo si es publico -- y/o activa la capa de gobernanza local
    (tools/git-hooks/) para quien no necesita (o no puede) tocar la parte de
    GitHub.

.DESCRIPTION
    GitHub NO copia branch protection ni ninguna otra configuracion del repo
    al crear uno con "Use this template" -- copia ficheros, y de las ramas
    solo la rama por defecto (main), no dev. Este script existe para dejar
    un repo (esta plantilla, o cualquier repo cliente creado a partir de
    ella) correctamente configurado del lado de GitHub de un solo golpe.
    Ejecutarlo una vez tras el primer push del repo cliente es obligatorio,
    no opcional. Es idempotente -- puede volver a ejecutarse sin efectos
    distintos de "queda igual".

    Antes eran dos scripts separados (`setup-github-repo.ps1` +
    `setup-local-git-guard.ps1`); se fusionaron en este a peticion del
    usuario para tener un unico punto de entrada. La fusion no es un simple
    pegado: la parte de GitHub requiere `gh` autenticado con permisos de
    ADMINISTRADOR del repo (crear/proteger ramas), mientras que la parte del
    guard local (`core.hooksPath`) no toca la API de GitHub en absoluto y la
    puede ejecutar cualquiera. Dos casos reales donde esa diferencia importa:
    un colaborador con acceso "Write" pero no "Admin" en el repo cliente
    (minimo privilegio, no todo el mundo que commitea deberia poder tocar
    branch protection), o el propio administrador autenticado en `gh` con un
    token de alcance reducido (fine-grained PAT sin el permiso
    `administration`) por politica de seguridad corporativa. Por eso existe
    el modo `-LocalGuardOnly` (ver mas abajo): quien este en cualquiera de
    esos casos puede activar su guard local sin necesitar en absoluto
    permisos de administrador ni siquiera tener `gh` instalado.

    Tres modos, mutuamente excluyentes:

    - Con -ClientName: crea el repo nuevo desde esta plantilla (autodetecta
      de que plantilla, leyendo el remoto 'origin' del directorio actual --
      hay que ejecutar este modo desde un clon local de la plantilla, nunca
      desde un repo cliente ya creado), lo clona, y aplica todo lo de abajo
      dentro de el. Si el repo resulta privado, activa ademas
      automaticamente el guard local en ese mismo clon (ver mas abajo).
    - Sin -ClientName ni -LocalGuardOnly: actua sobre el repo del directorio
      actual (autodetecta Owner/Repo de su remoto 'origin') -- para
      aplicar/reaplicar esto sobre un repo que ya existe (la propia
      plantilla, o un repo cliente ya clonado). Igual que el modo anterior,
      si el repo es privado activa tambien el guard local automaticamente.
    - Con -LocalGuardOnly [-RepoRoot <ruta>]: NO llama a `gh` en absoluto ni
      lo requiere instalado. Solo activa `core.hooksPath` -> `tools/git-hooks`
      en el clon indicado (por defecto, el directorio actual) y comprueba
      que `gitleaks`/Tabular Editor 2 esten disponibles. Pensado para
      cualquier persona que solo necesita que los hooks nativos de ese clon
      se disparen, sin tocar la configuracion de GitHub.

    Alcance deliberado (acordado explicitamente) de los modos que tocan
    GitHub: solo configuran GitHub y el guard local de ese mismo clon. NO
    instalan nada en el equipo (Tabular Editor 2, DAX Studio, gitleaks) --
    esos pasos quedan impresos al final como pendientes manuales, ver
    files/context/limites-duros.md.

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
    files/context/limites-duros.md). Este script NUNCA reporta "OK" con un
    403 de fondo -- ese error se imprime siempre en rojo. Pero, a
    diferencia de una version anterior (bug real encontrado y corregido en
    dogfooding, ver docs/CHANGELOG.md), en un repo PRIVADO ese 403 ya NO
    aborta el script entero: se avisa y se continua, precisamente para
    llegar al bloque que activa el guard local automaticamente (la
    mitigacion pensada para este caso). En un repo PUBLICO, en cambio, ese
    mismo fallo SI aborta el script (seria inesperado).

.PARAMETER ClientName
    Si se pasa, activa el modo "crear repo nuevo". Admite "Nombre" (se crea
    bajo la cuenta autenticada de gh) o "Owner/Nombre" (se crea bajo esa
    cuenta/organizacion) -- gh repo create interpreta ambos formatos.
    Incompatible con -LocalGuardOnly.

.PARAMETER Visibility
    'Public' (por defecto) o 'Private'. Solo se usa si se pasa -ClientName
    (decide con que visibilidad se crea el repo nuevo). Si es 'Private',
    branch protection puede fallar con 403 en plan Free -- el script lo
    explica y para, no lo oculta.

.PARAMETER LocalGuardOnly
    Si se pasa, se salta por completo la parte de GitHub (no requiere `gh`
    instalado ni autenticado) y solo activa la capa de gobernanza local
    (`core.hooksPath` -> `tools/git-hooks`) en -RepoRoot. Incompatible con
    -ClientName/-Visibility.

.PARAMETER RepoRoot
    Solo con -LocalGuardOnly: raiz del clon donde activar el guard local.
    Por defecto, el directorio de trabajo actual.

.EXAMPLE
    # Repo cliente nuevo, publico, bajo la cuenta autenticada:
    pwsh -File tools/setup-github.ps1 -ClientName Informe-ClienteX

.EXAMPLE
    # Repo cliente nuevo, privado, bajo una organizacion:
    pwsh -File tools/setup-github.ps1 -ClientName MiOrg/Informe-ClienteX -Visibility Private

.EXAMPLE
    # Reaplicar sobre el repo del directorio actual (esta plantilla, o un cliente ya creado):
    pwsh -File tools/setup-github.ps1

.EXAMPLE
    # Solo activar el guard local en este clon, sin tocar GitHub (no requiere permisos de administrador):
    pwsh -File tools/setup-github.ps1 -LocalGuardOnly
#>
[CmdletBinding()]
param(
    [string]$ClientName,
    [ValidateSet('Public', 'Private')]
    [string]$Visibility = 'Public',
    [switch]$LocalGuardOnly,
    [string]$RepoRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

if ($LocalGuardOnly -and ($ClientName -or $PSBoundParameters.ContainsKey('Visibility'))) {
    throw "-LocalGuardOnly es incompatible con -ClientName/-Visibility -- son modos mutuamente excluyentes (ver .SYNOPSIS). Ejecuta el script solo con -LocalGuardOnly [-RepoRoot <ruta>], sin los otros parametros."
}

function Set-LocalGitGuard {
    <#
    Antes era tools/setup-local-git-guard.ps1 (fusionado aqui). Activa
    'core.hooksPath' -> 'tools/git-hooks' en -RepoRoot y comprueba que la
    toolchain que esos hooks necesitan (gitleaks, Tabular Editor 2) esta
    disponible. No toca la API de GitHub en absoluto -- puede ejecutarla
    cualquiera, sin permisos de administrador del repo ni `gh` instalado.
    Idempotente.
    #>
    param([string]$RepoRoot)

    if (-not (Test-Path (Join-Path $RepoRoot '.git'))) {
        throw "No se encontro '.git' bajo '$RepoRoot' -- ejecuta esto desde la raiz de un clon real, no de un checkout parcial."
    }

    Push-Location $RepoRoot
    try {
        git config core.hooksPath tools/git-hooks
        Write-Host "OK: core.hooksPath -> tools/git-hooks" -ForegroundColor Green

        foreach ($hook in @('pre-commit', 'pre-push')) {
            $hookPath = Join-Path $RepoRoot "tools\git-hooks\$hook"
            if (-not (Test-Path $hookPath)) {
                Write-Host "Aviso: no se encontro '$hookPath' -- el hook '$hook' no se ejecutara aunque core.hooksPath este configurado." -ForegroundColor Yellow
                continue
            }
            # El bit ejecutable no importa en Windows, pero si en macOS/Linux/WSL.
            if ($IsLinux -or $IsMacOS) {
                & chmod +x $hookPath
            }
        }

        Write-Host ""
        Write-Host "Comprobando herramientas que estos hooks necesitan..." -ForegroundColor Cyan

        $gitleaks = Get-Command gitleaks -ErrorAction SilentlyContinue
        if ($gitleaks) {
            Write-Host "OK: gitleaks encontrado ($($gitleaks.Source))." -ForegroundColor Green
        }
        else {
            Write-Host "Aviso: 'gitleaks' no esta en el PATH. Instalalo (https://github.com/gitleaks/gitleaks) -- en un repo marcado 'visibilidad: privado', el hook pre-commit bloqueara todos los commits hasta que este instalado (fail-closed deliberado, ver tools/git-hooks/pre-commit.ps1)." -ForegroundColor Yellow
        }

        $teExe = $env:TABULAR_EDITOR_PATH
        if ((-not $teExe -or -not (Test-Path $teExe)) -and (Get-Command TabularEditor.exe -ErrorAction SilentlyContinue)) {
            $teExe = (Get-Command TabularEditor.exe).Source
        }
        if ($teExe -and (Test-Path $teExe)) {
            Write-Host "OK: Tabular Editor 2 encontrado ($teExe)." -ForegroundColor Green
        }
        else {
            Write-Host "Aviso: Tabular Editor 2 no localizable (TABULAR_EDITOR_PATH/PATH). El hook pre-push omitira la comprobacion BPA local sin bloquear el push -- CI sigue siendo la capa autoritativa para eso." -ForegroundColor Yellow
        }

        $configPath = Join-Path $RepoRoot '.claude\project-config.json'
        if (Test-Path $configPath) {
            try {
                $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
                if (-not $config.visibilidad) {
                    Write-Host "Aviso: '.claude/project-config.json' no tiene el campo 'visibilidad' -- los hooks lo tratan como 'publico' (warn-only en secretos) hasta que se rellene. Invoca 'requirements-intake' para completarlo." -ForegroundColor Yellow
                }
                else {
                    Write-Host "Visibilidad configurada: '$($config.visibilidad)'." -ForegroundColor Cyan
                }
            }
            catch {
                Write-Host "Aviso: no se pudo leer '.claude/project-config.json' ($($_.Exception.Message))." -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "Aviso: '.claude/project-config.json' no existe todavia (repo sin bootstrap) -- los hooks tratan esto como 'publico' hasta que exista." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Listo. Verifica con: git config --get core.hooksPath" -ForegroundColor Cyan
    }
    finally {
        Pop-Location
    }
}

if ($LocalGuardOnly) {
    Set-LocalGitGuard -RepoRoot $RepoRoot
    exit 0
}

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
    # carrera de propagacion de GitHub. Aun asi, separar create y clone con
    # un pequeno reintento es una defensa razonable y barata por si existiera
    # alguna demora real de propagacion en otros escenarios.
    #
    # Esa demora de propagacion SI se confirmo despues, en otra sesion de
    # dogfooding (ver docs/CHANGELOG.md): "gh repo clone" salio con exit code
    # 0 mientras GitHub todavia no habia terminado de copiar el commit
    # inicial de "Use this template" -- el clon resultante existia pero
    # tenia 0 commits ("git status" -> "No commits yet"), y el bucle de
    # reintentos de entonces solo miraba el exit code de "gh repo clone", que
    # tambien es 0 al clonar un repo remoto vacio. Por eso ahora, ademas del
    # exit code, se verifica que el HEAD del clon resuelve a un commit real
    # antes de darlo por valido.
    $cloneDir = ($ClientName -split '/')[-1]
    Write-Host "Repo creado. Clonando en '$cloneDir' (con reintentos por si acaso)..." -ForegroundColor Cyan
    $maxAttempts = 6
    $cloned = $false
    for ($attempt = 1; $attempt -le $maxAttempts -and -not $cloned; $attempt++) {
        if (Test-Path $cloneDir) { Remove-Item -Recurse -Force $cloneDir }
        gh repo clone $ClientName $cloneDir 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            git -C $cloneDir rev-parse HEAD *> $null
            if ($LASTEXITCODE -eq 0) {
                $cloned = $true
            }
            else {
                Write-Host "Aviso: '$cloneDir' se clono pero esta vacio (GitHub todavia propagando el commit inicial) -- reintentando..." -ForegroundColor Yellow
                Start-Sleep -Seconds 5
            }
        }
        else {
            Start-Sleep -Seconds 5
        }
    }
    if (-not $cloned) {
        throw "No se pudo clonar '$ClientName' con contenido real tras $maxAttempts intentos (el clon salio vacio, o 'gh repo clone' fallo, en cada intento). El repo SI se creo en GitHub -- reintenta manualmente en unos segundos: gh repo clone $ClientName"
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

# Se calcula ANTES de intentar branch protection (no despues, como en la
# version original) por un bug real encontrado en dogfooding: si el repo es
# privado en plan Free, Set-BranchProtection lanza una excepcion (403) que
# aborta el script entero por $ErrorActionPreference='Stop' -- el bloque de
# mas abajo que activa el guard local automaticamente para repos privados
# nunca llegaba a ejecutarse, precisamente en el unico escenario para el que
# existe. Confirmado con un repo de prueba real
# (test-obsidian-docs-dogfood-20260913): el script terminaba con excepcion
# en 'dev' sin haber activado el guard local en absoluto.
$repoVisibility = gh api "repos/$Owner/$Repo" --jq '.visibility'

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
        throw "No se pudo aplicar branch protection sobre '$Branch' (gh api devolvio exit code $LASTEXITCODE). Si el mensaje menciona 'Upgrade to GitHub Pro or make this repository public', es un bloqueo real de plan de GitHub: la branch protection (clasica y rulesets) requiere GitHub Pro o repo publico en repos privados de plan Free. No hay workaround gratuito por API -- decide con el usuario si se hace publico el repo, se pasa a GitHub Pro, o se acepta la mitigacion local documentada en files/context/control-versiones.md ('Escenario privado (Free) -- capa de gobernanza local': tools/git-hooks/ + 'tools/setup-github.ps1 -LocalGuardOnly'), que ata a cualquiera que use un clon con el guard instalado pero NUNCA puede impedir un merge hecho desde la propia UI web de GitHub."
    }

    Write-Host "OK: '$Branch' protegida." -ForegroundColor Green
}

# dev: PR obligatoria + CI en verde. Sin minimo de aprobaciones (revisor
# unico == autor; GitHub no cuenta la propia aprobacion del autor como
# revision, asi que exigir 1 bloquearia siempre al propio autor).
# main: igual, mas el gate que obliga a que la PR venga de dev/release/*.
#
# Envueltas en try/catch (a diferencia de la version original, que dejaba
# que la excepcion de Set-BranchProtection abortara todo el script): en un
# repo PRIVADO de plan Free, un 403 aqui es el resultado ESPERADO (ver
# .SYNOPSIS), no un error real -- abortar el script entero le impedia
# llegar al bloque de mas abajo que activa el guard local automaticamente,
# precisamente la mitigacion pensada para este caso. En un repo PUBLICO, en
# cambio, un fallo aqui SI es inesperado y se relanza (no se traga el
# error).
try {
    Set-BranchProtection -Branch 'dev' -RequiredChecks @('validate', 'gitleaks') -RequiredApprovingReviews 0
    Set-BranchProtection -Branch 'main' -RequiredChecks @('validate', 'gitleaks', 'source-branch-gate') -RequiredApprovingReviews 0
}
catch {
    if ($repoVisibility -eq 'public') {
        throw
    }
    Write-Host ""
    Write-Host "Aviso: no se pudo aplicar branch protection completa (repo privado, bloqueo de plan esperado -- ver mensaje de arriba). Se continua para dejar activada al menos la mitigacion local." -ForegroundColor Yellow
}

# Deliberadamente NO se toca default_branch: debe seguir siendo 'main' (ver
# IMPORTANTE en la cabecera del fichero) para que "Use this template" siga
# copiando 'main' y no 'dev'.

Write-Host "Comprobando visibilidad para el secret scanning nativo de GitHub..." -ForegroundColor Cyan
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

# Registra la visibilidad real en project-config.json, si ya existe (repo
# con bootstrap ya hecho). Si no existe todavia, requirements-intake la
# preguntara/escribira en su paso 0 -- no se crea el fichero aqui.
$projectConfigPath = Join-Path (Get-Location).Path '.claude\project-config.json'
if (Test-Path $projectConfigPath) {
    try {
        $projectConfig = Get-Content -Raw -Path $projectConfigPath | ConvertFrom-Json
        $nuevaVisibilidad = if ($repoVisibility -eq 'public') { 'publico' } else { 'privado' }
        $projectConfig | Add-Member -NotePropertyName 'visibilidad' -NotePropertyValue $nuevaVisibilidad -Force
        $projectConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $projectConfigPath -Encoding utf8
        Write-Host "OK: '.claude/project-config.json'.visibilidad = '$nuevaVisibilidad' (segun la visibilidad real del repo en GitHub)." -ForegroundColor Green
    }
    catch {
        Write-Host "Aviso: no se pudo actualizar 'visibilidad' en '.claude/project-config.json' ($($_.Exception.Message)). Rellenalo a mano o via requirements-intake." -ForegroundColor Yellow
    }
}

if ($repoVisibility -ne 'public') {
    Write-Host ""
    Write-Host "Repo privado: activando automaticamente el guard local en ESTE clon (mitigacion de no tener branch protection/secret scanning nativos)..." -ForegroundColor Yellow
    Set-LocalGitGuard -RepoRoot (Get-Location).Path
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
if ($repoVisibility -ne 'public') {
    Write-Host "  4. Repo privado: el guard local YA se ha activado aqui mismo (arriba). Cualquier OTRO clon de este repo (otra maquina, u otra persona sin permisos de administrador del repo) debe ejecutar 'pwsh -File tools/setup-github.ps1 -LocalGuardOnly' por su cuenta -- no viaja con el repo. Ver files/context/control-versiones.md, seccion 'Escenario privado (Free)'." -ForegroundColor Yellow
}
