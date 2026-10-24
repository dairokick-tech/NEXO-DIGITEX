-- NOVA DIGITEX: diagnóstico de solo lectura antes de conectar la sincronización.
-- Ejecutar en Supabase SQL Editor con una cuenta administradora.
-- Este archivo NO crea, modifica ni elimina datos. No compartir claves ni tokens.
-- Copiar los resultados de las consultas para diseñar el procesador contra el esquema real.

-- 1) Tablas de ventas, detalle, inventario y bandeja offline presentes en public.
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_type = 'BASE TABLE'
  and (
    table_name ilike '%sale%'
    or table_name ilike '%venta%'
    or table_name ilike '%stock%'
    or table_name ilike '%product%'
    or table_name ilike '%sync%'
  )
order by table_name;

-- 2) Columnas y tipos de las tablas que se usan en ventas/sincronización.
select table_name, ordinal_position, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and (
    table_name ilike '%sale%'
    or table_name ilike '%venta%'
    or table_name ilike '%stock%'
    or table_name ilike '%product%'
    or table_name ilike '%sync%'
  )
order by table_name, ordinal_position;

-- 3) Restricciones únicas/FK: claves para impedir ventas duplicadas y mantener integridad.
select tc.table_name, tc.constraint_name, tc.constraint_type,
       kcu.column_name, ccu.table_name as foreign_table, ccu.column_name as foreign_column
from information_schema.table_constraints tc
left join information_schema.key_column_usage kcu
  on tc.constraint_schema = kcu.constraint_schema
 and tc.constraint_name = kcu.constraint_name
left join information_schema.constraint_column_usage ccu
  on tc.constraint_schema = ccu.constraint_schema
 and tc.constraint_name = ccu.constraint_name
where tc.table_schema = 'public'
  and tc.table_name in (
    select table_name from information_schema.tables
    where table_schema = 'public'
      and (table_name ilike '%sale%' or table_name ilike '%venta%'
        or table_name ilike '%stock%' or table_name ilike '%product%'
        or table_name ilike '%sync%')
  )
order by tc.table_name, tc.constraint_type, tc.constraint_name;

-- 4) Funciones relacionadas con checkout, sincronización, membresías y permisos.
-- Se devuelve la firma y definición para revisar el contrato real antes de cambiarlo.
select n.nspname as schema_name, p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments,
       pg_get_function_result(p.oid) as return_type,
       p.prosecdef as security_definer,
       pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and (
    p.proname ilike '%checkout%'
    or p.proname ilike '%sync%'
    or p.proname ilike '%sale%'
    or p.proname ilike '%company_member%'
    or p.proname ilike '%plan_module%'
  )
order by p.proname;

-- 5) Políticas RLS sobre tablas operativas (sin datos de clientes/ventas).
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and (
    tablename ilike '%sale%' or tablename ilike '%venta%'
    or tablename ilike '%stock%' or tablename ilike '%product%'
    or tablename ilike '%sync%'
  )
order by tablename, policyname;

-- 6) Estado de RLS de las tablas operativas.
select c.relname as table_name, c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and (
    c.relname ilike '%sale%' or c.relname ilike '%venta%'
    or c.relname ilike '%stock%' or c.relname ilike '%product%'
    or c.relname ilike '%sync%'
  )
order by c.relname;
