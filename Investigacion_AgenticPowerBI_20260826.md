# Informe Power BI agéntico con Claude Code + VS Code sobre PBIP/TMDL — base de conocimiento para un proyecto plantilla

## TL;DR
- **Sí es viable hoy** construir y mantener informes Power BI de forma agéntica editando PBIP en texto (TMDL para el modelo, PBIR para el informe) desde VS Code/Claude Code, pero con una frontera dura: el modelo semántico en TMDL es el terreno fiable para automatización; **PBIR sigue en preview** (el blog oficial de Microsoft Power BI confirma verbatim *"General Availability (planned for Q3 2026)"* para PBIR y *"General Availability for PBIP is planned for 2026"*) y ciertas operaciones (refresco de metadatos de M, credenciales/gateway, verificación de query folding) **exigen Power BI Desktop** y no son automatizables sin él.
- **La divisoria A/B es de capacidad, no de herramienta**: XMLA write, Git de workspace y Deployment Pipelines requieren PPU/Premium/Fabric; en **Pro puro no existen**. En Pro sigues editando PBIP/TMDL local, validando con Tabular Editor 2 + BPA + DAX Studio, versionando en GitHub y publicando vía Fabric REST item-definition APIs (license-gated, no capacity-gated) o publish manual — pierdes XMLA write, Git de workspace y pipelines.
- **El comportamiento del asistente se ingeniería, no se improvisa**: CLAUDE.md + skills + hooks + plan mode configuran a Claude Code para hacer toma de requisitos exhaustiva y anti-sycophancy antes de tocar código; los hooks (deterministas) garantizan validación BPA/schema en cada commit mientras que CLAUDE.md (probabilístico) fija convenciones.

## Key Findings

1. **Formato PBIP = TMDL (modelo) + PBIR (informe).** TMDL es la superficie madura para agentes (sintaxis tipo YAML, un archivo por tabla/rol/perspectiva, diffs legibles). PBIR reemplaza al report.json monolítico (PBIR-Legacy) por una carpeta con un JSON por visual/página/marcador con schema público validable en VS Code. Estados: PBIP GA prevista 2026; PBIR en preview con GA prevista **Q3 2026**, momento en que PBIR-Legacy se elimina y toda conversión es irreversible.

2. **Tabular Editor 2 (gratuito, MIT) es el caballo de batalla en ambos escenarios**, pero su motor de scripting C# (CS-Script) es antiguo: por defecto **no soporta string interpolation ni local functions**; usa concatenación con `+` y, si quieres C# moderno, activa el compilador Roslyn. La documentación de Tabular Editor lo confirma verbatim: *"If you prefer to compile your scripts using the new Roslyn compiler... you can set this up under File > Preferences > General, starting with Tabular Editor version 2.12.2. This allows you to use newer C# language features such as string interpolation."*

3. **DAX UDFs pasaron a GA en junio de 2026.** Microsoft Learn lo confirma verbatim: *"DAX UDFs require database compatibility level 1702 or higher and the feature is generally available in Power BI Desktop and Power BI Service as of the June 2026 release."* (Entraron en preview en la actualización de septiembre 2025.) Se escriben en TMDL (`functions.tmdl`) y se inspeccionan con `INFO.USERDEFINEDFUNCTIONS()`.

4. **La automatización agéntica es fiable en TMDL, frágil en PBIR y bloqueada en credenciales/M-refresh.** Editar visual.json puede romper el informe (errores *blocking* si violas el schema); refrescar metadatos de columnas de M requiere Desktop; las credenciales/gateway NUNCA las gestiona el agente (se configuran en el servicio).

5. **Herramientas gratuitas confirmadas:** Tabular Editor 2 (MIT), DAX Studio (open source), ALM Toolkit (open source), extensión oficial TMDL para VS Code (GA), reglas BPA de la comunidad (Kovalsky/Otykier, repo GitHub `TabularEditor/BestPracticeRules`), Deneb (MIT, certificado), pbiviz/powerbi-visuals-tools (open source), semantic-link/sempy y semantic-link-labs (solo Fabric notebooks), FabricPS-PBIP y fabric-cicd (open source, sin soporte oficial). Se excluyen Tabular Editor 3, DAX Optimizer y tiers de pago.

## Details

### Fase 0 — Estados de formato, licencias y la divisoria A/B

**Formatos (verificado, Microsoft Learn + blog Power BI, 2024–2026):**
- **PBIP**: contenedor de proyecto en texto. GA prevista 2026.
- **TMDL** (Tabular Model Definition Language): modelo semántico como texto, sintaxis YAML-like, indentación marca jerarquía, `///` para descripciones, triple backtick (```` ``` ````) para expresiones multi-línea (DAX/M con caracteres conflictivos como `:` y `=`), palabra clave `ref` para preservar orden de colecciones y evitar diffs. Carpeta `definition/` con `model.tmdl`, `database.tmdl`, `relationships.tmdl`, `expressions.tmdl`, `tables/`, `roles/`, `perspectives/`, `cultures/`, `functions.tmdl`.
- **PBIR**: informe como carpeta (`definition/pages/**/visuals/*/visual.json`, `page.json`, `bookmarks/`), schema JSON público. En **preview**; GA prevista Q3 2026. Por defecto en el servicio desde enero 2026 (rollout gradual por tamaño; el blog oficial confirma verbatim que *"as of March 2026, only reports with fewer than 100 visuals are eligible for automatic upgrade when edited in the service"*). En Desktop, el default a PBIR se retrasó: verbatim del blog oficial, *"PBIR as the default format for both PBIX and PBIP file formats has been delayed to the May Power BI Desktop release"*; hasta entonces hay que activar la preview feature "Store reports using enhanced metadata format (PBIR)". Conversión a PBIR **irreversible**.
- **PBIR-Legacy** (report.json monolítico): se elimina en GA de PBIR.

**Licencias y capacidades (verificado, Microsoft Learn 2026):**
- **Git integration de workspace**: requiere Premium (P SKU), Fabric capacity (F SKU) o PPU; el trial de Fabric sirve. **Pro puro (shared capacity) NO lo permite.** Cita Learn: *"To access the Git integration feature, you need one of the following: Power BI Premium license... Fabric capacity."*
- **Deployment Pipelines**: requieren suscripción Fabric/Premium/PPU; una workspace Premium por stage. **Pro puro NO.** Nota: desde el **12 de febrero de 2026** las pipelines retiran soporte a modelos no actualizados a Enhanced Metadata.
- **XMLA endpoint (read y write)**: existe **solo** en Premium/PPU/Fabric. *"A workspace on shared capacity has no XMLA endpoint at all."* Write además requiere el toggle read-write, rol Contributor+ y enhanced metadata. Desde junio 2025 Microsoft habilitó XMLA read/write por defecto en todos los SKU de capacidad Fabric/Power BI.
- **REST API en Pro**: un usuario Pro **sí** puede desplegar programáticamente semantic model + report a un workspace de shared capacity vía las **Fabric item-definition APIs** (Create Item / Update Item Definition), porque los items de Power BI son *license-gated*, no *capacity-gated*. Cita Learn: *"To create a non-PowerBI Fabric item the workspace must be on a supported Fabric capacity... To create a PowerBI item, the user must have the appropriate license."* Límites en Pro: sin XMLA write, modelos ≤1 GB, sin shareable cloud connections, y "reports que comparten semantic model no soportan despliegues automatizados vía Power BI REST API" (matiz de la API clásica /imports).

**Conclusión de arquitectura:** la plantilla debe separar `.SemanticModel` (TMDL, automatizable en A y B) de `.Report` (PBIR, editable con cautela). Todo lo que dependa del XMLA endpoint (Tabular Editor CLI deploy, probar DAX vía XMLA, la extensión PowerBI-VSCode de gbrueckl) es **solo escenario B**.

### Fase 1 — Orígenes de datos y revisión de cambios (schema drift)

Las expresiones M viven en `definition/expressions.tmdl` (parámetros y queries compartidas) y en las particiones de cada tabla. Sintaxis de parámetro en TMDL:

```tmdl
expression SqlEndpoint = "server.database.windows.net"
	meta [IsParameterQuery=true, IsParameterQueryRequired=true, Type="Text"]
	lineageTag: abc-123
	queryGroup: Parameters
```

- **Ficheros (Excel/CSV/JSON)**: el agente edita el `Source` M en la partición. Parametriza rutas/carpetas. Import solo.
- **SQL (SQL Server/PostgreSQL)**: define server/database como parámetros para rebinding por entorno. Soporta Import y DirectQuery.
- **Modelos semánticos del servicio** (live connection / composite / DirectQuery sobre modelo semántico): en composite, el modelo remoto se referencia; el agente puede añadir tablas locales y relaciones. Direct Lake solo aplica en B.

**Detección de schema drift automatizada:** en B, notebook Fabric con `sempy`/`semantic-link-labs` (`evaluate_dax`, `list_columns`) compara esquema del origen contra el modelo tras cada refresh, estilo pytest. En A, script Tabular Editor 2 sobre archivos: `Model.Tables["X"].RefreshDataColumns()` refresca metadatos de columnas desde el origen (requiere conexión OLE DB accesible) y un diff Git posterior revela columnas nuevas/eliminadas.

**Credenciales/gateway (límite de seguridad):** el agente NUNCA gestiona credenciales ni cadenas de conexión con secretos. Se configuran en el servicio (Manage gateways / dataset settings) o vía Service Principal en pipeline (secretos en Azure Key Vault / GitHub Secrets, nunca en TMDL). Regla dura en CLAUDE.md: "Never include credentials in source files".

### Fase 2 — Transformaciones Power Query (M)

- **Edición desde VS Code/agente**: M vive en TMDL; la **extensión oficial TMDL para VS Code (GA)** ofrece para M embebido autocompletado, diagnósticos de sintaxis, resaltado y formato.
- **Lint/validación fuera de Desktop (gratis)**: la extensión TMDL (análisis estático) y la extensión comunitaria "Power Query Lint". Pero es **solo estático**: no ejecuta ni previsualiza.
- **Query folding**: NO verificable fuera de Desktop. Los cuatro métodos (View Native Query, Query Folding Indicators, Query Diagnostics, y examinar el plegado paso a paso) viven en el Power Query Editor de Desktop.
- **Qué exige Desktop obligatoriamente**: ejecutar/previsualizar queries, refrescar metadatos de columnas de M, verificar folding, ver funciones/expresiones no cargadas. Patrón recomendado: staging queries (Enable Load off), parámetros `RangeStart`/`RangeEnd` para incremental refresh, funciones M reutilizables en `expressions.tmdl`, manejo de errores con `try...otherwise`.

### Fase 3 — Diseño y construcción del modelo (TMDL)

Sintaxis verificada. Relación:

```tmdl
relationship abc123-def
	fromColumn: Sales.CustomerKey
	toColumn: Customer.CustomerKey
	toCardinality: one
	crossFilteringBehavior: bothDirections
	isActive: false
```

Rol con RLS (usando una UDF/expresión de filtro):

```tmdl
role 'Account Managers'
	modelPermission: read
	tablePermission Customers = RLS.ApplySimpleRLS('Customers'[Account Manager])
```

Calculation group (time intelligence):

```tmdl
createOrReplace
	table 'Time Intelligence'
		calculationGroup
			precedence: 1
			calculationItem YTD = CALCULATE(SELECTEDMEASURE(), DATESYTD('Calendar'[Date]))
			calculationItem QTD = CALCULATE(SELECTEDMEASURE(), DATESQTD('Calendar'[Date]))
			calculationItem MTD = CALCULATE(SELECTEDMEASURE(), DATESMTD('Calendar'[Date]))
			calculationItem Current = SELECTEDMEASURE()
		column 'Show as'
			dataType: string
			sourceColumn: Name
			sortByColumn: Ordinal
		column Ordinal
			dataType: int64
			summarizeBy: none
			sourceColumn: Ordinal
```

Esquema estrella, role-playing dimensions (relaciones inactivas + `USERELATIONSHIP`), jerarquías, perspectivas y modelos composite: todo expresable en TMDL directo o vía script C# de Tabular Editor 2. Convención: `discourageImplicitMeasures: true` en model.tmdl y `compatibilityLevel` explícito en database.tmdl. Reutilización: copiar el `.tmdl` de una tabla entre modelos y reconfigurar `relationships.tmdl`.

### Fase 4 — Medidas/KPIs en DAX

**Scripting C# compatible con Tabular Editor 2 (CS-Script) — patrones verificados:**
- Evitar string interpolation (`$"..."`) y local functions por defecto.
- Usar concatenación `+`. Ejemplo verificado:

```csharp
foreach(var c in Selected.Columns) {
    var m = c.Table.AddMeasure(
        "Sum of " + c.Name,
        "SUM(" + c.DaxObjectFullName + ")",
        c.DisplayFolder);
    m.FormatString = "0.00";
    m.Description = "Auto-generated measure";
}
```
- `using` para acortar clases y `#r "assembly"` para ensamblados externos están soportados.
- Si necesitas C# moderno (incluida string interpolation): activar compilador **Roslyn** (File > Preferences > General, v2.12.2+).
- Limitación: si el script se guarda como macro, no puede contener métodos locales con modificadores de acceso (public/static).

**DAX UDFs (GA junio 2026, CL 1702+):** sintaxis TMDL:

```tmdl
createOrReplace
	function AddTax = (amount: NUMERIC) => amount * 1.1
```
Se guardan en `functions.tmdl`, se reutilizan entre modelos por TMDL, y se documentan con `///`, `@param` y `@returns`. **No soportadas en Azure AS / SQL Server AS** (verbatim Microsoft Learn/Tabular Editor: *"UDFs require compatibility level 1702 or higher; Azure Analysis Services and SQL Server Analysis Services don't support them"*).

**Validación DAX automática:**
- **BPA vía Tabular Editor 2 CLI** (A y B, sobre archivos): `TabularEditor.exe "Model.bim" -A "BPARules.json" -V` en GitHub Actions/Azure Pipelines. En enero 2026 Tabular Editor incorporó reglas BPA integradas en todas las instalaciones.
- **Probar medidas sin Desktop**: en B, DAX queries vía XMLA (`semantic-link-labs.evaluate_dax`) con aserciones pytest; en A, no hay XMLA, así que se prueba tras publish (Fabric REST) o en Desktop; DMVs/`INFO.VIEW` para introspección.

### Fase 5 — Temas del informe (theme JSON)

- Schema oficial en `microsoft/powerbi-desktop-samples` (carpeta Report Theme JSON Schema, Draft 7, versionado por release mensual). Referenciar con `$schema` en VS Code para validación in-line.
- Solo `name` es obligatorio; el resto opcional. Colores estructurales: `firstLevelElements`, `secondLevelElements`, `thirdLevelElements`, `fourthLevelElements`, `background`, `secondaryBackground`.
- **Accesibilidad/contraste**: verificar ratios WCAG (4.5:1 texto normal), probar con simuladores de daltonismo (Color Oracle, Coblis), no usar color como único canal. El agente puede generar la paleta y calcular contraste, pero debe versionar el theme JSON en la plantilla y aplicarse a un report representativo antes de desplegar.

### Fase 6 — Objetos visuales (PBIR) y custom visuals

- **Editar PBIR de forma fiable**: cambios batch por script (ej. `isHiddenInViewMode=true` en filtros), copiar/pegar carpetas de visual/página entre reports, find & replace de `semanticModelId` al promover Dev→Test→Prod. Validar contra `$schema`.
- **Qué rompe el informe**: violar el schema (blocking errors, Desktop no abre), IDs duplicados, referencias a campos inexistentes. Los visuales no tienen displayName: hay que identificarlos por `visualType`/`position`/`title`.
- **Alternativas sin desarrollar custom visual**: visuales nativos + formato avanzado; SVG en medidas DAX; **Deneb** (Vega/Vega-Lite, MIT, certificado por MS, gratuito, renderiza dentro de Power BI sin dependencias externas) para visuales bespoke — hay plantillas comunitarias (David Bacci, jack-bryde, avatorl).
- **Custom visual con pbiviz** (open source, npm): `npm install -g powerbi-visuals-tools`, `pbiviz new`, `pbiviz start`, `pbiviz package`. TypeScript + D3; `capabilities.json` define dataRoles y dataViewMappings; plantilla recomendada de dm-p (Daniel Marsh-Patrick). Certificación y publicación en organización/AppSource son pasos separados guiados por el usuario.

### Fase 7 — Diseño que no parezca "hecho por IA"

- **Señales que delatan IA**: dashboards genéricos sin pregunta de negocio, sobre-uso de tarjetas KPI idénticas, exceso de colores, títulos autogenéricos, layout sin grid ni jerarquía, todo el ancho igual. Evitarlas con grid consistente (misma altura/anchura en visuales de la misma fila), espaciado deliberado, tipografía jerárquica, canvas backgrounds tipo Figma, y **partir de una pregunta de negocio real**.
- **Perfilado para proponer análisis reales**: el agente perfila los datos (cardinalidades, distribuciones, candidatos a dimensión/medida) antes de proponer visuales, en lugar de plantillas genéricas.
- **Referentes de diseño**: Kurt Buhler / Data Goblins (checklists de app/dashboard, 60+ plantillas .pbip con datos de muestra en su repo público, y un plugin comunitario de desarrollo agéntico Power BI con skills TMDL/PBIR), Reid Havens (Havens Consulting), SQLBI (Marco Russo/Alberto Ferrari) para elección de tipo de gráfico. Gestión de estilo vía theme JSON + plantillas .pbit versionadas.

### Comportamiento del asistente (ingeniería de contexto en Claude Code)

**Anti-sycophancy (prácticas de la comunidad 2026):** funciona mejor "Challenge my assumptions" que "be brutal"/"critique everything" (esto produce output combativo y flaws inventados). Incluir sección "What you do NOT do" (las prohibiciones hacen más trabajo que las reglas). Regla clave: no retroceder ante objeción sin nueva evidencia. Ejemplo para CLAUDE.md:

```markdown
## Modo de trabajo crítico
- Antes de aceptar un requisito, identifica al menos un supuesto no comprobado y decláralo.
- Ante una decisión/plan, presenta primero el caso opuesto más fuerte; no lo suavices.
- Si objeto sin nueva evidencia/restricción, mantén tu posición. "Buen punto" sin datos no basta.
- No abras con elogio. El acuerdo se demuestra con acción, no anunciándolo.
- Si no lo sabes, di "no lo sé"; no rellenes con una suposición confiada.
- No inventes defectos para parecer riguroso. Discrepa cuando la evidencia lo indique.
```

**Toma de requisitos exhaustiva (skill de discovery):** cuestionario BI antes de desarrollar — audiencia y nivel de data literacy; preguntas de negocio y decisiones; definición precisa de cada métrica y su granularidad; dimensiones de análisis; storage mode (Import/DirectQuery/Direct Lake); SLA de refresco; volumen y crecimiento; seguridad (RLS/OLS); criterios de aceptación medibles. Materializar como plan mode + skill que bloquea el desarrollo hasta cerrar ambigüedades.

**Mecanismos de Claude Code (documentación oficial, 2026):**
- **CLAUDE.md**: constitución del repo (convenciones de naming, reglas TMDL, .gitignore, prohibiciones de seguridad). Jerarquía: `~/.claude/CLAUDE.md` (global) + CLAUDE.md de proyecto + subcarpetas.
- **Skills** (`.claude/skills/*/SKILL.md`): los slash commands se fusionaron en skills; auto-invocables por `description` o invocables por `/nombre`. Skills para: `pbip-scaffold`, `tmdl-model`, `dax-measures`, `pbir-visuals`, `bpa-validate`, `requirements-intake`.
- **Subagentes** (`.claude/agents/`): contexto aislado para investigación paralela (ej. un agente que perfila datos, otro que valida BPA).
- **Hooks**: deterministas, ideales para garantías (100% vs ~70% de una regla en CLAUDE.md). Ejemplo: hook post-edit que corre BPA CLI y validación de schema PBIR antes de aceptar; hook que bloquea comandos peligrosos.
- **Plan mode**: obligar planificación/aprobación antes de escribir.
- **MCP servers gratuitos**: Microsoft Learn MCP (`https://learn.microsoft.com/api/mcp`, plugin oficial `/plugin install microsoft-docs@claude-plugins-official`, herramientas `microsoft_docs_search`/`microsoft_docs_fetch`/`microsoft_code_sample_search`); MCP de GitHub y Azure DevOps para PRs; en Fabric, `microsoft/skills-for-fabric` (skills + MCP para operar Fabric vía REST/XMLA/GraphQL). `settings.json` controla permisos de herramientas (allowlist de comandos).

### Documentación autónoma
- **Del modelo**: generar data dictionary y linaje desde TMDL/DMVs (`INFO.VIEW.*`, `INFO.USERDEFINEDFUNCTIONS()`), dependencias de medidas, con script C# de TE2 o notebook sempy.
- **Del repo**: README, ADRs (decisiones de arquitectura), doc de consumidor (definiciones de KPI, cómo usar el informe).
- **Sincronización**: hooks de Claude Code + GitHub Actions/Azure Pipelines regeneran docs en cada cambio; BPA en CI garantiza convenciones.

### Estructura de repositorio plantilla propuesta

```
powerbi-report-template/
├─ .claude/
│  ├─ CLAUDE.md                      # constitución: naming, reglas TMDL, anti-sycophancy, seguridad
│  ├─ settings.json                  # permisos de herramientas (allowlist)
│  ├─ skills/
│  │  ├─ requirements-intake/SKILL.md
│  │  ├─ pbip-scaffold/SKILL.md
│  │  ├─ tmdl-model/SKILL.md
│  │  ├─ dax-measures/SKILL.md
│  │  ├─ pbir-visuals/SKILL.md
│  │  └─ bpa-validate/SKILL.md
│  ├─ agents/                        # subagentes: data-profiler, bpa-reviewer
│  └─ hooks/                         # post-edit: BPA CLI + validación schema PBIR
├─ src/
│  ├─ <Proyecto>.pbip                # pointer file
│  ├─ <Proyecto>.SemanticModel/
│  │  └─ definition/                 # model, database, relationships, expressions, tables/, roles/, functions.tmdl
│  └─ <Proyecto>.Report/
│     └─ definition/                 # pages/**/visuals/*/visual.json (PBIR)
├─ themes/                           # theme JSON + $schema
├─ templates/                        # .pbit
├─ tools/
│  ├─ BPARules.json                  # reglas comunidad
│  ├─ deploy.ps1                     # FabricPS-PBIP / fabric-cicd
│  └─ tests/                         # notebooks sempy (DAX assertions) [B]
├─ docs/                             # data dictionary, ADRs, KPI definitions, README consumidor
├─ .github/workflows/  ó  azure-pipelines.yml
├─ .gitignore
└─ .gitattributes
```

**`.gitignore`** (auto-generado por Desktop, ampliado):
```
**/.pbi/localSettings.json
**/.pbi/cache.abf
**/.pbi/editorSettings.json
**/.pbi/unappliedChanges.json
```
**`.gitattributes`**:
```
*.tmdl text eol=lf
*.json text eol=lf
*.pbip text eol=lf
*.pbir text eol=lf
*.abf binary
*.pbix binary
```

## Recommendations

**Etapa 1 — Bootstrap (ambos escenarios).** Crear el PBIP en Desktop una vez (para generar estructura y .gitignore), convertir a TMDL y PBIR. Configurar `.gitignore` y `.gitattributes` como arriba. Instalar extensión TMDL de VS Code, Tabular Editor 2, DAX Studio, ALM Toolkit. Escribir CLAUDE.md con convenciones + reglas anti-sycophancy + prohibiciones de seguridad. Cargar reglas BPA de la comunidad.

**Etapa 2 — Skills y hooks.** Implementar skills de intake de requisitos, scaffold PBIP, modelado TMDL, medidas DAX, y un hook post-edit que ejecute BPA CLI + validación de schema PBIR. Añadir Microsoft Learn MCP.

**Etapa 3 — Bucle de desarrollo.** Rama por feature (`feature/`, `fix/`, `release/`), commits semánticos, PR con revisión del diff TMDL. Pull antes de push; no cambiar de rama con PBIX abierto. El agente mantiene el control de versiones. Validar cada cambio: BPA (obligatorio), y en B pruebas DAX vía XMLA/sempy.

**Etapa 4 — Despliegue.**
- **A (Pro+GitHub):** GitHub Actions ejecuta BPA y despliega vía Fabric item-definition API (FabricPS-PBIP/fabric-cicd) a workspace de shared capacity con Service Principal. Sin XMLA write, sin Git de workspace, sin pipelines. Publish alternativo manual desde Desktop.
- **B (Fabric/PPU+Azure Repos):** Git de workspace conecta la workspace a Azure Repos; Azure Pipelines valida (Tabular Editor CLI + BPA) y promueve con Deployment Pipelines Dev→Test→Prod; XMLA write habilitado; Direct Lake si los datos están en OneLake.

**Flujo end-to-end resumido.** (1) `requirements-intake` cierra ambigüedades → (2) `pbip-scaffold` crea estructura → (3) el agente edita TMDL (orígenes, modelo, medidas, UDFs) → (4) hook corre BPA + schema → (5) refresh/folding/preview de M en Desktop cuando sea imprescindible → (6) PBIR: visuales, tema, layout con perfilado real → (7) commit semántico + PR → (8) CI valida → (9) deploy (A: REST item API; B: Git workspace + pipelines) → (10) docs regeneradas por hook/CI.

**Umbrales que cambian la recomendación:** si el cliente adquiere PPU/F SKU → migrar de A a B (activar XMLA write, Git de workspace, pipelines). Si PBIR alcanza GA (Q3 2026) → promover edición PBIR a producción. Si el modelo supera 1 GB → Pro deja de ser viable. Si los datos están en OneLake y el modelo es grande → Direct Lake over OneLake (sin fallback a DirectQuery, a diferencia de Direct Lake over SQL Endpoint).

## Caveats
- **PBIR en preview**: no asumir estabilidad de schema hasta GA (Q3 2026); edición agéntica de visual.json puede romper el report. Verificar siempre contra `$schema`.
- **Puntos NO fiables para automatización hoy**: refresco de metadatos de M (requiere Desktop), verificación de query folding (Desktop), credenciales/gateway (servicio, nunca el agente), edición masiva de PBIR sin validación.
- **CS-Script de TE2**: incompatibilidades con C# moderno; usar patrones verificados o activar Roslyn.
- **Fechas y vigencia**: fuentes 2024–2026; GA de PBIP/PBIR y fechas de retiro (pipelines sin Enhanced Metadata, feb 2026) pueden moverse — consultar el roadmap de Fabric.
- **FabricPS-PBIP y fabric-cicd** son open source sin soporte oficial de Microsoft (Learn lo indica explícitamente); validar en cada release.
- La afirmación de que Pro despliega TMDL vía Fabric item APIs es inferencia fuerte del gating license/capacity de Learn, no una frase verbatim end-to-end; probar en el tenant antes de comprometerlo en producción.
- **Direct Lake, Fabric MCP, semantic-link-labs**: aplican solo a escenario B (Fabric); no existen equivalentes en Pro puro.