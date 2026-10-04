<#
.SYNOPSIS
    Instala/verifica en ESTA MAQUINA la toolchain de terceros que la
    plantilla asume disponible (gitleaks, Tabular Editor 2, DAX Studio,
    Node.js LTS y el CLI npm powerbi-report-author), via winget/npm.
    Idempotente: si una herramienta ya esta instalada (y, en el caso del
    CLI, en la version fijada), no la toca.

.DESCRIPTION
    Deliberadamente SEPARADO de tools/setup-github.ps1, no fusionado en el.
    Son dos ejes ortogonales con ciclo de vida distinto: setup-github.ps1
    configura *un repo* (GitHub + core.hooksPath de ESE clon) -- se repite
    una vez por repo cliente. Este script configura *esta maquina* -- se
    ejecuta una vez por equipo, independientemente de cuantos repos cliente
    se trabajen despues desde el. Mezclarlos acoplaria un paso idempotente
    por repo con uno idempotente por maquina, y automatizaria sin mas la
    instalacion de binarios de terceros (mayor blast radius que escribir en
    la API de GitHub o en .git/config) sin pedirlo explicitamente -- ver
    files/context/limites-duros.md sobre no introducir herramientas sin
    autorizacion explicita.

    Power BI Desktop queda fuera a proposito: se distribuye normalmente via
    Microsoft Store o instalador propio de Microsoft, no via un paquete
    winget silencioso fiable para este flujo -- sigue siendo un paso manual
    (ver README.md, punto 4). Python/semantic-link-labs (Escenario B)
    tambien queda fuera -- no forma parte de la toolchain base de Escenario
    A que cubre este script.

    Node.js LTS y el CLI @microsoft/powerbi-report-authoring-cli (version
    fijada abajo en $PbiReportCliVersion, NO @latest) los necesitan los
    skills vendorizados powerbi-authoring (ver .claude/skills/UPSTREAM.md,
    Fase 2 del plan de integracion). El CLI es beta upstream: la version
    fijada es la unica probada (solo --version y doctor).

    Diseno, no dogfoodeado todavia en una sesion real ni en maquina limpia (mismo criterio de
    honestidad que el resto de la plantilla) -- verifica que los IDs de
    winget de abajo siguen resolviendo el paquete esperado en tu maquina
    antes de asumirlo; pueden cambiar de nombre entre versiones de winget o
    quedar retirados del repositorio de paquetes.

.PARAMETER SkipGitleaks
    Omite la instalacion/comprobacion de gitleaks.

.PARAMETER SkipTabularEditor
    Omite la instalacion/comprobacion de Tabular Editor 2.

.PARAMETER SkipDaxStudio
    Omite la instalacion/comprobacion de DAX Studio.

.PARAMETER SkipNode
    Omite la instalacion/comprobacion de Node.js LTS (>= 20). Si lo omites,
    tambien se omite el CLI powerbi-report-author, que depende de npm.

.PARAMETER SkipPbiReportCli
    Omite la instalacion/comprobacion del CLI powerbi-report-author.

.EXAMPLE
    # Instala (o confirma) las tres herramientas:
    pwsh -File tools/install-tools.ps1

.EXAMPLE
    # Ya tienes gitleaks por otra via (p.ej. Chocolatey, WSL) -- solo TE2 y DAX Studio:
    pwsh -File tools/install-tools.ps1 -SkipGitleaks
#>
[CmdletBinding()]
param(
    [switch]$SkipGitleaks,
    [switch]$SkipTabularEditor,
    [switch]$SkipDaxStudio,
    [switch]$SkipNode,
    [switch]$SkipPbiReportCli
)

$ErrorActionPreference = 'Stop'

# Version fijada del CLI. Los skills upstream exigen >= 0.3.0-beta.0 y
# recomiendan @latest; aqui se fija a la unica version comprobada.
$PbiReportCliVersion = '0.4.0'
$PbiReportCliPackage = '@microsoft/powerbi-report-authoring-cli'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "No se encuentra 'winget' en el PATH. Instala 'App Installer' desde Microsoft Store, o instala cada herramienta manualmente (ver README.md, punto 4)."
}

function Install-ToolIfMissing {
    param(
        [string]$Name,
        [string]$WingetId,
        [scriptblock]$DetectInstalled
    )

    if (& $DetectInstalled) {
        Write-Host "OK: $Name ya esta instalado -- no se toca." -ForegroundColor Green
        return
    }

    Write-Host "Instalando $Name (winget id: $WingetId)..." -ForegroundColor Cyan
    winget install --id $WingetId -e --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Aviso: 'winget install $WingetId' devolvio exit code $LASTEXITCODE -- revisa el mensaje de winget de arriba. Puede requerir instalacion manual (ver README.md, punto 4)." -ForegroundColor Yellow
        return
    }
    Write-Host "OK: $Name instalado. Puede hacer falta abrir una terminal nueva para que el PATH actualizado se propague." -ForegroundColor Green
}

if ($SkipGitleaks) {
    Write-Host "Omitido: gitleaks (-SkipGitleaks)." -ForegroundColor Yellow
}
else {
    Install-ToolIfMissing -Name 'gitleaks' -WingetId 'Gitleaks.Gitleaks' -DetectInstalled {
        [bool](Get-Command gitleaks -ErrorAction SilentlyContinue)
    }
}

if ($SkipTabularEditor) {
    Write-Host "Omitido: Tabular Editor 2 (-SkipTabularEditor)." -ForegroundColor Yellow
}
else {
    Install-ToolIfMissing -Name 'Tabular Editor 2' -WingetId 'TabularEditor.TabularEditor.2' -DetectInstalled {
        if ($env:TABULAR_EDITOR_PATH -and (Test-Path $env:TABULAR_EDITOR_PATH)) { return $true }
        [bool](Get-Command TabularEditor.exe -ErrorAction SilentlyContinue)
    }
}

if ($SkipDaxStudio) {
    Write-Host "Omitido: DAX Studio (-SkipDaxStudio)." -ForegroundColor Yellow
}
else {
    Install-ToolIfMissing -Name 'DAX Studio' -WingetId 'DaxStudio.DaxStudio' -DetectInstalled {
        [bool](Get-Command DaxStudio.exe -ErrorAction SilentlyContinue)
    }
}

if ($SkipNode) {
    Write-Host "Omitido: Node.js LTS y CLI powerbi-report-author (-SkipNode)." -ForegroundColor Yellow
}
else {
    Install-ToolIfMissing -Name 'Node.js LTS' -WingetId 'OpenJS.NodeJS.LTS' -DetectInstalled {
        $node = Get-Command node -ErrorAction SilentlyContinue
        if (-not $node) { return $false }
        $major = (& node -v) -replace '^v(\d+)\..*$', '$1'
        return ([int]$major -ge 20)
    }
}

if ($SkipNode -or $SkipPbiReportCli) {
    if (-not $SkipNode) {
        Write-Host "Omitido: CLI powerbi-report-author (-SkipPbiReportCli)." -ForegroundColor Yellow
    }
}
elseif (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "Aviso: 'npm' no esta en el PATH (Node.js recien instalado o no instalado). Abre una terminal nueva y vuelve a ejecutar este script para instalar el CLI powerbi-report-author $PbiReportCliVersion." -ForegroundColor Yellow
}
else {
    $installedVersion = $null
    if (Get-Command powerbi-report-author -ErrorAction SilentlyContinue) {
        $installedVersion = (& powerbi-report-author --version 2>$null | Select-Object -First 1)
    }
    if ($installedVersion -eq $PbiReportCliVersion) {
        Write-Host "OK: powerbi-report-author $PbiReportCliVersion ya esta instalado -- no se toca." -ForegroundColor Green
    }
    else {
        if ($installedVersion) {
            Write-Host "powerbi-report-author $installedVersion instalado, version fijada $PbiReportCliVersion -- se reinstala la fijada." -ForegroundColor Yellow
        }
        Write-Host "Instalando $PbiReportCliPackage@$PbiReportCliVersion (npm, global)..." -ForegroundColor Cyan
        npm install -g "$PbiReportCliPackage@$PbiReportCliVersion"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Aviso: 'npm install -g' devolvio exit code $LASTEXITCODE -- revisa el mensaje de npm de arriba." -ForegroundColor Yellow
        }
        else {
            Write-Host "OK: CLI instalado. Comprueba con 'powerbi-report-author doctor' en una terminal nueva." -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Pendiente manual, fuera de alcance de este script (ver README.md, punto 4):" -ForegroundColor Cyan
Write-Host "  - Power BI Desktop (Microsoft Store o instalador propio)."
Write-Host "  - Si Tabular Editor 2 no queda en el PATH, define TABULAR_EDITOR_PATH en el campo 'env' de .claude/settings.json (no via variable de entorno de sistema/setx -- una sesion de Claude Code no la hereda de forma fiable)."
Write-Host "  - Python + semantic-link-labs, solo si el proyecto va a operar en Escenario B."
