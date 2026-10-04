---
tags: [investigacion, fabric, skills, plantilla]
date: 2026-10-04
relacionado: [[escenario-licencia]], [[herramientas-documentacion]]
---

# Análisis de `microsoft/skills-for-fabric` e integración en la plantilla

## Contexto

Estudio del repo `Fabric\skills-for-fabric` (v0.3.18, 2026-09-24, MIT, Microsoft) para decidir qué aprovechar en `Agentic-PowerBI-Template`, una plantilla de informes Power BI locales (PBIP/TMDL/PBIR) mantenidos con Claude Code. La plantilla tiene dos escenarios de licencia: **A** (Pro puro, capacidad compartida) y **B** (PPU/Premium/Fabric). Todo el dogfooding real es del escenario A. Hoy el escenario B está sin probar.

Fuentes: lectura de los `SKILL.md`, de las referencias, de `agents/`, `common/`, `mcp-setup/`, `plugins/` y del `CLAUDE.md`, `.claude/` y `files/context/` de la plantilla. Lo que el repo no afirma y yo deduzco está marcado como *(inferencia)*.

## 1. Qué es el repositorio y qué casos de uso cubre

### Qué es
No es código ejecutable. Es una **biblioteca de instrucciones para agentes de IA** (Claude Code, GitHub Copilot CLI, Cursor, Codex…) que enseña al agente a operar Microsoft Fabric de forma correcta y segura. Cada "skill" es una carpeta con un `SKILL.md` (el punto de entrada) y ficheros `references/` (procedimientos detallados). El agente lee el skill y luego ejecuta él mismo `az rest`, `sqlcmd`, la API REST de Fabric, o herramientas MCP.

Arquitectura en tres capas, **Agents → Skills → Common**:

| Capa | Qué contiene | Ejemplo |
|---|---|---|
| **Agents** (5) | Personas que orquestan varios skills | `FabricDataEngineer`, `FabricAdmin`, `FabricAppDev`, `FabricIQ`, `FabricMigrationEngineer` |
| **Skills** (25) | Un skill por workload/item de Fabric | `sqldw-cli`, `spark-cli`, `powerbi-report-cli` |
| **Common** | Conocimiento REST compartido: audiencias de token, operaciones largas (LRO), throttling, paginación, formato de definiciones de items | `COMMON-CORE.md`, `COMMON-CLI.md`, `ITEM-DEFINITIONS-CORE.md` |

### Conceptos de Fabric imprescindibles para un analista de Power BI
- **Capacidad (capacity):** el "motor de cómputo" que se compra (SKU F2…F8192). Casi todo lo que hacen estos skills exige un workspace asignado a una capacidad.
- **Workspace e item:** igual que en Power BI. En Fabric, además de informes y modelos, un item puede ser Lakehouse, Warehouse, Notebook, Pipeline, Dataflow Gen2, Eventstream, etc.
- **OneLake:** el "OneDrive de los datos" del tenant. Todo se guarda como Delta/Parquet.
- **Lakehouse:** carpetas de ficheros + tablas Delta, con un *SQL analytics endpoint* de solo lectura en T-SQL.
- **Warehouse:** almacén T-SQL con escritura (DDL/DML).
- **Direct Lake:** modo de almacenamiento de un modelo semántico que lee los Delta de OneLake sin importar copia (rendimiento tipo Import, frescura tipo DirectQuery). Es **solo Fabric**.
- **Medallion (Bronze/Silver/Gold):** capas de calidad de datos: crudo → limpio → listo para análisis.
- **Item definition API:** Fabric representa cada item como un conjunto de ficheros (p. ej. un informe PBIR o un modelo TMDL). Se leen con `getDefinition` y se escriben con `updateDefinition`. Es lo que permite que un agente edite informes con ficheros.
- **MCP (Model Context Protocol):** servidores que dan al agente herramientas "vivas" (consultar un modelo DAX, ejecutar T-SQL, editar un modelo abierto).

### Casos de uso que cubre
1. **Construir una plataforma de datos de extremo a extremo:** ingesta → medallion → modelo semántico → informe (`prompt_examples/NYCTaxi_MedallionArchitecture.txt`).
2. **Crear y editar informes y modelos semánticos con IA** (PBIR/PBIP, TMDL, DAX, temas, accesibilidad).
3. **Preguntar a los datos en lenguaje natural** sobre informes ya publicados (FabricIQ + `ExecuteQuery` DAX).
4. **ALM / CI-CD:** Git de workspace, Deployment Pipelines dev→test→prod, parametrización por entorno con Variable Library.
5. **Tiempo real:** Eventstream → Eventhouse (KQL) → alertas con Activator.
6. **Operación y diagnóstico:** rendimiento de warehouse, SQL database y Spark; documentación automática de un workspace.
7. **Gobierno:** inventario de items, dominios, etiquetas de sensibilidad, auditorías.
8. **Migración** desde Synapse, HDInsight, Databricks y Data Factory; **estimación de coste** de capacidad.
9. **Ontologías (Fabric IQ, preview):** capa semántica de negocio para agentes.

### Madurez (importante antes de depender de ello)
- Pre-1.0, releases casi semanales. 0.3.17 fusionó cuatro skills de informe en `powerbi-report-cli` y movió el endpoint de FabricIQ. Hay riesgo de cambios incompatibles.
- Varias piezas son preview: MLV (Materialized Lake Views), Event Schema Sets, Ontology, Mirrored Catalogs, y el CLI `powerbi-report-author` (versiones `0.3.0-beta`).
- El repo no declara requisitos de licencia Pro/PPU por skill. Todos los skills de Fabric asumen capacidad.
- No hay CI que valide los `SKILL.md` ni están en el checkout los scripts de build (`build/`); los `plugins/*` son copias físicas de `skills/` y `common/`.
- Inconsistencia: el bundle `fabric-skills` incluye 4 agentes (falta `FabricMigrationEngineer`), mientras APM despliega los 5.

## 2. Skills agrupados por fase del proceso

| Fase | Skills |
|---|---|
| **0. Descubrimiento y planificación** | `search-consumption-cli`, `e2e-fabric-cost-estimation`, `e2e-medallion-architecture` (diseño) |
| **1. Ingesta** | `dataflows-cli`, `eventstream-cli`, `eventschemaset-cli`, `project-osmos` |
| **2. Transformación** | `spark-cli`, `dataflows-cli`, `e2e-medallion-architecture`, `project-osmos` |
| **3. Almacenamiento / serving** | `sqldw-cli`, `sqldb-cli`, `eventhouse-cli`, `spark-cli` (Lakehouse) |
| **4. Modelado semántico** | `semantic-model-authoring`, `fabriciq-ontology-cli` |
| **5. Visualización** | `powerbi-report-cli` |
| **6. Consumo y análisis** | `fabriciq`, `sqldw-cli` (consumo), `eventhouse-cli` (consumo) |
| **7. ALM / CI-CD** | `git-integration-operations-cli`, `deployment-pipelines-authoring-cli`, `variable-library-cli` |
| **8. Operación y alertas** | `activator-cli`, `spark-cli` (operations), `sqldw-cli` (operations), `sqldb-cli` (operations), `azmon-mirroredcatalogs-operations-cli` |
| **9. Gobierno** | `onelake-catalog-govern-cli`, `search-consumption-cli`, `eventschemaset-cli` |
| **10. Migración** | `synapse-migration`, `databricks-migration`, `hdinsight-migration`, `pipeline-migration` |

## 3. Catálogo de skills (25) con su uso

Convención: **Pro** = utilizable sin capacidad Fabric (ver §5). Los skills son *dispatchers de modos*: el `SKILL.md` no contiene procedimientos, remite a `references/<modo>.md`. Todas las llamadas a `api.fabric.microsoft.com` llevan la cabecera de telemetría `x-ms-fabric-skill`.

### 3.1 Visualización y modelado (el núcleo para la plantilla)

**`powerbi-report-cli`** (v1.0.4; también en el bundle `powerbi-authoring`). Gestiona el ciclo completo del informe en cuatro modos, siempre en este orden:
- **planning:** 3–5 rondas de preguntas, una a una; entrada `Local Model`, `Live Connected Model` o `No Model` (este último se deriva a `semantic-model-authoring`). Genera `_brief/report-spec.md` con un `Design Brief:` YAML. Hay una **puerta de aprobación** que es frontera de turno: no se construye hasta que el usuario aprueba en un mensaje posterior.
- **design:** investigación de los datos primero, tono (catálogo de 12), 5 arquetipos de página (Executive Summary, Operational Monitor, Analytical Canvas, Narrative Story, Comparative Benchmark) con variantes de layout, selección de gráfico, tema (`assets/base.json`), `layout_contract` mecánico, accesibilidad WCAG 2.1/2.2 (contraste 4,5:1 texto y 3:1 no texto, objetivo ≥24×24 px, texto alternativo, orden de tabulación, daltonismo). No edita PBIR.
- **authoring:** mecánica de ficheros PBIR/PBIP. `powerbi-report-author scaffold` crea el informe (prohíbe escribir `$schema` a mano). Comandos `catalog`, `formatting`, `expr encode`, `theme encode`, `validate`, `pack`/`unpack`, `doctor`. Prohíbe tipos legacy (`card`, `table`, `matrix`, `map`…; usar `cardVisual`, `tableEx`, `pivotTable`, `azureMap`). Cubre bookmarks, drillthrough, botones, field parameters, formato condicional, filtros, visuales personalizados, re-theming. Bucle de validación: **`preview --host desktop`** recarga el informe en Power BI Desktop y captura screenshots; "schema success alone is never task completion".
- **management:** subida/descarga/rebinding en Fabric vía `az rest` y `pack --raw`/`unpack`. Publicar un `.pbip` local sigue 10 pasos y exige permiso explícito antes de crear o sobrescribir.
- Requisitos: Node 20+, `npm i -g @microsoft/powerbi-report-authoring-cli`, Desktop (solo Windows), `powerbi-modeling-mcp` para modelos vivos. **Pro** parcial: planning/design/authoring sobre PBIP local no necesitan Fabric; management sí usa la API de Fabric.

**`semantic-model-authoring`.** Crea, edita, analiza y despliega modelos semánticos: tablas, columnas, medidas, relaciones, field parameters, DAX, Import/DirectQuery/Direct Lake, refresco, permisos y binding de conexión. Doce flujos (crear, descubrir metadatos, modificar, optimizar DAX, mejores prácticas, preparar para IA, exportar a PBIP, desplegar, refrescar, gestionar…).
- **Prioridad de herramientas:** Tier 1 `powerbi-modeling-mcp` (Desktop, workspace o PBIP) → Tier 2 TMDL en disco o round-trip `getDefinition`/`updateDefinition` → si no hay ninguna, se detiene. Es anti-patrón leer `.tmdl` mientras el MCP está conectado.
- Reglas: esquema en estrella, medidas explícitas con columna base oculta, sin prefijos `Fact`/`Dim`, no usar `Double`, TMDL antes que TMSL. En despliegue, usar la API de Fabric si hay ficheros en disco; **no es idempotente** (un reintento crea un duplicado). No gestiona la pertenencia a roles RLS/OLS (redirige al portal).
- Guías de Direct Lake (`EntityPartitionSource`, expresión `AzureStorage.DataLake`, sin M, compat. ≥1702), DAX perf (patrones DAX001–021, QRY001+), `connection-binding.md` (`POST .../bindConnection`, solo el propietario del modelo).
- **No integra Tabular Editor/BPA**; su "Analyze Best Practices" compara contra sus propias guías.
- **Pro:** alto (edición local y Desktop). Refresco/permisos vía API de Power BI son *(inferencia)* viables en Pro; Direct Lake y Fabric Items API son solo Fabric.

**`fabriciq`.** Agente analista: responde preguntas de negocio sobre informes/modelos publicados con el MCP FabricIQ. Flujo: `DiscoverArtifacts`/`ResolveFabricItem` → `GetReportMetadata` → `GetSemanticModelSchema` (instrucciones personalizadas y *Verified Answers*) → `ValueSearch` → DAX → `ExecuteQuery` (1–4 `EVALUATE`, 250 filas por defecto, máx. 1.000). Los *Verified Answers* mandan; nunca inventa datos ni enseña DAX. Útil también para **comprobar medidas contra el modelo publicado**. Requiere que el tenant tenga el endpoint habilitado. Solo informes y modelos (no paginados ni dashboards).

**`fabriciq-ontology-cli`** (preview). Autoría y consulta de items *Ontology*: tipos de entidad y relación, data bindings, grounding, recorridos de grafo. Preview-and-confirm obligatorio antes de escribir. Solo Fabric.

### 3.2 Ingesta y transformación

**`dataflows-cli`.** Dataflow Gen2 (Power Query en la nube). Modos: *authoring* (edita `mashup.pq`, conexiones, destinos de salida, `executeQuery` para previsualizar), *consumption* (estado, historial de refresco, gráficos ASCII), *upgrade* (Gen1→Gen2 vía `saveAsNativeArtifact`, con evaluación de riesgo). Reglas: previsualizar con `executeQuery` antes de `updateDefinition`; si el origen no es Gen1 se detiene. **Lo más cercano a lo que ya conoce un analista**: el lenguaje M es el mismo que en Desktop.

**`spark-cli`.** El caballo de batalla de transformación. Modos *authoring* (celdas de notebook `%%sql`/PySpark/`notebookutils`, ejecución, sesiones Livy), *consumption* (Livy ad hoc), *operations* (diagnóstico de jobs fallidos, OOM, sesiones atascadas) y *mlv* (ciclo de vida de Materialized Lake Views: `CREATE MATERIALIZED LAKE VIEW`, programación, refresco, historial; API en preview). Regla de oro: MLV exige lakehouse con esquemas.

**`eventstream-cli`.** Topologías de ingesta en streaming (Event Hubs, IoT Hub, Service Bus, CDC de SQL/MySQL, MQTT…) hacia Eventhouse/Lakehouse. Nombres de nodo en PascalCase alfanumérico; pide confirmación antes de leer credenciales del endpoint personalizado.

**`eventschemaset-cli`** (preview). Registro de tipos de evento y esquemas. Es gobierno del streaming, no un pipeline. `updateDefinition` reemplaza todo.

**`project-osmos`.** Cliente de un servicio remoto autónomo de Microsoft que, dado un resultado deseado, inspecciona datos, escribe y ejecuta Spark y entrega notebooks y tablas. Una tarea por resultado; borrar requiere reintroducir el ID. Servicio propietario, solo Fabric; su disponibilidad y licenciamiento no se indican en el skill.

**`e2e-medallion-architecture`.** Guía de arquitectura (361 líneas, un solo fichero): perfiles Bronze (append-only + metadatos), Silver (deduplicar, conformar), Gold (optimizado para lectura, V-Order). Opción preferida: un lakehouse con esquemas `bronze/silver/gold`. Termina con el traspaso a un modelo Direct Lake y un informe PBIR. Recuerda que Spark de Fabric no lee URLs HTTP externas (hay que aterrizar los ficheros en `Files/`).

### 3.3 Almacenamiento y consulta

**`sqldw-cli`.** T-SQL sobre Warehouse, SQL endpoint de Lakehouse y bases espejadas. Modos *authoring* (DDL/DML, `COPY INTO`, CTAS), *consumption* (solo lectura), *operations* (Query Insights, correlación con Capacity Metrics). Usa el MCP `fabric-sqlendpoint` (`execute_query`). Límites: un lote por llamada (sin `GO`), 10.000 filas, 300 s, 20 req/min. Superficie T-SQL reducida (sin `DEFAULT`, `NVARCHAR`, `MONEY`; PK solo `NOT ENFORCED`).

**`sqldb-cli`.** Fabric SQL database (motor OLTP tipo Azure SQL). Authoring (tablas, índices, vectores, dacpac, GraphQL), consumption (solo lectura, temporales, JSON, vectores), operations (Query Store, DMVs, Extended Events). **El más portable** fuera de Fabric: T-SQL, Query Store y dacpac valen para Azure SQL/SQL Server.

**`eventhouse-cli`.** KQL: tablas, funciones, políticas, vistas materializadas, ingesta y consultas de solo lectura vía API de Kusto. Scripts `.sh/.ps1` incluidos. KQL es el mismo lenguaje que Azure Data Explorer y Log Analytics.

### 3.4 ALM y CI/CD

**`git-integration-operations-cli`** (experimental). Ciclo Git de un workspace (connect, commit, update, status, conflictos, disconnect, service principal) con `fab api` o `az rest`. Reglas: nunca dos operaciones Git simultáneas en un workspace; éxito = `workspaceHead == remoteCommitHash`. Requiere capacidad; el switch de GitHub está apagado por defecto en el tenant.

**`deployment-pipelines-authoring-cli`.** Crea pipelines (2–10 etapas), asigna workspaces, despliega con LRO (≤300 items), **despliegue selectivo de solo lo cambiado** con `diff_item_definitions.py`. Límites: no hay API para reglas de despliegue ni comparación; reasignar el emparejamiento borra el historial; un workspace solo en una etapa.

**`variable-library-cli`.** Variables y *value sets* por entorno (dev/test/prod), con sintaxis de consumo en pipelines, notebooks, Dataflows y UDFs. El value set activo es estado del item (no va en Git ni en deployment pipelines); hay que fijarlo tras desplegar.

### 3.5 Gobierno, operación y coste

**`onelake-catalog-govern-cli`.** Matriz 2×2 (admin / propietario × auditar / remediar) sobre dominios, capacidades, etiquetas, tags, descripciones. Regla: auditoría primero; los modos de auditoría no mutan aunque se pida. Tabla de escrituras irreversibles con puerta de confirmación.

**`search-consumption-cli`.** `POST /v1/catalog/search` para localizar items en todos los workspaces cuando no se sabe cuál es. Filtros restringidos (`eq`, `ne`, `or`). Índice con retraso de minutos.

**`activator-cli`.** Alertas "avísame cuando X": reglas, condiciones y acciones (Teams, email, ejecutar pipeline/notebook), con fuentes KQL, Eventstream, Power BI, Real-Time Hub. Puerta de validación de la fuente antes de crear. Se parece conceptualmente a las alertas de Power BI pero es otro producto.

**`azmon-mirroredcatalogs-operations-cli`.** Trae telemetría de Azure Monitor/App Insights/Log Analytics a Eventhouse y la correlaciona con datos de negocio (flujo obligatorio de 17 etapas). Observabilidad de aplicaciones, ajena a la construcción de informes.

**`e2e-fabric-cost-estimation`.** Dimensiona SKU (F2–F8192) y compara PAYG, Reserved y Autoscale con precios en vivo de la Azure Retail Prices API (obligatorio, nunca precios memorizados). No compara licencias Pro/PPU.

### 3.6 Migración

`synapse-migration` (Dedicated Pool, Spark pools, Lake Databases; el pool original es de solo lectura; 3 rutas), `databricks-migration` (`dbutils`→`notebookutils`, Unity Catalog→esquemas, DLT bloqueante), `hdinsight-migration` (WASB/ABFS→shortcuts, Hive→Delta, Oozie→pipelines; no se puede acceder a `hdfs://`), `pipeline-migration` (pipelines de Synapse/ADF→Fabric: datasets inlined, linked services→Connections, parámetros globales→Variable Library). Útiles solo en proyectos corporativos con plataforma previa.

### 3.7 Los 5 agentes y los servidores MCP
- `FabricDataEngineer` (punto de entrada transversal), `FabricAdmin` (gobierno, coste, "documenta mi workspace"), `FabricAppDev` (apps con ODBC/XMLA/REST), `FabricIQ` (preguntas de negocio, con lectura previa obligatoria de su skill), `FabricMigrationEngineer` (marco de 6 fases).
- MCP: **FabricIQ** (`fabriciq.svc.cloud.microsoft`), **powerbi-modeling-mcp** (remoto en `fabric-skills`; **stdio vía `npx -y @microsoft/powerbi-modeling-mcp@latest --start`** en `powerbi-authoring`, que es el modo local), **fabric-sqlendpoint**. Auth con `az login` reutilizado mediante `headersHelper` en Claude Code.

### 3.8 Conocimiento transversal en `common/` útil aunque no uses los skills
Audiencias de token (la causa nº 1 de 401): Fabric `https://api.fabric.microsoft.com`, Power BI `https://analysis.windows.net/powerbi/api`, OneLake `https://storage.azure.com`, SQL `https://database.windows.net`, Kusto. LROs (202 + `Location`/`Retry-After`), throttling (429 con backoff y jitter), paginación por `continuationToken`, `updateDefinition?updateMetadata=true`, formato de definición (`parts[]` base64 + `.platform`).

## 4. Idoneidad: proyectos individuales vs corporativos

| Skill | Individual | Corporativo | Comentario |
|---|---|---|---|
| `powerbi-report-cli` | Sí (local) | Sí | Valor máximo en ambos |
| `semantic-model-authoring` | Sí (local/Desktop) | Sí | Idem; deploy y binding más corporativos |
| `fabriciq` | Sí si hay endpoint | Sí | Útil para QA de medidas |
| `dataflows-cli` | Sí con Fabric | Sí | Bajo coste de aprendizaje (M) |
| `sqldw-cli` / `sqldb-cli` | Con Fabric | Sí | `sqldb-cli` reutilizable en Azure SQL |
| `spark-cli`, `e2e-medallion-architecture` | Con Fabric | Sí | Datos grandes / plataforma |
| `eventhouse-cli`, `eventstream-cli`, `activator-cli`, `eventschemaset-cli` | Raro | Sí | Tiempo real |
| `git-integration…`, `deployment-pipelines…`, `variable-library-cli` | No | Sí | Equipos y entornos; exigen capacidad |
| `onelake-catalog-govern-cli`, `search-consumption-cli` | No | Sí | Tenant grande, roles de admin |
| `e2e-fabric-cost-estimation` | Marginal | Sí | Decisión de SKU |
| `azmon-…`, migraciones ×4, `project-osmos`, `fabriciq-ontology-cli` | No | Solo en casos específicos | Nicho |

Criterio: **individual** = una persona, sin capacidad Fabric o con trial; **corporativo** = capacidad, varios entornos, roles y gobierno.

## 5. ¿Sirven fuera de Fabric (p. ej. Power BI Pro)?

**Ninguno de los skills declara soportar Pro.** Todos asumen workspaces con capacidad. Clasificación, con la salvedad de que lo marcado *(inferencia)* no está confirmado por el repo:

### A. Reutilizables sin Fabric (alto valor)
- `powerbi-report-cli` en **planning, design y authoring** sobre un PBIP local con Desktop: scaffold, validación de esquema, preview y screenshots, temas, accesibilidad, arquetipos de diseño. No necesita servicio.
- `semantic-model-authoring` **Tier 1/2 sobre Desktop o PBIP local**: modelado, DAX, field parameters, revisión de buenas prácticas, rendimiento DAX (con trace). Se apoya en `powerbi-modeling-mcp` en modo stdio.
- Las guías `tmdl-guidelines`, `dax-guidelines`, `modeling-guidelines`, `naming-conventions`, `dax-perf-*`, `field-parameters`: conocimiento puro.

### B. Parcial o por verificar en Pro *(inferencia)*
- `powerbi-report-cli` **service preview** (renderiza el PBIR local contra un modelo publicado) y **management**: usan API de Fabric Items; no se indica si un workspace Pro la acepta. (La plantilla ya usa esa API en Pro real en el escenario A, así que la vía parece viable.)
- `semantic-model-authoring` refresco, fuentes de datos, parámetros y permisos: la API de datasets de Power BI existe en Pro. XMLA de escritura **no** existe en Pro.
- `fabriciq`: lee modelos publicados; depende de que el endpoint esté habilitado en el tenant.
- `e2e-fabric-cost-estimation` (precios públicos) y `common/COMMON-*.md` (auth, LRO, throttling).

### C. Reutilizable solo como conocimiento (no el skill)
- `sqldb-cli` → Azure SQL/SQL Server; `eventhouse-cli` → Azure Data Explorer/Log Analytics; `dataflows-cli` → lenguaje M; `spark-cli`/medallion → PySpark/Delta en Databricks; `sqldw-cli` → T-SQL con restricciones propias.

### D. Solo Fabric
Direct Lake, `bindConnection`, Deployment Pipelines, Git de workspace, Variable Library, Ontology, OneLake governance, Catalog Search, Activator, Azure Monitor mirroring, MLV, Event Schema Sets, Osmos y las migraciones.

## 6. Encaje con Agentic-PowerBI-Template

### Ya cubierto por la plantilla
Flujo de ramas, hooks, CI, validación BPA con Tabular Editor 2, validador de esquema PBIR, 14 skills propios, documentación automática, despliegue del escenario A.

### Huecos que llenan los skills
| Hueco de la plantilla | Aporte |
|---|---|
| `visuales-pbir`, `diseno-informe`, `temas` sin dogfooding | `powerbi-report-cli`: arquetipos, `layout_contract`, accesibilidad, preview/screenshots reales (mayor solape) |
| Escenario B sin guía operativa | `deployment-pipelines-authoring-cli`, `git-integration-operations-cli`, `variable-library-cli` |
| Modelado vivo (XMLA, Direct Lake) | `semantic-model-authoring` + `powerbi-modeling-mcp` |
| Verificación de medidas tras publicar (Pro sin XMLA) | `fabriciq` `ExecuteQuery` |
| Capa de datos en la nube | `dataflows-cli`, `sqldw-cli`, `e2e-medallion-architecture` |
| Decisión A/B por coste | `e2e-fabric-cost-estimation` |
| Conocimiento REST (401, LRO, 429) | `common/COMMON-CORE.md` |

### Fricciones a resolver
1. **Doble vía de edición del modelo:** el skill prohíbe leer TMDL con el MCP conectado; la plantilla edita TMDL en disco y su hook `post-edit-tmdl` ejecuta BPA solo sobre ediciones de fichero. Hay que decidir qué manda (propuesta: TMDL en disco + BPA por defecto; MCP solo para refresco/DAX en vivo).
2. **Límite duro de credenciales/gateway:** `bindConnection` y conexiones de Dataflows tocan credenciales. Mantenerlo como paso manual.
3. **Herramientas libres:** la plantilla evita software de pago; `powerbi-report-author` y `powerbi-modeling-mcp` son npm/gratis, bien. El CLI está en beta.
4. **PBIR:** la plantilla lo trata como preview (GA prevista Q3 2026). Verificar el estado actual antes de fijar versiones.
5. **Idioma:** skills en inglés, plantilla en español. Cabecera `x-ms-fabric-skill` solo si se llama a la API de Fabric.
6. **Volatilidad:** v0.3.x con fusiones recientes. Conviene fijar versión.
7. **Instalación:** plugin `powerbi-authoring@fabric-collection` (solo 2 skills + MCP) o `apm install … --skill powerbi-report-cli --skill semantic-model-authoring`, no el bundle completo.

### Recomendación por prioridad
- **P1 (integrar):** `powerbi-report-cli`, `semantic-model-authoring`, y copiar/adaptar `common/COMMON-CORE.md`.
- **P2 (escenario B):** `deployment-pipelines-authoring-cli`, `git-integration-operations-cli`, `variable-library-cli`, `fabriciq`.
- **P3 (opcionales por proyecto):** `dataflows-cli`, `sqldw-cli`, `e2e-medallion-architecture`, `e2e-fabric-cost-estimation`.
- **Descartar para la plantilla:** migraciones, Osmos, Ontology, Azure Monitor, Eventstream/Activator/Eventhouse salvo proyecto concreto.


