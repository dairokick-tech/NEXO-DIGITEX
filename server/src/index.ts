import "dotenv/config";
import Fastify from "fastify";
import cors from "@fastify/cors";
import { Pool } from "pg";
import { createHash, randomUUID, timingSafeEqual } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { z } from "zod";

const port = Number(process.env.PORT ?? 8080);
const host = process.env.HOST ?? "0.0.0.0";
const prefix = (process.env.TENANT_DB_PREFIX ?? "nova_company_").replace(/[^a-z0-9_]/gi, "").toLowerCase();
const registryUrl = process.env.REGISTRY_DATABASE_URL;
const adminUrl = process.env.DATABASE_ADMIN_URL;
const provisioningSecret = process.env.PROVISIONING_SECRET;

if (!registryUrl || !adminUrl || !provisioningSecret || provisioningSecret.length < 32) {
  throw new Error("Configura REGISTRY_DATABASE_URL, DATABASE_ADMIN_URL y PROVISIONING_SECRET (mínimo 32 caracteres).");
}

const registry = new Pool({ connectionString: registryUrl, max: 5, ssl: process.env.PGSSL === "true" ? { rejectUnauthorized: true } : undefined });
const admin = new Pool({ connectionString: adminUrl, max: 2, ssl: process.env.PGSSL === "true" ? { rejectUnauthorized: true } : undefined });
const app = Fastify({ logger: true, bodyLimit: 64 * 1024 });

await app.register(cors, {
  origin: (process.env.CORS_ORIGIN ?? "http://localhost:5173").split(",").map((s) => s.trim()),
  methods: ["GET", "POST", "OPTIONS"],
});

const CompanyInput = z.object({
  legalName: z.string().trim().min(2).max(180),
  tradeName: z.string().trim().min(2).max(120),
  taxId: z.string().trim().max(20).optional().transform((v) => v || undefined),
  businessType: z.enum(["general", "minimarket", "clothing", "hardware", "pharmacy", "restaurant", "bookstore", "electronics", "wholesale", "agriculture", "lodging"]).default("general"),
  storeSlug: z.string().trim().toLowerCase().min(3).max(50).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
});

function safeIdentifier(value: string): string {
  if (!/^[a-z][a-z0-9_]{0,62}$/.test(value)) throw new Error("Identificador de base no válido.");
  return '"' + value + '"';
}
function safeSecretEqual(a: string, b: string): boolean {
  const aa = Buffer.from(a);
  const bb = Buffer.from(b);
  return aa.length === bb.length && timingSafeEqual(aa, bb);
}
function requestHash(input: z.infer<typeof CompanyInput>): string {
  return createHash("sha256").update(JSON.stringify(input)).digest("hex");
}
function databaseName(): string {
  return (prefix + randomUUID().replaceAll("-", "").slice(0, 24)).slice(0, 63);
}

app.get("/health", async () => ({ status: "ok", service: "nova-digitex-api" }));

app.post("/api/companies", async (request, reply) => {
  const suppliedSecret = String(request.headers["x-provisioning-secret"] ?? "");
  if (!safeSecretEqual(suppliedSecret, provisioningSecret!)) {
    return reply.code(401).send({ error: "No autorizado." });
  }

  const parsed = CompanyInput.safeParse(request.body);
  if (!parsed.success) return reply.code(400).send({ error: "Datos inválidos.", details: parsed.error.flatten() });

  const idempotencyKey = String(request.headers["idempotency-key"] ?? "").trim();
  if (idempotencyKey.length < 16 || idempotencyKey.length > 120) {
    return reply.code(400).send({ error: "Envía una cabecera Idempotency-Key de 16 a 120 caracteres." });
  }

  const input = parsed.data;
  const hash = requestHash(input);
  const prior = await registry.query(
    "SELECT r.request_hash, r.status, r.company_id, c.trade_name, c.store_slug, c.provisioning_status FROM provisioning_requests r LEFT JOIN companies c ON c.id=r.company_id WHERE r.idempotency_key=$1",
    [idempotencyKey],
  );
  if (prior.rowCount) {
    const p = prior.rows[0];
    if (p.request_hash !== hash) return reply.code(409).send({ error: "La clave de idempotencia ya se usó con otros datos." });
    if (p.status === "completed" && p.company_id) {
      return reply.code(200).send({ companyId: p.company_id, status: p.provisioning_status, storeUrl: `/tienda/${p.store_slug}`, reused: true });
    }
    return reply.code(409).send({ error: "La solicitud ya existe y requiere reintento o revisión.", status: p.status });
  }

  const dbName = databaseName();
  const client = await registry.connect();
  let companyId: string | undefined;
  try {
    await client.query("BEGIN");
    const inserted = await client.query(
      "INSERT INTO companies (legal_name, trade_name, tax_id, business_type, db_name, store_slug, provisioning_status) VALUES ($1,$2,$3,$4,$5,$6,'provisioning') RETURNING id",
      [input.legalName, input.tradeName, input.taxId ?? null, input.businessType, dbName, input.storeSlug],
    );
    companyId = inserted.rows[0].id;
    await client.query(
      "INSERT INTO provisioning_requests (idempotency_key, company_id, request_hash, status) VALUES ($1,$2,$3,'started')",
      [idempotencyKey, companyId, hash],
    );
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK").catch(() => undefined);
    const pgError = error as { code?: string };
    if (pgError.code === "23505") return reply.code(409).send({ error: "Ya existe una empresa con ese RUC o una tienda con ese enlace." });
    request.log.error({ err: error }, "No se pudo crear el registro de empresa");
    return reply.code(500).send({ error: "No se pudo iniciar el registro de la empresa." });
  } finally {
    client.release();
  }

  try {
    // CREATE DATABASE cannot run inside a transaction. Database name is generated by the server and identifier-validated.
    const quotedDb = safeIdentifier(dbName);
    await admin.query(`CREATE DATABASE ${quotedDb}`);
    const tenant = new Pool({
      connectionString: adminUrl!.replace(/\/postgres(?:\?.*)?$/, `/${dbName}`),
      max: 2,
      ssl: process.env.PGSSL === "true" ? { rejectUnauthorized: true } : undefined,
    });
    try {
      const tenantSql = await readFile(path.resolve(process.cwd(), "sql/tenant-initial.sql"), "utf8");
      await tenant.query(tenantSql);
    } finally {
      await tenant.end();
    }

    await registry.query("INSERT INTO online_stores (company_id, slug, display_name) VALUES ($1,$2,$3)", [companyId, input.storeSlug, input.tradeName]);
    await registry.query("UPDATE companies SET provisioning_status='active', activated_at=now(), provisioning_error=NULL WHERE id=$1", [companyId]);
    await registry.query("UPDATE provisioning_requests SET status='completed', updated_at=now() WHERE idempotency_key=$1", [idempotencyKey]);
    return reply.code(201).send({
      companyId,
      status: "active",
      database: "created",
      onlineStore: "created",
      storeUrl: `/tienda/${input.storeSlug}`,
      note: "La base PostgreSQL es exclusiva de esta empresa. El dominio público debe configurarse en el despliegue.",
    });
  } catch (error) {
    request.log.error({ err: error, companyId, dbName }, "Falló la provisión de empresa/tienda");
    await registry.query(
      "UPDATE companies SET provisioning_status='provisioning_failed', provisioning_error=$2 WHERE id=$1",
      [companyId, "Falló la provisión; revisar logs del servidor y reintentar de forma controlada."],
    ).catch(() => undefined);
    await registry.query("UPDATE provisioning_requests SET status='failed', updated_at=now() WHERE idempotency_key=$1", [idempotencyKey]).catch(() => undefined);
    return reply.code(500).send({ error: "La empresa quedó registrada pero la provisión no terminó. Se requiere reintento administrativo." });
  }
});


const StoreSlug = z.string().trim().toLowerCase().min(3).max(50).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/);
const PublicOrderInput = z.object({
  customerName: z.string().trim().min(2).max(140),
  customerPhone: z.string().trim().max(30).optional(),
  customerEmail: z.string().trim().email().max(180).optional(),
  deliveryAddress: z.string().trim().max(500).optional(),
  items: z.array(z.object({
    productId: z.string().uuid(),
    quantity: z.number().positive().max(10000),
  })).min(1).max(100),
});

async function findActiveStore(slug: string) {
  const found = await registry.query(
    "SELECT c.id AS company_id, c.db_name, c.trade_name, s.slug, s.display_name, s.currency FROM companies c JOIN online_stores s ON s.company_id=c.id WHERE s.slug=$1 AND s.enabled=true AND c.provisioning_status='active'",
    [slug],
  );
  return found.rows[0] as { company_id: string; db_name: string; trade_name: string; slug: string; display_name: string; currency: string } | undefined;
}
async function tenantPool(dbName: string): Promise<Pool> {
  safeIdentifier(dbName);
  const url = new URL(adminUrl!);
  url.pathname = "/" + dbName;
  return new Pool({
    connectionString: url.toString(),
    max: 3,
    ssl: process.env.PGSSL === "true" ? { rejectUnauthorized: true } : undefined,
  });
}

app.get("/api/store/:slug", async (request, reply) => {
  const parsed = StoreSlug.safeParse((request.params as { slug: string }).slug);
  if (!parsed.success) return reply.code(400).send({ error: "Enlace de tienda no válido." });
  const store = await findActiveStore(parsed.data);
  if (!store) return reply.code(404).send({ error: "Tienda no encontrada o no publicada." });
  const tenant = await tenantPool(store.db_name);
  try {
    const products = await tenant.query(
      "SELECT id, sku, barcode, name, description, category, price, stock, image_url FROM products WHERE active=true AND online_visible=true AND stock>0 ORDER BY name LIMIT 500",
    );
    return { store: { name: store.display_name, slug: store.slug, currency: store.currency }, products: products.rows };
  } finally {
    await tenant.end();
  }
});

app.post("/api/store/:slug/orders", async (request, reply) => {
  const slug = StoreSlug.safeParse((request.params as { slug: string }).slug);
  if (!slug.success) return reply.code(400).send({ error: "Enlace de tienda no válido." });
  const parsed = PublicOrderInput.safeParse(request.body);
  if (!parsed.success) return reply.code(400).send({ error: "Datos de pedido inválidos.", details: parsed.error.flatten() });
  const idempotencyKey = String(request.headers["idempotency-key"] ?? "").trim();
  if (idempotencyKey.length < 16 || idempotencyKey.length > 120) {
    return reply.code(400).send({ error: "Envía una cabecera Idempotency-Key de 16 a 120 caracteres." });
  }
  const store = await findActiveStore(slug.data);
  if (!store) return reply.code(404).send({ error: "Tienda no encontrada o no publicada." });
  const tenant = await tenantPool(store.db_name);
  const client = await tenant.connect();
  try {
    await client.query("BEGIN");
    const existing = await client.query("SELECT id, order_number, status, total FROM online_orders WHERE idempotency_key=$1", [idempotencyKey]);
    if (existing.rowCount) {
      await client.query("ROLLBACK");
      return reply.code(200).send({ order: existing.rows[0], reused: true });
    }

    // Combine duplicate product IDs before locking rows, then validate availability in this tenant database only.
    const quantities = new Map<string, number>();
    for (const item of parsed.data.items) quantities.set(item.productId, (quantities.get(item.productId) ?? 0) + item.quantity);
    const ids = [...quantities.keys()];
    const selected = await client.query(
      "SELECT id, name, price, stock FROM products WHERE id = ANY($1::uuid[]) AND active=true AND online_visible=true FOR UPDATE",
      [ids],
    );
    if (selected.rowCount !== ids.length) {
      await client.query("ROLLBACK");
      return reply.code(400).send({ error: "Uno o más productos ya no están disponibles." });
    }
    const products = new Map(selected.rows.map((p) => [p.id as string, p]));
    let subtotal = 0;
    const lines = ids.map((id) => {
      const product = products.get(id)!;
      const quantity = quantities.get(id)!;
      if (Number(product.stock) < quantity) throw new Error("STOCK_INSUFFICIENT");
      const unitPrice = Number(product.price);
      const lineTotal = Math.round(unitPrice * quantity * 100) / 100;
      subtotal += lineTotal;
      return { id, name: product.name as string, quantity, unitPrice, lineTotal };
    });
    subtotal = Math.round(subtotal * 100) / 100;

    const created = await client.query(
      "INSERT INTO online_orders (customer_name, customer_phone, customer_email, delivery_address, status, subtotal, delivery_fee, total, idempotency_key) VALUES ($1,$2,$3,$4,'new',$5,0,$5,$6) RETURNING id, order_number, status, total, created_at",
      [parsed.data.customerName, parsed.data.customerPhone ?? null, parsed.data.customerEmail ?? null, parsed.data.deliveryAddress ?? null, subtotal, idempotencyKey],
    );
    const order = created.rows[0];
    for (const line of lines) {
      await client.query(
        "INSERT INTO online_order_items (order_id, product_id, product_name, quantity, unit_price, line_total) VALUES ($1,$2,$3,$4,$5,$6)",
        [order.id, line.id, line.name, line.quantity, line.unitPrice, line.lineTotal],
      );
      await client.query("UPDATE products SET stock=stock-$1 WHERE id=$2", [line.quantity, line.id]);
    }
    await client.query("COMMIT");
    return reply.code(201).send({ order, message: "Pedido recibido. La empresa debe confirmar su preparación y entrega." });
  } catch (error) {
    await client.query("ROLLBACK").catch(() => undefined);
    if (error instanceof Error && error.message === "STOCK_INSUFFICIENT") {
      return reply.code(409).send({ error: "Stock insuficiente para uno de los productos." });
    }
    request.log.error({ err: error, storeSlug: slug.data }, "No se pudo registrar pedido online");
    return reply.code(500).send({ error: "No se pudo registrar el pedido." });
  } finally {
    client.release();
    await tenant.end();
  }
});

app.setErrorHandler((error, request, reply) => {
  request.log.error({ err: error }, "Error no controlado");
  reply.code(500).send({ error: "Error interno del servidor." });
});

const shutdown = async () => {
  await app.close();
  await registry.end();
  await admin.end();
  process.exit(0);
};
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

await app.listen({ port, host });
