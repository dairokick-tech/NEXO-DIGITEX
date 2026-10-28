-- NOVA DIGITEX: initial multi-tenant schema for Supabase/PostgreSQL.
-- Apply this migration in the Supabase SQL Editor or through Supabase CLI.
-- Every tenant-owned row includes company_id and is protected by RLS.

create extension if not exists pgcrypto;

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null,
  commercial_name text not null,
  tax_id varchar(11),
  business_type text not null default 'general',
  status text not null default 'pending' check (status in ('pending','active','suspended')),
  created_at timestamptz not null default now(),
  unique (tax_id)
);

create table if not exists public.company_members (
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','manager','seller','cashier','accountant')),
  created_at timestamptz not null default now(),
  primary key (company_id, user_id)
);

create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  slug text not null unique,
  logo_url text,
  primary_color text not null default '#2864E8',
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  unique (id, company_id)
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (id, company_id),
  unique (company_id, name)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  category_id uuid,
  sku text,
  name text not null,
  description text,
  price numeric(12,2) not null default 0 check (price >= 0),
  cost numeric(12,2) not null default 0 check (cost >= 0),
  stock numeric(12,3) not null default 0 check (stock >= 0),
  image_url text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, company_id),
  unique (company_id, sku),
  foreign key (category_id, company_id) references public.categories(id, company_id)
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  full_name text not null,
  document_number text,
  email text,
  phone text,
  created_at timestamptz not null default now(),
  unique (id, company_id)
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  customer_id uuid,
  order_number bigint generated always as identity,
  status text not null default 'pending' check (status in ('pending','confirmed','processing','shipped','delivered','cancelled')),
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  tax numeric(12,2) not null default 0 check (tax >= 0),
  total numeric(12,2) not null check (total >= 0),
  currency char(3) not null default 'PEN',
  idempotency_key uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now(),
  unique (company_id, idempotency_key),
  unique (company_id, order_number),
  unique (id, company_id),
  foreign key (customer_id, company_id) references public.customers(id, company_id)
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  order_id uuid not null,
  product_id uuid,
  product_name text not null,
  quantity numeric(12,3) not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  subtotal numeric(12,2) not null check (subtotal >= 0),
  foreign key (order_id, company_id) references public.orders(id, company_id) on delete cascade,
  foreign key (product_id, company_id) references public.products(id, company_id)
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  order_id uuid not null,
  provider text not null default 'manual',
  provider_reference text,
  method text not null check (method in ('cash','yape','plin','card','bank_transfer','other')),
  amount numeric(12,2) not null check (amount > 0),
  status text not null default 'pending' check (status in ('pending','approved','rejected','refunded')),
  created_at timestamptz not null default now(),
  foreign key (order_id, company_id) references public.orders(id, company_id) on delete cascade
);

create unique index if not exists payments_provider_reference_unique
  on public.payments(provider, provider_reference)
  where provider_reference is not null;

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  product_id uuid not null,
  movement_type text not null check (movement_type in ('purchase','sale','return','adjustment','transfer')),
  quantity numeric(12,3) not null check (quantity <> 0),
  reference text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  foreign key (product_id, company_id) references public.products(id, company_id)
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  company_id uuid not null references public.companies(id) on delete cascade,
  actor_id uuid references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists products_company_idx on public.products(company_id);
create index if not exists orders_company_date_idx on public.orders(company_id, created_at desc);
create index if not exists customers_company_idx on public.customers(company_id);
create index if not exists inventory_company_product_idx on public.inventory_movements(company_id, product_id, created_at desc);
create index if not exists audit_company_date_idx on public.audit_logs(company_id, created_at desc);

create or replace function public.is_company_member(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.company_members m
    where m.company_id = p_company_id and m.user_id = (select auth.uid())
  );
$$;

create or replace function public.has_company_role(p_company_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.company_members m
    where m.company_id = p_company_id
      and m.user_id = (select auth.uid())
      and m.role = any(p_roles)
  );
$$;

revoke all on function public.is_company_member(uuid) from public;
revoke all on function public.has_company_role(uuid, text[]) from public;
grant execute on function public.is_company_member(uuid) to authenticated;
grant execute on function public.has_company_role(uuid, text[]) to authenticated;

-- Create company and its owner membership atomically.
create or replace function public.create_company(
  p_legal_name text,
  p_commercial_name text,
  p_tax_id text default null,
  p_business_type text default 'general'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_company_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if nullif(trim(p_legal_name), '') is null or nullif(trim(p_commercial_name), '') is null then
    raise exception 'Legal name and commercial name are required';
  end if;
  insert into public.companies(legal_name, commercial_name, tax_id, business_type)
  values (trim(p_legal_name), trim(p_commercial_name), nullif(trim(p_tax_id), ''), coalesce(nullif(trim(p_business_type), ''), 'general'))
  returning id into new_company_id;
  insert into public.company_members(company_id, user_id, role)
  values (new_company_id, auth.uid(), 'owner');
  insert into public.stores(company_id, name, slug)
  values (new_company_id, trim(p_commercial_name), lower(regexp_replace(trim(p_commercial_name), '[^a-zA-Z0-9]+', '-', 'g')) || '-' || substr(new_company_id::text, 1, 8));
  return new_company_id;
end;
$$;
revoke all on function public.create_company(text, text, text, text) from public;
grant execute on function public.create_company(text, text, text, text) to authenticated;

alter table public.companies enable row level security;
alter table public.company_members enable row level security;
alter table public.stores enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.audit_logs enable row level security;

create policy "company members can read their companies" on public.companies
for select to authenticated using (public.is_company_member(id));
create policy "company admins can update their companies" on public.companies
for update to authenticated using (public.has_company_role(id, array['owner','admin'])) with check (public.has_company_role(id, array['owner','admin']));

create policy "members can read memberships in their company" on public.company_members
for select to authenticated using (user_id = (select auth.uid()) or public.has_company_role(company_id, array['owner','admin']));
create policy "owners and admins can add memberships" on public.company_members
for insert to authenticated with check (public.has_company_role(company_id, array['owner','admin']));
create policy "owners and admins can update memberships" on public.company_members
for update to authenticated using (public.has_company_role(company_id, array['owner','admin'])) with check (public.has_company_role(company_id, array['owner','admin']));
create policy "owners and admins can remove memberships" on public.company_members
for delete to authenticated using (public.has_company_role(company_id, array['owner','admin']));

create policy "members can read stores" on public.stores
for select to authenticated using (public.is_company_member(company_id));
create policy "published stores are public" on public.stores
for select to anon using (is_published = true);
create policy "admins manage stores" on public.stores
for all to authenticated using (public.has_company_role(company_id, array['owner','admin'])) with check (public.has_company_role(company_id, array['owner','admin']));

create policy "members read categories" on public.categories
for select to authenticated using (public.is_company_member(company_id));
create policy "admins manage categories" on public.categories
for all to authenticated using (public.has_company_role(company_id, array['owner','admin','manager'])) with check (public.has_company_role(company_id, array['owner','admin','manager']));

create policy "members read products" on public.products
for select to authenticated using (public.is_company_member(company_id));
create policy "published products are public" on public.products
for select to anon using (is_published = true and exists (select 1 from public.stores s where s.company_id = products.company_id and s.is_published = true));
create policy "authorized staff insert products" on public.products
for insert to authenticated with check (public.has_company_role(company_id, array['owner','admin','manager']));
create policy "authorized staff update products" on public.products
for update to authenticated using (public.has_company_role(company_id, array['owner','admin','manager'])) with check (public.has_company_role(company_id, array['owner','admin','manager']));
create policy "admins delete products" on public.products
for delete to authenticated using (public.has_company_role(company_id, array['owner','admin']));

create policy "members manage customers" on public.customers
for all to authenticated using (public.has_company_role(company_id, array['owner','admin','manager','seller','cashier'])) with check (public.has_company_role(company_id, array['owner','admin','manager','seller','cashier']));
create policy "members read orders" on public.orders
for select to authenticated using (public.is_company_member(company_id));
create policy "authorized staff create orders" on public.orders
for insert to authenticated with check (public.has_company_role(company_id, array['owner','admin','manager','seller','cashier']));
create policy "authorized staff update orders" on public.orders
for update to authenticated using (public.has_company_role(company_id, array['owner','admin','manager','seller','cashier'])) with check (public.has_company_role(company_id, array['owner','admin','manager','seller','cashier']));
create policy "admins cancel delete orders" on public.orders
for delete to authenticated using (public.has_company_role(company_id, array['owner','admin']));

create policy "members read order items" on public.order_items
for select to authenticated using (public.is_company_member(company_id));
create policy "authorized staff insert order items" on public.order_items
for insert to authenticated with check (public.has_company_role(company_id, array['owner','admin','manager','seller','cashier']));
create policy "authorized staff update order items" on public.order_items
for update to authenticated using (public.has_company_role(company_id, array['owner','admin','manager','seller','cashier'])) with check (public.has_company_role(company_id, array['owner','admin','manager','seller','cashier']));

create policy "members read payments" on public.payments
for select to authenticated using (public.is_company_member(company_id));
create policy "authorized staff register payments" on public.payments
for insert to authenticated with check (public.has_company_role(company_id, array['owner','admin','manager','seller','cashier']));
create policy "admins update payments" on public.payments
for update to authenticated using (public.has_company_role(company_id, array['owner','admin'])) with check (public.has_company_role(company_id, array['owner','admin']));

create policy "members read inventory movements" on public.inventory_movements
for select to authenticated using (public.is_company_member(company_id));
create policy "authorized staff record inventory movements" on public.inventory_movements
for insert to authenticated with check (public.has_company_role(company_id, array['owner','admin','manager']));
create policy "members read audit logs" on public.audit_logs
for select to authenticated using (public.has_company_role(company_id, array['owner','admin']));
create policy "members insert audit logs" on public.audit_logs
for insert to authenticated with check (public.is_company_member(company_id) and actor_id = (select auth.uid()));

grant select, insert, update, delete on public.companies to authenticated;
grant select, insert, update, delete on public.company_members to authenticated;
grant select, insert, update, delete on public.stores to authenticated;
grant select, insert, update, delete on public.categories to authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on public.customers to authenticated;
grant select, insert, update, delete on public.orders to authenticated;
grant select, insert, update, delete on public.order_items to authenticated;
grant select, insert, update, delete on public.payments to authenticated;
grant select, insert, update, delete on public.inventory_movements to authenticated;
grant select, insert on public.audit_logs to authenticated;
grant select on public.stores, public.products to anon;

-- Public checkout is intentionally not granted to anon. Add a server-side
-- checkout Edge Function that validates prices, stock and payment webhooks.
