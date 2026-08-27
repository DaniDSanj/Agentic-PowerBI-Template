# Orígenes de datos y schema drift

Las expresiones M viven en `definition/expressions.tmdl` (parámetros y queries compartidas) y en las particiones de cada tabla:

```tmdl
expression SqlEndpoint = "server.database.windows.net"
	meta [IsParameterQuery=true, IsParameterQueryRequired=true, Type="Text"]
	lineageTag: abc-123
	queryGroup: Parameters
```

- **Ficheros individuales (Excel/CSV/JSON)**: edita el `Source` M en la partición; parametriza rutas/carpetas; solo import.
- **SQL (SQL Server/PostgreSQL)**: define server/database como parámetros para permitir rebinding por entorno; soporta Import y DirectQuery.
- **Modelos semánticos del servicio** (live connection / composite / DirectQuery sobre modelo semántico): en composite el modelo remoto se referencia y se pueden añadir tablas locales y relaciones; Direct Lake solo aplica en Escenario B.
- **Detección de schema drift**: en Escenario A, script de Tabular Editor 2 (`Model.Tables["X"].RefreshDataColumns()`) refresca metadatos desde el origen (requiere conexión OLE DB accesible) y un diff de Git posterior revela columnas nuevas/eliminadas; en Escenario B, notebook Fabric con `sempy`/`semantic-link-labs` (`evaluate_dax`, `list_columns`) compara el esquema del origen contra el modelo tras cada refresh, al estilo pytest.

**Regla dura de seguridad**: el agente **nunca** gestiona credenciales, cadenas de conexión con secretos, ni configuración de gateway. Eso se configura en el servicio (Manage gateways / dataset settings) o vía Service Principal en pipeline, con secretos en Azure Key Vault o GitHub Secrets — nunca en TMDL ni en ningún fichero versionado.
