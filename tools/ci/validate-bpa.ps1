<#
.SYNOPSIS
    Validacion de CI (GitHub Actions / Azure Pipelines): ejecuta Tabular Editor 2
    Best Practice Analyzer contra todos los modelos semanticos del repo y falla
    el job (exit 1) si hay violaciones de severidad Error. Es la contraparte de
    servidor del hook local `post-edit-tmdl.ps1` -- misma invocacion TE2, mismo
    criterio de bloqueo, pero sobre el repo completo en vez de un solo fichero
    tocado, y con exit 1 (falla de job) en vez de exit 2 (bloqueo de hook).

    NOTA (sin dogfooding todavia): la guarda inicial que comprueba
    ".claude/project-config.json" se anadio al convertir la plantilla en un
    GitHub Template Repository -- el objetivo es que un PR contra el propio
    repositorio plantilla (sin ningun proyecto PBIP scaffolded todavia) no
    falle este job por falta de *.SemanticModel. No se ha probado aun contra
    un PR real al repo plantilla; verificar en la primera sesion que abra un
    PR ahi antes de asumir que el guard funciona como se describe.

    Verificado en dogfooding real (TE2 2.28.0, runner windows-latest):
    - TE2 debe apuntar a la subcarpeta "<Proyecto>.SemanticModel\definition"
      (donde vive model.tmdl), no a la carpeta "*.SemanticModel" en si.
    - Invocar el CLI con "& $teExe ... 2>&1" NO captura de forma fiable
      stdout/stderr/exit-code en absoluto (ni output ni exit code) cuando
      corre como script no interactivo -- confirmado tambien fuera del
      contexto de hooks, con la CLI portable descargada directamente del
      release de GitHub. La API de Process (.NET) con redireccion explicita
      si funciona en ese mismo contexto -- unico metodo usado aqui.

.PARAMETER RepoRoot
    Raiz del repo a inspeccionar. Por defecto, el directorio de trabajo actual.

.PARAMETER TabularEditorPath
    Ruta al TabularEditor.exe. Por defecto, $env:TABULAR_EDITOR_PATH.
#>
param(
    [string]$RepoRoot = (Get-Location).Path,
    [string]$TabularEditorPath = $env:TABULAR_EDITOR_PATH
)

$ErrorActionPreference = 'Stop'

if (-not $TabularEditorPath -or -not (Test-Path $TabularEditorPath)) {
    Write-Error "No se encontro Tabular Editor 2 en TABULAR_EDITOR_PATH='$TabularEditorPath'. El paso de instalacion de TE2 debe ejecutarse antes que este script."
    exit 1
}

$projectConfig = Join-Path $RepoRoot '.claude\project-config.json'
if (-not (Test-Path $projectConfig)) {
    Write-Output "No existe '.claude\project-config.json': este repo todavia no ha pasado por el bootstrap (requirements-intake/pbip-scaffold), por lo que no se espera ningun *.SemanticModel todavia. Esto es normal en el propio repositorio plantilla (creado via 'Use this template' pero sin scaffolding aplicado) -- se omite la validacion BPA sin marcar el job como fallido."
    exit 0
}

$bpaRules = Join-Path $RepoRoot 'tools\BPARules.json'
if (-not (Test-Path $bpaRules)) {
    Write-Error "No existe '$bpaRules'. No se puede ejecutar BPA sin el fichero de reglas del proyecto."
    exit 1
}

$semanticModelDirs = Get-ChildItem -Path $RepoRoot -Directory -Filter '*.SemanticModel' -Recurse -ErrorAction SilentlyContinue
if (-not $semanticModelDirs) {
    Write-Error "No se encontro ninguna carpeta *.SemanticModel bajo '$RepoRoot'."
    exit 1
}

$anyError = $false

foreach ($smDir in $semanticModelDirs) {
    $definitionDir = Join-Path $smDir.FullName 'definition'
    if (-not (Test-Path (Join-Path $definitionDir 'model.tmdl'))) {
        Write-Error "No se encontro '$definitionDir\model.tmdl' -- saltando '$($smDir.FullName)'."
        $anyError = $true
        continue
    }

    Write-Output "=== Ejecutando BPA sobre '$definitionDir' ==="

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $TabularEditorPath
    $psi.Arguments = "`"$definitionDir`" -A `"$bpaRules`" -V"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $proc.Start() | Out-Null
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $output = ($stdout + "`n" + $stderr) -split "`r?`n"

    $output | ForEach-Object { Write-Output $_ }

    # -V (VSTS logging) etiqueta cada violacion como
    # "##vso[task.logissue type=error;]..." / "type=warning;..." segun su
    # severidad en BPARules.json. Solo las de tipo "error" bloquean el job.
    $errorLines = $output | Where-Object { $_ -match '(?i)\berror\b' }
    if ($errorLines) {
        Write-Output "::error::BPA encontro $($errorLines.Count) violacion(es) de severidad Error en '$definitionDir'"
        $anyError = $true
    }
}

if ($anyError) {
    exit 1
}

Write-Output "BPA: sin violaciones de severidad Error."
exit 0
