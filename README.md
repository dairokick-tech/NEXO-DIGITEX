# NEXO DIGITEX
ERP + SaaS para negocios — interfaz clara, adaptable a Android y computadora.

## Estado actual
- Interfaz principal en `index.html`.
- Autenticación conectada a Supabase Auth: iniciar sesión, registro de cuenta y cierre de sesión.
- Solicitud de alta de empresa con estado inicial `pending`.
- La empresa no se considera aprobada hasta que un superadministrador la cambie de estado.
- Esquema inicial de PostgreSQL aplicado al proyecto Supabase conectado.
- Las pantallas de los módulos empresariales en `index.html` siguen pendientes de terminar y probar.

## POS local disponible en esta rama
- Abre `pos.html` para usar el punto de venta local.
- Permite registrar/editar productos, buscar por nombre/código, crear ventas, descontar stock, imprimir un ticket interno, consultar el historial y exportar/importar respaldo JSON.
- La app no necesita bibliotecas externas para las operaciones del POS.
- Incluye manifiesto PWA y caché de la pantalla POS para abrirla sin conexión después de cargarla al menos una vez en un hosting HTTPS compatible.
- Los datos se guardan en el almacenamiento del navegador del dispositivo. No se comparten con otros equipos y pueden perderse si se borran los datos del navegador. Haz copias de seguridad.
- El ticket es interno; no es boleta/factura electrónica ni está conectado a SUNAT.
- Aún no incluye sincronización multi-dispositivo, cuentas/permisos integrados al POS ni pruebas de uso comercial en producción. No tratarlo como sistema fiscal certificado.

## Supabase
- URL del proyecto: https://jznbuxqgsmvjkcgdbigv.supabase.co
- La clave publishable/anon incluida en el frontend es una clave pública diseñada para usarse en navegador. Nunca colocar aquí `service_role`, contraseñas ni secretos.
- Tablas iniciales: perfiles, empresas, miembros, planes, suscripciones, productos, clientes, proveedores, ventas, detalle de venta, compras, movimientos de stock, movimientos de caja, empleados, recetas, pedidos de restaurante y lotes de farmacia.
- RLS habilitado en estas tablas.

## Publicar
El sitio estático puede publicarse desde Netlify conectando este repositorio y usando la rama `main`; no necesita comando de build ni carpeta de publicación. Para probar esta versión de desarrollo, publica la rama `nova-digitex-build` en un entorno de prueba o abre `pos.html` desde la vista de archivos del repositorio. El sitio publicado desde `main` no cambia hasta que los cambios se integren en esa rama y el hosting vuelva a desplegarse.

## Siguientes tareas
1. Terminar operaciones comerciales en el panel principal y conectar el POS a la base central con transacciones idempotentes.
2. Confirmar flujo de registro e inicio de sesión y ajuste de confirmación de correo.
3. Crear de forma segura el primer superadministrador autorizado.
4. Construir aprobación de empresas, asignación de planes y permisos.
5. Implementar sincronización offline con validación del servidor y pruebas de seguridad multiempresa.
6. Integrar comprobantes electrónicos de SUNAT solo tras configuración legal y técnica correspondiente.
7. Empaquetar y probar las versiones Windows y Android.

No se deben presentar cifras de muestra como datos reales.