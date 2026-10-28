# Backend NOVA DIGITEX

## Funciones incluidas en esta etapa
- API de salud: `GET /health`.
- Alta de empresa protegida con `x-provisioning-secret` y `Idempotency-Key`.
- Creación de una base PostgreSQL con nombre generado por el servidor y migración inicial.
- Registro de una tienda por empresa con slug único.
- Catálogo público: `GET /api/store/:slug`.
- Tienda responsive: `GET /tienda/:slug`.
- Pedidos online guardados en la base de esa empresa, con control transaccional de stock e idempotencia.

## Preparar PostgreSQL
1. Crea una base central llamada `nova_registry`.
2. Ejecuta `psql "$REGISTRY_DATABASE_URL" -f sql/registry.sql`.
3. Crea un usuario de provisión con permisos para crear bases de datos. No uses el superusuario de PostgreSQL en producción.
4. Configura `REGISTRY_DATABASE_URL`, `DATABASE_ADMIN_URL`, `PROVISIONING_SECRET`, `PGSSL=true` y los orígenes CORS.
5. Ejecuta `npm install` y `npm run build`.

## Crear empresa desde un servicio administrativo de confianza
No llames al endpoint de provisión directamente desde el navegador y nunca expongas `PROVISIONING_SECRET` en una web pública. Ejemplo desde un servidor autorizado:

```bash
curl -X POST "$NOVA_API_URL/api/companies" \
  -H "Content-Type: application/json" \
  -H "x-provisioning-secret: $PROVISIONING_SECRET" \
  -H "Idempotency-Key: $(openssl rand -hex 16)" \
  -d '{
    "legalName":"Comercial Ejemplo SAC",
    "tradeName":"Comercial Ejemplo",
    "taxId":"20123456789",
    "businessType":"minimarket",
    "storeSlug":"comercial-ejemplo"
  }'
```

## Cómo funciona la tienda
- La tienda solo muestra productos activos marcados `online_visible=true` y con stock positivo.
- Los pedidos se insertan en `online_orders` y `online_order_items` de la base exclusiva de la empresa.
- El stock se descuenta dentro de una transacción. No se procesa pago online; el pedido queda pendiente de confirmación.
- El enlace `/tienda/:slug` se sirve desde la misma API. Para publicar un dominio propio por empresa se debe configurar DNS/proxy en el proveedor de despliegue.

## Estado y límites
Esta es una base funcional inicial, no un sistema listo para producción. Antes de abrir registros públicos, añade autenticación administrativa real (OIDC/JWT), autorización por roles, rate limiting, protección contra spam, monitorización, backups/restauración probados y una estrategia de reintentos de aprovisionamiento. La integración SUNAT y el cobro online no están incluidos en esta etapa.