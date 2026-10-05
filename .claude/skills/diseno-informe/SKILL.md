---
name: diseno-informe
description: Planifica y diseña el layout de una pestaña/página del informe evitando que "parezca hecho por IA". Invócalo tras cerrar requirements-intake y antes de construir visuales, o para fijar la disposición final de una página. Punto de entrada único para planning/design de informe; este skill decide cuándo leer el upstream.
---

Lee `files/context/diseno.md` antes de proponer layout. Invoca al subagente `data-profiler` primero si no lo has hecho ya para esta página — el diseño debe partir de los datos reales y de la pregunta de negocio cerrada en `requirements-intake`, nunca de una plantilla genérica.

## Upstream (delegación del "cómo")

Entra siempre por este skill; **no invoques `powerbi-report-cli` directamente**. Lee el upstream solo en los modos que toca, de forma dirigida (no cargues todo `references/`):

- **Modo `planning`** (informe nuevo): [planning.md](../powerbi-report-cli/references/planning.md) y después [planning-part-02.md](../powerbi-report-cli/references/planning-part-02.md) (obligatorio antes de producir el spec).
- **Modo `design`**: [design.md](../powerbi-report-cli/references/design.md); bajo demanda [layout](../powerbi-report-cli/references/design/layout.md), [accessibility](../powerbi-report-cli/references/design/accessibility.md), [chart-selection](../powerbi-report-cli/references/design/chart-selection.md), [anti-patterns](../powerbi-report-cli/references/design/anti-patterns.md) y el arquetipo elegido en `design/archetypes/`.
- Entregable de design: el `Design Brief:` completo con `layout_contract` por página, sin editar PBIR ni llamar a APIs de Fabric. Escribirlo en PBIR es `visuales-pbir`.

## Qué evitar activamente

Dashboards genéricos sin pregunta de negocio detrás, tarjetas KPI idénticas repetidas, exceso de colores, títulos autogenéricos, layout sin grid ni jerarquía, todo el ancho igual.

## Qué hacer

1. Grid consistente: misma altura/anchura en visuales de la misma fila.
2. Espaciado deliberado, tipografía jerárquica, canvas background cuidado (coherente con el theme de `temas`).
3. Elección de tipo de gráfico apoyada en criterio de referentes reconocidos (Kurt Buhler/Data Goblins, Reid Havens, SQLBI) y en las guías de arquetipo/accesibilidad (WCAG) del upstream — como fuente de criterio, no como dependencia técnica a instalar.
4. Cada visual de la página debe trazarse a una pregunta de negocio concreta cerrada en `requirements-intake`; si no puedes trazarlo, cuestiona si el visual debe estar ahí antes de construirlo.

## Reglas de arbitraje (mandan sobre el upstream)

- **Planning parte de `requirements-intake`**: el upstream pregunta de nuevo audiencia, trabajo a resolver y KPIs. Aquí **no repitas** lo ya cerrado en `requirements-intake` (ni en `.claude/project-config.json`); infiérelo y pregunta solo lo que falte (rondas de modelo/alcance, narrativa de páginas, identidad de diseño). El upstream "ask_user" equivale a preguntar al usuario, una pregunta cada vez.
- **Puerta de aprobación**: persiste el spec en `docs/brief/report-spec.md` (sustituye al `_brief/report-spec.md` upstream; la ruta se formaliza en `arquitectura-repositorio.md` en la Fase 4), pide aprobación explícita y **para antes de construir**; no construyas en el mismo turno aunque la petición original también lo pidiera.
- **Fuera de alcance del agente**: el modo `management` (publicar/subir/rebind), `bindConnection` y credenciales (`limites-duros.md`). Si el plan upstream incluye un paso de publicación, documéntalo como paso manual / `deploy`, no lo ejecutes.
- **Escenario A/B**: lee `.claude/project-config.json`; no propongas Direct Lake ni nada que requiera capacidad en Escenario A (`escenario-licencia.md`).
- Si el spec upstream choca con una regla de la plantilla, gana la plantilla y lo declaras.

## Cierre

Tras fijar el layout, cualquier `visual.json`/`page.json` tocado pasa igualmente por la validación de `visuales-pbir` (hook `post-edit-pbir` + subagente `pbir-schema-validator`) antes de commit. Orden del flujo: planning → design → `temas` → `visuales-pbir`.
