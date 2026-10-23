# NOVA DIGITEX — plan de evolución seguro

Este trabajo se desarrolla en la rama `nova-digitex-build` para no sobrescribir `main` ni eliminar datos existentes.

## Alcance acordado
- Conservar el sitio actual de NEXO-DIGITEX como base.
- Evolucionar la marca y los flujos hacia NOVA DIGITEX.
- Separar administración central y acceso por empresa.
- Operación comercial multiempresa y permisos aplicados en servidor.
- POS e inventario; rubros configurables (bodega/minimarket, ropa/calzado, ferretería, restaurante, farmacia, librería, electrónica/repuestos y mayoristas).
- Modo offline con identificadores idempotentes y sincronización posterior.
- Preparación de integración SUNAT mediante un proveedor/servicio seguro, con credenciales solo en servidor.
- Clientes, proveedores, compras, caja, reportes y auditoría.
- Despliegue web adaptable; para Windows/Android se requiere empaquetado y pruebas específicas.

## Primer cambio de base de datos
La migración `20261023_offline_sync_operations.sql` agrega una bandeja de operaciones con una restricción única por empresa e identificador de operación. Es aditiva y no elimina tablas ni registros existentes. Los clientes solo pueden encolar operaciones propias; el procesamiento y la actualización del resultado quedan reservados al servidor de confianza.

## Importante: estado real
Esta migración es infraestructura, no una sincronización completa por sí sola. Aún hace falta implementar el procesador transaccional que valide el payload, aplique la venta/stock, guarde el resultado y haga reintentos seguros; además de pruebas de concurrencia y RLS. No se debe usar para ventas reales hasta completar y probar ese flujo.

## Orden de trabajo
1. Revisar y respaldar el esquema conectado antes de aplicar migraciones.
2. Terminar autenticación, superadministrador y aislamiento multiempresa.
3. Implementar productos/clientes/ventas con transacciones y pruebas de idempotencia.
4. Construir cola local persistente en web/Android y sincronización con reintentos.
5. Completar caja, compras, stock, módulos por rubro, auditoría y reportes.
6. Integrar SUNAT en entorno de pruebas y luego certificar el flujo legal aplicable.
7. Empaquetar Windows/Android, probar recuperación, copias y restauración.

## Seguridad y despliegue
- Nunca incluir `service_role`, contraseñas ni certificados privados en el frontend o en el repositorio.
- No aplicar la migración a producción sin validar primero las funciones RLS existentes y tener una copia de respaldo.
- La rama de trabajo no cambia automáticamente el sitio publicado desde `main`.
