-- NEXO DIGITEX: automatic logical workspace provisioning for every new company.
-- PostgreSQL/Supabase uses a shared database with tenant isolation by company_id.
-- This creates a separate company workspace and default role/module configuration automatically;
-- it intentionally does not create a physical PostgreSQL database per tenant.
begin;

create table if not exists public.nexo_company_workspaces (
  company_id uuid primary key references public.nexo_companies(id) on delete restrict,
  workspace_status text not null default 'active' check (workspace_status in ('provisioning','active','suspended','error')),
  schema_version integer not null default 1,
  preferences jsonb not null default '{}'::jsonb,
  provisioned_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(preferences) = 'object')
);

create table if not exists public.nexo_company_role_templates (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.nexo_companies(id) on delete restrict,
  role_key text not null check (role_key in ('cashier','seller','supervisor','administrator')),
  role_label text not null,
  permissions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(company_id, role_key),
  check (jsonb_typeof(permissions) = 'object')
);

create table if not exists public.nexo_company_module_state (
  company_id uuid not null references public.nexo_companies(id) on delete restrict,
  module_key text not null,
  enabled boolean not null default true,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(company_id, module_key),
  check (jsonb_typeof(settings) = 'object')
);

create index if not exists nexo_company_role_templates_company_idx
  on public.nexo_company_role_templates(company_id);
create index if not exists nexo_company_module_state_enabled_idx
  on public.nexo_company_module_state(company_id, enabled);

create or replace function public.nexo_provision_company_workspace()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.nexo_company_workspaces(company_id, workspace_status)
  values (new.id, 'active')
  on conflict (company_id) do nothing;

  insert into public.nexo_company_role_templates(company_id, role_key, role_label, permissions)
  values
    (new.id, 'cashier', 'Cajero', '{"pos.sales.create":true,"pos.cash.open":true,"pos.cash.close":true,"pos.sales.view_own":true}'::jsonb),
    (new.id, 'seller', 'Vendedor', '{"pos.sales.create":true,"pos.quotes.create":true,"customers.view":true,"inventory.view":true}'::jsonb),
    (new.id, 'supervisor', 'Supervisor', '{"pos.sales.view":true,"pos.discounts.approve":true,"pos.returns.approve":true,"pos.voids.approve":true,"pos.cash.reconcile":true}'::jsonb),
    (new.id, 'administrator', 'Administrador', '{"company.settings.manage":true,"users.manage":true,"roles.manage":true,"inventory.manage":true,"reports.view":true,"pos.manage":true}'::jsonb)
  on conflict (company_id, role_key) do nothing;

  -- Activate common modules for the new company. Rubric-specific modules are added
  -- after the company selects its business rubric.
  insert into public.nexo_company_module_state(company_id, module_key, enabled)
  values
    (new.id, 'ventas', true),
    (new.id, 'inventario', true),
    (new.id, 'compras', true),
    (new.id, 'clientes', true),
    (new.id, 'caja', true),
    (new.id, 'cotizaciones', true),
    (new.id, 'devoluciones', true),
    (new.id, 'reportes', true),
    (new.id, 'configuracion', true)
  on conflict (company_id, module_key) do nothing;

  -- If the central rubric catalog is installed and contains "otro", set it as a safe default.
  if to_regclass('public.nexo_company_rubric_settings') is not null
     and exists (select 1 from public.nexo_rubric_catalog where rubric_key = 'otro') then
    insert into public.nexo_company_rubric_settings(company_id, rubric_key, enabled_module_keys, custom_settings)
    values (new.id, 'otro', array['ventas','inventario','compras','clientes','caja','cotizaciones','devoluciones','reportes','configuracion'], '{}'::jsonb)
    on conflict (company_id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists nexo_companies_auto_provision_workspace on public.nexo_companies;
create trigger nexo_companies_auto_provision_workspace
after insert on public.nexo_companies
for each row execute function public.nexo_provision_company_workspace();

-- Backfill existing companies without deleting or overwriting their records.
insert into public.nexo_company_workspaces(company_id, workspace_status)
select c.id, 'active' from public.nexo_companies c
on conflict (company_id) do nothing;

insert into public.nexo_company_role_templates(company_id, role_key, role_label, permissions)
select c.id, r.role_key, r.role_label, r.permissions
from public.nexo_companies c
cross join (values
 ('cashier','Cajero','{"pos.sales.create":true,"pos.cash.open":true,"pos.cash.close":true,"pos.sales.view_own":true}'::jsonb),
 ('seller','Vendedor','{"pos.sales.create":true,"pos.quotes.create":true,"customers.view":true,"inventory.view":true}'::jsonb),
 ('supervisor','Supervisor','{"pos.sales.view":true,"pos.discounts.approve":true,"pos.returns.approve":true,"pos.voids.approve":true,"pos.cash.reconcile":true}'::jsonb),
 ('administrator','Administrador','{"company.settings.manage":true,"users.manage":true,"roles.manage":true,"inventory.manage":true,"reports.view":true,"pos.manage":true}'::jsonb)
) as r(role_key, role_label, permissions)
on conflict (company_id, role_key) do nothing;

insert into public.nexo_company_module_state(company_id, module_key, enabled)
select c.id, m.module_key, true
from public.nexo_companies c
cross join (values ('ventas'),('inventario'),('compras'),('clientes'),('caja'),('cotizaciones'),('devoluciones'),('reportes'),('configuracion')) as m(module_key)
on conflict (company_id, module_key) do nothing;

alter table public.nexo_company_workspaces enable row level security;
alter table public.nexo_company_role_templates enable row level security;
alter table public.nexo_company_module_state enable row level security;

commit;
