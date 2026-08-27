# Modelo de datos (TMDL)

Relación:
```tmdl
relationship abc123-def
	fromColumn: Sales.CustomerKey
	toColumn: Customer.CustomerKey
	toCardinality: one
	crossFilteringBehavior: bothDirections
	isActive: false
```

Rol con RLS (vía UDF/expresión de filtro):
```tmdl
role 'Account Managers'
	modelPermission: read
	tablePermission Customers = RLS.ApplySimpleRLS('Customers'[Account Manager])
```

Calculation group (time intelligence):
```tmdl
createOrReplace
	table 'Time Intelligence'
		calculationGroup
			precedence: 1
			calculationItem YTD = CALCULATE(SELECTEDMEASURE(), DATESYTD('Calendar'[Date]))
			calculationItem QTD = CALCULATE(SELECTEDMEASURE(), DATESQTD('Calendar'[Date]))
			calculationItem MTD = CALCULATE(SELECTEDMEASURE(), DATESMTD('Calendar'[Date]))
			calculationItem Current = SELECTEDMEASURE()
		column 'Show as'
			dataType: string
			sourceColumn: Name
			sortByColumn: Ordinal
		column Ordinal
			dataType: int64
			summarizeBy: none
			sourceColumn: Ordinal
```

- Esquema estrella como convención por defecto; role-playing dimensions vía relaciones inactivas + `USERELATIONSHIP` en la medida, no vía tablas duplicadas.
- Fija siempre `discourageImplicitMeasures: true` y un `compatibilityLevel` explícito en `database.tmdl`.
- Reutiliza modelo entre proyectos copiando el `.tmdl` de una tabla y reconfigurando `relationships.tmdl` — no reconstruyas desde cero lo que ya existe validado en otro modelo.
