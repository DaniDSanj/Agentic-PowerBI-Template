# Origen de los skills vendorizados

Ficheros copiados **sin editar** desde `microsoft/skills-for-fabric`. No los modifiques aquí: los envoltorios de la plantilla delegan en ellos y la copia debe poder actualizarse por diff limpio.

| Campo | Valor |
|---|---|
| Repositorio | https://github.com/microsoft/skills-for-fabric |
| Versión / tag | `v0.3.18` |
| Commit | `6c11ad58c25992e5d1435ce7cd80d217d5598a31` |
| Licencia | MIT (`LICENSE-skills-for-fabric`, copia del `LICENSE` upstream) |
| Fecha de vendorizado | 2026-10-04 |
| Fuente | `plugins/powerbi-authoring/` (no la copia de la raíz `skills/`) |

## Mapeo

| Upstream | Aquí |
|---|---|
| `plugins/powerbi-authoring/skills/powerbi-report-cli/` | `.claude/skills/powerbi-report-cli/` |
| `plugins/powerbi-authoring/skills/semantic-model-authoring/` | `.claude/skills/semantic-model-authoring/` |
| `plugins/powerbi-authoring/common/` | `.claude/common/` |

Excluidos: `apm.yml`, `.claude-plugin/`, `.github/`, `.mcp.json` del plugin. Los enlaces upstream (`../../common/`, `../../../common/`) resuelven sin cambios con este mapeo; compruébalo con `tools/ci/check-skill-links.ps1`.

## Procedimiento manual de actualización

1. Clona/actualiza upstream y haz checkout del tag nuevo; anota tag y commit.
2. En una rama `feature/`, compara cada carpeta del mapeo con `diff -r` (o `git diff --no-index`) contra la copia actual y revisa los cambios.
3. Copia sobre `.claude/` (sin `apm.yml`), actualiza esta tabla (versión, commit, fecha) y `LICENSE-skills-for-fabric` si cambió.
4. Ejecuta `pwsh tools/ci/check-skill-links.ps1`; revisa también que los nombres de skill no choquen con los de la plantilla.
5. Añade entrada a `docs/CHANGELOG.md`, abre PR contra `dev` y revisa el diff antes de mergear (merge siempre humano).
