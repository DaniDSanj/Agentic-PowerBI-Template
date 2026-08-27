# Transformaciones Power Query (M)

- Edita M embebido en TMDL usando la extensión oficial TMDL para VS Code (GA): autocompletado, diagnósticos de sintaxis, resaltado y formato. La extensión comunitaria "Power Query Lint" añade análisis estático adicional, pero ambas son **solo estáticas**: no ejecutan ni previsualizan.
- **Requieren Power BI Desktop de forma obligatoria** (no automatizables desde aquí): ejecutar o previsualizar queries, refrescar metadatos de columnas de M, verificar query folding (View Native Query, Query Folding Indicators, Query Diagnostics, plegado paso a paso), ver funciones/expresiones no cargadas. Cuando una tarea dependa de esto, indícalo explícitamente como paso manual pendiente en Desktop — no lo des por hecho.
- Patrones recomendados: staging queries con `Enable Load` desactivado, parámetros `RangeStart`/`RangeEnd` para incremental refresh, funciones M reutilizables centralizadas en `expressions.tmdl`, manejo de errores con `try...otherwise`.
