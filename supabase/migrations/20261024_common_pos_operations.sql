-- NEXO DIGITEX: common POS operations for all configured business rubrics.
-- Schema-only migration. Review tenant RLS policies and apply in Supabase before enabling production writes.
begin;
create table if not exists public.nexo_pos_quotes (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 branch_id uuid, quote_number text not null, customer_id uuid, customer_name text not null, customer_document text,
 customer_type text not null default 'general' check (customer_type in ('general','school','company','government')),
 customer_email text, customer_phone text, issue_date date not null default current_date, valid_until date,
 currency text not null default 'PEN', subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
 discount_total numeric(14,2) not null default 0 check (discount_total >= 0), tax_total numeric(14,2) not null default 0 check (tax_total >= 0),
 total numeric(14,2) not null default 0 check (total >= 0),
 status text not null default 'draft' check (status in ('draft','sent','accepted','rejected','expired','converted','cancelled')),
 lines jsonb not null default '[]'::jsonb, notes text, created_by uuid, approved_by uuid, approved_at timestamptz,
 converted_sale_id uuid, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(company_id, quote_number), check (jsonb_typeof(lines) = 'array')
);
create index if not exists nexo_pos_quotes_company_date_idx on public.nexo_pos_quotes(company_id, issue_date desc);
create index if not exists nexo_pos_quotes_customer_idx on public.nexo_pos_quotes(company_id, customer_id);
create table if not exists public.nexo_pos_returns (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 branch_id uuid, return_number text not null, original_sale_id uuid, original_receipt_number text, customer_id uuid,
 reason text not null, lines jsonb not null default '[]'::jsonb, subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
 tax_total numeric(14,2) not null default 0 check (tax_total >= 0), total numeric(14,2) not null default 0 check (total >= 0),
 refund_method text check (refund_method in ('cash','card','transfer','digital_wallet','credit_note','store_credit','none')),
 status text not null default 'pending' check (status in ('pending','approved','rejected','completed','cancelled')),
 requested_by uuid, approved_by uuid, completed_by uuid, approval_note text, idempotency_key text not null,
 created_at timestamptz not null default now(), completed_at timestamptz, unique(company_id, return_number),
 unique(company_id, idempotency_key), check (jsonb_typeof(lines) = 'array')
);
create index if not exists nexo_pos_returns_company_date_idx on public.nexo_pos_returns(company_id, created_at desc);
create index if not exists nexo_pos_returns_sale_idx on public.nexo_pos_returns(company_id, original_sale_id);
create table if not exists public.nexo_pos_cash_sessions (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 branch_id uuid, register_id text not null, cashier_id uuid not null, opened_at timestamptz not null default now(),
 opening_amount numeric(14,2) not null default 0 check (opening_amount >= 0), closed_at timestamptz,
 expected_cash numeric(14,2), counted_cash numeric(14,2), difference numeric(14,2),
 status text not null default 'open' check (status in ('open','closed','reconciled')),
 opening_note text, closing_note text, closed_by uuid, created_at timestamptz not null default now()
);
create unique index if not exists nexo_pos_one_open_session_per_cashier on public.nexo_pos_cash_sessions(company_id, branch_id, register_id, cashier_id) where status = 'open';
create index if not exists nexo_pos_cash_sessions_company_date_idx on public.nexo_pos_cash_sessions(company_id, opened_at desc);
create table if not exists public.nexo_pos_operation_queue (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.nexo_companies(id) on delete restrict,
 device_id text not null, idempotency_key text not null,
 operation_type text not null check (operation_type in ('sale','payment','return','quote','cash_open','cash_close','inventory_adjustment','void')),
 local_created_at timestamptz not null, payload jsonb not null,
 status text not null default 'pending' check (status in ('pending','processing','synced','conflict','failed')),
 server_result jsonb, error_message text, received_at timestamptz not null default now(), synced_at timestamptz,
 unique(company_id, device_id, idempotency_key)
);
create index if not exists nexo_pos_queue_pending_idx on public.nexo_pos_operation_queue(company_id, status, received_at);
create table if not exists public.nexo_pos_audit_events (
 id bigint generated always as identity primary key, company_id uuid not null references public.nexo_companies(id) on delete restrict,
 branch_id uuid, actor_id uuid, actor_role text, action text not null, entity_type text not null, entity_id text,
 reason text, before_data jsonb, after_data jsonb, device_id text, idempotency_key text, created_at timestamptz not null default now()
);
create index if not exists nexo_pos_audit_company_date_idx on public.nexo_pos_audit_events(company_id, created_at desc);
create index if not exists nexo_pos_audit_entity_idx on public.nexo_pos_audit_events(company_id, entity_type, entity_id);
alter table public.nexo_pos_quotes enable row level security;
alter table public.nexo_pos_returns enable row level security;
alter table public.nexo_pos_cash_sessions enable row level security;
alter table public.nexo_pos_operation_queue enable row level security;
alter table public.nexo_pos_audit_events enable row level security;
commit;
