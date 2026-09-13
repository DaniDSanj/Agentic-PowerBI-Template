---
tags: [plantilla, adr, tools]
date: 2026-09-13
---

# 0001 — Separar la instalación de toolchain (`install-tools.ps1`) de la configuración de repo (`setup-github.ps1`)

## Contexto

Al crear el repo sandbox de dogfooding (`Agentic-PowerBI-Sandbox`), `tools/setup-github.ps1` dejó como pendiente manual instalar `gitleaks` (solo lo detecta y avisa si falta — alcance ya deliberado, documentado en la cabecera del script). Surgió la duda de si esa instalación debería integrarse en el propio `setup-github.ps1` para tener un único punto de entrada de configuración de repo cliente.

## Decisión

No fusionar. Se crea `tools/install-tools.ps1`, un script aparte que instala/verifica vía `winget` `gitleaks`, Tabular Editor 2 y DAX Studio (Power BI Desktop y Python/`semantic-link-labs` quedan fuera, ver más abajo), con un parámetro `-Skip<Herramienta>` por cada una.

## Motivación

- **Ejes ortogonales, ciclos de vida distintos.** `setup-github.ps1` configura *un repo* (API de GitHub + `core.hooksPath` de ese clon) — se repite una vez por repo cliente. `install-tools.ps1` configura *la máquina* — una vez por equipo, sin importar cuántos repos cliente se trabajen después desde ahí. Fusionarlos acoplaría un paso idempotente-por-repo con uno idempotente-por-máquina.
- **Blast radius distinto.** Escribir en la API de GitHub o en `.git/config` es de bajo riesgo y reversible. Instalar binarios de terceros vía `winget` requiere permisos elevados y red, y automatizarlo dentro del script de "configurar este repo cliente" añadiría una superficie de "se instaló algo en tu máquina que no pediste explícitamente para este repo" — en tensión con el límite de no introducir herramientas sin autorización explícita (`files/context/limites-duros.md`).
- **El patrón ya existente lo confirma.** `setup-github.ps1` (función `Set-LocalGitGuard`) ya separaba detección (sí, en el script de repo: avisa si `gitleaks`/TE2 no están) de instalación (no, en el script de repo) — `install-tools.ps1` completa ese patrón en vez de romperlo.

## Alcance de `install-tools.ps1`

Cubre `gitleaks`, Tabular Editor 2 y DAX Studio — la toolchain base de Escenario A que los hooks/CI de esta plantilla asumen. Deliberadamente fuera:
- **Power BI Desktop**: se distribuye vía Microsoft Store o instalador propio de Microsoft, sin un paquete winget silencioso fiable para este flujo.
- **Python + `semantic-link-labs`**: solo aplica a Escenario B, no es parte de la toolchain base que cubre este script.

## Estado

Diseño, pendiente de su propio dogfooding real — los IDs de winget usados (`Gitleaks.Gitleaks`, `TabularEditor.TabularEditor.2`, `DaxStudio.DaxStudio`) no se han confirmado ejecutando el script en una máquina limpia. Ver `docs/CHANGELOG.md` (entrada del mismo día).
