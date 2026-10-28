# NOVA DIGITEX — Supabase Free prototype

This repository is being prepared for a zero-cost prototype using **one Supabase Free project** with PostgreSQL row-level security (RLS) to isolate multiple companies. This is not one physical PostgreSQL database per company; Supabase Free project limits make that model unsuitable for many tenants.

## Setup

1. Create a Supabase project on the Free plan.
2. Open **SQL Editor** in the Supabase dashboard.
3. Run the migration in `supabase/migrations/202610270001_initial.sql`.
4. In **Authentication → Providers**, enable the sign-in methods you intend to use.
5. Use the project's **Project URL** and **publishable/anon key** only in the client application.
6. Never put the `service_role` key, database password, or management API token in frontend code, a public repository, or a mobile APK.

## What this migration provides

- Company registry and business-rubro selection.
- Memberships and roles (owner, admin, manager, cashier, inventory).
- Tenant tables for products, customers, suppliers, cash sessions, sales, sale items, inventory movements and audit log.
- RLS policies that restrict tenant data by authenticated membership.
- `create_company(name, tax_id, business_type)` RPC that creates a company and assigns the signed-in user as owner.

## Important limitations

- This is a database foundation, not a finished POS interface or production deployment.
- Multiple companies share this project's PostgreSQL instance; data isolation relies on RLS and must be tested before real use.
- Some features need additional migrations and transaction-safe database functions: payment capture, stock decrement, returns, discounts/approval limits, company user invitations, role-specific write policies, offline sync/idempotency, backups, SUNAT electronic invoicing, rubro-specific inventory and restaurant workflows.
- The SQL migration should be reviewed and tested in a disposable Supabase project before production. Do not use real customer or financial data in this prototype.
- Supabase Free projects may pause after inactivity and have quotas; review current limits before sharing the prototype publicly.

## Client configuration

Set these in the web app's local environment (do not commit real values):

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

Only the public/publishable key belongs in client-side configuration. RLS is mandatory; never rely on hiding a company ID in the UI as a security boundary.
