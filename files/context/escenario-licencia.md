# Detección del escenario de licencia

Power BI/Fabric tiene una divisoria de capacidades **de licencia, no de herramienta**, que determina qué es automatizable. Al empezar a trabajar en un repo instalado desde esta plantilla, si no es evidente por el contexto, **pregunta explícitamente** qué escenario aplica antes de asumir capacidades:

| Capacidad | Escenario A — Pro puro (shared capacity) | Escenario B — Premium / PPU / Fabric capacity |
|---|---|---|
| Git integration de workspace | No disponible | Disponible |
| XMLA endpoint read/write | No existe (shared capacity no tiene XMLA) | Disponible (write requiere toggle + rol Contributor+ + enhanced metadata) |
| Deployment Pipelines | No disponible | Disponible (una workspace Premium por stage) |
| Direct Lake | No aplica | Disponible (si los datos están en OneLake) |
| Publicación programática | Fabric REST item-definition APIs (license-gated, no capacity-gated) o publish manual desde Desktop | Git de workspace + Deployment Pipelines Dev→Test→Prod |
| Pruebas DAX sin Desktop | No hay XMLA; probar tras publish o en Desktop | XMLA vía `semantic-link-labs.evaluate_dax` con aserciones pytest |

Reglas derivadas:
- En Escenario A **nunca** propongas XMLA write, Git de workspace o Deployment Pipelines: no existen en Pro puro.
- En Escenario A, despliega vía Fabric item-definition APIs (herramientas open source `FabricPS-PBIP`/`fabric-cicd`, sin soporte oficial de Microsoft — valida en cada release) o documenta el publish manual desde Desktop.
- Si el cliente adquiere PPU o una capacidad F, ese es el umbral para migrar de A a B: activar XMLA write, Git de workspace y pipelines.
- Modelos que superen 1 GB dejan de ser viables en Pro puro.
