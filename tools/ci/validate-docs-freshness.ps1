<#
.SYNOPSIS
    Validacion de CI: contraparte de servidor del hook local
    `post-commit-docs.ps1`, pero verificando de verdad en vez de solo
    recordar. Sobre el diff completo del PR (`git diff --name-only
    <base>...HEAD`):

    - Si el diff toca modelo/informe (*.tmdl, definition/pages/**) -- modo
      cliente -- exige que tambien toque docs/data-dictionary.md,
      docs/linaje-medidas.md, docs/README-consumidor.md o docs/adr/**.
    - Si el diff toca el mecanismo de la propia plantilla (files/context/**,
      .claude/**, tools/**, CLAUDE.md, README.md, .github/workflows/**) --
      modo plantilla -- exige que tambien toque docs/CHANGELOG.md o
      docs/decisiones/**.

    Ambas condiciones son independientes: un PR puede disparar una, la otra,
    las dos, o ninguna. No falla si el repo no tiene ningun *.SemanticModel
    (la condicion de modo cliente simplemente no llega a aplicar nunca) --
    ese es el caso de la propia plantilla sin bootstrap todavia.

    NOTA DE HONESTIDAD (ver docs/CHANGELOG.md): verificado localmente contra
    dos ramas de prueba reales (falla si el diff toca .claude/ sin tocar
    docs/, pasa si los toca a la vez) y confirmado en verde como job real de
    GitHub Actions dentro de un PR (Agentic-PowerBI-Template PR #10).

.PARAMETER RepoRoot
    Raiz del repo. Por defecto, el directorio de trabajo actual.

.PARAMETER BaseRef
    Referencia git contra la que diffear para encontrar ficheros tocados
    (normalmente el SHA/rama base del PR).
#>
param(
    [string]$RepoRoot = (Get-Location).Path,
    [Parameter(Mandatory = $true)][string]$BaseRef
)

$ErrorActionPreference = 'Stop'
Set-Location $RepoRoot

$changedFiles = git diff --name-only --diff-filter=ACMR "$BaseRef...HEAD"
if (-not $changedFiles) {
    Write-Output "Sin ficheros modificados frente a '$BaseRef'."
    exit 0
}

$touchesModelOrReport = $changedFiles | Where-Object {
    $_ -match '\.tmdl$' -or $_ -match 'definition[\\/]pages[\\/]'
}

$touchesTemplateMechanism = $changedFiles | Where-Object {
    $_ -match '^files[\\/]context[\\/]' -or
    $_ -match '^\.claude[\\/]' -or
    $_ -match '^tools[\\/]' -or
    $_ -match '^CLAUDE\.md$' -or
    $_ -match '^README\.md$' -or
    $_ -match '^\.github[\\/]workflows[\\/]'
}

$touchesClientDocs = $changedFiles | Where-Object {
    $_ -match '^docs[\\/]data-dictionary\.md$' -or
    $_ -match '^docs[\\/]linaje-medidas\.md$' -or
    $_ -match '^docs[\\/]README-consumidor\.md$' -or
    $_ -match '^docs[\\/]adr[\\/]'
}

$touchesTemplateDocs = $changedFiles | Where-Object {
    $_ -match '^docs[\\/]CHANGELOG\.md$' -or
    $_ -match '^docs[\\/]decisiones[\\/]'
}

$anyError = $false

if ($touchesModelOrReport -and -not $touchesClientDocs) {
    Write-Output "::error::El PR toca modelo/informe (*.tmdl o definition/pages/**) pero no docs/data-dictionary.md, docs/linaje-medidas.md, docs/README-consumidor.md ni docs/adr/**. Invoca el subagente docs-writer (o el skill docs-sync) antes de mergear."
    $anyError = $true
}

if ($touchesTemplateMechanism -and -not $touchesTemplateDocs) {
    Write-Output "::error::El PR toca el mecanismo de la plantilla (files/context, .claude, tools, CLAUDE.md, README.md o .github/workflows) pero no docs/CHANGELOG.md ni docs/decisiones/**. Invoca el subagente docs-writer (o el skill docs-sync) antes de mergear."
    $anyError = $true
}

if ($anyError) {
    exit 1
}

Write-Output "Validacion de frescura de documentacion: sin problemas."
exit 0
