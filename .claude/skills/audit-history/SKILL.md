---
name: audit-history
description: Dispara bajo demanda al subagente merge-audit para detectar (no prevenir) merges en main/dev sin PR asociada o con CI en rojo. Relevante sobre todo en repos privados de GitHub Free, donde branch protection no existe y tools/git-hooks/ no puede cerrar el hueco del botón Merge de la web. Invócalo periódicamente o al cierre de una unidad de trabajo grande, nunca como sustituto de branch protection real.
---

Este skill es el disparador manual de una auditoría de historial — no hay ningún hook automático equivalente, porque no hay ningún evento local (commit, push, edición de fichero) al que enganchar una detección de "merge indebido hecho desde la web de GitHub". Léelo junto a `files/context/control-versiones.md`, sección "Escenario privado (Free) — capa de gobernanza local", si no lo has hecho ya.

## Cuándo usarlo

- Periódicamente en un repo marcado `visibilidad: "privado"` (p. ej. al empezar cada unidad de trabajo grande, o cuando el usuario lo pida explícitamente) — es la única forma de saber si el hueco que `tools/git-hooks/` no puede cerrar se ha usado de verdad.
- Tras cualquier sospecha concreta ("¿se mergeó esa PR con el CI en rojo?", "¿quién tocó `main` directamente?").
- **No** tiene sentido invocarlo en un repo público con branch protection real activa (`tools/setup-github.ps1` ya aplicado con éxito) — ahí GitHub ya impide técnicamente lo que esto solo puede detectar después.

## Qué hacer

1. Invoca al subagente `merge-audit` indicándole las ramas a revisar (`main`, `dev`, o ambas) y, si el usuario lo pidió por un motivo concreto, ese contexto.
2. Si el subagente reporta hallazgos, no los corrijas en silencio: preséntaselos al usuario tal cual, con el SHA y el motivo exacto, y deja que decida si hace falta una acción (revert, comunicación al cliente, ajuste de permisos del repo).
3. Si el hallazgo revela que un clon concreto no tenía `tools/git-hooks/` instalado, recuerda invocar `local-git-guard` en ese clon — no asumas que ya está resuelto solo por haber detectado el problema.

## Qué NO hacer

- No presentes un informe "limpio" de `merge-audit` como prueba de que el repo está tan protegido como uno con branch protection real — solo prueba que, en la ventana revisada, no se detectó abuso; el hueco de la UI web sigue existiendo igual mañana.
