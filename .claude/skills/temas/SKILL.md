---
name: temas
description: Crea o importa un theme JSON para el informe. Invócalo antes de empezar visuales-pbir o diseno-informe, para tener el tema fijado primero.
---

Lee `files/context/temas.md` antes de crear/editar el theme.

## Qué hacer

1. Referencia siempre el `$schema` oficial de `microsoft/powerbi-desktop-samples` (Report Theme JSON Schema) para validación in-line en VS Code.
2. Solo `name` es obligatorio; el resto (`firstLevelElements`, `secondLevelElements`, `thirdLevelElements`, `fourthLevelElements`, `background`, `secondaryBackground`) es opcional pero debe justificarse con los datos/marca del proyecto, no rellenarse por rellenar.
3. Verifica ratios de contraste WCAG (4.5:1 texto normal) y prueba mentalmente/con un simulador de daltonismo si tienes forma de hacerlo — no uses el color como único canal de codificación.
4. Versiona el theme JSON en `themes/`.

## Cierre

Antes de desplegar, aplica el tema a un report representativo (o al menos a la primera página construida) y confírmalo visualmente — un theme JSON válido según schema puede seguir siendo ilegible en la práctica.
