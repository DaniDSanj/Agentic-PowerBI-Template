# Flujo de trabajo agéntico end-to-end

Este fichero es la pieza de enganche entre "qué hay que hacer en cada fase" (el resto de `files/context/`) y "qué mecanismo nativo de Claude Code lo ejecuta" (`.claude/`, ya presente en la raíz de cualquier repo creado a partir de esta plantilla — ver `README.md`). Léelo siempre al principio de una sesión sobre un repo creado a partir de esta plantilla: te dice en qué paso estás y qué invocar a continuación.

## 0. Bootstrap (una sola vez por proyecto)

Si `.claude/project-config.json` no existe, el repo no ha sido inicializado todavía. Invoca el skill `requirements-intake` — su paso 0 pregunta explícitamente el escenario de licencia (ver `escenario-licencia.md`) y escribe `.claude/project-config.json` con `{"proyecto", "escenario": "A"|"B", "storageMode", "fechaBootstrap"}`. **Nunca asumas el escenario por el nombre del cliente o del repo.** El hook `session-start-check.ps1` te lo recordará al abrir sesión si falta ese fichero.

Todo lo que sigue lee ese fichero para decidir sus ramas condicionales A/B.

## 1. Toma de requisitos

`requirements-intake` (skill) aplica `toma-requisitos.md` íntegro: audiencia, preguntas de negocio, definición exacta de KPIs, dimensiones, storage mode, SLA de refresco, volumen, RLS/OLS, criterios de aceptación. No se avanza al paso 2 sin cerrar esta lista explícitamente con el usuario.

## 2. Scaffold del proyecto

`pbip-scaffold` (skill) crea la estructura de `arquitectura-repositorio.md` (`src/`, `themes/`, `templates/`, `tools/`, `docs/`, `.gitignore`, `.gitattributes`) y abre `feature/<nombre-informe>` **desde `dev`** (nunca desde `main`, que está protegida — ver `control-versiones.md`) según `control-versiones.md`. Si el PBIP no existe aún, este es el único punto del flujo en el que se declara explícitamente un paso manual en Desktop (crear el .pbip una vez para heredar su `.gitignore` base y convertir a TMDL/PBIR).

## 3. Bucle de desarrollo del modelo

Orden recomendado, cada fase con su skill homónimo y su fichero de contexto asociado (el skill lo lee bajo demanda, no lo dupliques):

| Fase | Skill | Contexto | Validación |
|---|---|---|---|
| Orígenes de datos | `origenes-datos` | `origenes-datos.md` | — |
| Transformaciones M | `transformaciones-m` | `transformaciones-m.md` | pendiente manual en Desktop (folding/preview) |
| Modelo TMDL | `modelo-tmdl` | `modelo-tmdl.md` | hook `post-edit-tmdl.ps1` en cada edición + skill `bpa-validate` antes de cerrar la unidad |
| Medidas/DAX/UDFs | `medidas-dax` | `medidas-dax.md` | idem |

El hook `post-edit-tmdl.ps1` (`PostToolUse` sobre `Edit`/`Write` matcheando `**/*.tmdl`) ejecuta Tabular Editor 2 CLI contra `tools/BPARules.json` tras cada edición y **bloquea** (exit code 2) si hay violaciones de severidad Error — no hace falta acordarse de invocarlo. Antes de dar una unidad de trabajo del modelo por cerrada (previa a commit), invoca igualmente el skill `bpa-validate` de forma explícita: delega en el subagente `bpa-reviewer`, que interpreta el informe completo (no solo el último fichero tocado) y resume violaciones de severidad Warning/Info que el hook no bloquea pero que sí deben documentarse o corregirse.

## 4. Bucle de desarrollo del informe

| Fase | Skill | Contexto |
|---|---|---|
| Tema | `temas` | `temas.md` |
| Visuales PBIR | `visuales-pbir` | `visuales-pbir.md` |
| Diseño de página | `diseno-informe` | `diseno.md` |

El hook `post-edit-pbir.ps1` (`PostToolUse` sobre `Edit`/`Write` matcheando `**/definition/pages/**/*.json`) delega en el subagente `pbir-schema-validator` contra el `$schema` público de PBIR — bloquea si el JSON resultante no valida. `visuales-pbir` invoca además al subagente `data-profiler` antes de proponer cualquier visual nuevo, para partir de cardinalidades/distribuciones reales y no de una plantilla genérica (ver `diseno.md`).

## 5. Cierre de la unidad de trabajo: commit y PR

Commit semántico (`feat(model): ...`, `fix(report): ...`) sobre la rama `feature/`/`fix/` activa, siguiendo `control-versiones.md`. El agente commitea y abre el PR **contra `dev`** de forma autónoma, sin pedir permiso en cada paso — **pero nunca hace merge de su propio PR ni push directo a `dev`/`main`/`release/*`**; `settings.json` lo refuerza técnicamente (deny explícito en `permissions`), no solo por instrucción, y la branch protection de GitHub (`tools/setup-github-repo.ps1`) lo refuerza además a nivel de plataforma. El merge queda siempre a criterio humano tras revisar el diff TMDL/PBIR.

La promoción `dev → main` es una PR separada y explícita (no ocurre en cada cierre de unidad de trabajo) — el job `source-branch-gate` de CI bloquea cualquier PR contra `main` que no venga de `dev` o `release/*`.

El hook `post-commit-docs.ps1` (`PostToolUse` sobre `Bash` matcheando `git commit`) invoca al subagente `docs-writer`, que regenera data dictionary, linaje de medidas y README de consumidor en `docs/` a partir de TMDL/DMVs — no bloquea el commit, corre después. Si prefieres regenerarla fuera de ese momento, el skill `docs-sync` hace lo mismo bajo demanda.

## 6. CI

`.github/workflows/validate-pr.yml` (ya activo en la raíz de cualquier repo creado a partir de esta plantilla, incluida la propia plantilla — ver la nota sobre la guarda de `.claude/project-config.json` en `README.md`) es un fichero real, no una descripción: se dispara en cada PR contra `main`/`master`/`dev`/`develop`/`release/**`, corre en runner `windows-latest` (Tabular Editor 2 es .NET Framework/Windows, no corre en Linux/macOS) y ejecuta dos scripts standalone, contraparte server-side de los hooks locales:

- `tools/ci/validate-bpa.ps1` — repite la invocación TE2 confirmada de `post-edit-tmdl.ps1` (`TabularEditor.exe "<Proyecto>.SemanticModel\definition" -A tools\BPARules.json -V`, vía `System.Diagnostics.Process` con redirección explícita — `& $teExe ... 2>&1` no captura salida/exit-code de forma fiable ni siquiera fuera del contexto de hooks, reconfirmado en runner real) sobre **todos** los `*.SemanticModel` del repo, y falla el job (`exit 1`) si hay líneas `##vso[task.logissue type=error;]`.
- `tools/ci/validate-pbir-schema.ps1` — repite la comprobación superficial de `post-edit-pbir.ps1` (JSON válido + array `required` de nivel superior del `$schema` declarado) mas no una validación completa de JSON Schema, solo sobre los ficheros PBIR tocados en el diff del PR (`git diff --name-only <base>...HEAD`).
- `tools/ci/validate-docs-freshness.ps1` — contraparte de servidor del hook local `post-commit-docs.ps1`, pero verificando de verdad en vez de solo recordar: si el diff del PR toca modelo/informe (`*.tmdl`, `definition/pages/**`) exige que también toque `docs/data-dictionary.md`, `docs/linaje-medidas.md`, `docs/README-consumidor.md` o `docs/adr/**`; si toca mecanismo de la plantilla (`files/context/**`, `.claude/**`, `tools/**`, `CLAUDE.md`, `README.md`, `.github/workflows/**`) exige que también toque `docs/CHANGELOG.md` o `docs/decisiones/**`. Falla el job (`exit 1`) si falta la actualización correspondiente; no falla si el repo no tiene ningún `*.SemanticModel` (la primera condición simplemente no llega a aplicar). **Añadido en esta revisión (2026-09)**: verificado localmente contra dos ramas de prueba reales (falla si el diff toca `.claude/` sin tocar `docs/`, pasa si los toca a la vez), pero todavía sin ejecutarse como job real de `validate-pr.yml` dentro de un PR de GitHub Actions — mismo criterio de honestidad que el resto de este fichero: no se da por probado del todo hasta verificarlo ahí. Ver `docs/CHANGELOG.md`.

El workflow tiene además dos jobs de seguridad (`gitleaks`, `source-branch-gate`) que no dependen de TE2 ni de PBIR — detalle completo en `control-versiones.md`.

Instalación de TE2 en el runner: descarga directa de `TabularEditor.Portable.zip` desde el release de GitHub `TabularEditor/TabularEditor` (versión fijada, `2.28.0` al validar esto) — **no** `winget`, que en un runner GitHub-hosted requeriría aceptar acuerdos de fuente de forma no interactiva y no se dio por fiable sin probarlo.

**Confirmado en dogfooding real** (repo privado `Sandbox-Agentic-PowerBI`, PR #1, tres pushes sucesivos sobre la misma rama): el job pasa en verde sobre un modelo/PBIR limpios; falla de forma aislada tanto por una violación BPA de severidad Error (medida con división de denominador no constante, `DAX_DIVISION_COLUMNS`) como por un `page.json` sin la propiedad `displayName` requerida por su `$schema` (los steps de GitHub Actions paran en el primer fallo, así que cada comprobación se probó por separado); y vuelve a verde al corregir ambos. De paso se descubrió que el propio modelo de ejemplo del sandbox ya tenía 6 violaciones Error preexistentes (`META_AVOID_FLOAT`, columnas `double` sin corregir) nunca detectadas hasta ejecutar TE2 manualmente — corregidas antes de dar la validación de CI por buena.

Pendiente/no bloqueante: un `azure-pipelines.yml` equivalente para Azure DevOps (misma lógica, distinta sintaxis) no se ha creado ni probado todavía — mismo criterio de honestidad que el resto de esta plantilla, no darlo por hecho hasta ejecutarlo.

## 7. Despliegue

Skill `deploy`, ramificado por `escenario` en `project-config.json`:
- **A (Pro puro)**: Fabric item-definition API vía `FabricPS-PBIP` (open source sin soporte oficial — valida en cada release) con Service Principal, o publish manual desde Desktop si no hay pipeline. Sin XMLA write, sin Git de workspace, sin Deployment Pipelines: no existen en shared capacity.
  **Confirmado en dogfooding real** contra un workspace Power BI Pro real: App Registration + client secret + toggle "Service principals can use Fabric APIs" (rol de administrador de tenant) + SP como Contributor del workspace → `tools/deploy.ps1` ejecutado por el usuario (nunca por el agente) con `Import-FabricItems` creó de verdad los items `SemanticModel` y `Report` del sandbox en el workspace, confirmado también abriendo el report en el servicio. Bug real encontrado: `FabricPS-PBIP` exige PowerShell **7.1+** (falla en Windows PowerShell 5.1 con `Modules_InsufficientPowerShellVersion`) — usa `pwsh`, no `powershell`, y abre una terminal nueva tras instalarlo.

  **El despliegue publica estructura, no datos**: el report abrió bien pero sin datos al arrastrar un campo; `Refresh now` sobre el semantic model devolvió `Data source error: Scheduled refresh is disabled because at least one data source is missing credentials`. Causa real: la consulta M del sandbox usa un fichero local de Desktop, inalcanzable desde el servicio sin gateway. Configurar credenciales/gateway es un paso manual fuera de alcance del agente (`limites-duros.md`) — no se intentó resolver, se deja documentado como pendiente. Con un origen ya alcanzable desde la nube (SQL Server con gateway existente, SharePoint, cloud storage) este paso sí sería viable.

  Pendiente sin estresar: el límite de ~1 GB y la ausencia real de XMLA/Git de workspace/Deployment Pipelines en Pro puro (documentados por Microsoft, no observados con este dataset pequeño).
- **B (Premium/PPU/Fabric capacity)**: Git de workspace conectado a Azure Repos/GitHub, `Deployment Pipelines` Dev→Test→Prod, XMLA write habilitado, Direct Lake si los datos están en OneLake. **No probado en esta plantilla** — todo el dogfooding hasta ahora ha sido en Escenario A.

## Qué NUNCA se automatiza en este flujo (recordatorio, ver `limites-duros.md`)

Refresco de metadatos M, verificación de query folding, credenciales/gateway, y cualquier cambio en PBIR sin pasar por `pbir-schema-validator`. Si una tarea depende de uno de estos puntos, decláralo explícitamente como paso manual pendiente en Desktop en vez de darlo por hecho.

## Nota sobre el esquema de hooks/skills usado en `.claude/`

Los ficheros de `.claude/` usan únicamente el subconjunto de campos de hooks/skills/subagentes/MCP de Claude Code que se pueden confirmar con alta confianza (hooks `type: command` con JSON por stdin y exit code 2 para bloquear; frontmatter de skill con `name`/`description`/`allowed-tools`; frontmatter de subagente con `name`/`description`/`tools`/`model`; `.mcp.json` con `mcpServers.{type, command|url, env|headers}`; permisos `allow`/`ask`/`deny` con sintaxis `Tool(patrón)`).

**Dogfooding end-to-end ya realizado** sobre un sandbox real (`.pbip`/TMDL/PBIR reales, varias sesiones de Claude Code reales, más un PR real de GitHub Actions para el paso 6 de este mismo fichero) — ver el resumen en `README.md` ("Aviso sobre el esquema de hooks/skills") y las cabeceras de los propios scripts en `.claude/hooks/` para el detalle completo. Ese dogfooding se hizo bajo el modelo anterior de dos repos (plantilla-origen sin git + `Sandbox-Agentic-PowerBI` con `.claude/` copiado y parcheado a mano) — sigue siendo válido como evidencia de que el propio mecanismo de hooks/skills funciona, pero la reestructuración a GitHub Template Repository descrita en `README.md` es posterior y todavía no tiene su propio dogfooding end-to-end; trátala como diseño razonado, no como confirmado, hasta que se cree un repo cliente real con "Use this template" y se repita la validación. En corto: el contrato exit-2 → bloqueo real de los hooks `PostToolUse` está confirmado y funciona; el hook `SessionStart` está confirmado que NO propaga su aviso al agente de forma fiable (de ahí que el paso 0 de este mismo fichero insista en comprobar `project-config.json` como mecanismo independiente); se encontraron y corrigieron tres bugs reales en `post-edit-tmdl.ps1` (versión mínima de TE2, ruta al modelo TMDL, captura de salida del proceso); el workflow de CI del paso 6 (antes un stub `echo "TODO"` sin implementar) se implementó y se confirmó real en un PR de GitHub contra un runner `windows-latest`, incluyendo el mismo hallazgo de captura de salida de TE2 (`& $teExe ... 2>&1` no fiable) reproducido fuera del contexto de hooks; y el skill `deploy` (Escenario A, paso 7) se confirmó real contra un tenant Power BI Pro con Service Principal, incluyendo el hallazgo de que `FabricPS-PBIP` exige PowerShell 7.1+ (Windows PowerShell 5.1 no vale). Antes de dar por buena cualquier modificación futura de estos hooks en un proyecto real, repite la validación en una sesión real — el comportamiento del harness puede cambiar entre versiones de Claude Code.

**Hallazgo real adicional** (dogfooding de visuales PBIR, `Sandbox-Agentic-PowerBI` PR #3): los hooks están arraigados a la carpeta de proyecto **con la que se abrió la sesión de Claude Code** (`CLAUDE_PROJECT_DIR`), no a la ruta del fichero que se edita. En esta sesión, arraigada en el repo de la plantilla-origen, se editaron `visual.json` reales dentro del sandbox vía ruta absoluta — el `post-edit-pbir.ps1` del sandbox **no se disparó** (confirmado por `hook-debug.log` del sandbox, sin nueva entrada tras las ediciones). La comprobación real del hook tuvo que hacerse invocando el script directamente por `pwsh -File ... < payload.json`, replicando el JSON que el harness le pasaría por stdin — válido para probar la lógica del script, pero no prueba el cableado automático del harness en ese escenario. Implicación práctica: para dogfooding fiable de hooks de un repo real, la sesión de Claude Code debe abrirse **con ese repo como working directory**, no operar sobre él desde una sesión arraigada en otro sitio.
