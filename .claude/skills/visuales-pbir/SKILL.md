---
name: visuales-pbir
description: Genera o modifica objetos visuales (PBIR) o evalúa la necesidad de un custom visual. Invócalo al trabajar sobre visual.json/page.json bajo definition/pages/.
---

Lee `files/context/visuales-pbir.md` antes de tocar ningún `visual.json`/`page.json`. Invoca primero al subagente `data-profiler` si aún no has perfilado los datos relevantes en esta sesión — no propongas visuales sobre una tabla sin conocer sus cardinalidades/distribuciones reales.

## Qué hacer

1. Antes de proponer un custom visual nuevo, evalúa alternativas sin desarrollo: visuales nativos + formato avanzado, SVG en medidas DAX, o Deneb (Vega/Vega-Lite, certificado por Microsoft) — hay plantillas comunitarias de referencia.
2. Si el custom visual es imprescindible, usa `pbiviz`/`powerbi-visuals-tools` (open source): `npm install -g powerbi-visuals-tools`, `pbiviz new`, `pbiviz start`, `pbiviz package`. La certificación/publicación en AppSource es un paso guiado por el usuario, no automatizable por el agente.
3. Cambios batch (p. ej. `isHiddenInViewMode=true` en filtros) o copiar/pegar carpetas de visual/página entre reports: hazlo, pero siempre pasa por la validación del paso siguiente antes de darlo por bueno.
4. Identifica visuales por `visualType`/`position`/`title` — no tienen `displayName`.

## Validación (obligatoria antes de cerrar)

El hook `post-edit-pbir` valida sintaxis JSON y `$schema` tras cada edición y bloquea en JSON inválido. Antes de dar el cambio por bueno de verdad, invoca al subagente `pbir-schema-validator` para el análisis completo (IDs duplicados, referencias a campos inexistentes) — el hook solo hace una comprobación superficial de `required` top-level.
