---
name: temas
description: Crea o importa un theme JSON para el informe. Invócalo antes de empezar visuales-pbir o diseno-informe, para tener el tema fijado primero. Punto de entrada único para temas; este skill decide cuándo leer el upstream.
---

Lee `files/context/temas.md` antes de crear/editar el theme.

## Upstream (delegación del "cómo")

Entra siempre por este skill; **no invoques `powerbi-report-cli` directamente**. Lee solo lo necesario, en modo `design` (decisión) y `authoring` (aplicación):

- Dirección de color y tema: [color.md](../powerbi-report-cli/references/design/color.md) y la base [assets/base.json](../powerbi-report-cli/references/design/assets/base.json) como punto de partida.
- Mecánica: [theming.md](../powerbi-report-cli/references/authoring/theming.md); si el informe ya existe y cambia de marca, [re-theming.md](../powerbi-report-cli/references/authoring/re-theming.md). Codificación de tema con `powerbi-report-author theme encode` (en `allow`).
- Estrategia de color en visuales: [color-strategy.md](../powerbi-report-cli/references/authoring/color-strategy.md).

## Qué hacer

1. Referencia siempre el `$schema` oficial de `microsoft/powerbi-desktop-samples` (Report Theme JSON Schema) para validación in-line en VS Code.
2. Solo `name` es obligatorio; el resto (`firstLevelElements`, `secondLevelElements`, `thirdLevelElements`, `fourthLevelElements`, `background`, `secondaryBackground`) es opcional pero debe justificarse con los datos/marca del proyecto, no rellenarse por rellenar.
3. Verifica ratios de contraste WCAG (**≥4,5:1** texto normal) y prueba mentalmente/con un simulador de daltonismo si tienes forma de hacerlo — no uses el color como único canal de codificación.
4. Versiona el theme JSON en `themes/` (la copia que el informe referencia desde PBIR se alinea con ésta; no dejes dos temas divergentes).

## Reglas de arbitraje

- Si la guía upstream propone una paleta/tono distinto del de `requirements-intake` o de la marca del cliente, mandan los requisitos cerrados; el upstream solo aporta método.
- Fuera de alcance del agente: publicar o rebindear el informe (`management`), credenciales (`limites-duros.md`).

## Cierre

Antes de desplegar, aplica el tema a un report representativo (o al menos a la primera página construida) y confírmalo visualmente — un theme JSON válido según schema puede seguir siendo ilegible en la práctica. La captura se hace con el flujo Desktop de `visuales-pbir` (con tu permiso); si Desktop no está disponible, declara **"verificación visual pendiente manual"**, nunca como verificada.
