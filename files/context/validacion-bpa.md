# Validación DAX/modelo

- **BPA obligatorio en cada cambio de modelo**, vía Tabular Editor 2 CLI. Contra un proyecto TMDL (PBIP), apunta a la subcarpeta `definition` de `*.SemanticModel` (donde vive `model.tmdl`), no a `Model.bim` ni a la carpeta `*.SemanticModel` en sí:
  ```
  TabularEditor.exe "<Proyecto>.SemanticModel\definition" -A "tools\BPARules.json" -V
  ```
  Verificado en dogfooding real (Tabular Editor 2.28.0): esta es la única forma que carga el modelo sin error. Requiere **TE2 >= 2.20.0** (sep-2023) — versiones anteriores usan la extensión `.tmd` y no reconocen los `.tmdl` que genera Power BI Desktop actual. Las reglas de `tools/BPARules.json` provienen de `TabularEditor/BestPracticeRules` — concretamente `BPARules-PowerBI.json` renombrado, ver `pbip-scaffold/SKILL.md`. El flag `-V` (VSTS logging) etiqueta cada violación como `##vso[task.logissue type=error;]...` (severidad Error) o `type=warning;...` (severidad Warning) — es lo que el hook `post-edit-tmdl` usa para decidir si bloquea. No des una medida o relación por terminada sin pasar BPA.
- **`TABULAR_EDITOR_PATH`**: si `TabularEditor.exe` no está en el PATH, no dependas de fijar esta variable a nivel de sistema operativo (`setx`) — verificado que una sesión de Claude Code ya abierta no la hereda, y ni siquiera una sesión nueva la recoge de forma fiable en todos los casos. Defínela en el campo `"env"` de nivel raíz de `.claude/settings.json` (funciona incluso en caliente, sin reiniciar sesión):
  ```json
  { "env": { "TABULAR_EDITOR_PATH": "C:\\ruta\\a\\TabularEditor.exe" } }
  ```
- Pruebas de medidas sin Desktop: en Escenario B, vía XMLA (`semantic-link-labs.evaluate_dax`) con aserciones estilo pytest; en Escenario A no hay XMLA, así que valida tras publish (Fabric REST) o en Desktop, y usa DMVs/`INFO.VIEW` para introspección.
