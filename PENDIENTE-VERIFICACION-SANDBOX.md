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

## Integración skills powerbi-authoring (Fase 0, 2026-10-04) — NO verificado

Plan: `docs/plan-integracion-skills-fabric-p1.md`.

- **Node ≥20**: `node`/`npm` no están instalados en la máquina de trabajo (ni en PATH ni en `C:\Program Files\nodejs`). Instalación global = paso manual (`winget install OpenJS.NodeJS.LTS`, terminal nueva); no la hizo el agente.
- **`@microsoft/powerbi-report-authoring-cli` + `powerbi-report-author doctor`**: no ejecutado. Versión exacta que funcione: **sin determinar**.
- **`microsoft-learn` desde `.claude/.mcp.json`**: sin verificar con `/mcp` (comando interactivo del usuario). Estático: existe `.claude/.mcp.json` y no existe `.mcp.json` en la raíz, que es donde Claude Code lo lee → probablemente no se carga.
