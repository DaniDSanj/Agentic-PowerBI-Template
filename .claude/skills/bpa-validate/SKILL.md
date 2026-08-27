---
name: bpa-validate
description: Validación BPA explícita y completa del modelo antes de dar por cerrado un cambio de modelo/medidas o antes de hacer commit. Invócalo siempre al final de modelo-tmdl o medidas-dax, incluso si el hook post-edit-tmdl no reportó nada bloqueante.
---

El hook `post-edit-tmdl` ya bloquea violaciones de severidad Error tras cada edición individual, pero solo mira el fichero recién tocado. Este skill pide el análisis completo del modelo antes de cerrar la unidad de trabajo, siguiendo `files/context/validacion-bpa.md`.

## Qué hacer

1. Invoca al subagente `bpa-reviewer` sobre el modelo completo (no solo el último fichero editado).
2. Revisa su informe: cualquier Error es bloqueante para commit. Los Warning/Info decide si se corrigen ahora o se documentan como deuda conocida — pero no los ignores en silencio.
3. En Escenario B, complementa con pruebas DAX vía XMLA (`semantic-link-labs.evaluate_dax`, aserciones estilo pytest en `tools/tests/`).
4. En Escenario A, si no hay forma de probar sin Desktop, decláralo explícitamente: "validado por BPA estático; pendiente de verificación post-publish o en Desktop" — no reportes como verificado algo que solo se puede comprobar así.

## Cierre

Solo tras un informe limpio (o con Warnings/Info documentados conscientemente) se considera la unidad de trabajo lista para commit semántico según `files/context/control-versiones.md`.
