# NOVA DIGITEX — recepción autenticada de operaciones offline

## Qué se añadió

La función `supabase/functions/nexo-sync-operations/index.ts` recibe una operación autenticada y la registra en `public.nexo_sync_operations`. La restricción única `(company_id, operation_id)` protege contra la inserción repetida de la misma operación; una repetición del mismo usuario y tipo devuelve la operación ya existente.

La función usa la sesión JWT del usuario y la clave pública `SUPABASE_ANON_KEY`. No incluye ni necesita una clave `service_role` en el navegador o en el repositorio. La pertenencia a la empresa y la lectura de la operación existente quedan sujetas a las políticas RLS de la tabla.

## Payload esperado

```json
{
  "company_id": "UUID-DE-LA-EMPRESA",
  "operation_id": "UUID-ESTABLE-DE-LA-OPERACION",
  "operation_type": "sale.create",
  "payload": {
    "sale": {
      "id": "UUID-IGUAL-A-operation_id",
      "number": "V-000001",
      "items": [],
      "total": 0
    }
  }
}
```

Encabezados: `Authorization: Bearer <sesión JWT del usuario>`, `apikey: <clave pública>`, `Content-Type: application/json`.

Tipos permitidos: `sale.create`, `stock.adjust`, `customer.upsert`, `cash.movement`.

## Respuestas relevantes

- `201`: operación añadida a la bandeja.
- `200` con `duplicate: true`: ya existía la misma operación.
- `401`: falta una sesión válida.
- `403`: la política RLS impide acceder a la empresa.
- `409`: el identificador ya existe con una operación incompatible.
- `500`: error de configuración o base de datos; revisar los logs de la función.

## Límites importantes

**Esta función solo recibe y pone en cola operaciones. No registra la venta final, no descuenta inventario y no devuelve una confirmación de cobro.** El procesador transaccional de ventas sigue pendiente hasta revisar los resultados de `docs/SQL_DIAGNOSTICO_SEGURO_NOVA_DIGITEX.sql`, especialmente la definición y firma real de `nexo_pos_checkout`, las tablas de detalle, las restricciones y las políticas RLS. No se debe conectar el POS local a este endpoint como si la venta ya estuviera sincronizada.

El POS local de `pos.html` todavía no tiene una sesión autenticada ni un `company_id` fiable, por lo que este endpoint aún no está conectado a la interfaz.

## Pruebas previas a producción

1. Aplicar la migración de `nexo_sync_operations` únicamente en un entorno de prueba revisado.
2. Desplegar la función en un entorno de prueba y verificar que el gateway exige JWT.
3. Enviar una operación con un usuario miembro de la empresa: debe crear una sola fila.
4. Repetir exactamente la operación: debe responder `duplicate: true` y no crear otra fila.
5. Probar con usuario sin membresía: debe rechazarse por RLS.
6. Probar UUID inválido, tipo no permitido y payload excesivo.
7. Verificar logs y que ningún secreto de servicio se expone en frontend.
8. Solo después implementar y probar el procesador transaccional de ventas y el cliente de sincronización.

No aplicar cambios a producción ni anunciar sincronización multi-dispositivo hasta pasar estas pruebas.
