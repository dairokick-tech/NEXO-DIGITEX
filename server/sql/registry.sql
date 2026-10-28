CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  legal_name text NOT NULL,
  trade_name text NOT NULL,
  tax_id text,
  business_type text NOT NULL DEFAULT 'general',
  db_name text NOT NULL UNIQUE,
  store_slug text NOT NULL UNIQUE,
  provisioning_status text NOT NULL DEFAULT 'provisioning'
    CHECK (provisioning_status IN ('provisioning','active','provisioning_failed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  activated_at timestamptz,
  provisioning_error text
);

CREATE UNIQUE INDEX IF NOT EXISTS companies_tax_id_unique
  ON companies (tax_id) WHERE tax_id IS NOT NULL AND tax_id <> '';

CREATE TABLE IF NOT EXISTS provisioning_requests (
  idempotency_key text PRIMARY KEY,
  company_id uuid REFERENCES companies(id) ON DELETE SET NULL,
  request_hash text NOT NULL,
  status text NOT NULL CHECK (status IN ('started','completed','failed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS online_stores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL UNIQUE REFERENCES companies(id) ON DELETE CASCADE,
  slug text NOT NULL UNIQUE,
  display_name text NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  currency char(3) NOT NULL DEFAULT 'PEN',
  created_at timestamptz NOT NULL DEFAULT now()
);