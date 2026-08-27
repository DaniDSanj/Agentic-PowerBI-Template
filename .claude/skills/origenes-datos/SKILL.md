---
name: origenes-datos
description: Añade o modifica orígenes de datos (Excel/CSV/JSON, SQL Server/PostgreSQL, modelos semánticos del servicio) y revisa schema drift. Invócalo al trabajar sobre expressions.tmdl o las particiones de tabla que definen el Source M.
---

Lee `files/context/origenes-datos.md` antes de tocar ninguna partición o `expressions.tmdl` si no lo has hecho ya en esta sesión.

## Qué hacer

1. Identifica el tipo de origen (fichero individual, SQL, modelo semántico del servicio) y aplica el patrón correspondiente del fichero de contexto: parámetros en `expressions.tmdl` para rutas/servidores, `IsParameterQuery=true` cuando aplique.
2. **Regla dura, sin excepción**: nunca escribas credenciales, cadenas de conexión con secretos, ni configuración de gateway en ningún fichero versionado. Eso se configura en el servicio o vía Service Principal con secretos en Key Vault/GitHub Secrets — jamás en TMDL.
3. Si el cambio introduce o modifica columnas, revisa schema drift:
   - Escenario A: script Tabular Editor 2 (`Model.Tables["X"].RefreshDataColumns()`), diff de Git posterior.
   - Escenario B: notebook `sempy`/`semantic-link-labs` (`evaluate_dax`, `list_columns`) comparando esquema origen vs modelo.
4. Tras cualquier edición de `.tmdl`, el hook `post-edit-tmdl` corre BPA automáticamente — no lo dupliques manualmente salvo que quieras el informe completo del subagente `bpa-reviewer` (skill `bpa-validate`).

## Cierre

Si el cambio requiere refrescar metadatos M desde el origen real, decláralo explícitamente como paso manual pendiente en Desktop (`files/context/transformaciones-m.md`) — no lo des por hecho ni lo simules.
