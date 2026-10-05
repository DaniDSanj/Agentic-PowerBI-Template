---
tags: [plantilla, pendiente, dogfooding]
date: 2026-09-13
---

# Pendiente de verificar contra un informe Power BI real

Listado consolidado, generado durante el trabajo del PR [#10](https://github.com/DaniDSanj/Agentic-PowerBI-Template/pull/10) de `Agentic-PowerBI-Template`, de todo lo que sigue **sin dogfooding contra un proyecto Power BI real** (TMDL/PBIR exportado de Desktop). Pensado para copiarse al repo privado permanente de sandbox que se creará para seguir mejorando la plantilla — no es documentación de un cambio ya hecho, es la lista de trabajo pendiente.

Ver `docs/CHANGELOG.md` de `Agentic-PowerBI-Template` para el detalle de lo que sí quedó confirmado en esa misma sesión (capa de gobernanza local, `validate-docs-freshness.ps1`, hook `post-commit-docs` ampliado).

## Bootstrap / requisitos

- **`pbip-scaffold`** — nunca confirmado de extremo a extremo con el modelo actual de la plantilla (el dogfooding conocido es anterior a la reestructuración a Template Repository). Falta probar el paso manual declarado ("crear el `.pbip` una vez en Desktop y convertir a TMDL/PBIR") con el flujo actual.
- **`requirements-intake`** — falta re-verificar el flujo completo con el campo nuevo `visibilidad` (añadido en la sesión del PR #10) y la pregunta de escenario de licencia A/B en una toma de requisitos real, no sintética.

## Orígenes de datos y transformaciones M

- **`origenes-datos`** — sin dogfooding documentado en ningún momento (Excel/CSV/JSON, SQL Server/PostgreSQL, modelos semánticos del servicio, revisión de schema drift).
- **`transformaciones-m`** — la verificación de query folding/preview sigue siendo un paso manual declarado en Desktop, nunca confirmado siquiera manualmente en una sesión de dogfooding.

## Modelo TMDL y DAX

- **`modelo-tmdl`** — el hook `post-edit-tmdl` + BPA están confirmados, pero el contenido de guía (RLS, esquema estrella, **calculation groups**, **roles/OLS**) nunca se ha estresado contra un modelo real con esos elementos.
- **`medidas-dax`** — DAX UDFs en `functions.tmdl` y scripts C# (CS-Script) de Tabular Editor 2 nunca probados; solo medidas DAX simples se han dogfoodeado (sandbox del `META_AVOID_FLOAT`/`DAX_DIVISION_COLUMNS`).
- **`bpa-reviewer`** (vía skill `bpa-validate`) — confirmado que el hook bloquea Error; **no confirmado** que el subagente interprete y triage correctamente violaciones Warning/Info sobre un informe completo real.

## Informe (PBIR)

- **`temas`** — creación/importación de theme JSON nunca dogfoodeada.
- **`visuales-pbir`** + subagente **`data-profiler`** — el hook de validación de esquema PBIR está confirmado (caso `page.json` sin `displayName`), pero el propio `data-profiler` (perfilado de cardinalidades/distribuciones antes de proponer un visual) nunca se ha invocado sobre datos reales.
- **`diseno-informe`** — layout de página, criterio "que no parezca hecho por IA" — sin dogfooding.
- Criterio de evaluación de **custom visuals** (cuándo justifican salirse de los nativos) — nunca ejercitado.

## Documentación autónoma (Obsidian-friendly, PR #10)

- **`docs-writer` modo cliente** — el pendiente más importante: `data-dictionary.md`, `linaje-medidas.md`, `README-consumidor.md`, `docs/adr/` generados desde TMDL real. Todo lo probado en el PR #10 fue en modo plantilla (`docs/CHANGELOG.md`/`decisiones/`).
- **Rama "modo cliente" de `validate-docs-freshness.ps1`** — solo se ejercitó la rama que exige `docs/CHANGELOG.md`/`decisiones/`; la rama que exige `data-dictionary.md`/`linaje-medidas.md`/`README-consumidor.md`/`adr/**` nunca se ha disparado de verdad.
- **El vault abierto en Obsidian de verdad** — todo lo verificado fue a nivel de contenido de fichero (frontmatter, wikilinks como texto); nadie ha abierto `docs/` con la aplicación Obsidian para confirmar que el graph view/backlinks funcionan como se espera.

## CI / despliegue

- **`azure-pipelines.yml` equivalente** — repetidamente señalado como no creado ni probado (mismo criterio de honestidad en cada mención del propio repo).
- **Escenario B completo** (Git de workspace, Deployment Pipelines Dev→Test→Prod, XMLA write, Direct Lake, notebooks `semantic-link-labs` con aserciones DAX vía `sempy`) — cero dogfooding; todo lo confirmado hasta ahora es Escenario A (Pro puro).
- **Todo el pipeline de CI en una sola PR real contra un proyecto poblado** (`validate-bpa` + `validate-pbir-schema` + `validate-docs-freshness` modo cliente + `gitleaks` + `source-branch-gate` juntos) — cada uno se confirmó por separado en sandboxes distintos, nunca los cinco a la vez sobre un modelo/informe real con contenido.

## Ya confirmado (no repetir, solo referencia)

Capa de gobernanza local completa (`tools/git-hooks/`, `setup-github.ps1` con `-LocalGuardOnly` y modo GitHub, `merge-audit`/`audit-history`), `validate-docs-freshness.ps1` modo plantilla, hook `post-commit-docs.ps1` ampliado, `docs-writer` modo plantilla — todo esto quedó dogfoodeado de extremo a extremo en la sesión del PR #10, con hallazgos reales documentados en `docs/CHANGELOG.md` (incluye un bug real encontrado y corregido: el guard local no se activaba cuando branch protection fallaba en repo privado).

## Integración skills powerbi-authoring (Fase 0, 2026-10-04) — parcialmente verificado (solo queda la compatibilidad 0.4.0 ↔ skills)

Plan: `docs/plan-integracion-skills-fabric-p1.md`.

**Verificado (ejecutado por el usuario, Windows, PowerShell):**
- Node `24.19.0` (requerido ≥20).
- `npm i -g @microsoft/powerbi-report-authoring-cli@0.4.0` OK; `powerbi-report-author --version` → `0.4.0`.
- `powerbi-report-author doctor` → `ok: true` (node-version, ajv, metadata-provider: 57 visual types, 15 VCOs).
- Versiones publicadas en npm al consultar: `0.1.0, 0.1.1, 0.1.4, 0.3.0-beta.0, 0.4.0`.

**No verificado:**
- **Compatibilidad 0.4.0 ↔ skills v0.3.18**: los skills exigen `>= 0.3.0-beta.0` y recomiendan `@latest`; `0.4.0` lo cumple, pero no hay evidencia de que los comandos/flags documentados no hayan cambiado. `doctor` solo comprueba Node, ajv y el proveedor de metadatos; no ejerce `scaffold`/`validate`/`preview`.
- **`microsoft-learn` desde `.claude/.mcp.json`**: **VERIFICADO que NO se carga** — el usuario ejecutó `/mcp` (2026-10-04) en una sesión abierta en este repo y no aparece. Coincide con que Claude Code lee `.mcp.json` de la raíz y no existe. Corrección pendiente en Fase 2 (mover/duplicar a `.mcp.json` en la raíz).

## Integración skills powerbi-authoring (Fase 1, 2026-10-04) — NO verificado

- **`tools/ci/check-skill-links.ps1` en CI real**: solo ejecutado en local (224 enlaces OK, prueba negativa OK). No está cableado en `validate-pr.yml` (Fase 2+) ni probado en `windows-latest`.
- **Skills vendorizados cargados por Claude Code**: sin comprobar en sesión real que `powerbi-report-cli` y `semantic-model-authoring` aparecen y se disparan; sus descripciones amplias pueden competir con los skills de la plantilla (regla de enrutado pendiente, Fase 3).
- **Uso real del CLI** (`scaffold`, `validate`, `preview`) y de las guías upstream: sin probar (depende de Fase 0/Node).

## Integración skills powerbi-authoring (Fase 2, 2026-10-04) — NO verificado

- ✅ **VERIFICADO (usuario, Fase 3)** — **`.mcp.json` en la raíz carga**: `/mcp` muestra conectado `microsoft-learn` desde `.mcp.json` en la raíz (movido desde `.claude/.mcp.json`; corrige el hallazgo de Fase 0).
- ✅ **VERIFICADO (usuario, Fase 3)** — **`powerbi-modeling-mcp` 1.0.0 conecta**: `/mcp` lo muestra conectado (`powerbi-modeling-mcp@1.0.0`), lo que cubre el wrapper `cmd /c npx` y la descarga del binario. **Sigue sin verificar** que sus tools coincidan con lo que citan los skills v0.3.18 (upstream usa `@latest`; antes de 1.0.0 solo había betas).
- **`tools/install-tools.ps1` (Node LTS + CLI 0.4.0)**: solo parseado. Sin ejecutar en máquina limpia; ID winget `OpenJS.NodeJS.LTS` y la ruta "npm aún no en PATH" sin probar.
- ✅ **VERIFICADO (usuario, Fase 3)** — **Patrones de permisos**: validate/catalog/formatting/preview-visuals/doctor/scaffold/`expr encode`/`theme encode` en allow; `preview`, `pack`, `unpack` y `az rest` piden permiso; `preview-visuals` NO pide permiso (el patrón `preview *` con espacio no lo solapa). **Sin verificar**: subcomandos nuevos de 0.4.0 (`preview-pages`, `preview-filters`, `preview-themes`), que deberían caer en prompt por defecto.
- **`scaffold`, `validate`, `preview`** siguen sin ejercitarse (solo `--help`).
