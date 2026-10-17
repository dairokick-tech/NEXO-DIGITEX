-- NEXO DIGITEX: aplica de forma obligatoria los permisos de módulos del plan.
-- Las políticas permisivas se combinan con OR; por eso el control del plan debe ser RESTRICTIVE.
-- Esta migración convierte todas las políticas nexo_plan_gate existentes a RESTRICTIVE.
do $$
declare r record;
begin
 for r in
  select tablename, qual, with_check
  from pg_policies
  where schemaname='public' and policyname='nexo_plan_gate'
 loop
  execute format('drop policy if exists %I on public.%I', 'nexo_plan_gate', r.tablename);
  execute format(
   'create policy %I on public.%I as restrictive for all to authenticated using (%s) with check (%s)',
   'nexo_plan_gate', r.tablename, r.qual, coalesce(r.with_check,r.qual)
  );
 end loop;
end $$;

-- Verificación posterior:
-- select tablename, permissive from pg_policies
-- where schemaname='public' and policyname='nexo_plan_gate';
-- Todas deben mostrar permissive = 'RESTRICTIVE'.
