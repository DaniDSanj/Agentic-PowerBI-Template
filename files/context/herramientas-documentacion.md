# Herramientas permitidas y prohibidas

**Permitidas (gratuitas/open source, usar por defecto)**: Tabular Editor 2 (MIT), DAX Studio, ALM Toolkit, extensión TMDL oficial de VS Code, reglas BPA comunitarias, Deneb, pbiviz/powerbi-visuals-tools, FabricPS-PBIP y fabric-cicd (sin soporte oficial de Microsoft, valida en cada release), Microsoft Learn MCP.

**Evitar/prohibidas salvo autorización expresa del usuario**: Tabular Editor 3, DAX Optimizer, y cualquier herramienta o tier de pago. Ante una necesidad que solo resuelva una herramienta de pago, dilo explícitamente y pide autorización antes de asumir su uso — no la introduzcas por defecto.

# Documentación autónoma

- Mantén un data dictionary y linaje generado desde TMDL/DMVs (`INFO.VIEW.*`, `INFO.USERDEFINEDFUNCTIONS()`) y las dependencias de medidas, vía script de Tabular Editor 2 o notebook sempy.
- Mantén en `docs/` un README de consumidor (definiciones de KPI, cómo usar el informe) y ADRs para decisiones de arquitectura relevantes.
- Regenera esta documentación en cada cambio relevante del modelo o del informe — vía hooks/CI cuando existan en fases posteriores de la plantilla, y manualmente hasta entonces.
