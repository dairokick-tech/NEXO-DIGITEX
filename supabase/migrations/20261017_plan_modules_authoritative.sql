-- NEXO DIGITEX: los módulos explícitos del plan son la fuente de verdad.
-- Si features.modules es un array, no conceder permisos adicionales por flags globales.
-- Los planes que usan claves booleanas siguen permitiendo solo las claves marcadas en true.

create or replace function public.nexo_has_plan_module(_company_id uuid, _module text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
 select exists (
   select 1
   from public.nexo_subscriptions s
   join public.nexo_companies c on c.id = s.company_id
   join public.nexo_plans p on p.id = s.plan_id
   where s.company_id = _company_id
     and s.status = 'active'
     and c.status = 'approved'
     and p.active = true
     and (
       case
         when jsonb_typeof(p.features -> 'modules') = 'array' then
           exists (
             select 1
             from jsonb_array_elements_text(p.features -> 'modules') as m(value)
             where m.value = any(
               case _module
                 when 'contabilidad' then array['contabilidad','reportes']
                 when 'rrhh' then array['rrhh','empleados','personal']
                 when 'compras' then array['compras','proveedores']
                 when 'inventario' then array['inventario','kardex']
                 when 'ventas' then array['ventas','ventas_pos']
                 else array[_module]
               end
             )
           )
         else
           p.features -> _module = 'true'::jsonb
           or (_module = 'contabilidad' and p.features -> 'reportes' = 'true'::jsonb)
           or (_module = 'rrhh' and (p.features -> 'empleados' = 'true'::jsonb or p.features -> 'personal' = 'true'::jsonb))
           or (_module = 'compras' and p.features -> 'proveedores' = 'true'::jsonb)
           or (_module = 'inventario' and p.features -> 'kardex' = 'true'::jsonb)
           or (_module = 'ventas' and p.features -> 'ventas_pos' = 'true'::jsonb)
       end
     )
 );
$function$;
