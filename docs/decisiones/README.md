---
tags: [plantilla, adr]
date: 2026-09-13
---

# Decisiones de arquitectura de la plantilla

ADRs (`NNNN-titulo.md`) sobre decisiones del **mecanismo** de `Agentic-PowerBI-Template` (por qué `dev` es rama de integración obligatoria, por qué el repo es público, etc.) — la contraparte de `docs/adr/` en un repo cliente, pero sobre la plantilla en sí en vez de sobre un modelo/informe concreto.

Generado por el subagente `docs-writer` (modo plantilla), solo cuando quien lo invoca le pasa explícitamente una decisión a registrar — nunca de forma especulativa (ver `.claude/agents/docs-writer.md`). Carpeta vacía por ahora: las decisiones ya tomadas hasta la fecha están narradas en `docs/CHANGELOG.md` y en `files/context/control-versiones.md`, pero no se han registrado todavía aquí como ADRs formales.
