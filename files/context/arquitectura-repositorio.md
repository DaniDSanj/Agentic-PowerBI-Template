# Arquitectura esperada del proyecto

Una vez este esqueleto se inicialice sobre un proyecto Power BI real, la estructura de carpetas es:

```
<repo>/
├─ .claude/                 # settings.json, skills/, agents/, hooks/ — ya presente desde el primer commit (repo creado con "Use this template")
├─ src/
│  ├─ <Proyecto>.pbip                         # fichero puntero
│  ├─ <Proyecto>.SemanticModel/definition/    # model, database, relationships, expressions, tables/, roles/, perspectives/, cultures/, functions.tmdl
│  └─ <Proyecto>.Report/definition/           # pages/**/visuals/*/visual.json, page.json, bookmarks/ (PBIR)
├─ themes/                  # theme JSON + $schema
├─ templates/               # ficheros .pbit
├─ tools/
│  ├─ BPARules.json         # reglas Best Practice Analyzer de la comunidad
│  ├─ deploy.ps1            # FabricPS-PBIP / fabric-cicd
│  ├─ setup-github.ps1      # crea/configura el repo en GitHub (branch protection, secret scanning) y/o el guard local (-LocalGuardOnly)
│  ├─ git-hooks/            # hooks nativos (pre-commit, pre-push) — solo se activan con 'setup-github.ps1 -LocalGuardOnly', ver control-versiones.md
│  └─ tests/                # notebooks sempy con aserciones DAX (solo Escenario B)
├─ docs/                    # vault Obsidian-friendly: data dictionary, linaje de medidas, README de consumidor, adr/
│  └─ adr/                  # decisiones de arquitectura del modelo/informe (NNNN-titulo.md)
├─ .github/workflows/  o  azure-pipelines.yml
├─ .gitignore
└─ .gitattributes
```

**Separación dura**: `<Proyecto>.SemanticModel` (TMDL) es el terreno fiable para automatización en ambos escenarios. `<Proyecto>.Report` (PBIR) sigue en **preview** (GA prevista Q3 2026, tras la cual PBIR-Legacy se elimina y la conversión es irreversible) — trátalo con cautela y valida siempre contra su `$schema` público antes de dar un cambio por bueno.

`.gitignore` (ampliar el auto-generado por Desktop):
```
**/.pbi/localSettings.json
**/.pbi/cache.abf
**/.pbi/editorSettings.json
**/.pbi/unappliedChanges.json
.claude/hook-debug.log
.obsidian/
docs/**/.obsidian/
```
La última entrada cubre el caso de abrir `docs/` como vault de Obsidian localmente (ver "Convención Obsidian-friendly" en `herramientas-documentacion.md`): el propio contenido de `docs/` sí se versiona, solo se ignora la configuración local de vault que Obsidian genera al abrirlo.

`.gitattributes`:
```
*.tmdl text eol=lf
*.json text eol=lf
*.pbip text eol=lf
*.pbir text eol=lf
*.abf binary
*.pbix binary
tools/git-hooks/* text eol=lf
```
La última línea es necesaria para que `tools/git-hooks/pre-commit`/`pre-push` (shims POSIX con shebang `#!/bin/sh`) no se corrompan con CRLF en un clon con `core.autocrlf=true` en Windows — un shebang con `\r` al final no lo reconoce `sh`.
