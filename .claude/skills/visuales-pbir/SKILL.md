---
name: visuales-pbir
description: Genera o modifica objetos visuales (PBIR) o evalúa la necesidad de un custom visual. Invócalo al trabajar sobre visual.json/page.json bajo definition/pages/. Punto de entrada único para authoring de informe; este skill decide cuándo leer el upstream.
---

Lee `files/context/visuales-pbir.md` antes de tocar ningún `visual.json`/`page.json`. Invoca primero al subagente `data-profiler` si aún no has perfilado los datos relevantes en esta sesión — no propongas visuales sobre una tabla sin conocer sus cardinalidades/distribuciones reales.

## Upstream (delegación del "cómo")

Entra siempre por este skill; **no invoques `powerbi-report-cli` directamente**. Modo `authoring`: lee [authoring.md](../powerbi-report-cli/references/authoring.md) entero antes de la primera edición (y sus partes [02](../powerbi-report-cli/references/authoring-part-02.md), [03](../powerbi-report-cli/references/authoring-part-03.md), [04](../powerbi-report-cli/references/authoring-part-04.md) si el flujo lo pide) y, por tipo de visual, solo la guía correspondiente de `references/authoring/` (p. ej. [card](../powerbi-report-cli/references/authoring/card.md), [cartesian](../powerbi-report-cli/references/authoring/cartesian.md), [table](../powerbi-report-cli/references/authoring/table.md), [slicers](../powerbi-report-cli/references/authoring/slicers.md), [custom-visuals](../powerbi-report-cli/references/authoring/custom-visuals.md)). No cargues el resto.

Usa el CLI `powerbi-report-author` (beta; versión fijada en `tools/install-tools.ps1`) en vez de adivinar esquemas/propiedades: `catalog` y `formatting` para consultar, `validate` para validar, `scaffold` solo según `pbip-scaffold`. Permisos: `validate`/`catalog`/`formatting`/`preview-visuals` están en `allow`; `preview`, `pack` y `unpack` piden permiso.

## Qué hacer

1. Antes de proponer un custom visual nuevo, evalúa alternativas sin desarrollo: visuales nativos + formato avanzado, SVG en medidas DAX, o Deneb (Vega/Vega-Lite, certificado por Microsoft) — hay plantillas comunitarias de referencia.
2. Si el custom visual es imprescindible, usa `pbiviz`/`powerbi-visuals-tools` (open source): `npm install -g powerbi-visuals-tools`, `pbiviz new`, `pbiviz start`, `pbiviz package`. La certificación/publicación en AppSource es un paso guiado por el usuario, no automatizable por el agente.
3. Cambios batch (p. ej. `isHiddenInViewMode=true` en filtros) o copiar/pegar carpetas de visual/página entre reports: hazlo, pero siempre pasa por la validación del paso siguiente antes de darlo por bueno.
4. Identifica visuales por `visualType`/`position`/`title` — no tienen `displayName`.
5. Cada visual nuevo se traza a una pregunta de `requirements-intake` / al spec aprobado en `docs/brief/report-spec.md` (ver `diseno-informe`).

## Validación (obligatoria antes de cerrar) — dos capas

1. **Capa 1 (upstream)**: `powerbi-report-author validate "<carpeta .Report>"` tras cada lote lógico de ediciones.
2. **Capa 2 (plantilla, segunda capa independiente)**: el hook `post-edit-pbir` valida sintaxis JSON y `$schema` tras cada edición y bloquea en JSON inválido. Antes de dar el cambio por bueno, invoca al subagente `pbir-schema-validator` para el análisis completo (IDs duplicados, referencias a campos inexistentes) — el hook solo hace una comprobación superficial de `required` top-level. **No sustituyas esta capa por `validate`**: que `validate` detecte IDs duplicados está sin comprobar.
3. **Validación visual (gate upstream, acotado)**: el upstream exige validate → cargar en preview → captura → revisión antes de dar por cerrado. Aquí **solo `--host desktop`**, y `preview` pide tu permiso (`ask`). Sigue el flujo `status` → abrir/recargar → captura de `authoring.md` y su ciclo de capturas (`authoring/preview.md`, `authoring/screenshot-review.md`). **El host `service` queda fuera de alcance** (usa workspace/credenciales). Si Desktop no está disponible o hay `hasUnsavedChanges: true`, declara **"validación visual pendiente manual en Desktop"**: nunca la reportes como verificada (`limites-duros.md`).

## Reglas de arbitraje

- Fuera de alcance del agente: modo `management` (subir/publicar/rebind del informe), `bindConnection` y credenciales. Documenta el paso manual.
- `model-binding` upstream: el `.Report` se enlaza al modelo local por ruta (`byPath`), no se rebindea a un workspace.
- El PBIR sigue en preview: ante conflicto entre una guía upstream y el `$schema` público, gana el `$schema`.
- Cabecera `x-ms-fabric-skill`: solo aplica a llamadas a `api.fabric.microsoft.com`, que este skill no hace.
