# NOVA DIGITEX

Prototipo de POS multiempresa y multirrubro. La etapa actual está orientada a **Supabase Free ($0/mes)**: varias empresas en un proyecto PostgreSQL, con aislamiento de filas mediante RLS.

## Empezar con Supabase Free

1. Crea un proyecto en Supabase.
2. Abre **SQL Editor** y ejecuta el archivo `supabase/migrations/202610270001_initial.sql`.
3. Configura autenticación en el panel Supabase.
4. Sigue `supabase/README.md` para conectar el cliente con la URL y la clave pública del proyecto.
5. Verifica el aislamiento entre usuarios y empresas antes de usar datos reales.

## Qué incluye la migración inicial

- Registro de empresas y selección de rubro.
- Propietario y miembros por empresa.
- Productos, clientes, proveedores, caja, ventas, detalle de venta, movimientos de inventario y auditoría.
- Políticas RLS y función `create_company` para registrar una empresa y asignar al usuario autenticado como propietario.

## Arquitectura y límites del plan gratuito

- **Supabase Free usa una base PostgreSQL compartida por el proyecto**; las empresas se aíslan mediante políticas RLS. No crea una base física por empresa.
- El plan gratuito tiene límites de proyectos y recursos; puede pausar proyectos inactivos. Revisa los límites vigentes en Supabase.
- No se debe publicar ninguna clave `service_role`, token de gestión, contraseña de base de datos o secreto administrativo.
- El backend anterior de aprovisionamiento PostgreSQL sigue en el repositorio como trabajo legado y no forma parte del flujo Supabase Free. No se debe desplegar como si ya estuviera integrado con Supabase.

## Estado honesto del prototipo

La migración y la guía de Supabase se han añadido al repositorio, pero aún no se han ejecutado contra tu proyecto Supabase ni probado en un entorno real. Esto no es todavía un POS terminado. Falta la interfaz conectada, pruebas de seguridad RLS, flujos transaccionales de ventas e inventario, caja completa, sincronización offline, respaldos, módulos por rubro y la integración validada de comprobantes electrónicos SUNAT.

No uses datos reales de clientes ni ventas hasta completar pruebas y revisión de seguridad.
