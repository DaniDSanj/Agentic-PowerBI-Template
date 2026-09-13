---
name: docs-sync
description: Regenera bajo demanda la documentación autónoma del proyecto — data dictionary/linaje/README de consumidor/ADRs en un repo cliente con modelo PBI, o CHANGELOG/decisiones sobre el propio mecanismo en un repo sin modelo todavía (como esta plantilla). Normalmente se dispara solo (hook post-commit-docs tras un commit relevante); invoca este skill explícitamente cuando quieras regenerarla fuera de ese momento.
---

Este skill es el disparador manual de lo mismo que hace el hook `post-commit-docs` automáticamente. Lee `files/context/herramientas-documentacion.md` (sección "Documentación autónoma") si no lo has hecho ya.

## Qué hacer

1. Invoca al subagente `docs-writer` con el alcance que corresponda: modelo completo, o solo lo tocado desde el último commit. El propio subagente detecta si aplica modo cliente (existe `*.SemanticModel` bajo `src/`) o modo plantilla (no existe) — no se lo indiques tú salvo un caso ambiguo real.
2. Si vas a registrar una decisión de arquitectura (ADR en modo cliente, o decisión de mecanismo en modo plantilla), pásale explícitamente la decisión y su motivación — el subagente no genera ninguna de las dos de forma especulativa por su cuenta.
3. Revisa el resultado antes de commitearlo: confirma que no se han inventado descripciones de negocio para medidas/tablas (modo cliente) ni motivos de cambio (modo plantilla) sin contexto disponible — deben quedar marcadas como pendientes, no rellenadas.

## Cuándo usarlo explícitamente en vez de confiar solo en el hook

- Acabas de importar/copiar un modelo completo de otro proyecto y quieres regenerar toda la documentación de una vez, no solo el diff del último commit.
- El hook `post-commit-docs` no está configurado o disponible en este entorno (verifícalo en `.claude/settings.json`).
