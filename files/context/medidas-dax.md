# Medidas/KPIs y DAX

**Scripting C# con Tabular Editor 2 (CS-Script)**: el motor es antiguo — por defecto **no soporta string interpolation ni local functions**. Usa concatenación con `+`:

```csharp
foreach(var c in Selected.Columns) {
    var m = c.Table.AddMeasure(
        "Sum of " + c.Name,
        "SUM(" + c.DaxObjectFullName + ")",
        c.DisplayFolder);
    m.FormatString = "0.00";
    m.Description = "Auto-generated measure";
}
```

`using` para acortar clases y `#r "assembly"` para ensamblados externos sí están soportados. Si el script se guarda como macro, no puede contener métodos locales con modificadores de acceso (`public`/`static`). Si necesitas C# moderno (incluida string interpolation), activa el compilador **Roslyn** (File > Preferences > General, Tabular Editor 2.12.2+) — no asumas que está activo por defecto.

**DAX UDFs** (GA desde junio 2026, requieren compatibility level 1702+):
```tmdl
createOrReplace
	function AddTax = (amount: NUMERIC) => amount * 1.1
```
Se guardan en `functions.tmdl`, se documentan con `///`, `@param` y `@returns`, y se reutilizan entre modelos copiando el TMDL. **No están soportadas en Azure Analysis Services ni SQL Server Analysis Services** — no las propongas si el destino es alguno de esos motores.
