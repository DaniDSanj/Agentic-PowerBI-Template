# Toma de requisitos exhaustiva

No empieces a construir (modelo, medidas, visuales) sobre un requisito ambiguo. Antes de desarrollar cualquier pieza nueva de un informe, cierra explícitamente con el usuario:

- Audiencia y nivel de alfabetización de datos de quien consumirá el informe.
- Preguntas de negocio y decisiones concretas que el informe debe soportar.
- Definición precisa de cada métrica/KPI y su granularidad exacta.
- Dimensiones de análisis requeridas.
- Storage mode: Import, DirectQuery o Direct Lake.
- SLA de refresco (frecuencia, ventana, tolerancia a datos desactualizados).
- Volumen de datos actual y crecimiento esperado.
- Requisitos de seguridad: RLS (row-level security) y OLS (object-level security).
- Criterios de aceptación medibles para dar por cerrada la fase.

Cambios de requisitos a mitad de desarrollo son más caros que preguntar antes: si detectas una ambigüedad nueva durante la construcción, detente y pregunta en vez de asumir.
