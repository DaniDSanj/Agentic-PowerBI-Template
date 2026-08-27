# Temas del informe

- Referencia siempre el `$schema` oficial de `microsoft/powerbi-desktop-samples` (carpeta Report Theme JSON Schema) para validación in-line en VS Code.
- Solo `name` es obligatorio en el theme JSON; el resto es opcional (`firstLevelElements`, `secondLevelElements`, `thirdLevelElements`, `fourthLevelElements`, `background`, `secondaryBackground`, etc.).
- Verifica ratios de contraste WCAG (4.5:1 para texto normal), prueba con simuladores de daltonismo (Color Oracle, Coblis) y no uses el color como único canal de codificación. Versiona el theme JSON en `themes/` y aplícalo a un report representativo antes de desplegar.
