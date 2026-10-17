-- NEXO DIGITEX: restringe funciones SECURITY DEFINER para evitar llamadas RPC anónimas.
-- Solo la función de tienda pública queda disponible para anon; los helpers RLS son para authenticated.
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef
  loop
    execute format('revoke all on function %s from public, anon, authenticated', r.signature);
    execute format('grant execute on function %s to service_role', r.signature);
  end loop;
end $$;
grant execute on function public.nexo_has_company_role(uuid, text[]) to authenticated;
grant execute on function public.nexo_has_plan_module(uuid, text) to authenticated;
grant execute on function public.nexo_is_company_member(uuid) to authenticated;
grant execute on function public.nexo_is_superadmin() to authenticated;
grant execute on function public.nexo_sale_item_plan_allowed(uuid) to authenticated;
grant execute on function public.nexo_public_store(uuid) to anon, authenticated;
