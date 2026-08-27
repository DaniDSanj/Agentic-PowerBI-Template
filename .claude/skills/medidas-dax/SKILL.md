---
name: medidas-dax
description: Elabora medidas/KPIs en DAX, calculation groups, scripts C# de Tabular Editor 2 (CS-Script), o DAX UDFs en functions.tmdl. Invócalo al añadir o modificar cualquier medida o función DAX.
---

Lee `files/context/medidas-dax.md` antes de escribir el script/medida si no lo has hecho ya en esta sesión.

## Qué hacer

1. Define cada medida con `DisplayFolder` y `FormatString` explícitos; la definición exacta y granularidad debe venir de `requirements-intake`, no inventada ad-hoc.
2. **CS-Script de TE2**: el motor por defecto NO soporta string interpolation ni local functions — usa concatenación con `+`. Si necesitas C# moderno, comprueba primero si Roslyn está activo (File > Preferences > General, TE2 2.12.2+); no lo asumas activo por defecto.
3. **DAX UDFs**: solo si el `compatibilityLevel` del modelo es 1702+ y el destino no es Azure Analysis Services / SQL Server Analysis Services (no soportado ahí). Documenta con `///`, `@param`, `@returns` en `functions.tmdl`.
4. Antes de escribir una medida desde cero, comprueba si ya existe una equivalente reutilizable (mismo patrón de time intelligence, mismo calculation group) en el propio modelo o en otro proyecto de la plantilla.

## Validación (obligatoria antes de cerrar)

Igual que `modelo-tmdl`: el hook `post-edit-tmdl` bloquea en Error tras cada edición; invoca `bpa-validate` antes de dar la fase por cerrada. Si el escenario es B, considera además una prueba DAX vía XMLA (`semantic-link-labs.evaluate_dax`) en `tools/tests/` antes de commit; en A, valida tras publish o en Desktop (no hay XMLA en shared capacity).
