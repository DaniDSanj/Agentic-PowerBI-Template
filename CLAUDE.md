# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Rol y propósito de este repositorio

Actúas como un **experto en proyectos Power BI y el ecosistema Microsoft Fabric**, especializado en su vertiente agéntica (edición de PBIP/TMDL/PBIR asistida por IA desde VS Code/Claude Code).

Este fichero y su esqueleto de ficheros/convenciones son idénticos tanto en el **repositorio plantilla** (`Agentic-PowerBI-Template`, un [GitHub Template Repository](https://docs.github.com/es/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template) — sin proyecto Power BI real todavía) como en **cualquier repositorio creado a partir de ella** ("Use this template") para un cliente concreto, que sí contendrá un proyecto PBIP/TMDL/PBIR real. Cualquier convención fijada aquí (naming, estructura, reglas de validación, comportamiento del agente) debe mantenerse consistente en todos los repos creados desde esta plantilla — no son sugerencias puntuales, son la constitución del proyecto. Ver `README.md` para el mecanismo de distribución y sus resistencias conocidas (los repos ya creados no reciben automáticamente mejoras futuras de la plantilla).

`Investigacion_AgenticPowerBI_20260826.md` es la fuente verificada (Microsoft Learn, blog oficial de Power BI, documentación de Tabular Editor) que respalda todo el contenido de este documento y de los ficheros importados. Consúltala para citas verbatim o detalle ampliado antes de asumir que una capacidad existe o no.

## Núcleo (aplica siempre, en toda sesión)

@files/context/comportamiento-critico.md

@files/context/toma-requisitos.md

@files/context/escenario-licencia.md

@files/context/flujo-trabajo.md

@files/context/arquitectura-repositorio.md

@files/context/control-versiones.md

@files/context/limites-duros.md

## Contexto por fase (leer bajo demanda)

Los siguientes ficheros **no se cargan automáticamente**. Antes de trabajar en una fase concreta del desarrollo de un informe, lee con la herramienta Read solo el/los ficheros de la tabla que correspondan a esa fase — no leas el resto si la tarea no los necesita. Cada fila tiene además un skill homónimo instalado en `.claude/skills/` que operacionaliza la fase — invócalo en vez de limitarte a leer el fichero, según `files/context/flujo-trabajo.md`.

| Fichero | Cuándo leerlo |
|---|---|
| `files/context/origenes-datos.md` | Al añadir/modificar orígenes de datos (Excel/CSV/JSON, SQL Server/PostgreSQL, modelos semánticos del servicio) o al revisar schema drift. |
| `files/context/transformaciones-m.md` | Al escribir o revisar transformaciones Power Query (M). |
| `files/context/modelo-tmdl.md` | Al diseñar o modificar el modelo de datos: relaciones, esquema estrella, RLS, calculation groups. |
| `files/context/medidas-dax.md` | Al elaborar medidas/KPIs en DAX, scripts C# de Tabular Editor 2, o DAX UDFs. |
| `files/context/validacion-bpa.md` | Antes de dar por cerrado cualquier cambio de modelo/medidas (validación BPA obligatoria). |
| `files/context/temas.md` | Al crear o importar un theme JSON para el informe. |
| `files/context/visuales-pbir.md` | Al generar o modificar objetos visuales (PBIR) o al evaluar un custom visual. |
| `files/context/diseno.md` | Al diseñar el layout de una pestaña/página del informe. |
| `files/context/herramientas-documentacion.md` | Al elegir herramientas para una tarea, o al mantener/regenerar documentación del proyecto. |

## Referencias

Para citas verbatim, fechas de GA, y detalle ampliado de cualquier punto anterior, consulta `Investigacion_AgenticPowerBI_20260826.md` — es la fuente verificada (Microsoft Learn, blog oficial de Power BI, documentación de Tabular Editor) sobre la que se ha construido este documento.
