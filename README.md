# NOVA DIGITEX

Sistema POS multiempresa y multirrubro. Cada empresa registrada debe recibir recursos propios y una tienda online inicializada automáticamente.

## Regla de creación de empresa

Al registrar una empresa, el backend debe:
1. Validar el usuario administrador y los datos de la empresa (incluido RUC cuando corresponda).
2. Registrar la solicitud con estado `provisioning` e identificador idempotente.
3. Crear una base de datos PostgreSQL exclusiva para esa empresa usando credenciales administrativas solo del servidor.
4. Ejecutar las migraciones iniciales dentro de esa base.
5. Crear el registro de tienda online, su slug único y configuración inicial.
6. Marcar la empresa como `active` únicamente si todos los pasos terminan correctamente.
7. Si falla un paso, marcar `provisioning_failed`, registrar el error sin secretos y permitir reintentar sin duplicar empresas, bases ni tiendas.

## Arquitectura

- `server/`: API Node.js/TypeScript para provisión segura de empresas, bases de datos y tiendas.
- `server/sql/`: esquema de registro central y esquema inicial por empresa.
- Base de registro central: guarda metadatos de empresas y el estado de provisión; nunca guarda contraseñas de clientes en texto plano.
- Base PostgreSQL por empresa: ventas, productos, inventario, clientes, caja, pedidos, usuarios y auditoría.
- Tienda online: URL propia con catálogo, precios, disponibilidad, carrito y pedidos. Los pedidos se guardan en la base de la empresa correspondiente.

## Requisitos para ejecutar el backend

- Node.js 20+
- PostgreSQL con permisos de creación de bases de datos para la cuenta de provisión.
- Variables de entorno configuradas en el servidor (ver `server/.env.example`).

**Importante:** GitHub Pages solo publica archivos estáticos; no puede crear bases PostgreSQL ni guardar secretos. El backend debe desplegarse en un servidor compatible. Nunca poner `DATABASE_ADMIN_URL`, contraseñas PostgreSQL ni claves de servicio en el frontend.

## Desarrollo

```bash
cd server
npm install
npm run dev
```

La API no debe considerarse lista para producción hasta añadir autenticación real, límites de uso, TLS, copias de seguridad, monitorización y pruebas de recuperación.

## Levantar el entorno de prueba con Docker

1. Instala Docker Engine y el complemento Docker Compose en un equipo o servidor.
2. Copia `.env.example` a `.env` y cambia las cuatro contraseñas/secretos por valores aleatorios largos.
3. Ejecuta `docker compose up --build -d`.
4. Comprueba `http://localhost:8080/health`.
5. Abre `http://localhost:8080/admin` para registrar una empresa y generar su tienda.
6. La tienda se abre en `http://localhost:8080/tienda/tu-slug`.

Este despliegue local crea la base central automáticamente al inicializar el volumen PostgreSQL. El esquema central se aplica al arrancar la API. Si cambias las contraseñas después de crear el volumen, tendrás que actualizar los roles existentes en PostgreSQL; las variables de inicialización solo se aplican al crear un volumen nuevo.

**Para publicar en Internet:** despliega el conjunto en un servidor privado con Docker, dominio y HTTPS. No publiques el puerto de PostgreSQL. Usa un firewall, copias externas y un mecanismo de rotación de secretos. El alta de empresas es administrativa; no expongas el secreto en páginas públicas.
