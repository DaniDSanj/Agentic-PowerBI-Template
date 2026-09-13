# Herramientas permitidas y prohibidas

**Permitidas (gratuitas/open source, usar por defecto)**: Tabular Editor 2 (MIT), DAX Studio, ALM Toolkit, extensión TMDL oficial de VS Code, reglas BPA comunitarias, Deneb, pbiviz/powerbi-visuals-tools, FabricPS-PBIP y fabric-cicd (sin soporte oficial de Microsoft, valida en cada release), Microsoft Learn MCP.

**Evitar/prohibidas salvo autorización expresa del usuario**: Tabular Editor 3, DAX Optimizer, y cualquier herramienta o tier de pago. Ante una necesidad que solo resuelva una herramienta de pago, dilo explícitamente y pide autorización antes de asumir su uso — no la introduzcas por defecto.

# Documentación autónoma

- Mantén un data dictionary y linaje generado desde TMDL/DMVs (`INFO.VIEW.*`, `INFO.USERDEFINEDFUNCTIONS()`) y las dependencias de medidas, vía script de Tabular Editor 2 o notebook sempy.
- Mantén en `docs/` un README de consumidor (definiciones de KPI, cómo usar el informe) y ADRs para decisiones de arquitectura relevantes.
- En un repo sin modelo PBI todavía (como esta propia plantilla), la documentación autónoma equivalente es `docs/CHANGELOG.md` (cambios al mecanismo: skills, hooks, agentes, CI, convenciones) y `docs/decisiones/` (ADRs sobre el mecanismo) — ver el detalle de ambos modos en `.claude/agents/docs-writer.md`.
- Regenera esta documentación en cada cambio relevante del modelo/informe (o del mecanismo de la plantilla) — vía el hook `post-commit-docs` y el skill `docs-sync`, y desde 2026-09 con una comprobación adicional en CI (`tools/ci/validate-docs-freshness.ps1`) que falla el PR si el diff toca modelo/informe/mecanismo sin tocar la documentación correspondiente.

## Convención Obsidian-friendly

`docs/` está pensada para poder abrirse como vault de [Obsidian](https://obsidian.md/) sin instalar nada adicional — es simplemente Markdown con dos convenciones:

- **Frontmatter YAML** mínimo al principio de cada nota generada: `tags` y `date` (y `aliases` cuando aplique).
- **Wikilinks** `[[nota]]` / `[[nota#sección]]` entre notas relacionadas del propio vault (p. ej. una medida en `data-dictionary.md` enlaza a su entrada en `linaje-medidas.md`; una entrada de `CHANGELOG.md` enlaza al ADR/decisión correspondiente).

Explícitamente **no** se commitea una carpeta `.obsidian/` (configuración de vault, plugins) ni se depende de Obsidian Sync/Publish — son de pago y quedan cubiertos por la regla de "evitar herramientas de pago sin autorización expresa" de este mismo fichero. Si alguien abre `docs/` como vault local, `.obsidian/` se genera en su máquina y debe quedar ignorada por git (ver `.gitignore` en `files/context/arquitectura-repositorio.md`).

**Nota de ubicación y fugas de información**: `docs/` se versiona en git junto al resto del repo (no en una carpeta externa ni en gitignore) — es la única opción de las evaluadas que cumple a la vez "constancia de cambios" y "control humano vía PR" sin sacrificarlos por privacidad. La contrapartida, no resuelta técnicamente por esta plantilla: en un repo cliente, cualquier dato de negocio que entre en `docs/` queda en el historial de git de forma permanente (incluso si el fichero se borra después). Se recomienda que el repo cliente sea privado, pero esto no se fuerza ni se comprueba de forma automática — es una decisión a tomar explícitamente con cada cliente, no un supuesto.
