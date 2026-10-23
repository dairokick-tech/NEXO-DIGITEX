-- NOVA DIGITEX: bandeja idempotente para operaciones generadas sin conexión.
-- Aditiva: no altera ni elimina las tablas ni los datos existentes.
-- Las operaciones se insertan como queued; solo el servidor de confianza debe procesarlas
-- y completar result/status. Esta tabla por sí sola NO implementa el procesamiento de ventas.

create table if not exists public.nexo_sync_operations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  operation_id uuid not null,
  operation_type text not null check (
    operation_type in ('sale.create', 'stock.adjust', 'customer.upsert', 'cash.movement')
  ),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  status text not null default 'queued' check (
    status in ('queued', 'processing', 'completed', 'failed')
  ),
  result jsonb,
  error_code text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  constraint nexo_sync_operations_idempotency unique (company_id, operation_id)
);

create index if not exists nexo_sync_operations_company_status_idx
  on public.nexo_sync_operations (company_id, status, created_at);

alter table public.nexo_sync_operations enable row level security;

drop policy if exists "nexo_sync_insert_member_queue" on public.nexo_sync_operations;
create policy "nexo_sync_insert_member_queue"
  on public.nexo_sync_operations
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and status = 'queued'
    and result is null
    and processed_at is null
    and public.nexo_is_company_member(company_id)
  );

drop policy if exists "nexo_sync_read_member_queue" on public.nexo_sync_operations;
create policy "nexo_sync_read_member_queue"
  on public.nexo_sync_operations
  for select to authenticated
  using (
    created_by = auth.uid()
    and public.nexo_is_company_member(company_id)
  );

revoke all on public.nexo_sync_operations from anon, public;
grant select, insert on public.nexo_sync_operations to authenticated;
grant all on public.nexo_sync_operations to service_role;

comment on table public.nexo_sync_operations is
  'Bandeja idempotente de operaciones offline de NOVA DIGITEX; el servidor debe validar y procesar cada payload de forma transaccional.';
