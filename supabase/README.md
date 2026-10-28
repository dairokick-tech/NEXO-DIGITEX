# NOVA DIGITEX — configuración de Supabase

## Corregir el error `Could not find the table 'public.companies'`

La migración inicial tenía un error de sintaxis al final de la función `complete_sale`. PostgreSQL revierte toda la transacción cuando una migración falla; por eso pueden faltar todas las tablas. **El archivo inicial ya está corregido en GitHub.**

### Pasos para reparar el proyecto

1. Abre tu proyecto en [Supabase](https://supabase.com/dashboard).
2. En el menú del proyecto, entra en **SQL Editor** y crea una consulta nueva.
3. Abre el archivo [migración inicial corregida](./migrations/202610270001_initial.sql) en GitHub. Copia todo su contenido, desde el primer comentario hasta el final, y pégalo en SQL Editor.
4. Pulsa **Run**. Espera que termine. Si muestra un error, no sigas a la siguiente migración: copia el texto del error para diagnosticarlo.
5. Crea otra consulta nueva. Abre [migración de Superadministrador](./migrations/202610270002_platform_superadmin.sql), copia todo su contenido y pulsa **Run**.
6. En Supabase, abre **Authentication → Users** y confirma que tu cuenta ya existe.
7. Para asignar el rol global, en SQL Editor ejecuta esta consulta, sustituyendo el correo de ejemplo por el correo exacto de tu cuenta de inicio de sesión:

```sql
insert into public.platform_superadmins (user_id)
select id from auth.users where lower(email) = lower('TU_CORREO_DE_SUPERADMIN')
on conflict (user_id) do nothing;
```

Ejecuta ese último bloque solo tú, como propietario del proyecto Supabase. No lo pongas en el frontend ni compartas claves secretas.

8. Vuelve a abrir la aplicación y recárgala. Si el error persiste después de que ambas migraciones terminaron correctamente, abre **Project Settings → API** y confirma que la API usa el esquema `public`; luego en SQL Editor ejecuta `NOTIFY pgrst, 'reload schema';`.

## Importante

- No compartas la contraseña de base de datos, la clave `service_role` ni tokens de administración.
- La clave `sb_publishable` es una clave pública de cliente; la protección real depende de las políticas RLS.
- El proyecto actual usa una base PostgreSQL compartida con aislamiento por empresa (RLS); no crea una base física distinta por empresa.
- La migración SQL no se ejecuta automáticamente por estar guardada en GitHub. Debes ejecutarla en el SQL Editor de tu propio proyecto; no tengo acceso a tu sesión privada de Supabase para pulsar Run por ti.
- Hasta terminar estos pasos y probar altas/ventas, NOVA DIGITEX debe considerarse un prototipo, no un POS listo para operaciones comerciales reales.
