---
name: docs-sync
description: Regenera bajo demanda la documentación autónoma del proyecto (data dictionary, linaje de medidas, README de consumidor, ADRs). Normalmente se dispara solo (hook post-commit-docs tras un commit de modelo/informe); invoca este skill explícitamente cuando quieras regenerarla fuera de ese momento.
---

Este skill es el disparador manual de lo mismo que hace el hook `post-commit-docs` automáticamente. Lee `files/context/herramientas-documentacion.md` (sección "Documentación autónoma") si no lo has hecho ya.

## Qué hacer

1. Invoca al subagente `docs-writer` con el alcance que corresponda: modelo completo, o solo lo tocado desde el último commit.
2. Si vas a registrar una decisión de arquitectura (ADR), pásale explícitamente la decisión y su motivación — el subagente no genera ADRs especulativos por su cuenta.
3. Revisa el resultado antes de commitearlo: confirma que no se han inventado descripciones de negocio para medidas/tablas sin contexto disponible (deben quedar marcadas como pendientes, no rellenadas).

## Cuándo usarlo explícitamente en vez de confiar solo en el hook

- Acabas de importar/copiar un modelo completo de otro proyecto y quieres regenerar toda la documentación de una vez, no solo el diff del último commit.
- El hook `post-commit-docs` no está configurado o disponible en este entorno (verifícalo en `.claude/settings.json`).
