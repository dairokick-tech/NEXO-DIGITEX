# NEXO DIGITEX
ERP + SaaS para negocios — interfaz clara, adaptable a Android y computadora.

## Estado actual
- Interfaz principal en `index.html`.
- Autenticación conectada a Supabase Auth: iniciar sesión, registro de cuenta y cierre de sesión.
- Solicitud de alta de empresa con estado inicial `pending`.
- La empresa no se considera aprobada hasta que un superadministrador la cambie de estado.
- Esquema inicial de PostgreSQL aplicado al proyecto Supabase conectado.
- Las pantallas de los módulos todavía son una maqueta; no registrar operaciones reales hasta completar sus flujos y pruebas.

## Supabase
- URL del proyecto: https://jznbuxqgsmvjkcgdbigv.supabase.co
- La clave publishable/anon incluida en el frontend es una clave pública diseñada para usarse en navegador. Nunca colocar aquí `service_role`, contraseñas ni secretos.
- Tablas iniciales: perfiles, empresas, miembros, planes, suscripciones, productos, clientes, proveedores, ventas, detalle de venta, compras, movimientos de stock, movimientos de caja, empleados, recetas, pedidos de restaurante y lotes de farmacia.
- RLS habilitado en todas estas tablas.

## Publicar
El sitio estático puede publicarse desde Netlify conectando este repositorio y usando la rama `main`; no necesita comando de build ni carpeta de publicación. Si Netlify ya está conectado, espera el despliegue automático tras el commit.

## Siguientes tareas
1. Confirmar flujo de registro e inicio de sesión y ajuste de confirmación de correo.
2. Crear de forma segura el primer superadministrador autorizado.
3. Construir aprobación de empresas, asignación de planes y permisos.
4. Implementar operaciones reales por módulo y pruebas de seguridad multiempresa.
5. Integrar comprobantes electrónicos de SUNAT solo tras configuración legal y técnica correspondiente.

No se deben presentar cifras de muestra como datos reales.
