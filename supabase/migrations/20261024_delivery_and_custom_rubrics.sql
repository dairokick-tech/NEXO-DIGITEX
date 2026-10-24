-- NEXO DIGITEX: esquema aditivo para Delivery y rubros configurables.
-- Ejecutar primero en entorno de pruebas. No borra datos existentes.
create extension if not exists pgcrypto;

create table if not exists public.nexo_delivery_orders (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.nexo_companies(id) on delete restrict,
 order_code text not null, customer_id uuid, customer_name text not null,
 customer_phone text, delivery_address text not null, delivery_reference text,
 promised_at timestamptz, assigned_driver_id uuid,
 status text not null default 'pending' check(status in ('pending','assigned','in_transit','delivered','failed','returned','cancelled')),
 payment_method text, cod_amount numeric(14,2) not null default 0 check(cod_amount>=0),
 cod_collected numeric(14,2) not null default 0 check(cod_collected>=0),
 currency char(3) not null default 'PEN', delivery_notes text,
 proof_type text check(proof_type is null or proof_type in ('signature','photo','code','none')),
 proof_reference text, delivered_at timestamptz, failure_reason text,
 created_by uuid, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,order_code), check(cod_collected<=cod_amount)
);
create index if not exists idx_nexo_delivery_company_status on public.nexo_delivery_orders(company_id,status,created_at desc);
create index if not exists idx_nexo_delivery_driver_status on public.nexo_delivery_orders(company_id,assigned_driver_id,status);

create table if not exists public.nexo_delivery_events (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 delivery_order_id uuid not null references public.nexo_delivery_orders(id) on delete cascade,
 event_type text not null check(event_type in ('created','assigned','picked_up','in_transit','proof_received','delivered','failed','returned','cod_collected','incident','note')),
 event_at timestamptz not null default now(), latitude numeric(10,7), longitude numeric(10,7), notes text, evidence_reference text,
 actor_id uuid, idempotency_key text, created_at timestamptz not null default now(), unique(company_id,idempotency_key)
);
create index if not exists idx_nexo_delivery_events_order on public.nexo_delivery_events(delivery_order_id,event_at desc);

create table if not exists public.nexo_delivery_settlements (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 settlement_code text not null, driver_id uuid not null, period_start timestamptz not null, period_end timestamptz not null,
 expected_cod numeric(14,2) not null default 0, declared_cod numeric(14,2) not null default 0, expenses numeric(14,2) not null default 0,
 difference numeric(14,2) generated always as (declared_cod - expected_cod + expenses) stored,
 status text not null default 'draft' check(status in ('draft','submitted','approved','rejected','paid')),
 notes text, created_by uuid, approved_by uuid, created_at timestamptz not null default now(), approved_at timestamptz,
 unique(company_id,settlement_code), check(period_end>=period_start), check(expected_cod>=0 and declared_cod>=0 and expenses>=0)
);
create table if not exists public.nexo_delivery_settlement_lines (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 settlement_id uuid not null references public.nexo_delivery_settlements(id) on delete cascade,
 delivery_order_id uuid not null references public.nexo_delivery_orders(id) on delete restrict,
 expected_amount numeric(14,2) not null default 0, collected_amount numeric(14,2) not null default 0, note text,
 unique(settlement_id,delivery_order_id)
);
create table if not exists public.nexo_delivery_expenses (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 driver_id uuid, delivery_order_id uuid references public.nexo_delivery_orders(id) on delete set null, route_code text,
 expense_type text not null check(expense_type in ('fuel','toll','parking','maintenance','food','other')),
 amount numeric(14,2) not null check(amount>=0), currency char(3) not null default 'PEN',
 quantity numeric(12,3), unit text, odometer_km numeric(12,2), receipt_reference text, notes text,
 spent_at timestamptz not null default now(), created_by uuid, created_at timestamptz not null default now()
);
create table if not exists public.nexo_delivery_incidents (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 delivery_order_id uuid references public.nexo_delivery_orders(id) on delete set null, driver_id uuid,
 severity text not null default 'medium' check(severity in ('low','medium','high','critical')),
 category text not null, description text not null, resolution text,
 status text not null default 'open' check(status in ('open','investigating','resolved','closed')),
 occurred_at timestamptz not null default now(), resolved_at timestamptz, created_by uuid, created_at timestamptz not null default now()
);

create table if not exists public.nexo_custom_categories (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 parent_id uuid references public.nexo_custom_categories(id) on delete set null, name text not null,
 category_type text not null default 'product' check(category_type in ('product','service','asset','project','work_order')),
 sort_order integer not null default 0, active boolean not null default true, created_at timestamptz not null default now(),
 unique(company_id,parent_id,name)
);
create table if not exists public.nexo_custom_units (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 code text not null, name text not null, symbol text not null, decimal_places smallint not null default 2 check(decimal_places between 0 and 6),
 active boolean not null default true, unique(company_id,code)
);
create table if not exists public.nexo_custom_fields (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 business_type text not null default 'otros',
 entity_type text not null check(entity_type in ('product','service','asset','customer','supplier','purchase','sale','work_order','project')),
 field_key text not null, label text not null,
 field_type text not null check(field_type in ('text','number','currency','date','datetime','boolean','select','multiselect','email','phone','url')),
 required boolean not null default false, options jsonb not null default '[]'::jsonb,
 validation jsonb not null default '{}'::jsonb, sort_order integer not null default 0, active boolean not null default true, created_at timestamptz not null default now(),
 unique(company_id,entity_type,field_key)
);
create table if not exists public.nexo_custom_field_values (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 entity_type text not null, entity_id uuid not null, field_id uuid not null references public.nexo_custom_fields(id) on delete restrict,
 value jsonb, updated_by uuid, updated_at timestamptz not null default now(), unique(company_id,entity_type,entity_id,field_id)
);
create table if not exists public.nexo_price_lists (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 name text not null, currency char(3) not null default 'PEN', customer_segment text, valid_from date, valid_until date,
 active boolean not null default true, created_at timestamptz not null default now(), unique(company_id,name),
 check(valid_until is null or valid_from is null or valid_until>=valid_from)
);
create table if not exists public.nexo_price_list_items (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 price_list_id uuid not null references public.nexo_price_lists(id) on delete cascade, item_id uuid not null,
 item_type text not null default 'product' check(item_type in ('product','service')), unit_id uuid references public.nexo_custom_units(id) on delete set null,
 min_quantity numeric(14,3) not null default 1 check(min_quantity>0), unit_price numeric(14,4) not null check(unit_price>=0),
 unique(price_list_id,item_id,item_type,min_quantity)
);
create table if not exists public.nexo_work_orders (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 order_code text not null, title text not null, description text, customer_id uuid, project_code text,
 status text not null default 'draft' check(status in ('draft','pending_approval','approved','in_progress','blocked','completed','cancelled')),
 priority text not null default 'normal' check(priority in ('low','normal','high','urgent')), assigned_to uuid,
 planned_start timestamptz, planned_end timestamptz, actual_start timestamptz, actual_end timestamptz,
 estimated_cost numeric(14,2) not null default 0, actual_cost numeric(14,2) not null default 0, custom_data jsonb not null default '{}'::jsonb,
 created_by uuid, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id,order_code), check(estimated_cost>=0 and actual_cost>=0)
);
create table if not exists public.nexo_workflow_definitions (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 name text not null, entity_type text not null, steps jsonb not null default '[]'::jsonb, active boolean not null default true,
 created_by uuid, created_at timestamptz not null default now(), unique(company_id,name)
);
create table if not exists public.nexo_workflow_runs (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 workflow_id uuid not null references public.nexo_workflow_definitions(id) on delete restrict, entity_type text not null, entity_id uuid not null,
 current_step integer not null default 0, status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')),
 history jsonb not null default '[]'::jsonb, requested_by uuid, completed_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.nexo_document_templates (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 name text not null, document_type text not null, template_body text not null default '', variables jsonb not null default '[]'::jsonb,
 active boolean not null default true, created_by uuid, created_at timestamptz not null default now(), unique(company_id,name)
);

-- No abrir acceso público. Las políticas RLS deben vincularse a la tabla real de membresías del proyecto antes de usar estas tablas desde el navegador.
