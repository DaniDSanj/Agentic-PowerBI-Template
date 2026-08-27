# Agentic-PowerBI-Template

Plantilla para mantener informes Power BI/Fabric de forma agéntica con Claude Code + VS Code, sobre proyectos PBIP/TMDL/PBIR. Este repositorio es un **[GitHub Template Repository](https://docs.github.com/es/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template)**: no contiene un informe real, pero sí contiene ya, en su sitio final (`.claude/`, `.github/workflows/`, `tools/`, `files/context/`, `CLAUDE.md`), todo lo que necesita un repositorio nuevo para arrancar el flujo agéntico desde el primer commit — sin ningún paso manual de copiar/pegar ficheros entre repos.

## Cómo empezar un proyecto nuevo a partir de esta plantilla

1. **Crea el repo del cliente a partir de esta plantilla** (no hagas `git clone` de este repositorio — eso arrastraría su historial de git; usa el mecanismo de "template" para partir de un repo nuevo y limpio):
   ```
   gh repo create <nombre-cliente> --template <owner>/Agentic-PowerBI-Template --private --clone
   ```
   o el botón **"Use this template"** en GitHub. El repo resultante nace con `.claude/`, `.github/workflows/validate-pr.yml`, `tools/ci/`, `files/context/` y `CLAUDE.md` ya en la raíz — nada que copiar a mano.
2. Abre el repo del cliente (ya clonado en tu máquina) con Claude Code **desde esa carpeta** — los hooks de `.claude/settings.json` están arraigados al directorio de proyecto de la sesión (`CLAUDE_PROJECT_DIR`), así que solo se disparan si Claude Code se abre con esa carpeta como raíz de sesión, no editando sus ficheros desde otra ubicación.
3. En la primera sesión, si `.claude/project-config.json` no existe (siempre será así en un repo recién creado desde la plantilla), el hook `session-start-check` y `files/context/flujo-trabajo.md` te dirigirán a invocar el skill `requirements-intake` — no empieces por ningún otro sitio. Ese mismo paso 0 de `requirements-intake` es también donde se fija `TABULAR_EDITOR_PATH` y el resto de valores específicos de esta máquina/cliente (ver punto 4) — no antes.
4. Instala en la máquina la toolchain que asumen los hooks: **Power BI Desktop, Tabular Editor 2 (>= 2.20.0, sep-2023 — versiones anteriores no reconocen los `.tmdl` que genera Desktop actual; instala la última con `winget install TabularEditor.TabularEditor.2`), DAX Studio**, y **Python** si el proyecto va a operar en Escenario B (semantic-link-labs). Si `TabularEditor.exe` no está en el `PATH`, define `TABULAR_EDITOR_PATH` en el campo `"env"` de nivel raíz de `.claude/settings.json` — **no** con `setx`/variable de entorno de sistema, verificado que una sesión de Claude Code no la hereda de forma fiable ni siquiera arrancando después de fijarla:
   ```json
   { "env": { "TABULAR_EDITOR_PATH": "C:\\ruta\\a\\TabularEditor.exe" } }
   ```
   Este valor es específico de cada máquina/cliente y **nunca** debe quedar commiteado en la plantilla con una ruta real de una máquina concreta — solo en el repo ya creado del cliente, y ahí sí conviene commitearlo (no es un secreto, es una ruta local del entorno de desarrollo del equipo).

### Por qué no un `git clone` directo de esta plantilla

Cada `git clone` de este mismo repositorio compartiría su historial de git entre todos los clientes, y arrastraría cualquier proyecto PBIP real que llegara a existir aquí. El mecanismo de "template repository" de GitHub crea, en cambio, un repositorio nuevo con un único commit inicial, sin vínculo de historial — cada cliente parte limpio. La contrapartida, aceptada explícitamente: los repos ya creados a partir de esta plantilla **no reciben automáticamente** mejoras futuras (bugfixes de hooks, nuevos skills) — hay que reaplicarlas a mano en cada repo cliente activo, o recrear el repo desde la plantilla actualizada.

## Qué garantiza esta plantilla

- **Nunca se asume el escenario de licencia** (A — Pro puro / B — Premium, PPU, Fabric capacity): se pregunta explícitamente en el bootstrap y todo el flujo se ramifica desde `.claude/project-config.json`.
- **Nunca se avanza sobre requisitos ambiguos**: `requirements-intake` cierra audiencia, KPIs, dimensiones, storage mode, SLA, RLS/OLS y criterios de aceptación antes de construir nada.
- **BPA es obligatorio, no opcional**: cada edición de `.tmdl` dispara el hook `post-edit-tmdl` (Tabular Editor 2 CLI), y cada unidad de trabajo de modelo pasa además por el skill `bpa-validate` antes de commit.
- **PBIR nunca se da por bueno sin validar contra su `$schema`** público — está en preview (GA prevista Q3 2026) y un JSON inválido puede impedir que Desktop abra el informe.
- **El agente es autónomo en commits y PRs, pero nunca mergea sus propios PR** ni empuja directo a `main`/`release/*` — reforzado tanto en las instrucciones como técnicamente en `permissions.deny` de `settings.json`.
- **La documentación se regenera sola**: el hook `post-commit-docs` regenera data dictionary, linaje de medidas y README de consumidor tras cada commit que toque modelo o informe.
- **Nunca se gestionan credenciales, cadenas de conexión ni gateways** desde el agente, en ningún fichero de este flujo.

Detalle completo del flujo, fase por fase, con qué skill/agente/hook corresponde a cada una: `files/context/flujo-trabajo.md`.

## Estructura de este repositorio

Es un árbol **1:1 con lo que necesita cualquier repo cliente** — no hay ninguna carpeta intermedia que "instalar": lo que ves aquí es exactamente lo que un repo creado con "Use this template" recibe en su raíz.

```
CLAUDE.md                                  # constitución del agente (raíz, siempre cargado)
Investigacion_AgenticPowerBI_20260826.md   # fuente verificada que respalda CLAUDE.md y files/context/
README.md
files/
└─ context/                                # convenciones por fase, referenciadas por CLAUDE.md via @import
.claude/
├─ settings.json
├─ .mcp.json
├─ project-config.example.json
├─ skills/                                 # un skill por fase del flujo (files/context/flujo-trabajo.md los enumera)
├─ agents/                                 # bpa-reviewer, pbir-schema-validator, docs-writer, data-profiler
└─ hooks/                                  # post-edit-tmdl, post-edit-pbir, post-commit-docs, session-start-check
.github/
└─ workflows/validate-pr.yml               # CI real, activo desde el primer commit del repo cliente
azure-pipelines.yml                        # equivalente Azure DevOps, sin activar salvo que el repo destino lo use
tools/
└─ ci/                                     # validate-bpa.ps1, validate-pbir-schema.ps1 (los que invoca validate-pr.yml)
```

**Nota sobre `.github/workflows/validate-pr.yml` activo en la propia plantilla**: al ser un GitHub Template Repository, este workflow corre también sobre PRs contra la propia plantilla (antes de que ningún cliente exista todavía). `tools/ci/validate-bpa.ps1` tiene una guarda explícita para eso — si no existe `.claude/project-config.json` (siempre será el caso en la plantilla sin bootstrap), se omite la validación en vez de fallar el job. **Confirmado en dogfooding real** (`Agentic-PowerBI-Template` PR #1, cerrado tras la verificación): el job `validate` pasó en verde, y el log confirma que se tomó la rama de la guarda ("No existe '.claude\project-config.json': este repo todavia no ha pasado por el bootstrap... se omite la validacion BPA sin marcar el job como fallido") en vez de fallar por falta de `*.SemanticModel`.

## Aviso sobre el esquema de hooks/skills

Los ficheros de `.claude/` usan el subconjunto de campos de hooks/skills/subagentes/MCP de Claude Code que se pueden confirmar con confianza a fecha de esta plantilla. **Dogfooding end-to-end ya realizado** (sandbox real con `.pbip`/TMDL/PBIR reales, varias sesiones de Claude Code reales, un PR real de GitHub Actions — ver historial de cambios de esta plantilla) — resultado resumido:

- **Confirmado que funciona**: el contrato exit-2 → bloqueo real (system-reminder) de los hooks `PostToolUse` (`post-edit-tmdl`, `post-edit-pbir`, `post-commit-docs`); los skills `requirements-intake`, `pbip-scaffold`, `bpa-validate`/`bpa-reviewer` y `docs-sync`/`docs-writer` se comportan como se documenta, incluido el rechazo explícito a fabricar resultados cuando la herramienta subyacente (TE2) no está disponible.
- **Confirmado que NO llega al agente**: el hook `SessionStart` (`session-start-check.ps1`) — no propagó ningún aviso visible en ninguna de las sesiones de prueba pese a disparar correctamente en aislado. Trátalo como mejor esfuerzo, no como garantía; el fallback manual que ya describe `files/context/flujo-trabajo.md` (comprobar `project-config.json` al principio de sesión) es obligatorio, no redundante.
- **Bugs reales encontrados y corregidos** en `post-edit-tmdl.ps1`: requiere TE2 >= 2.20.0, debe apuntar a la subcarpeta `definition` (no a `*.SemanticModel`), y debe invocar TE2 vía `System.Diagnostics.Process` en vez de `& ... 2>&1` (que no captura salida en el subproceso no interactivo del hook). Detalle completo en la cabecera de ese script y en `files/context/validacion-bpa.md`.
- Importante en general: un hook `PostToolUse` con exit 2 es informativo, no preventivo — el Edit/Write/commit ya se aplicó antes de que el hook corra.
- **CI (`.github/workflows/validate-pr.yml`) implementado y probado real**, no solo descrito: antes de esta sesión no existía ningún fichero de workflow en todo el repo (solo prosa mencionando la carpeta). Se creó `tools/ci/validate-bpa.ps1` + `tools/ci/validate-pbir-schema.ps1` + el workflow (runner `windows-latest`, TE2 instalado descargando `TabularEditor.Portable.zip` del release de GitHub — `winget` no se dio por fiable en un runner GitHub-hosted sin probarlo), y se confirmó en un PR real (`Sandbox-Agentic-PowerBI#1`) que: falla de forma aislada tanto por una violación BPA Error como por un `page.json` sin propiedad `required` de su `$schema`, y pasa en verde al corregir ambas. Detalle completo en `files/context/flujo-trabajo.md` paso 6. Un `azure-pipelines.yml` equivalente para Azure DevOps queda sin crear ni probar — no darlo por hecho.
- **Deploy (Escenario A, `FabricPS-PBIP` con Service Principal) — confirmado en dogfooding real contra un tenant Power BI Pro real.** Ver la sección siguiente.
- **Hallazgo real que motivó convertir esta plantilla en GitHub Template Repository**: en una sesión con dos repos abiertos a la vez (plantilla-origen + repo cliente ya creado), se confirmó por `hook-debug.log` que los hooks de `.claude/settings.json` del repo cliente **no se disparan** al editar sus ficheros desde una sesión de Claude Code arraigada en otro directorio (`CLAUDE_PROJECT_DIR` distinto) — aunque se edite por ruta absoluta. Este repositorio, al distribuirse como plantilla en vez de como fuente para copy-paste manual entre dos carpetas, elimina ese escenario: cada cliente abre su propia sesión arraigada en su propio repo desde el primer commit. **Pendiente de reverificar en una sesión real** tras esta reestructuración — no darlo por resuelto solo por analogía.

## Aviso sobre el skill `deploy` (Escenario A) — confirmado en dogfooding real

El skill `deploy/SKILL.md` (Escenario A: Pro puro / shared capacity) despliega vía `FabricPS-PBIP` con un Service Principal contra la Fabric REST item-definition API. **Se ejecutó de verdad contra un tenant/workspace Power BI Pro real** (no solo inspección de código):

1. Azure AD App Registration con client secret (Entra ID → App registrations → Certificates & secrets).
2. Toggle "Service principals can use Fabric APIs" habilitado en el Admin Portal (requiere rol de administrador de tenant, no solo dueño del workspace).
3. Service Principal añadido como Contributor del workspace destino.
4. `tools/deploy.ps1` (implementación real, ya no un placeholder) ejecutado por el usuario en su propia terminal — el agente nunca gestiona el client secret, que se solicita por un prompt seguro (`Read-Host -AsSecureString`).

**Resultado real**: `Import-FabricItems` creó dos items en el workspace (`SemanticModel` y `Report` del sandbox), confirmados también abriendo el report en el servicio.

**Bug real encontrado y corregido**: `FabricPS-PBIP` requiere **PowerShell 7.1+** — falla con `Modules_InsufficientPowerShellVersion` bajo Windows PowerShell 5.1 (la versión por defecto de Windows, la misma que usan los hooks de esta plantilla). Instala PowerShell 7 e invoca `tools/deploy.ps1` con `pwsh`, no con `powershell` — y abre una terminal nueva tras instalarlo, el PATH actualizado no llega a una consola ya abierta.

**Hallazgo real adicional — el despliegue publica estructura, no datos**: tras el `Import-FabricItems`, el report abrió sin error con la estructura bien enlazada (tablas/medidas visibles), pero al arrastrar un campo no se veían datos. Comprobado con `Refresh now` en el semantic model: `Data source error: Scheduled refresh is disabled because at least one data source is missing credentials`. Causa real, no un bug del script: la consulta M del sandbox usa un fichero **local** (`Financial Sample.xlsx` bajo `C:\Program Files\WindowsApps\...`), inalcanzable desde el servicio sin un gateway on-premises. Configurar credenciales o un gateway cae directamente en `limites-duros.md` ("nunca gestiona credenciales... ni configuración de gateway") — se documenta como paso manual pendiente, no se ha intentado resolver. En un proyecto real con un origen ya alcanzable desde la nube (SQL Server con gateway existente, SharePoint, almacenamiento cloud) este paso de refresco sí sería viable.

**Pendiente/no estresado en esta sesión**: el límite de ~1 GB de Pro puro (el dataset del sandbox es muy pequeño) y la ausencia real de XMLA write/Git de workspace/Deployment Pipelines en shared capacity — documentados por Microsoft, no observados aquí directamente.
