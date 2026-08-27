---
name: diseno-informe
description: Diseña el layout de una pestaña/página del informe evitando que "parezca hecho por IA". Invócalo tras tener tema y visuales base decididos, antes de fijar la disposición final de una página.
---

Lee `files/context/diseno.md` antes de proponer layout. Invoca al subagente `data-profiler` primero si no lo has hecho ya para esta página — el diseño debe partir de los datos reales y de la pregunta de negocio cerrada en `requirements-intake`, nunca de una plantilla genérica.

## Qué evitar activamente

Dashboards genéricos sin pregunta de negocio detrás, tarjetas KPI idénticas repetidas, exceso de colores, títulos autogenéricos, layout sin grid ni jerarquía, todo el ancho igual.

## Qué hacer

1. Grid consistente: misma altura/anchura en visuales de la misma fila.
2. Espaciado deliberado, tipografía jerárquica, canvas background cuidado (coherente con el theme de `temas`).
3. Elección de tipo de gráfico apoyada en criterio de referentes reconocidos (Kurt Buhler/Data Goblins, Reid Havens, SQLBI) — como fuente de criterio, no como dependencia técnica a instalar.
4. Cada visual de la página debe trazarse a una pregunta de negocio concreta cerrada en `requirements-intake`; si no puedes trazarlo, cuestiona si el visual debe estar ahí antes de construirlo.

## Cierre

Tras fijar el layout, cualquier `visual.json`/`page.json` tocado pasa igualmente por la validación de `visuales-pbir` (hook `post-edit-pbir` + subagente `pbir-schema-validator`) antes de commit.
