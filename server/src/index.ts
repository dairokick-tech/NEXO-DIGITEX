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
function escapeHtml(value: string): string {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#39;");
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


app.get("/tienda/:slug", async (request, reply) => {
  const slug = StoreSlug.safeParse((request.params as { slug: string }).slug);
  if (!slug.success) return reply.code(404).type("text/plain").send("Tienda no encontrada");
  const store = await findActiveStore(slug.data);
  if (!store) return reply.code(404).type("text/html; charset=utf-8").send("<h1>Tienda no encontrada</h1><p>Esta tienda aún no está publicada.</p>");
  const safeStoreName = escapeHtml(store.display_name);\n  const html = String.raw`<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="theme-color" content="#101c3b"><title>${safeStoreName} | NOVA DIGITEX</title>
<style>
:root{font-family:Inter,system-ui,-apple-system,Segoe UI,sans-serif;color:#172033;background:#f5f7fb}*{box-sizing:border-box}body{margin:0}.top{background:#101c3b;color:white;padding:24px max(20px,calc((100% - 1100px)/2));display:flex;justify-content:space-between;align-items:center;gap:16px}.brand{font-weight:800;font-size:22px}.tag{font-size:12px;color:#b9c7e7}.wrap{max-width:1100px;margin:auto;padding:28px 18px}.intro h1{margin:0 0 6px;font-size:clamp(26px,4vw,38px)}.intro p{color:#65718a;margin:0 0 24px}.layout{display:grid;grid-template-columns:minmax(0,1fr) 310px;gap:22px}.products{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:16px}.card,.cart{background:white;border:1px solid #e4e8f0;border-radius:16px;overflow:hidden}.photo{height:145px;background:#edf1f8;display:grid;place-items:center;color:#8290a8;font-size:13px}.photo img{width:100%;height:100%;object-fit:cover}.details{padding:14px}.details h3{font-size:15px;margin:0 0 8px}.price{font-weight:800;font-size:20px;margin:8px 0 12px}.muted{color:#758098;font-size:12px}.btn{border:0;background:#315eea;color:white;font-weight:700;padding:11px 14px;border-radius:10px;cursor:pointer}.btn:disabled{opacity:.4;cursor:not-allowed}.cart{padding:18px;height:max-content;position:sticky;top:14px}.cart h2{margin:0 0 14px;font-size:18px}.cartline{display:flex;justify-content:space-between;gap:10px;border-bottom:1px solid #edf0f5;padding:10px 0;font-size:13px}.field{width:100%;border:1px solid #dbe1eb;border-radius:9px;padding:11px;margin:6px 0 10px;font:inherit}.total{display:flex;justify-content:space-between;font-size:18px;font-weight:800;margin:16px 0}.notice{padding:12px;border-radius:10px;background:#eaf7ef;color:#166534;margin:12px 0;display:none}.empty{padding:30px;color:#758098;text-align:center;background:white;border-radius:14px}.foot{text-align:center;padding:26px;color:#8791a4;font-size:12px}@media(max-width:760px){.layout{grid-template-columns:1fr}.cart{position:static;order:-1}.top{align-items:flex-start;flex-direction:column}.products{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:420px){.products{grid-template-columns:1fr 1fr;gap:9px}.photo{height:110px}.details{padding:10px}.price{font-size:17px}.btn{padding:10px;font-size:12px}}
</style></head><body>
<header class="top"><div><div class="brand" id="storeName">${safeStoreName}</div><div class="tag">TIENDA ONLINE · NOVA DIGITEX</div></div><div class="tag">Compra directamente a la empresa</div></header>
<main class="wrap"><section class="intro"><h1>Catálogo de productos</h1><p>Elige tus productos y envía tu pedido a la tienda.</p></section>
<div id="notice" class="notice" role="status"></div><div class="layout"><section><div id="products" class="products"><div class="empty">Cargando catálogo…</div></div></section>
<aside class="cart"><h2>Tu pedido</h2><div id="cartLines" class="muted">Aún no agregas productos.</div><div class="total"><span>Total</span><span id="total">S/ 0.00</span></div>
<form id="orderForm"><label for="customerName">Nombre completo *</label><input class="field" id="customerName" required minlength="2" maxlength="140" autocomplete="name" placeholder="Tu nombre">
<label for="customerPhone">Teléfono</label><input class="field" id="customerPhone" maxlength="30" autocomplete="tel" placeholder="Número de contacto">
<label for="customerEmail">Correo</label><input class="field" id="customerEmail" type="email" maxlength="180" autocomplete="email" placeholder="correo@ejemplo.com">
<label for="deliveryAddress">Dirección de entrega</label><textarea class="field" id="deliveryAddress" maxlength="500" rows="2" placeholder="Dirección (si corresponde)"></textarea>
<button class="btn" id="submitOrder" type="submit" style="width:100%">Enviar pedido</button><p class="muted">El pedido queda pendiente de confirmación por la empresa. Este formulario no cobra pagos.</p></form></aside></div></main>
<footer class="foot">Tienda creada con NOVA DIGITEX</footer>
<script>
const slug = ${JSON.stringify(slug.data)};
const cart = new Map();
let catalog = [];
const money = n => new Intl.NumberFormat('es-PE',{style:'currency',currency:'PEN'}).format(Number(n||0));
const notice = (text, ok=false) => { const el=document.getElementById('notice');el.textContent=text;el.style.display='block';el.style.background=ok?'#eaf7ef':'#fff1f0';el.style.color=ok?'#166534':'#9f2424'; };
function renderCart(){const host=document.getElementById('cartLines');const entries=[...cart.entries()];if(!entries.length){host.textContent='Aún no agregas productos.'}else{host.innerHTML='';entries.forEach(([id,qty])=>{const p=catalog.find(x=>x.id===id);if(!p)return;const row=document.createElement('div');row.className='cartline';const left=document.createElement('span');left.textContent=p.name+' × '+qty;const right=document.createElement('strong');right.textContent=money(Number(p.price)*qty);row.append(left,right);host.append(row)})}document.getElementById('total').textContent=money(entries.reduce((sum,[id,q])=>{const p=catalog.find(x=>x.id===id);return sum+(p?Number(p.price)*q:0)},0));}
function renderProducts(){const host=document.getElementById('products');host.innerHTML='';if(!catalog.length){host.innerHTML='<div class="empty">No hay productos publicados en este momento.</div>';return}catalog.forEach(p=>{const card=document.createElement('article');card.className='card';const photo=document.createElement('div');photo.className='photo';if(p.image_url){const img=document.createElement('img');img.src=p.image_url;img.alt=p.name;img.loading='lazy';img.onerror=()=>{photo.textContent='Producto'};photo.append(img)}else photo.textContent='Producto';const details=document.createElement('div');details.className='details';const name=document.createElement('h3');name.textContent=p.name;const category=document.createElement('div');category.className='muted';category.textContent=p.category||'Disponible';const price=document.createElement('div');price.className='price';price.textContent=money(p.price);const stock=document.createElement('div');stock.className='muted';stock.textContent='Disponibles: '+p.stock;const btn=document.createElement('button');btn.className='btn';btn.textContent='Agregar';btn.onclick=()=>{cart.set(p.id,Math.min(Number(p.stock), (cart.get(p.id)||0)+1));renderCart()};details.append(name,category,price,stock,btn);card.append(photo,details);host.append(card)})}
async function load(){try{const res=await fetch('/api/store/'+encodeURIComponent(slug));const data=await res.json();if(!res.ok)throw new Error(data.error||'No se pudo cargar la tienda');document.getElementById('storeName').textContent=data.store.name;catalog=data.products||[];renderProducts();renderCart()}catch(e){document.getElementById('products').textContent=e.message;}}
document.getElementById('orderForm').addEventListener('submit',async e=>{e.preventDefault();if(!cart.size){notice('Agrega al menos un producto al pedido.');return}const btn=document.getElementById('submitOrder');btn.disabled=true;btn.textContent='Enviando…';try{const payload={customerName:document.getElementById('customerName').value.trim(),customerPhone:document.getElementById('customerPhone').value.trim()||undefined,customerEmail:document.getElementById('customerEmail').value.trim()||undefined,deliveryAddress:document.getElementById('deliveryAddress').value.trim()||undefined,items:[...cart.entries()].map(([productId,quantity])=>({productId,quantity}))};const key=crypto.randomUUID();const res=await fetch('/api/store/'+encodeURIComponent(slug)+'/orders',{method:'POST',headers:{'Content-Type':'application/json','Idempotency-Key':key},body:JSON.stringify(payload)});const data=await res.json();if(!res.ok)throw new Error(data.error||'No se pudo enviar el pedido');cart.clear();renderCart();e.target.reset();notice('Pedido #'+data.order.order_number+' recibido. La empresa debe confirmar disponibilidad y entrega.',true)}catch(err){notice(err.message||'Error al enviar el pedido. Intenta nuevamente.')}finally{btn.disabled=false;btn.textContent='Enviar pedido'}});
load();
</script></body></html>`;
  return reply.type("text/html; charset=utf-8").header("Cache-Control", "no-store").send(html);
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
