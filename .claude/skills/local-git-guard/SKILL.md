---
name: local-git-guard
description: Instala/diagnostica la capa de gobernanza local de git (tools/git-hooks/) en el clon actual — sustituto parcial de branch protection y secret scanning nativo para un repo cliente privado en GitHub Free. Invócalo en el bootstrap (paso 0) cuando `.claude/project-config.json`.visibilidad sea "privado", o bajo demanda para comprobar si el guard ya está activo en este clon.
---

Este skill instala/diagnostica, en el clon actual, la mitigación local descrita en `files/context/control-versiones.md` ("Escenario privado (Free) — capa de gobernanza local"): git hooks nativos (`tools/git-hooks/pre-commit`, `tools/git-hooks/pre-push`) que atan a cualquiera que use ese clon, no solo al agente — a diferencia de `permissions.deny`/los hooks de `.claude/settings.json`.

## Cuándo invocarlo

- En el paso 0 de `requirements-intake`, si `.claude/project-config.json`.visibilidad es `"privado"` — es un paso de bootstrap obligatorio en ese escenario, no opcional.
- Bajo demanda, cuando el usuario pregunte si el guard local está activo en este clon, o tras clonar de nuevo el mismo repo en otra máquina (`core.hooksPath` es config local de cada `.git/config`, no viaja con el repo).

## Qué hacer

1. Comprueba `git config --get core.hooksPath` en la raíz del repo. Si ya apunta a `tools/git-hooks`, informa que el guard ya está activo y pasa directamente al paso 3.
2. Si no, ejecuta `pwsh -File tools/setup-github.ps1 -LocalGuardOnly` (o `powershell.exe` si `pwsh` no está disponible en esta máquina) y muestra su salida al usuario tal cual — incluye avisos sobre `gitleaks`/Tabular Editor 2 ausentes que no debes silenciar ni resumir de forma optimista. Este modo no toca la API de GitHub ni requiere permisos de administrador del repo: sirve igual para quien creó el repo que para un colaborador con acceso de solo escritura.
3. Confirma explícitamente al usuario, en una frase, qué queda cubierto por este guard (push directo a `main`/`dev`/`release/*` desde este clon, secretos en cada commit y push, comprobaciones tipo CI antes del push) y qué **no** queda cubierto bajo ninguna circunstancia: un merge hecho desde la UI web de GitHub con CI en rojo, o una edición de fichero hecha directamente en el navegador. No presentes esto como equivalente a branch protection real — es una mitigación con un hueco residual documentado, no un sustituto.
4. Si `gitleaks` no está instalado y `visibilidad` es `"privado"`, deja claro que **todo commit quedará bloqueado** hasta instalarlo (fail-closed deliberado, ver `tools/git-hooks/pre-commit.ps1`) — no es un bug, es el comportamiento esperado en ese escenario.

## Qué NO hacer

- No instales `gitleaks` ni Tabular Editor 2 por tu cuenta — son pasos manuales del usuario (`files/context/limites-duros.md`).
- No marques esta capa como sustituto del modo por defecto de `tools/setup-github.ps1` (sin `-LocalGuardOnly`) — ambas son complementarias, no alternativas: una protege GitHub del lado de plataforma cuando puede (requiere permisos de administrador), la otra protege el clon local cuando la primera no puede o no está al alcance de quien la ejecuta.
