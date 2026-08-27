---
name: transformaciones-m
description: Escribe o revisa transformaciones Power Query (M) embebidas en TMDL. Invócalo al editar el cuerpo M de una partición o una función reutilizable en expressions.tmdl.
---

Lee `files/context/transformaciones-m.md` antes de editar. Edita el M usando los patrones de la extensión oficial TMDL de VS Code (autocompletado/diagnóstico estático).

## Qué hacer

1. Aplica los patrones recomendados: staging queries con `Enable Load` desactivado, parámetros `RangeStart`/`RangeEnd` para incremental refresh, funciones M reutilizables centralizadas en `expressions.tmdl`, `try...otherwise` para manejo de errores.
2. **Límite duro de esta fase**: ejecutar/previsualizar queries, refrescar metadatos de columnas, y verificar query folding (View Native Query, Query Folding Indicators, Query Diagnostics) **requieren Power BI Desktop y no son automatizables desde aquí**. Cuando la tarea dependa de uno de estos pasos, decláralo explícitamente como pendiente manual en Desktop en el mismo mensaje donde reportas el cambio — nunca digas "verificado" sobre algo que no has podido comprobar sin Desktop.
3. Tras editar, el hook `post-edit-tmdl` valida BPA automáticamente sobre el `.tmdl` resultante.

## Cierre

No cierres esta fase afirmando que el query folding o el refresco de metadatos están confirmados si no se ha abierto Desktop en esta sesión.
