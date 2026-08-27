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
│  └─ tests/                # notebooks sempy con aserciones DAX (solo Escenario B)
├─ docs/                    # data dictionary, ADRs, definiciones de KPI, README de consumidor
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
```

`.gitattributes`:
```
*.tmdl text eol=lf
*.json text eol=lf
*.pbip text eol=lf
*.pbir text eol=lf
*.abf binary
*.pbix binary
```
