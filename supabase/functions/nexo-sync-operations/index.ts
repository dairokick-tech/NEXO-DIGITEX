/// <reference path="../_shared/deno.d.ts" />
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

/**
 * Authenticated intake only. This function stores an operation in the idempotent
 * queue; it deliberately does NOT create sales or deduct stock. A separate,
 * schema-reviewed transactional processor must do that after the live schema
 * and the existing nexo_pos_checkout contract have been verified.
 */
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) return json({ error: "server_not_configured" }, 500);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const companyId = body.company_id;
  const operationId = body.operation_id;
  const operationType = body.operation_type;
  const payload = body.payload;

  if (!isUuid(companyId) || !isUuid(operationId)) {
    return json({ error: "company_id_and_operation_id_must_be_uuids" }, 400);
  }
  if (operationType !== "sale.create" && operationType !== "stock.adjust" &&
      operationType !== "customer.upsert" && operationType !== "cash.movement") {
    return json({ error: "unsupported_operation_type" }, 400);
  }
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return json({ error: "payload_must_be_an_object" }, 400);
  }
  if (JSON.stringify(payload).length > 200_000) {
    return json({ error: "payload_too_large" }, 413);
  }

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) return json({ error: "unauthorized" }, 401);

  // Membership is enforced by the INSERT/SELECT RLS policies on
  // nexo_sync_operations; this avoids duplicating the helper RPC contract here.

  const row = {
    company_id: companyId,
    operation_id: operationId,
    operation_type: operationType,
    payload,
    status: "queued",
    created_by: userData.user.id,
  };

  const { data: inserted, error: insertError } = await supabase
    .from("nexo_sync_operations")
    .insert(row)
    .select("id, company_id, operation_id, operation_type, status, created_at")
    .maybeSingle();

  if (!insertError && inserted) return json({ ok: true, duplicate: false, operation: inserted }, 201);

  // A repeated request is accepted only when the same operation already exists
  // for this user/company. The unique constraint is the final idempotency guard.
  if (insertError?.code === "23505") {
    const { data: existing, error: readError } = await supabase
      .from("nexo_sync_operations")
      .select("id, company_id, operation_id, operation_type, status, created_at, created_by")
      .eq("company_id", companyId)
      .eq("operation_id", operationId)
      .maybeSingle();

    if (!readError && existing && existing.created_by === userData.user.id &&
        existing.operation_type === operationType) {
      const { created_by: _createdBy, ...safeExisting } = existing;
      return json({ ok: true, duplicate: true, operation: safeExisting }, 200);
    }
    return json({ error: "idempotency_conflict" }, 409);
  }

  console.error("Queue insert failed", insertError?.message ?? "unknown error");
  return json({ error: "queue_insert_failed" }, 500);
});
