---
name: pbip-scaffold
description: Crea la estructura de carpetas del proyecto Power BI (src/, themes/, templates/, tools/, docs/, .gitignore, .gitattributes) y abre la rama de trabajo. Invócalo justo después de cerrar requirements-intake, una sola vez por proyecto nuevo.
---

Requiere que `requirements-intake` haya cerrado ya requisitos y que `.claude/project-config.json` exista con `escenario` relleno. Si no es así, invoca `requirements-intake` primero.

## Upstream (solo para el informe)

Entra siempre por este skill; **no invoques `powerbi-report-cli` directamente**. Para crear el esqueleto del `.Report` puedes usar `powerbi-report-author scaffold` (ver [authoring.md](../powerbi-report-cli/references/authoring.md) y [pbip.md](../semantic-model-authoring/references/pbip.md) para la estructura PBIP). Reglas de la plantilla que acotan su uso:

- **Nunca con `--force`**: `scaffold*` está en `allow` y `--force` sobrescribe ficheros del proyecto sin pedir permiso. Si el destino ya contiene un proyecto, para y pregunta.
- `scaffold` genera también un `<nombre>.pbip` y un `.Report`. La regla de abajo ("no generes tú un `.pbip` desde cero") sigue mandando: úsalo **solo cuando el `.SemanticModel` ya exista en `src/`** (creado/convertido desde Desktop) y pásale `--model-path ../<Proyecto>.SemanticModel` para que el `.Report` quede enlazado por ruta; si no hay modelo, no lo ejecutes y declara el paso manual de Desktop. Que el resultado abra bien en Desktop está **sin verificar** hasta probarlo.
- Con `--model-path` omitido escribe un binding placeholder: no lo dejes así en un commit.
- Credenciales, `bindConnection` y publicación (`management`) quedan fuera del alcance del agente (`limites-duros.md`).

## Qué hacer

1. Aplica la estructura exacta de `files/context/arquitectura-repositorio.md`:
   ```
   src/<Proyecto>.pbip
   src/<Proyecto>.SemanticModel/definition/...
   src/<Proyecto>.Report/definition/...
   themes/
   templates/
   tools/BPARules.json
   tools/deploy.ps1
   tools/ci/validate-bpa.ps1
   tools/ci/validate-pbir-schema.ps1
   tools/tests/          (solo si escenario == "B")
   docs/
   .github/workflows/validate-pr.yml  (o azure-pipelines.yml equivalente si el repo destino usa Azure DevOps, ver control-versiones.md)
   .gitignore
   .gitattributes
   ```
2. **El `.pbip` inicial casi siempre requiere un paso manual en Power BI Desktop** (crear el fichero una vez para heredar su `.gitignore`/estructura base y convertir a TMDL/PBIR vía las opciones de Desktop). Decláralo explícitamente como pendiente si el `.pbip` no existe ya en el repo — no generes tú un `.pbip` desde cero.
3. Descarga `tools/BPARules.json` desde las reglas comunitarias de `TabularEditor/BestPracticeRules` (o usa las reglas BPA integradas de Tabular Editor si la versión instalada ya las trae, según `files/context/herramientas-documentacion.md`). **Ojo**: ese repo no tiene ningún fichero llamado literalmente `BPARules.json` — tiene `BPARules-standard.json`, `BPARules-standard-lax.json`, `BPARules-PowerBI.json` y `BPARules-contrib.json` (verificado). Para proyectos Power BI usa `BPARules-PowerBI.json` y renómbralo a `tools/BPARules.json` al copiarlo (`https://raw.githubusercontent.com/TabularEditor/BestPracticeRules/master/BPARules-PowerBI.json`).
4. Escribe `.gitignore` y `.gitattributes` exactamente como en `arquitectura-repositorio.md` — no los reinventes.
5. Copia `tools/ci/validate-bpa.ps1`, `tools/ci/validate-pbir-schema.ps1` y `.github/workflows/validate-pr.yml` (los tres, ficheros reales de esta plantilla, no descripciones) — el workflow ejecuta ambos scripts sobre cada PR en un runner `windows-latest` (Tabular Editor 2 es .NET Framework/Windows). Ver `files/context/flujo-trabajo.md` paso 6 para el detalle de qué valida y cómo se probó. Si el repo destino usa Azure DevOps en vez de GitHub, adapta el mismo par de scripts a un `azure-pipelines.yml` equivalente (misma lógica, distinta sintaxis de pipeline).
6. Inicializa el repo Git si no existe, y crea la rama `feature/<nombre-informe>` siguiendo `files/context/control-versiones.md`. No trabajes directamente sobre `main`/`master`.
7. Si `escenario == "B"`, crea también `tools/tests/` para los futuros notebooks `sempy`/`semantic-link-labs`.

## Cierre

Confirma la estructura creada con un listado breve y pasa el testigo a las fases de desarrollo (`origenes-datos` → `transformaciones-m` → `modelo-tmdl` → `medidas-dax`), según `files/context/flujo-trabajo.md`.
