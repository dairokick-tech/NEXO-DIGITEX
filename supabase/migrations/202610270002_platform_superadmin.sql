-- NOVA DIGITEX: separación de Superadministración de plataforma y administración por empresa.
-- La tabla empieza vacía deliberadamente. El primer Superadministrador debe asignarse desde un canal confiable
-- después de que exista su cuenta de Auth; nunca se permite autoasignar este rol desde el navegador.
begin;

create table if not exists public.platform_superadmins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);

alter table public.platform_superadmins enable row level security;

create or replace function public.is_platform_superadmin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null and exists (
    select 1 from public.platform_superadmins p where p.user_id = auth.uid()
  );
$$;

revoke all on function public.is_platform_superadmin() from public;
grant execute on function public.is_platform_superadmin() to authenticated;

-- Solo el propio rol de plataforma puede consultar la lista global de empresas.
drop policy if exists companies_read_members on public.companies;
create policy companies_read_members on public.companies for select to authenticated
  using (public.is_company_member(id) or public.is_platform_superadmin());

-- Superadministración puede consultar membresías para soporte global; la gestión diaria sigue siendo por empresa.
drop policy if exists members_read_same_company on public.company_members;
create policy members_read_same_company on public.company_members for select to authenticated
  using (public.is_company_member(company_id) or public.is_platform_superadmin());

-- Evitar lectura o modificación directa de la tabla de superadministradores desde clientes.
revoke all on public.platform_superadmins from anon, authenticated;
grant select on public.platform_superadmins to authenticated;
drop policy if exists platform_superadmins_read_self on public.platform_superadmins;
create policy platform_superadmins_read_self on public.platform_superadmins for select to authenticated
  using (user_id = auth.uid());

commit;

-- Alta inicial (ejecutar por el propietario del proyecto en SQL Editor después de crear la cuenta):
-- insert into public.platform_superadmins (user_id)
-- select id from auth.users where email = 'CORREO_DEL_SUPERADMINISTRADOR'
-- on conflict (user_id) do nothing;
