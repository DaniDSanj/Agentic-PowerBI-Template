---
name: requirements-intake
description: Bootstrap del proyecto y toma de requisitos exhaustiva. Invócalo al empezar a trabajar en un informe nuevo, o cuando falte .claude/project-config.json, o cuando detectes una ambigüedad de requisitos a mitad de desarrollo.
---

## Paso 0 — Bootstrap (solo si `.claude/project-config.json` no existe)

No asumas nada del escenario de licencia por el nombre del cliente, del repo, o por costumbre de proyectos anteriores. Sigue `files/context/escenario-licencia.md` al pie de la letra:

1. Pregunta explícitamente al usuario qué escenario aplica (A — Pro puro / B — Premium, PPU o Fabric capacity), citando la tabla de capacidades del fichero de contexto si hay duda sobre qué implica cada uno.
2. Pregunta también la visibilidad del repo en GitHub (pública/privada) si no es evidente por el contexto (p. ej. `gh repo view --json visibility`) — no la asumas. Si es privada, ten presente que branch protection y secret scanning nativo no están disponibles en GitHub Free (`files/context/control-versiones.md`, sección "Escenario privado (Free)") y que tras este bootstrap corresponde invocar el skill `local-git-guard`.
3. Copia `project-config.example.json` (de este mismo `.claude/`) a `.claude/project-config.json` y rellena `proyecto`, `escenario`, `storageMode` (una vez conocido, ver Paso 1), `visibilidad` (`"publico"`|`"privado"`) y `fechaBootstrap`.
4. Este fichero es lo que leen el resto de skills/hooks para bifurcar su comportamiento — no lo dejes con placeholders (`A|B`, cadenas vacías).
5. Si `visibilidad` es `"privado"`, invoca ahora el skill `local-git-guard` para activar `tools/git-hooks/` en este clon — no lo dejes pendiente para más adelante, los hooks no protegen nada hasta que `core.hooksPath` esté configurado.
6. **Patchea `.claude/settings.json` con los valores específicos de esta máquina/cliente** — nunca asumas que los valores heredados de la plantilla sirven tal cual, y nunca dejes en el repo del cliente una ruta absoluta de una máquina distinta:
   - Pregunta o detecta la ruta real de `TabularEditor.exe` en esta máquina (`Get-Command TabularEditor.exe` o localiza la instalación de winget) y fija `env.TABULAR_EDITOR_PATH` en `.claude/settings.json` en consecuencia — solo si `TabularEditor.exe` no está ya en el `PATH`.
   - Confirma si los hooks deben invocarse con `powershell.exe` o `pwsh` según lo que exista en esta máquina (algunas dependencias del skill `deploy`, como `FabricPS-PBIP`, requieren PowerShell 7.1+; los hooks en sí no, pero mantén consistencia).
   - Este parcheo es el único momento del flujo en el que un valor de entorno concreto se commitea al repo del cliente — no lo hagas antes (no debe llegar nunca a la plantilla compartida) ni lo dejes para después (los hooks fallarán silenciosamente hasta que se haga).

## Paso 1 — Toma de requisitos exhaustiva

Aplica `files/context/toma-requisitos.md` íntegro. No avances a `pbip-scaffold` sin cerrar explícitamente con el usuario, por escrito en la conversación:

- Audiencia y nivel de alfabetización de datos.
- Preguntas de negocio y decisiones concretas que el informe debe soportar.
- Definición precisa de cada métrica/KPI y su granularidad exacta.
- Dimensiones de análisis requeridas.
- Storage mode (Import / DirectQuery / Direct Lake) — condicionado por el escenario de licencia del Paso 0 (Direct Lake no aplica en A).
- SLA de refresco (frecuencia, ventana, tolerancia a datos desactualizados).
- Volumen de datos actual y crecimiento esperado (recuerda el umbral de 1 GB en Pro puro).
- Requisitos de RLS/OLS.
- Criterios de aceptación medibles para dar la fase por cerrada.

Antes de aceptar cualquiera de estos puntos tal cual lo plantea el usuario, aplica `files/context/comportamiento-critico.md`: identifica al menos un supuesto no comprobado y decláralo antes de darlo por bueno.

## Paso 2 — Cierre

Resume en un único mensaje todos los puntos cerrados (no disperses la confirmación en varios turnos) y solo entonces invoca el skill `pbip-scaffold`. Si durante el desarrollo posterior aparece una ambigüedad nueva sobre cualquiera de estos puntos, vuelve a este skill en vez de asumir — un cambio de requisitos a mitad de desarrollo es más caro que preguntar antes.
