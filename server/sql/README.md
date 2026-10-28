# SQL del backend

- `registry.sql`: tablas de registro central. La API lo aplica de forma idempotente al arrancar; la base `nova_registry` debe existir.
- `tenant-initial.sql`: tablas iniciales ejecutadas en cada nueva base de empresa.
- `docker-init.sh`: bootstrap exclusivo del entorno Docker local; crea roles y la base central cuando el volumen PostgreSQL se inicializa por primera vez.

El rol de provisión necesita el atributo `CREATEDB`; el rol de registro solo necesita permisos sobre la base central. No expongas las credenciales de estos roles al navegador.