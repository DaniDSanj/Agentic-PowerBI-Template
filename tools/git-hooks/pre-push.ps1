<#
.SYNOPSIS
    Git hook NATIVO pre-push. Repone, para CUALQUIERA que use este clon (no
    solo el agente de Claude Code), dos cosas que un repo privado de GitHub
    Free pierde a nivel de plataforma: (1) que nadie pueda empujar directo
    a main/dev/release/*, y (2) una version local y temprana de los checks
    de CI (BPA, esquema PBIR, frescura de docs, secretos) antes de que el
    push llegue al remoto.

.DESCRIPTION
    Ver files/context/control-versiones.md, seccion "Escenario privado
    (Free) -- capa de gobernanza local", para el diseno completo y sus
    limites. Resumen de lo que este hook NO puede cerrar, para no
    presentarlo como equivalente a branch protection real: nada de esto
    impide un merge hecho desde la UI web de GitHub con los checks de CI en
    rojo, ni una edicion de fichero hecha directamente en el navegador --
    esos casos no pasan por ningun git local, y por tanto por ningun hook
    local, sea este o cualquier otro.

    git pasa por stdin una linea por cada ref que se va a empujar:
    '<local ref> <local sha1> <remote ref> <remote sha1>'.

    Logica:
    1. Si el '<remote ref>' es refs/heads/main, refs/heads/master,
       refs/heads/dev o refs/heads/release/* -> bloquea SIEMPRE (exit 1),
       sin depender de ninguna herramienta externa. El merge a esas ramas
       debe hacerse via PR + boton Merge de GitHub, nunca via push directo
       desde un clon.
    2. Para cualquier otra rama (feature/*, fix/*, etc.): calcula el rango
       de commits que se van a empujar (merge-base con dev, o con main si
       dev no es resoluble localmente) y sobre ese rango:
       - gitleaks detect: bloqueante si hay hallazgo. Si 'gitleaks' no esta
         instalado, bloquea tambien cuando 'visibilidad: "privado"' (mismo
         criterio fail-closed que pre-commit.ps1); en repo publico, avisa
         y deja pasar.
       - tools/ci/validate-pbir-schema.ps1 y tools/ci/validate-docs-freshness.ps1
         sobre ese mismo rango: bloqueante si fallan. Se reutilizan tal
         cual (son los mismos scripts que corre CI, no una reimplementacion
         paralela).
       - tools/ci/validate-bpa.ps1 sobre el repo completo si Tabular Editor 2
         esta localizable (TABULAR_EDITOR_PATH o PATH); si no lo esta,
         avisa y NO bloquea -- exigir TE2 instalado solo para poder hacer
         'git push' seria mas friccion de la que este hook pretende anadir,
         y CI sigue siendo la capa autoritativa para esta comprobacion en
         concreto.
       Si no se puede resolver ningun rango base (dev/main no resolubles
       localmente, p.ej. primer push de un repo nuevo, o sin red para
       'git fetch'), se avisa y se deja pasar sin bloquear el push -- este
       hook es una capa adicional/temprana, no el unico lugar donde estas
       comprobaciones existen.
#>

$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    $root = git rev-parse --show-toplevel 2>$null
    if (-not $root) { throw "No se pudo determinar la raiz del repo (git rev-parse --show-toplevel)." }
    return $root
}

function Get-Visibilidad {
    param([string]$RepoRoot)
    $configPath = Join-Path $RepoRoot '.claude\project-config.json'
    if (-not (Test-Path $configPath)) { return 'publico' }
    try {
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
        if ($config.visibilidad) { return $config.visibilidad }
    }
    catch { }
    return 'publico'
}

$repoRoot = Get-RepoRoot
$visibilidad = Get-Visibilidad -RepoRoot $repoRoot
$protectedPattern = '^refs/heads/(main|master|dev)$|^refs/heads/release/'

$stdin = [Console]::In.ReadToEnd()
if (-not $stdin) { exit 0 }

$lines = $stdin -split "`r?`n" | Where-Object { $_ -and $_.Trim() -ne '' }
if (-not $lines) { exit 0 }

$blockedRefs = @()
$localShaToCheck = $null
$remoteRefToCheck = $null

foreach ($line in $lines) {
    $parts = $line -split '\s+'
    if ($parts.Count -lt 4) { continue }
    $localRef, $localSha, $remoteRef, $remoteSha = $parts[0..3]

    if ($localSha -eq ('0' * 40)) { continue }  # borrado de rama remota, no hay nada que validar

    if ($remoteRef -match $protectedPattern) {
        $blockedRefs += $remoteRef
        continue
    }

    # Solo se valida en profundidad la ultima rama no protegida del push
    # (lo tipico es empujar una sola rama feature/fix a la vez).
    $localShaToCheck = $localSha
    $remoteRefToCheck = $remoteRef
}

if ($blockedRefs.Count -gt 0) {
    Write-Host "[pre-push] Push directo bloqueado a: $($blockedRefs -join ', ')." -ForegroundColor Red
    Write-Host "main/dev/release/* solo se actualizan via PR + Merge en GitHub, nunca via 'git push' directo desde un clon -- ver files/context/control-versiones.md." -ForegroundColor Red
    exit 1
}

if (-not $localShaToCheck) { exit 0 }

Push-Location $repoRoot
try {
    # --- 1. Secretos sobre el rango que se va a empujar ---
    git fetch origin dev 2>$null 1>$null
    $baseRef = $null
    foreach ($candidate in @('origin/dev', 'dev', 'origin/main', 'main')) {
        git rev-parse --verify --quiet $candidate 2>$null 1>$null
        if ($LASTEXITCODE -eq 0) {
            $mb = git merge-base $candidate $localShaToCheck 2>$null
            if ($LASTEXITCODE -eq 0 -and $mb) { $baseRef = $mb; break }
        }
    }

    if (-not $baseRef) {
        Write-Host "[pre-push] No se pudo resolver una rama base local (dev/main) para acotar el rango a validar -- se omiten las comprobaciones locales de este push. CI sigue siendo la capa autoritativa en la PR." -ForegroundColor Yellow
        exit 0
    }

    $range = "$baseRef..$localShaToCheck"

    $gitleaks = Get-Command gitleaks -ErrorAction SilentlyContinue
    if ($gitleaks) {
        $glOutput = & gitleaks detect --source $repoRoot --log-opts="$range" --redact --exit-code 1 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[pre-push] gitleaks ha detectado un posible secreto en el rango '$range'. Push bloqueado." -ForegroundColor Red
            Write-Host ($glOutput | Out-String)
            exit 1
        }
    }
    elseif ($visibilidad -eq 'privado') {
        Write-Host "[pre-push] Repo privado y 'gitleaks' no esta instalado -- no hay red de secretos real en este push. Instalalo antes de continuar." -ForegroundColor Red
        exit 1
    }
    else {
        Write-Host "[pre-push] 'gitleaks' no esta instalado -- se omite el escaneo de secretos de este push (repo publico, el escaner nativo de GitHub sigue cubriendo esta capa)." -ForegroundColor Yellow
    }

    # --- 2. Contraparte local de los checks de CI, mismos scripts que CI ---
    $ciDir = Join-Path $repoRoot 'tools\ci'

    $pbirScript = Join-Path $ciDir 'validate-pbir-schema.ps1'
    if (Test-Path $pbirScript) {
        & $pbirScript -RepoRoot $repoRoot -BaseRef $baseRef
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[pre-push] validate-pbir-schema.ps1 encontro errores en el rango '$range'. Push bloqueado." -ForegroundColor Red
            exit 1
        }
    }

    $docsScript = Join-Path $ciDir 'validate-docs-freshness.ps1'
    if (Test-Path $docsScript) {
        & $docsScript -RepoRoot $repoRoot -BaseRef $baseRef
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[pre-push] validate-docs-freshness.ps1 encontro errores en el rango '$range'. Push bloqueado." -ForegroundColor Red
            exit 1
        }
    }

    $bpaScript = Join-Path $ciDir 'validate-bpa.ps1'
    $teExe = $env:TABULAR_EDITOR_PATH
    if (-not $teExe -or -not (Test-Path $teExe)) {
        $onPath = Get-Command TabularEditor.exe -ErrorAction SilentlyContinue
        if ($onPath) { $teExe = $onPath.Source }
    }
    if ((Test-Path $bpaScript) -and $teExe -and (Test-Path $teExe)) {
        & $bpaScript -RepoRoot $repoRoot -TabularEditorPath $teExe
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[pre-push] validate-bpa.ps1 encontro violaciones de severidad Error. Push bloqueado." -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "[pre-push] Tabular Editor 2 no localizable (TABULAR_EDITOR_PATH/PATH) -- se omite BPA en este push. CI sigue siendo la capa autoritativa para esta comprobacion." -ForegroundColor Yellow
    }
}
finally {
    Pop-Location
}

exit 0
