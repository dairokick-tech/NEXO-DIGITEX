# NOVA DIGITEX

Plataforma web multiempresa para ventas, inventario, caja y tiendas online, preparada para integrarse con Supabase.

## Estado inicial

Este repositorio contiene la base de la interfaz web, navegación por módulos, datos de demostración y una migración inicial de PostgreSQL con políticas RLS. Los importes y las ventas que aparecen en la interfaz son datos de ejemplo. Los cobros, la emisión SUNAT y la persistencia de todas las operaciones todavía requieren implementación y pruebas.

## Requisitos

- Node.js 20 o posterior
- npm
- Un proyecto de Supabase

## Ejecutar localmente

1. Instalar dependencias: `npm install`
2. Copiar `.env.example` a `.env.local`
3. Rellenar `NEXT_PUBLIC_SUPABASE_URL` y `NEXT_PUBLIC_SUPABASE_ANON_KEY` con los valores del proyecto de Supabase.
4. Iniciar: `npm run dev`
5. Abrir `http://localhost:3000`

## Base de datos

Aplicar `supabase/migrations/001_initial_schema.sql` en el SQL Editor de Supabase o mediante Supabase CLI después de revisar la migración. La función `public.create_company(...)` crea una empresa, asigna el usuario autenticado como owner y crea una tienda inicial.

## Seguridad

- Las tablas de negocio tienen Row Level Security (RLS).
- Las filas están asociadas a `company_id` y las políticas validan la membresía y el rol.
- No colocar claves `service_role` en el navegador ni en variables `NEXT_PUBLIC_*`.
- El checkout público debe implementarse en un endpoint de servidor o Edge Function, verificando precios y stock del lado servidor.
- Los webhooks de pago deben verificar firma e idempotencia antes de marcar un pago como aprobado.

## Próximas etapas

1. Autenticación real y recuperación de contraseña.
2. Registro de empresas y selección de empresa activa.
3. CRUD persistente de productos y clientes.
4. Ventas transaccionales, movimientos de stock, caja y auditoría.
5. Tienda pública por slug y checkout seguro.
6. Integración de proveedores de pago y comprobantes electrónicos/SUNAT.
7. Pruebas automatizadas de permisos y aislamiento multiempresa.
