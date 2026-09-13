---
tags: [plantilla, changelog]
date: 2026-09-13
---

# CHANGELOG de la plantilla

Registro cronológico (más reciente arriba) de cambios reales al **mecanismo** de `Agentic-PowerBI-Template` — skills, hooks, agentes, CI y convenciones de `files/context/`. No es el changelog de ningún informe Power BI concreto: eso vive en el `docs/CHANGELOG.md` de cada repo cliente, generado por `docs-writer` en modo cliente (ver `files/context/herramientas-documentacion.md`).

Generado y mantenido por el subagente `docs-writer` (modo plantilla) — ver `.claude/agents/docs-writer.md`. Es acumulativo: cada regeneración añade una entrada nueva aquí arriba, nunca sobrescribe las anteriores.

## 2026-09-13 — Bug real corregido: condición de carrera en `setup-github.ps1 -ClientName` al clonar

Al recrear el repo sandbox `Agentic-PowerBI-Sandbox` (tras promocionar `dev→main` con el contenido de `install-tools.ps1`), el clon local quedó completamente vacío (`git status` → "No commits yet") pese a que el script reportó éxito. Causa real: `gh repo clone` se ejecutó antes de que GitHub terminara de propagar el commit inicial de "Use this template" — clonar un repo remoto que técnicamente ya existe pero todavía no tiene contenido también sale con exit code 0, y el bucle de reintentos de entonces solo comprobaba ese exit code, no el contenido real del clon. Confirmado con `gh api repos/.../commits`: el commit real sí existía en el remoto segundos después.

Esto es la confirmación real de un escenario que el propio script ya dejaba anotado como "no confirmado, pero tampoco descartado" en un comentario anterior (distinto del bug de `MAX_PATH` que sí se investigó y descartó como causa de un fallo de `--clone` en una sesión previa). Corregido: tras cada `gh repo clone` con exit 0, se comprueba además que `git rev-parse HEAD` resuelve a un commit real en el clon; si no, se trata como intento fallido y se reintenta (hasta los mismos 6 intentos con 5s de espera ya existentes). Mitigado manualmente en la sesión donde se detectó (reclonando y reaplicando `-LocalGuardOnly`) antes de corregir el script.

**Pendiente**: no se ha vuelto a ejecutar `-ClientName` de extremo a extremo tras este fix para confirmar que la nueva comprobación realmente evita el problema (solo se verificó la lógica leyendo el diff) — mismo criterio de honestidad que el resto de esta plantilla.

## 2026-09-13 — `tools/install-tools.ps1`: instalación de toolchain separada de `setup-github.ps1`

Surgió al crear el repo sandbox de dogfooding (`Agentic-PowerBI-Sandbox`): `tools/setup-github.ps1` deja como pendiente manual instalar `gitleaks`/Tabular Editor 2/DAX Studio (solo los detecta y avisa si faltan, nunca los instala — alcance deliberado ya documentado en la cabecera de ese script). Se planteó fusionar la instalación dentro de `setup-github.ps1` para tener un único punto de entrada; se decidió **no** hacerlo y crear en su lugar `tools/install-tools.ps1`, separado.

Razón de la separación: son dos ejes ortogonales con ciclo de vida distinto. `setup-github.ps1` configura *un repo* (API de GitHub + `core.hooksPath` de ese clon) — se repite una vez por repo cliente. `install-tools.ps1` configura *la máquina* (instala vía `winget`) — una vez por equipo, sin importar cuántos repos cliente se trabajen después desde ahí. Fusionarlos acoplaría ambos ciclos y automatizaría sin pedirlo explícitamente la instalación de binarios de terceros (mayor blast radius que escribir en la API de GitHub o en `.git/config`), en tensión con el límite de no introducir herramientas sin autorización explícita (`files/context/limites-duros.md`).

`install-tools.ps1` es idempotente (comprueba antes de instalar) y admite `-SkipGitleaks`/`-SkipTabularEditor`/`-SkipDaxStudio` para quien ya tenga alguna herramienta por otra vía. Power BI Desktop y Python/`semantic-link-labs` (Escenario B) quedan fuera a propósito — no tienen (el primero) o no forman parte de la toolchain base de Escenario A (el segundo). **Diseño, pendiente de su propio dogfooding real** — los IDs de winget usados (`Gitleaks.Gitleaks`, `TabularEditor.TabularEditor.2`, `DaxStudio.DaxStudio`) no se han confirmado ejecutando el script en una máquina limpia, mismo criterio de honestidad que el resto de esta plantilla.

## 2026-09-13 — `merge-audit`/`audit-history` confirmados en dogfooding real

Se probó el subagente `merge-audit` de extremo a extremo contra un segundo repo privado de prueba real (`DaniDSanj/test-merge-audit-dogfood-20260913`, creado igual que el anterior vía `tools/setup-github.ps1 -ClientName ... -Visibility Private`): se abrió una PR (`#1`, `feature/red-ci-demo` → `dev`) con un patrón de secreto simulado a propósito para forzar el job `gitleaks` a rojo, y se mergeó manualmente desde la web de GitHub pese al CI en rojo — posible precisamente porque, al ser un repo privado en plan Free, la branch protection no pudo aplicarse (403 ya confirmado) y el botón "Merge" no estaba bloqueado.

Al invocar `merge-audit` contra ese repo, detectó correctamente el merge commit `51280ec` en `dev`, encontró su PR asociada (#1) y reportó el hallazgo exacto: `gitleaks` en `FAILURE` en el momento del merge, `validate` en `SUCCESS`, `source-branch-gate` en `SKIPPED` (correcto, ese job solo aplica contra `main`). Confirmó también, correctamente, que `main` no tenía ningún merge que auditar todavía (0 en total) y que no había falsos positivos de "merge sin PR asociada".

Con esto queda dogfoodeada toda la capa de gobernanza local descrita en las dos entradas anteriores de este mismo día — el único punto que quedaba genuinamente sin probar. Repos de prueba borrados tras la confirmación (el remoto, manualmente por el usuario en ambos casos; `gh repo delete` sigue denegado para el agente).

## 2026-09-13 — Bug real corregido: el guard local nunca se activaba en el escenario para el que existe

Dogfooding contra un repo privado real creado a propósito (`DaniDSanj/test-obsidian-docs-dogfood-20260913`, vía `pwsh -File tools/setup-github.ps1 -ClientName ... -Visibility Private`) reveló que el automatismo "si el repo es privado, activa el guard local al terminar" (entrada anterior de este mismo día) **nunca llegaba a ejecutarse** en el caso real: `Set-BranchProtection` lanzaba una excepción en el primer 403 (esperado en plan Free sobre repo privado) y, con `$ErrorActionPreference = 'Stop'`, esa excepción abortaba el script completo antes de llegar al bloque que activa `core.hooksPath` — precisamente en el único escenario para el que ese automatismo se diseñó.

Corregido: `$repoVisibility` se calcula ahora **antes** de intentar branch protection (no después), y las dos llamadas a `Set-BranchProtection` (`dev`, `main`) quedan envueltas en un `try/catch` — si el repo es privado, un 403 se avisa y el script continúa hasta activar el guard local; si el repo es público, el mismo fallo sigue relanzándose (`throw`), porque ahí sí sería un error real e inesperado.

**Confirmado en dogfooding real, con el fix aplicado, contra el mismo repo privado**: re-ejecutar `pwsh -File tools/setup-github.ps1` (modo "reaplicar", sin `-ClientName`) desde el clon ya existente terminó con `exit 0`, imprimiendo el mismo 403 esperado como aviso (no como error fatal) y, a continuación, `OK: core.hooksPath -> tools/git-hooks` — verificado también con `git config --get core.hooksPath` tras la ejecución. El repo de prueba se creó con `gh repo create --template` real y se limpió el clon local al terminar; el repo remoto en GitHub **no se pudo borrar** desde esta sesión (`gh repo delete` está en la lista `deny` de `.claude/settings.json`) — queda pendiente de borrado manual por el usuario.

## 2026-09-13 — Fusión de setup-github-repo.ps1 + setup-local-git-guard.ps1 en tools/setup-github.ps1

A petición del usuario, los dos scripts de gobernanza de repo (`tools/setup-github-repo.ps1`, que configura branch protection/secret scanning vía `gh api`, y `tools/setup-local-git-guard.ps1`, que activa el guard local de la entrada siguiente) se fusionan en un único `tools/setup-github.ps1` (`git mv` para conservar el historial del primero).

La fusión no es un simple pegado: `setup-github-repo.ps1` requiere `gh` autenticado con permisos de **administrador** del repo (crea/protege ramas), mientras que activar el guard local no toca la API de GitHub en absoluto. Dos casos reales donde esa diferencia importa, identificados antes de fusionar: un colaborador con acceso "Write" pero no "Admin" en el repo cliente (mínimo privilegio — no todo el mundo que commitea debería poder tocar branch protection), o el propio administrador autenticado en `gh` con un token de alcance reducido (fine-grained PAT sin el permiso `administration`) por política de seguridad corporativa. En ambos casos, si el script fusionado intentara siempre primero la parte de GitHub, esa persona nunca llegaría a activar su guard local.

Por eso `tools/setup-github.ps1` gana un tercer modo, `-LocalGuardOnly [-RepoRoot <ruta>]`, que salta por completo la parte de GitHub (no requiere `gh` instalado ni autenticado) y solo activa `core.hooksPath` + comprueba `gitleaks`/Tabular Editor 2 — exactamente lo que hacía `setup-local-git-guard.ps1` en solitario, ahora como función `Set-LocalGitGuard` dentro del fichero fusionado. Los dos modos que sí tocan GitHub (`-ClientName` o sin parámetros) siguen igual que antes, pero ahora, al terminar, si el repo resulta privado invocan automáticamente esa misma función sobre el clon actual — el usuario ya no tiene que acordarse de ejecutar un segundo script aparte en ese caso.

Se actualizaron todas las referencias vivas a los nombres antiguos (`README.md`, `control-versiones.md`, `arquitectura-repositorio.md`, los skills `local-git-guard`/`audit-history`, el hook `pre-commit-secrets-check.ps1`, los hooks nativos `tools/git-hooks/pre-commit*` y el comentario de `validate-pr.yml`) — las menciones históricas de renames anteriores (`setup-branch-protection.ps1` → `setup-github-repo.ps1`) se dejan intactas como narrativa, no se reescribe historia.

**Confirmado en dogfooding real** (sesión posterior, repo sandbox descartable fuera de este árbol de trabajo, sin `gh` instalado ni invocado en ningún momento): `pwsh -File tools/setup-github.ps1 -LocalGuardOnly -RepoRoot <ruta>` fijó `core.hooksPath` a `tools/git-hooks`, detectó correctamente `gitleaks` ausente y Tabular Editor 2 presente (vía `TabularEditor.exe` en el `PATH`), y avisó de que `.claude/project-config.json` no existía todavía — todo sin tocar la API de GitHub.

**Confirmado también el automatismo sobre GitHub real, en una sesión posterior** (ver la entrada de más arriba, "Bug real corregido..."): al probarlo contra un repo privado real (`gh repo create --template` + `gh api` con permisos de administrador), se encontró que ese automatismo nunca llegaba a ejecutarse por un bug real (excepción no capturada que abortaba el script antes de llegar ahí) — corregido, y reconfirmado en verde tras el fix.

## 2026-09-13 — Capa de gobernanza local para repo cliente privado (Free)

Se añade `tools/git-hooks/` (hooks nativos `pre-commit`/`pre-push`, activados por `tools/setup-local-git-guard.ps1` vía `git config core.hooksPath`) más el skill `local-git-guard` y el subagente `merge-audit`/skill `audit-history`, para mitigar localmente la ausencia de branch protection y secret scanning nativo en un repo cliente **privado** sobre GitHub Free (ya documentada como hallazgo real en la sección "Escaneo de secretos" de este mismo fichero de contexto, `control-versiones.md`). `.claude/project-config.json` gana el campo `visibilidad`, preguntado ahora en el paso 0 de `requirements-intake`.

A diferencia de los hooks de `.claude/settings.json` (que solo atan al agente de Claude Code), `tools/git-hooks/pre-commit` y `pre-push` son mecanismos de git puro: se disparan para cualquiera que use ese clon, agente o humano. `pre-commit` bloquea secretos (`gitleaks`) en todo commit, con fail-closed obligatorio en repos privados si `gitleaks` no está instalado. `pre-push` bloquea siempre el push directo a `main`/`dev`/`release/*` y, sobre cualquier otra rama, reutiliza tal cual los scripts de CI (`validate-pbir-schema.ps1`, `validate-docs-freshness.ps1`, `validate-bpa.ps1`) como comprobación previa al push.

Límite declarado explícitamente, no camuflado: ningún hook local puede impedir un merge hecho desde la UI web de GitHub con CI en rojo, ni una edición de fichero hecha directamente en el navegador — eso no pasa por ningún git local. Para ese hueco se añade `merge-audit` (detección a posteriori vía `gh api`/`gh pr checks` sobre el historial de merges, nunca prevención ni corrección automática).

**Motivo**: la recomendación de repo cliente privado se dejó en una sesión anterior (ver entrada de 2026-09-13 más abajo, "Documentación autónoma...") como sugerencia, no exigencia; al preguntarse qué limitaciones de seguridad implicaba, se confirmó que en GitHub Free un repo privado pierde branch protection y secret scanning nativo por completo (ya documentado), y se pidió una alternativa local combinando hooks/subagentes/skills de Claude Code.

**Confirmado en dogfooding real** (sesión posterior, repo git sandbox descartable con remoto local `bare`, `gitleaks` deliberadamente NO instalado en la máquina para probar el camino fail-closed): tras `core.hooksPath -> tools/git-hooks`, se confirmó en la práctica, con `git commit`/`git push` reales (no invocando los `.ps1` directamente):

- `pre-commit` deja pasar con aviso (`exit 0`) cuando `.claude/project-config.json` no existe o no tiene `visibilidad: "privado"`, y **bloquea** (`exit 1`) en cuanto el fichero en disco marca `visibilidad: "privado"` y `gitleaks` no está instalado — incluso en el propio commit que introduce ese fichero, porque el hook lee el `.claude/project-config.json` del árbol de trabajo en disco, no el contenido staged/committeado.
- `pre-push` bloquea siempre (`exit 1`), sin depender de ninguna herramienta, un push a `refs/heads/main` vía un remoto de prueba — confirmado también que el shim POSIX `#!/bin/sh` invoca correctamente `pre-push.ps1` y le reenvía el stdin con las refs (`git` pasa `<local ref> <local sha1> <remote ref> <remote sha1>` por línea).
- Sobre una rama `feature/*`: con el repo marcado público (sin `project-config.json`), reutiliza de verdad `tools/ci/validate-docs-freshness.ps1` sobre el rango a empujar — bloquea el push cuando el diff toca `.claude/` sin tocar `docs/CHANGELOG.md`/`docs/decisiones/`, y lo deja pasar en cuanto se añade la entrada correspondiente. `validate-bpa.ps1` respetó su propia guarda de `.claude/project-config.json` inexistente sin bloquear.

Sigue pendiente, porque el sandbox de esta prueba era deliberadamente descartable y sin `gh`: el escenario contra un repo cliente privado real conectado a GitHub (branch protection ausente de verdad, no simulada) y el subagente `merge-audit`/skill `audit-history` (requieren `gh api`/`gh pr checks` sobre historial de PRs reales) — ninguno de los dos se ha probado todavía.

## 2026-09-13 — Documentación autónoma Obsidian-friendly, en ambos modos

Se añade un modo "plantilla" a `docs-writer` (además del modo "cliente" ya existente): detecta si existe algún `*.SemanticModel` bajo `src/` para decidir si genera data dictionary/linaje/README de consumidor (cliente) o `docs/CHANGELOG.md`/`docs/decisiones/` (plantilla, este mismo fichero). Toda nota generada en cualquiera de los dos modos lleva ahora frontmatter YAML y wikilinks `[[nota]]`, para poder abrir `docs/` como vault de Obsidian sin instalar nada adicional — sin comprometer `.obsidian/` ni depender de funciones de pago (Sync/Publish), que quedan excluidas por `files/context/herramientas-documentacion.md`.

Se amplía el hook `.claude/hooks/post-commit-docs.ps1` para detectar también commits que tocan el mecanismo de la plantilla (`files/context/**`, `.claude/**`, `tools/**`, `CLAUDE.md`, `README.md`, `.github/workflows/**`), no solo modelo/informe. Se añade `tools/ci/validate-docs-freshness.ps1` y un nuevo job en `.github/workflows/validate-pr.yml` que falla el PR si el diff toca modelo/informe o mecanismo de plantilla sin tocar la documentación correspondiente — antes, la frescura de `docs/` dependía solo de que el agente atendiera el aviso interactivo del hook, sin ninguna verificación real en CI.

**Motivo**: la documentación autónoma existente (`docs-writer`, `docs-sync`) solo cubría el caso "repo cliente con modelo PBI"; no había ningún mecanismo para documentar cambios en el funcionamiento de la propia plantilla, que es justamente lo que este repo necesita documentar de sí mismo.

**Confirmado en dogfooding real** (esta misma sesión): el commit que introdujo este cambio tocaba `.claude/`, `tools/` y `files/context/` — el hook ampliado disparó correctamente el aviso de "modo plantilla" (`[post-commit-docs] El ultimo commit toca modo plantilla: anade una entrada a docs/CHANGELOG.md...`) en el turno siguiente al commit, igual que ya estaba confirmado para el modo cliente. Nótese que el hook no comprueba si `docs/CHANGELOG.md` ya se tocó en el mismo commit (a diferencia del job de CI) — sigue siendo un recordatorio incondicional, no una verificación de frescura; por eso disparó incluso en el commit que ya incluía esta misma entrada.

**Confirmado en CI real, no solo en local**: `tools/ci/validate-docs-freshness.ps1` se probó primero localmente contra dos ramas de prueba reales (falla con `exit 1` si el diff toca `.claude/` sin tocar `docs/`, pasa si los toca a la vez), y después el job `validate-docs-freshness` corrió y pasó de verdad en GitHub Actions dentro del PR #10 (`Agentic-PowerBI-Template`), junto con `validate` y `gitleaks`, también en verde — confirmado con `gh pr checks`, no solo con la ejecución local del script.

## 2026-09-12 — Bootstrap de repo cliente fusionado en un único script

`tools/setup-branch-protection.ps1` se renombra a `tools/setup-github-repo.ps1` y gana un modo de creación de repo (`-ClientName`, con `-Visibility Public|Private`): un solo comando cubre crear el repo cliente desde la plantilla, clonarlo, crear `dev`, proteger ambas ramas y activar secret scanning nativo si el repo es público. Verificado en pruebas reales con repos de prueba (`test-setup-github-repo-2026091*`): se corrigen dos bugs reales — `Test-BranchExists` daba falso positivo porque `gh api` escribe el cuerpo del error 404 en stdout (había que mirar `$LASTEXITCODE`, no el contenido), y se separa `gh repo create --clone` de un `git clone` explícito con reintento tras un fallo puntual por ruta de Windows demasiado larga (`MAX_PATH`).

**Motivo**: antes de este cambio, crear un repo cliente exigía `gh repo create` manual seguido de un script separado — dos pasos con superficie para el mismo tipo de error de propagación de plantilla que se quería evitar.

## 2026-09-11 — `dev` como rama de integración obligatoria + branch protection

Se introduce `dev` como rama de integración entre `feature/*`/`fix/*` y `main`, con ambas ramas protegidas y el job `source-branch-gate` en CI bloqueando cualquier PR contra `main` que no venga de `dev`/`release/*` (GitHub no tiene un mecanismo nativo para restringir la rama origen de una PR). Corrección el mismo día: un bug en el script de protección cambiaba también `default_branch` a `dev`, lo que habría roto "Use this template" (solo copia la rama por defecto) — corregido para que `main` siga siendo siempre la rama por defecto.

**Motivo**: sin `dev`, cada `feature/*` iba directo contra `main`, sin una rama de integración donde acumular cambios antes de promocionar a producción.

## 2026-08-27 — Conversión a GitHub Template Repository (árbol 1:1)

La plantilla pasa de "repo fuente para copiar a mano" a `GitHub Template Repository`: el árbol de `.claude/`, `.github/workflows/`, `tools/`, `files/context/` y `CLAUDE.md` queda ya en su sitio final desde el primer commit de cualquier repo creado con "Use this template", sin ningún paso manual de copiar/pegar entre repos. Se confirma en dogfooding real (PR #1 de esta plantilla) que la guarda de `tools/ci/validate-bpa.ps1` (comprobación de `.claude/project-config.json`) evita que el job de CI falle sobre la propia plantilla, que todavía no tiene ningún `*.SemanticModel`.

**Motivo**: un hallazgo real previo mostró que los hooks de `.claude/settings.json` están arraigados al directorio de proyecto con el que se abre la sesión de Claude Code (`CLAUDE_PROJECT_DIR`), no a la ruta del fichero editado — con dos repos abiertos a la vez (plantilla-origen + repo cliente), los hooks del repo cliente no se disparaban al editarlo desde la sesión arraigada en la plantilla. Distribuir como plantilla, en vez de como fuente para copiar, elimina ese escenario de raíz.
