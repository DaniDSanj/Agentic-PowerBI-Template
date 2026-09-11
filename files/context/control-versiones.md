# Control de versiones autónomo

## Modelo de ramas: `dev` como integración obligatoria, `main` protegida

- **`main` nunca recibe una PR directa de `feature/`/`fix/`**: está protegida (branch protection vía `tools/setup-branch-protection.ps1`) y solo acepta una PR cuya rama origen sea `dev` o `release/*` — lo hace cumplir el job de CI `source-branch-gate` (`.github/workflows/validate-pr.yml`), marcado como required status check, porque GitHub no tiene un mecanismo nativo de branch protection para restringir la rama origen de una PR.
- **`dev` es la rama de integración**: todo `feature/<nombre>`/`fix/<nombre>` nace de `dev` (no de `main`), y su PR de cierre va contra `dev`. `dev` también está protegida (PR obligatoria + CI en verde vía los checks `validate`/`gitleaks`) — sin push directo, ni siquiera del agente (`permissions.deny` en `.claude/settings.json` lo bloquea técnicamente).
- **Promoción `dev → main`**: es un paso humano y explícito, separado del cierre de cada unidad de trabajo — se abre cuando `dev` acumula cambios listos para publicar (no en cada commit). El agente puede abrir esa PR, pero **nunca la mergea** (igual regla que cualquier otra PR, ver más abajo).
- Commits semánticos; PR con revisión explícita del diff TMDL antes de mergear; haz `pull` antes de `push`; nunca cambies de rama con el PBIX abierto en Desktop.
- **Azure Repos/Azure Pipelines** es la alternativa equivalente cuando el repo externo ya use Azure DevOps: mismo flujo de branching y commits (con `dev` cumpliendo el mismo papel de rama de integración), con Deployment Pipelines sustituyendo a GitHub Actions en Escenario B.
- Mantén el control de versiones de forma autónoma (commitear, abrir PRs contra `dev`) salvo objeción explícita del usuario para ese repo concreto.

## Escaneo de secretos (tres capas)

- **GitHub secret scanning + push protection nativos** (`security_and_analysis` del repo, habilitados vía `gh api`): gratis porque el repo es **público** — bloquean el propio `git push` si el patrón de un proveedor conocido se detecta, antes de que el commit llegue al remoto.
- **CI (`gitleaks`, bloqueante)**: el job `gitleaks` de `.github/workflows/validate-pr.yml` escanea el diff completo de cada PR y es required status check en `main`/`dev` — cubre patrones no cubiertos por el escáner nativo de GitHub y actúa como red de seguridad independiente.
- **Local (`gitleaks`, best-effort)**: el hook `PreToolUse` `.claude/hooks/pre-commit-secrets-check.ps1` corre `gitleaks` sobre el staged antes de cada `git commit` si el binario está instalado en la máquina; si no lo está, avisa y deja pasar sin bloquear — la capa autoritativa sigue siendo CI/push protection, nunca se reporta una verificación local que no se hizo.

**Hallazgo real de esta sesión, no una elección de diseño**: se intentó mantener el repo privado y usar solo `gitleaks` como alternativa gratuita a GitHub Advanced Security. Al ejecutar `tools/setup-branch-protection.ps1` contra el repo privado, la API de branch protection (clásica y rulesets) devolvió `403 Upgrade to GitHub Pro or make this repository public` — **branch protection en sí, no solo el secret scanning nativo, requiere GitHub Pro o visibilidad pública en un repo con plan Free**. Confirmado con `gh api .../branches/main/protection` (GET) tras el intento fallido. El usuario decidió hacer público el repo (plantilla sin datos de cliente ni credenciales) en vez de pagar GitHub Pro; `gh repo edit --visibility public` lo aplicó y desde entonces la branch protection y el secret scanning nativo funcionan de verdad (verificado con GET, no solo con el exit code del script).

## Reaplicar esto en un repo cliente

Un repo creado con "Use this template" **no hereda** la branch protection de la plantilla — GitHub solo copia ficheros y ramas, no configuración del repo. Ejecuta `tools/setup-branch-protection.ps1` una vez, justo después del primer push del repo cliente, para crear/proteger `dev` y `main` ahí también.
