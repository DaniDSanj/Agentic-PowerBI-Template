---
name: medidas-dax
description: Elabora medidas/KPIs en DAX, calculation groups, scripts C# de Tabular Editor 2 (CS-Script), o DAX UDFs en functions.tmdl. Invócalo al añadir o modificar cualquier medida o función DAX. Punto de entrada único para DAX; este skill decide cuándo leer el upstream.
---

Lee `files/context/medidas-dax.md` antes de escribir el script/medida si no lo has hecho ya en esta sesión.

## Upstream (delegación del "cómo")

Entra siempre por este skill; **no invoques `semantic-model-authoring` directamente**. Lee de forma dirigida:

- Siempre al escribir o revisar DAX: [dax-guidelines.md](../semantic-model-authoring/references/dax-guidelines.md) (incluye refactor con UDFs).
- Medidas lentas (requiere cliente con trazas, p. ej. el MCP): [dax-perf-decision-guide.md](../semantic-model-authoring/references/dax-perf-decision-guide.md) primero; [dax-perf-patterns.md](../semantic-model-authoring/references/dax-perf-patterns.md) solo para los patrones candidatos.
- Field parameters: [field-parameters.md](../semantic-model-authoring/references/field-parameters.md) (parte del modelo; el slicer y el visual son de `visuales-pbir`).
- Para el modelo en sí (tablas, relaciones, naming): `modelo-tmdl`.

## Qué hacer

1. Define cada medida con `DisplayFolder` y `FormatString` explícitos; la definición exacta y granularidad debe venir de `requirements-intake`, no inventada ad-hoc.
2. **CS-Script de TE2**: el motor por defecto NO soporta string interpolation ni local functions — usa concatenación con `+`. Si necesitas C# moderno, comprueba primero si Roslyn está activo (File > Preferences > General, TE2 2.12.2+); no lo asumas activo por defecto.
3. **DAX UDFs**: solo si el `compatibilityLevel` del modelo es 1702+ y el destino no es Azure Analysis Services / SQL Server Analysis Services (no soportado ahí). Documenta con `///`, `@param`, `@returns` en `functions.tmdl`.
4. Antes de escribir una medida desde cero, comprueba si ya existe una equivalente reutilizable (mismo patrón de time intelligence, mismo calculation group) en el propio modelo o en otro proyecto de la plantilla.

## Reglas de arbitraje (mandan sobre el upstream)

- **TMDL en disco + hook BPA manda sobre el MCP** (regla 1 de `modelo-tmdl`): escribe las medidas en los `.tmdl`, no con las operaciones de escritura del MCP. El MCP vale para **ejecutar DAX** (`EVALUATE { [Medida] }`), inspeccionar y trazar rendimiento. Si escribes vía MCP, el hook no se dispara: `bpa-validate` a mano y decláralo.
- **Credenciales/gateway/`bindConnection` fuera del alcance del agente**; un fallo de credenciales en un refresco para y avisa, sin reintentos.
- **Escenario A/B**: en A no hay XMLA; las pruebas DAX se hacen contra Desktop o tras publish. No propongas XMLA write ni Direct Lake en A.
- El estilo DAX upstream (p. ej. variables, medidas base) complementa pero no sustituye a las reglas BPA de `tools/BPARules.json`; ante contradicción, gana BPA.

## Seguridad: EULA del MCP

`powerbi-modeling-mcp` expone `accept_eula`. **El agente NUNCA acepta un EULA en nombre del usuario**: si al ejecutar DAX o conectar el MCP exige aceptarlo, para y pídeselo al usuario.

## Validación (obligatoria antes de cerrar)

Igual que `modelo-tmdl`: el hook `post-edit-tmdl` bloquea en Error tras cada edición; invoca `bpa-validate` antes de dar la fase por cerrada. Si el escenario es B, considera además una prueba DAX vía XMLA (`semantic-link-labs.evaluate_dax`) en `tools/tests/` antes de commit; en A, valida tras publish o en Desktop (no hay XMLA en shared capacity). Lo que dependa de ejecutar DAX en Desktop y no se haya ejecutado se declara **pendiente manual**, no verificado.
