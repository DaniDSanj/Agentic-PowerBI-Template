---
name: modelo-tmdl
description: Diseña o modifica el modelo de datos en TMDL — relaciones, esquema estrella, RLS, calculation groups. Invócalo al trabajar sobre model.tmdl, relationships.tmdl, roles/ o tablas de calculation group.
---

Lee `files/context/modelo-tmdl.md` antes de editar si no lo has hecho ya en esta sesión.

## Qué hacer

1. Esquema estrella como convención por defecto. Role-playing dimensions vía relaciones inactivas + `USERELATIONSHIP` en la medida — nunca duplicando tablas de dimensión.
2. Fija siempre `discourageImplicitMeasures: true` y un `compatibilityLevel` explícito en `database.tmdl` si no están ya fijados.
3. RLS vía roles + expresión de filtro (o UDF reutilizable, ver `medidas-dax` para `functions.tmdl`); OLS si los requisitos lo pidieron en `requirements-intake`.
4. Antes de construir una tabla/relación desde cero, comprueba si ya existe algo equivalente y validado en otro modelo del repo (u otro proyecto derivado de esta plantilla) que puedas reutilizar copiando el `.tmdl` y reconfigurando `relationships.tmdl`.

## Validación (obligatoria antes de cerrar)

1. El hook `post-edit-tmdl` corre BPA tras cada edición y bloquea en violaciones de severidad Error — atiéndelas en el momento, no las acumules.
2. Antes de dar la unidad de trabajo del modelo por cerrada (previa a commit), invoca explícitamente el skill `bpa-validate` para el informe completo del subagente `bpa-reviewer`, incluidas violaciones Warning/Info que el hook no bloquea.
3. Solo entonces sigue a `medidas-dax` o a commit, según `files/context/flujo-trabajo.md`.
