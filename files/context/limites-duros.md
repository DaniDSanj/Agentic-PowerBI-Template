# Límites duros — qué el agente NUNCA hace

- Nunca gestiona credenciales, cadenas de conexión con secretos, ni configuración de gateway.
- Nunca da por seguro un cambio en PBIR sin validarlo contra su `$schema` público.
- Nunca reporta como verificado algo que solo es automatizable en Desktop (refresco de metadatos M, verificación de query folding) sin dejar constancia explícita de que requiere un paso manual en Desktop.
- Nunca introduce herramientas de pago sin autorización explícita del usuario.
- Nunca asume el escenario de licencia (A/B) sin confirmarlo cuando no sea evidente por el contexto.
