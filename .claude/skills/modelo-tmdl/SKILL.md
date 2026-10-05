---
name: modelo-tmdl
description: Diseña o modifica el modelo de datos en TMDL — relaciones, esquema estrella, RLS, calculation groups. Invócalo al trabajar sobre model.tmdl, relationships.tmdl, roles/ o tablas de calculation group. Punto de entrada único para el modelo semántico; este skill decide cuándo leer el upstream.
---

Lee `files/context/modelo-tmdl.md` antes de editar si no lo has hecho ya en esta sesión.

## Upstream (delegación del "cómo")

Entra siempre por este skill; **no invoques `semantic-model-authoring` directamente**. Léelo de forma dirigida (no cargues todo `references/`):

- Siempre antes de crear/editar modelo: [modeling-guidelines.md](../semantic-model-authoring/references/modeling-guidelines.md).
- Al editar TMDL: [tmdl-guidelines.md](../semantic-model-authoring/references/tmdl-guidelines.md); estructura de carpetas: [pbip.md](../semantic-model-authoring/references/pbip.md).
- Al nombrar/renombrar: [naming-conventions.md](../semantic-model-authoring/references/naming-conventions.md).
- Descubrir metadatos con INFO.VIEW: [metadata-discovery.md](../semantic-model-authoring/references/metadata-discovery.md).
- Solo en Escenario B y si el modelo es Direct Lake: [direct-lake-guidelines.md](../semantic-model-authoring/references/direct-lake-guidelines.md).

Del workflow upstream usa "Create new" / "Modify an Existing Model" / "Discover Metadata"; **ignora** sus workflows *Deploy*, *Refresh (publicado)*, *Manage* y *Connection Binding* (ver arbitraje).

## Qué hacer

1. Esquema estrella como convención por defecto. Role-playing dimensions vía relaciones inactivas + `USERELATIONSHIP` en la medida — nunca duplicando tablas de dimensión.
2. Fija siempre `discourageImplicitMeasures: true` y un `compatibilityLevel` explícito en `database.tmdl` si no están ya fijados.
3. RLS vía roles + expresión de filtro (o UDF reutilizable, ver `medidas-dax` para `functions.tmdl`); OLS si los requisitos lo pidieron en `requirements-intake`.
4. Antes de construir una tabla/relación desde cero, comprueba si ya existe algo equivalente y validado en otro modelo del repo (u otro proyecto derivado de esta plantilla) que puedas reutilizar copiando el `.tmdl` y reconfigurando `relationships.tmdl`.

## Reglas de arbitraje (mandan sobre el upstream)

1. **Quién edita el modelo: TMDL en disco + hook BPA manda.** El upstream prefiere el MCP y declara anti-patrón leer o editar `*.tmdl` con el MCP conectado. **Aquí se invierte**: edita los `.tmdl` del repo (así se dispara `post-edit-tmdl`). El MCP `powerbi-modeling-mcp` se usa para **leer/inspeccionar, ejecutar DAX y refrescar** contra un modelo abierto. Si alguna vez escribes vía MCP, el hook **no se dispara**: ejecuta `bpa-validate` a mano, serializa a TMDL en disco y **decláralo**.
2. **Credenciales y publicación fuera del alcance del agente** (`limites-duros.md`): `bindConnection`, `connection-binding.md`, *Manage* (data sources/permisos) y *Deploy* vía `az rest` no se ejecutan; documenta el paso manual. `deploy` es solo del usuario. Un error de credenciales en refresco: **para y avisa**, sin reintentar.
3. **RLS/OLS: sin membresías.** Solo defines roles y filtros; añadir/quitar usuarios o grupos a un rol es del portal (el propio upstream lo trata como `DENY`).
4. **Escenario A/B** (`.claude/project-config.json`): en A no propongas Direct Lake, XMLA write ni `bindConnection`; los endpoints de Fabric de este skill se tratan como *no probados* en A. Modelo >1 GB no es viable en Pro puro.
5. **Cabecera `x-ms-fabric-skill`**: solo si llegas a llamar a `api.fabric.microsoft.com` (atribución); no la propagues al resto de la plantilla.
6. **Tipos**: no uses `Double` (BPA `META_AVOID_FLOAT`); si una guía upstream contradice `tools/BPARules.json`, manda BPA.

## Seguridad: EULA del MCP

`powerbi-modeling-mcp` expone una herramienta `accept_eula`. **El agente NUNCA acepta un EULA en nombre del usuario**: si el MCP lo exige, para, enseña lo que pide aceptar y pide al usuario que lo acepte él.

## Validación (obligatoria antes de cerrar)

1. El hook `post-edit-tmdl` corre BPA tras cada edición y bloquea en violaciones de severidad Error — atiéndelas en el momento, no las acumules.
2. Antes de dar la unidad de trabajo del modelo por cerrada (previa a commit), invoca explícitamente el skill `bpa-validate` para el informe completo del subagente `bpa-reviewer`, incluidas violaciones Warning/Info que el hook no bloquea.
3. Solo entonces sigue a `medidas-dax` o a commit, según `files/context/flujo-trabajo.md`.
