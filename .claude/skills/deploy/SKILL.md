---
name: deploy
description: Despliega el informe al workspace de Power BI/Fabric, ramificado por el escenario de licencia del proyecto. Invócalo solo después de que el PR haya sido revisado y mergeado por un humano — el agente nunca despliega desde una rama sin mergear a menos que se le pida explícitamente un entorno de pruebas.
---

Lee `.claude/project-config.json` para conocer `escenario` antes de decidir cómo desplegar. Si no existe o `escenario` está vacío, detente e invoca `requirements-intake` primero — no asumas.

## Escenario A — Pro puro (shared capacity)

No existen XMLA write, Git de workspace, ni Deployment Pipelines en shared capacity — no los propongas.

1. Despliega vía Fabric REST item-definition APIs, usando `FabricPS-PBIP` o `fabric-cicd` (`tools/deploy.ps1`) con un Service Principal.
   - **`FabricPS-PBIP`**: módulo PowerShell alojado en `microsoft/Analysis-Services` (`pbidevmode/fabricps-pbip/`, MIT-equivalente, sample de Microsoft **sin soporte oficial de producto**). Confirmado por inspección de su README publicado: depende de `Az.Accounts` para autenticación; auth por SP con `Set-FabricAuthToken -servicePrincipalId "<AppId>" -servicePrincipalSecret "<AppSecret>" -tenantId "<TenantId>" -reset`; funciones principales `Import-FabricItems`/`Export-FabricItems` (todo el workspace) e `Import-FabricItem`/`Export-FabricItem` (item a item, necesario para bindear explícitamente `semanticModelId` al importar el `.Report` después del `.SemanticModel`). Nota del propio README: solo soporta el formato PBIP producido por Power BI Desktop desde marzo 2024 en adelante.
   - **`fabric-cicd`**: librería Python del mismo repo `microsoft/fabric-cicd` (PyPI `pip install fabric-cicd`, MIT, activamente mantenida). Alternativa a `FabricPS-PBIP` cuando el pipeline de despliegue ya es Python en vez de PowerShell.
   - **Confirmado en dogfooding real contra un tenant/workspace Power BI Pro real** (no solo por inspección): App Registration + client secret + toggle "Service principals can use Fabric APIs" habilitado (rol de administrador de tenant) + SP añadido como Contributor del workspace. `tools/deploy.ps1` (implementación real, no placeholder) descarga `FabricPS-PBIP`, se autentica con `Set-FabricAuthToken -servicePrincipalId/-servicePrincipalSecret/-tenantId`, e invoca `Import-FabricItems -workspaceId -path src\` sobre el `.pbip` completo del sandbox. Resultado real: dos items creados en el workspace (`SemanticModel` y `Report`), confirmados también visualmente abriendo el report en el servicio.
   - **Bug real encontrado y corregido**: `FabricPS-PBIP` requiere **PowerShell 7.1+** — falla con `Modules_InsufficientPowerShellVersion` bajo Windows PowerShell 5.1 (la versión que trae Windows por defecto y la que usan los hooks de esta misma plantilla). Instala PowerShell 7 (`winget install Microsoft.PowerShell`) e invoca el script con `pwsh`, no con `powershell`. Nota aparte: tras un `winget install`, una terminal ya abierta no recoge el PATH actualizado — hace falta abrir una terminal nueva (mismo patrón de "el proceso no hereda cambios de entorno posteriores a su arranque" ya documentado para `TABULAR_EDITOR_PATH`).
   - **Nunca ejecutes `tools/deploy.ps1` desde una sesión de Claude Code** — pide el Client Secret por un prompt seguro (`Read-Host -AsSecureString`) precisamente para que el agente nunca lo vea; ejecútalo siempre en una terminal del usuario.
   - **El despliegue vía item-definition API publica estructura, no datos.** Confirmado: tras `Import-FabricItems`, el report abre sin error y la estructura del modelo (tablas/medidas) está bien enlazada, pero el caché de filas del semantic model queda vacío hasta un refresco explícito — y ese refresco es un paso manual separado del despliegue, fuera del alcance de este skill (`limites-duros.md`: nunca gestiones credenciales ni gateway). Si el origen de datos del modelo es un fichero **local** de una máquina (como en el sandbox: `Financial Sample.xlsx` bajo `C:\Program Files\WindowsApps\...`), el refresco además es **imposible sin un gateway on-premises** apuntando a esa ruta — no es un problema de credenciales mal introducidas, es que el servicio no tiene ninguna vía de alcanzar un fichero local sin él. En un proyecto real con un origen ya alcanzable desde la nube (SQL Server con gateway existente, SharePoint, almacenamiento cloud) este paso sí sería viable, simplemente no se pudo probar con este sandbox. Documenta esto siempre como paso manual pendiente tras el deploy, nunca como "desplegado y listo".
2. Si no hay pipeline configurado en el repo destino, documenta el publish manual desde Desktop como alternativa y decláralo explícitamente como paso humano, no lo ejecutes tú.
3. Antes de desplegar, confirma que el modelo no supera ~1 GB — por encima de ese umbral, Pro puro deja de ser viable y hay que replantear el escenario con el usuario. **Tampoco verificado en la práctica** (el sandbox de dogfooding usa un dataset de ejemplo muy por debajo de ese límite) — es una cifra documentada por Microsoft, no observada aquí.

## Escenario B — Premium / PPU / Fabric capacity

1. Si el repo destino usa GitHub: Git de workspace conecta la workspace a GitHub; GitHub Actions valida (Tabular Editor CLI + BPA) y promueve.
2. Si usa Azure DevOps: Azure Pipelines valida (Tabular Editor CLI + BPA) y promueve con Deployment Pipelines Dev→Test→Prod.
3. XMLA write habilitado — requiere el toggle activo, rol Contributor+ y enhanced metadata en el workspace de destino; no lo asumas activo sin comprobarlo.
4. Direct Lake solo si los datos están en OneLake y así se decidió en `requirements-intake`; sin fallback a DirectQuery si es Direct Lake over OneLake (a diferencia de Direct Lake over SQL Endpoint).

## Reglas comunes a ambos escenarios

- Nunca gestiones credenciales, cadenas de conexión con secretos, ni configuración de gateway como parte de este despliegue — eso vive en el servicio o en Key Vault/GitHub Secrets, nunca en un fichero que tú escribes.
- No introduzcas herramientas de pago (Tabular Editor 3, DAX Optimizer, etc.) sin autorización explícita del usuario, incluso si simplificarían el despliegue.
- Este skill nunca hace merge de PR — el merge es siempre un gate humano previo a invocar `deploy`.
