---
tags: [plan, fabric, skills, integracion]
date: 2026-10-04
relacionado: [[analisis-skills-for-fabric]], [[escenario-licencia]]
---

# Plan: integrar P1 (powerbi-report-cli, semantic-model-authoring, common) en Agentic-PowerBI-Template

## Contexto
Del análisis (`docs/analisis-skills-for-fabric.md`) salió que P1 aporta lo que la plantilla tiene sin probar: diseño y autoría de informe (`temas`, `visuales-pbir`, `diseno-informe`) y guías de modelo/DAX. Decisión del usuario: **vendorizar fijado** en `microsoft/skills-for-fabric` v0.3.18 (MIT), no instalar como plugin.

## Principio de diseño
Dos capas, sin reemplazar nada:
- **Capa de gobierno (la plantilla, en español):** escenario A/B, límites duros, hooks, BPA, `pbir-schema-validator`, `data-profiler`, ramas y PR.
- **Capa de conocimiento y mecánica (upstream, en inglés, sin editar):** guías TMDL/DAX/diseño y CLI `powerbi-report-author`.

Los skills de la plantilla pasan a ser **envoltorios**: conservan sus reglas y delegan el "cómo" en el skill upstream. Así los ficheros vendorizados se pueden actualizar sin conflictos.

## Hechos verificados que condicionan el plan
- Los enlaces upstream usan `../../common/` y `../../../common/`. Copiando `skills/*` a `.claude/skills/` y `common/` a `.claude/common/` **resuelven sin tocar nada**.
- Los nombres upstream (`powerbi-report-cli`, `semantic-model-authoring`) no chocan con los 14 skills actuales.
- `.claude/.mcp.json` está en `.claude/`, pero Claude Code lee el MCP de proyecto desde `.mcp.json` **en la raíz**. El README también lo dibuja en la raíz. Probablemente hoy `microsoft-learn` no se carga (**por verificar con `/mcp`**).
- `tools/install-tools.ps1` instala con winget y hoy no instala Node.
- Los ficheros del skill upstream piden la cabecera `x-ms-fabric-skill` solo en llamadas a `api.fabric.microsoft.com`.

## Fase 0 — Preparación (antes de copiar nada)
1. Rama `feature/integrar-skills-fabric-p1` desde `dev`.
2. Verificar en la máquina de trabajo: `node -v` (≥20), `npm i -g @microsoft/powerbi-report-authoring-cli@<versión fijada>`, `powerbi-report-author doctor`. Registrar la versión exacta que funcione.
3. Verificar `/mcp` para saber si hoy se carga `microsoft-learn` desde `.claude/.mcp.json`.

## Fase 1 — Vendorizar (sin comportamiento nuevo todavía)
1. Copiar `plugins/powerbi-authoring/skills/powerbi-report-cli` y `semantic-model-authoring` a `.claude/skills/`, y `plugins/powerbi-authoring/common/` a `.claude/common/`. Excluir los `apm.yml`.
2. Añadir `.claude/skills/UPSTREAM.md`: origen, tag/commit, versión 0.3.18, licencia MIT, fecha, y el procedimiento manual de actualización (diff contra upstream, PR, revisión).
3. Copiar el `LICENSE` de upstream junto a `UPSTREAM.md` (obligación MIT al redistribuir).
4. Script `tools/ci/check-skill-links.ps1`: comprueba que los enlaces relativos de `.claude/**/*.md` resuelven. Un fallo aquí delata una copia incompleta.
5. Comprobar que `validate-docs-freshness` pasa (tocar `.claude/**` obliga a actualizar `docs/CHANGELOG.md` o `docs/decisiones/`).

## Fase 2 — Cableado de herramientas
1. **MCP:** mover/duplicar la config a `.mcp.json` en la raíz (según resultado de Fase 0) y añadir `powerbi-modeling-mcp` en modo stdio, **con versión fijada** en lugar de `@latest`.
2. **Instalador:** `tools/install-tools.ps1` instala Node LTS (winget `OpenJS.NodeJS.LTS`) y el CLI npm con la versión fijada. Sigue la separación del ADR 0001: la instalación vive aquí, no en `setup-github.ps1`.
3. **Permisos (`.claude/settings.json`):**
   - `allow`: `powerbi-report-author validate*`, `catalog*`, `formatting*`, `preview-visuals*`, `doctor*`, `scaffold*`, `expr encode*`, `theme encode*`.
   - `ask`: `powerbi-report-author preview*` (abre Desktop y escribe screenshots), `pack*`/`unpack*`, y **`az rest*`** (hoy sin regla).
   - Sin cambios en los `deny` existentes.

## Fase 3 — Envoltorios (la parte importante)
Reescribir los SKILL.md de la plantilla para que deleguen. Cada uno mantiene sus reglas propias y añade "Lee primero el skill upstream X, modo Y".

| Skill plantilla | Delega en | Se conserva de la plantilla |
|---|---|---|
| `diseno-informe` | `powerbi-report-cli` modos **planning + design** (arquetipos, `layout_contract`, accesibilidad WCAG) | Perfilado previo con `data-profiler`; cada visual se traza a una pregunta de `requirements-intake` |
| `temas` | `powerbi-report-cli` design (`assets/base.json`, `theme encode`, guía de re-theming) | Versionado en `themes/`, contraste ≥4,5:1, comprobación en un informe representativo |
| `visuales-pbir` | `powerbi-report-cli` modo **authoring** (`scaffold`, `catalog`, `formatting`, `validate`, `preview`) | Hook `post-edit-pbir` + `pbir-schema-validator` como **segunda capa** (cubre IDs duplicados) |
| `modelo-tmdl` | `semantic-model-authoring` → `tmdl-guidelines`, `modeling-guidelines`, `naming-conventions` | `discourageImplicitMeasures`, hook BPA, `bpa-validate` |
| `medidas-dax` | `semantic-model-authoring` → `dax-guidelines`, `dax-perf-*`, `field-parameters` | CS-Script de TE2, DAX UDFs con `compatibilityLevel` ≥1702 |
| `pbip-scaffold` | `powerbi-report-cli scaffold` para el informe | Estructura de repo y creación de rama |
| `deploy` | **No cambia.** Solo se añade una nota: el despliegue vía API no es idempotente (un reintento duplica el modelo) | `FabricPS-PBIP`, ejecución solo por el usuario |

**Reglas de arbitraje que los envoltorios deben fijar** (donde upstream y la plantilla chocan):
1. **Quién edita el modelo:** upstream prefiere el MCP y prohíbe leer `.tmdl` con el MCP conectado. Aquí manda **TMDL en disco + hook BPA**. El MCP se usa para leer, ejecutar DAX y refrescar. Si alguna vez escribe vía MCP, el hook no se dispara: ejecutar `bpa-validate` a mano y declararlo.
2. **Puerta de aprobación de planning:** upstream pregunta de nuevo audiencia y KPIs. Aquí planning **parte del cierre de `requirements-intake`** y no repite preguntas ya resueltas; solo conserva la aprobación explícita antes de construir.
3. **Credenciales:** `bindConnection`, `connection-binding.md` y el modo `management` que publica/sobrescribe quedan **fuera del alcance del agente** (límite duro). El agente documenta el paso manual y no lo ejecuta. Un error de credenciales en refresco: parar y avisar.
4. **Escenario A/B:** el modo `management` y el despliegue de modelos usan API de Fabric. En A se tratan como *no probados* hasta validarlos en Pro real. Direct Lake, XMLA de escritura y `bindConnection` no se proponen en A.
5. **Cabecera `x-ms-fabric-skill`:** se acepta tal cual si el agente llega a llamar a la API (es solo atribución). No se copia al resto de la plantilla.
6. **Enrutado:** los skills upstream tienen descripciones muy amplias y pueden dispararse antes que los de la plantilla. Añadir en `CLAUDE.md`/`flujo-trabajo.md` la regla: "entra por el skill de la plantilla de la fase; él decide cuándo leer el upstream".
7. **Herramientas gratuitas:** el CLI y el MCP son npm/MIT, compatibles con la regla de herramientas libres. Registrar el CLI como "beta" en `herramientas-documentacion.md`.

## Fase 4 — Documentación y contexto
1. `files/context/`: actualizar `visuales-pbir.md`, `diseno.md`, `temas.md`, `modelo-tmdl.md`, `medidas-dax.md` con una línea que apunte al skill upstream y a las reglas de arbitraje (sin duplicar contenido upstream).
2. `files/context/herramientas-documentacion.md`: añadir Node, `powerbi-report-author` y `powerbi-modeling-mcp`.
3. `files/context/flujo-trabajo.md` (pasos 3 y 4): reflejar la delegación y el orden planning → design → authoring → preview.
4. **ADR** `docs/decisiones/0002-vendorizar-skills-powerbi-authoring.md`: por qué vendorizar (reproducible, revisable por PR, heredado por repos cliente) frente a plugin; coste (actualización manual, 1,5 MB); versión fijada; reglas de arbitraje.
5. `docs/CHANGELOG.md`: entrada del cambio. `README.md`: nueva dependencia (Node) y árbol de `.claude/`.
6. `PENDIENTE-VERIFICACION-SANDBOX.md`: añadir cada ítem de la Fase 5 como **no verificado** hasta que se haga.

## Fase 5 — Verificación en el sandbox (criterio de honestidad de la plantilla)
Abrir la sesión de Claude Code **con el repo sandbox como directorio de trabajo** (los hooks se anclan a `CLAUDE_PROJECT_DIR`). Crear el repo desde la plantilla con `setup-github.ps1 -ClientName`.

1. `powerbi-report-author doctor` y `/mcp`: el MCP `powerbi-modeling-mcp` conecta; `microsoft-learn` también.
2. Informe nuevo: planning (sin repetir preguntas de `requirements-intake`) → design → `scaffold` → un `cardVisual` y un gráfico → `validate` → `preview --host desktop --screenshot`. Revisar la captura.
3. **Prueba de solape de validadores:** provocar un ID de visual duplicado y comprobar si `powerbi-report-author validate` lo detecta además de `pbir-schema-validator`. Si sí, subir el chequeo a CI.
4. Modelo: añadir una medida con `dax-guidelines` y confirmar que el hook BPA se dispara; luego una edición vía MCP y confirmar que **no** se dispara (documentarlo).
5. Sobre el modelo del sandbox (que ya tuvo 6 errores `META_AVOID_FLOAT`), comprobar que las guías upstream (no usar `Double`) no contradicen `BPARules`.
6. Compatibilidad de formato: abrir en Desktop un informe creado con `scaffold` y otro del sandbox anterior para detectar diferencias de versión PBIR.
7. CI: PR real con `check-skill-links.ps1` y `validate-docs-freshness` en verde. Valorar un job opcional de `powerbi-report-author validate` **sin bloquear** hasta confirmar que corre en `windows-latest` sin Desktop.
8. Escenario A: **no** ejecutar `management`/publicación hasta decidir (ver riesgos).

## Archivos críticos
- Nuevos: `.claude/skills/{powerbi-report-cli,semantic-model-authoring}/`, `.claude/common/`, `.claude/skills/UPSTREAM.md`, `tools/ci/check-skill-links.ps1`, `docs/decisiones/0002-…md`.
- Modificados: `.claude/skills/{diseno-informe,temas,visuales-pbir,modelo-tmdl,medidas-dax,pbip-scaffold}/SKILL.md`, `.claude/settings.json`, `.mcp.json` (raíz), `tools/install-tools.ps1`, `.github/workflows/validate-pr.yml`, `files/context/*.md`, `CLAUDE.md`, `README.md`, `docs/CHANGELOG.md`, `PENDIENTE-VERIFICACION-SANDBOX.md`.
- Reutilizar: hooks `post-edit-tmdl`/`post-edit-pbir`, subagentes `bpa-reviewer`, `pbir-schema-validator`, `data-profiler`; no se tocan.

## Riesgos y preguntas abiertas
- **Beta y deriva:** CLI en `0.3.0-beta`; upstream cambia cada semana. Mitigación: versión fijada y `UPSTREAM.md`.
- **Contexto:** son ~1,3 MB de Markdown. El skill carga referencias bajo demanda, pero hay que comprobar que los envoltorios no hagan que el agente lea todo.
- **Dos validadores de PBIR:** posible duplicidad (Fase 5.3).
- **`management` en Pro:** upstream no declara si un workspace Pro acepta la API de Fabric para informes; la plantilla ya lo hace con `FabricPS-PBIP`. Decisión pendiente tras el sandbox: mantener `deploy` o migrar.
- **Repos cliente existentes** no reciben esta mejora automáticamente (limitación ya documentada en el README).
- **Windows/Desktop:** `preview` exige Desktop abierto y un `.pbip` propietario; no corre en CI.

## Criterio de cierre
Un repo cliente creado desde la plantilla puede, sin pasos manuales ocultos: planificar y diseñar un informe, construirlo con `scaffold`/`validate`, ver una captura real desde Desktop, y pasar CI, con todo lo no probado listado en `PENDIENTE-VERIFICACION-SANDBOX.md`.

