---
tags: [plantilla, changelog]
date: 2026-09-13
---

# CHANGELOG de la plantilla

Registro cronológico (más reciente arriba) de cambios reales al **mecanismo** de `Agentic-PowerBI-Template` — skills, hooks, agentes, CI y convenciones de `files/context/`. No es el changelog de ningún informe Power BI concreto: eso vive en el `docs/CHANGELOG.md` de cada repo cliente, generado por `docs-writer` en modo cliente (ver `files/context/herramientas-documentacion.md`).

Generado y mantenido por el subagente `docs-writer` (modo plantilla) — ver `.claude/agents/docs-writer.md`. Es acumulativo: cada regeneración añade una entrada nueva aquí arriba, nunca sobrescribe las anteriores.

## 2026-09-13 — Documentación autónoma Obsidian-friendly, en ambos modos

Se añade un modo "plantilla" a `docs-writer` (además del modo "cliente" ya existente): detecta si existe algún `*.SemanticModel` bajo `src/` para decidir si genera data dictionary/linaje/README de consumidor (cliente) o `docs/CHANGELOG.md`/`docs/decisiones/` (plantilla, este mismo fichero). Toda nota generada en cualquiera de los dos modos lleva ahora frontmatter YAML y wikilinks `[[nota]]`, para poder abrir `docs/` como vault de Obsidian sin instalar nada adicional — sin comprometer `.obsidian/` ni depender de funciones de pago (Sync/Publish), que quedan excluidas por `files/context/herramientas-documentacion.md`.

Se amplía el hook `.claude/hooks/post-commit-docs.ps1` para detectar también commits que tocan el mecanismo de la plantilla (`files/context/**`, `.claude/**`, `tools/**`, `CLAUDE.md`, `README.md`, `.github/workflows/**`), no solo modelo/informe. Se añade `tools/ci/validate-docs-freshness.ps1` y un nuevo job en `.github/workflows/validate-pr.yml` que falla el PR si el diff toca modelo/informe o mecanismo de plantilla sin tocar la documentación correspondiente — antes, la frescura de `docs/` dependía solo de que el agente atendiera el aviso interactivo del hook, sin ninguna verificación real en CI.

**Motivo**: la documentación autónoma existente (`docs-writer`, `docs-sync`) solo cubría el caso "repo cliente con modelo PBI"; no había ningún mecanismo para documentar cambios en el funcionamiento de la propia plantilla, que es justamente lo que este repo necesita documentar de sí mismo.

**Pendiente de dogfooding real** (ver `files/context/flujo-trabajo.md`, sección de honestidad sobre hooks/skills): el nuevo job de CI (`validate-docs-freshness`) y la ampliación del hook no se han probado todavía contra un PR real — no se dan por confirmados hasta ejecutarlos en la práctica.

## 2026-09-12 — Bootstrap de repo cliente fusionado en un único script

`tools/setup-branch-protection.ps1` se renombra a `tools/setup-github-repo.ps1` y gana un modo de creación de repo (`-ClientName`, con `-Visibility Public|Private`): un solo comando cubre crear el repo cliente desde la plantilla, clonarlo, crear `dev`, proteger ambas ramas y activar secret scanning nativo si el repo es público. Verificado en pruebas reales con repos de prueba (`test-setup-github-repo-2026091*`): se corrigen dos bugs reales — `Test-BranchExists` daba falso positivo porque `gh api` escribe el cuerpo del error 404 en stdout (había que mirar `$LASTEXITCODE`, no el contenido), y se separa `gh repo create --clone` de un `git clone` explícito con reintento tras un fallo puntual por ruta de Windows demasiado larga (`MAX_PATH`).

**Motivo**: antes de este cambio, crear un repo cliente exigía `gh repo create` manual seguido de un script separado — dos pasos con superficie para el mismo tipo de error de propagación de plantilla que se quería evitar.

## 2026-09-11 — `dev` como rama de integración obligatoria + branch protection

Se introduce `dev` como rama de integración entre `feature/*`/`fix/*` y `main`, con ambas ramas protegidas y el job `source-branch-gate` en CI bloqueando cualquier PR contra `main` que no venga de `dev`/`release/*` (GitHub no tiene un mecanismo nativo para restringir la rama origen de una PR). Corrección el mismo día: un bug en el script de protección cambiaba también `default_branch` a `dev`, lo que habría roto "Use this template" (solo copia la rama por defecto) — corregido para que `main` siga siendo siempre la rama por defecto.

**Motivo**: sin `dev`, cada `feature/*` iba directo contra `main`, sin una rama de integración donde acumular cambios antes de promocionar a producción.

## 2026-08-27 — Conversión a GitHub Template Repository (árbol 1:1)

La plantilla pasa de "repo fuente para copiar a mano" a `GitHub Template Repository`: el árbol de `.claude/`, `.github/workflows/`, `tools/`, `files/context/` y `CLAUDE.md` queda ya en su sitio final desde el primer commit de cualquier repo creado con "Use this template", sin ningún paso manual de copiar/pegar entre repos. Se confirma en dogfooding real (PR #1 de esta plantilla) que la guarda de `tools/ci/validate-bpa.ps1` (comprobación de `.claude/project-config.json`) evita que el job de CI falle sobre la propia plantilla, que todavía no tiene ningún `*.SemanticModel`.

**Motivo**: un hallazgo real previo mostró que los hooks de `.claude/settings.json` están arraigados al directorio de proyecto con el que se abre la sesión de Claude Code (`CLAUDE_PROJECT_DIR`), no a la ruta del fichero editado — con dos repos abiertos a la vez (plantilla-origen + repo cliente), los hooks del repo cliente no se disparaban al editarlo desde la sesión arraigada en la plantilla. Distribuir como plantilla, en vez de como fuente para copiar, elimina ese escenario de raíz.
