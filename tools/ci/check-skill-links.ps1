<#
.SYNOPSIS
    Validacion de CI: comprueba que los enlaces Markdown relativos de
    `.claude/**/*.md` resuelven a un fichero o carpeta existente. Un fallo
    aqui delata una copia incompleta de los skills vendorizados (ver
    `.claude/skills/UPSTREAM.md`), cuyos enlaces `../../common/` solo
    resuelven si `common/` se copio a `.claude/common/`.

    Ignora enlaces con esquema (http, https, mailto...), anclas puras (#x) y
    enlaces dentro de bloques de codigo. Quita el fragmento (#...) y la
    query antes de comprobar. Es una comprobacion sintactica de rutas, no
    valida que el ancla exista dentro del destino.

.PARAMETER RepoRoot
    Raiz del repo. Por defecto, el directorio de trabajo actual.
#>
param(
    [string]$RepoRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$claudeDir = Join-Path $RepoRoot '.claude'
if (-not (Test-Path $claudeDir)) {
    Write-Host "No existe .claude/ en $RepoRoot; nada que comprobar."
    exit 0
}

$broken = New-Object System.Collections.Generic.List[string]
$checked = 0
$files = Get-ChildItem -Path $claudeDir -Recurse -File -Filter '*.md'

foreach ($file in $files) {
    $inFence = $false
    $lineNo = 0
    foreach ($line in (Get-Content -LiteralPath $file.FullName -Encoding UTF8)) {
        $lineNo++
        if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        $clean = [regex]::Replace($line, '`[^`]*`', '')
        foreach ($m in [regex]::Matches($clean, '\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)')) {
            $target = $m.Groups[1].Value
            if ($target -match '^[A-Za-z][A-Za-z0-9+.-]*:' -or $target.StartsWith('#')) { continue }
            $path = ($target -split '[#?]')[0]
            if ([string]::IsNullOrWhiteSpace($path)) { continue }
            $path = [uri]::UnescapeDataString($path)
            $resolved = Join-Path $file.DirectoryName $path
            $checked++
            if (-not (Test-Path -LiteralPath $resolved)) {
                $rel = $file.FullName.Substring($RepoRoot.Length).TrimStart('\', '/')
                $broken.Add("${rel}:${lineNo} -> $target")
            }
        }
    }
}

Write-Host "Ficheros .md revisados: $($files.Count); enlaces relativos comprobados: $checked"
if ($broken.Count -gt 0) {
    Write-Host "ENLACES ROTOS ($($broken.Count)):"
    $broken | ForEach-Object { Write-Host "  $_" }
    exit 1
}
Write-Host 'OK: todos los enlaces relativos resuelven.'
exit 0
