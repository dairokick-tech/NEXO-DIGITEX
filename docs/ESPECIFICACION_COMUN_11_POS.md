# NEXO DIGITEX — especificación común de los 11 POS

Todos los POS por rubro deben implementar este contrato funcional compartido. Los módulos especializados complementan estas funciones, no las sustituyen.

## Funciones obligatorias
1. Caja: apertura, cierre y arqueo por cajero, importe inicial, efectivo esperado, efectivo contado, diferencia y responsable.
2. Ventas: contado y crédito solo con autorización vigente; conservar vendedor, cajero, sucursal, hora y detalle.
3. Medios de pago: efectivo, tarjeta, transferencia y billeteras digitales; registrar pagos divididos si la configuración lo permite.
4. Descuentos: límite por rol y autorización de supervisor/administrador para superar el límite. Registrar motivo y aprobador.
5. Anulaciones y devoluciones: motivo obligatorio, estado de autorización, usuario solicitante y aprobador, relación con la venta original y trazabilidad; nunca borrar el movimiento original.
6. Comprobantes: impresión de ticket y comprobante configurado; numeración controlada. La emisión electrónica SUNAT solo se considera operativa después de configurar credenciales, certificado, series y pruebas de aceptación.
7. Inventario: descontar stock únicamente al confirmar la venta; las devoluciones aprobadas generan el movimiento inverso según el estado del producto. Cada movimiento debe ser trazable.
8. Historial: ventas, pagos, caja, anulaciones, devoluciones y movimientos de inventario filtrables por fecha, sucursal y usuario.
9. Offline: cola persistente por dispositivo, identificador de idempotencia único, reintentos seguros, estado de sincronización y resolución explícita de conflictos; no afirmar sincronización hasta confirmar respuesta del servidor.
10. Compatibilidad: Windows y Android mediante interfaz adaptable; impresión, lector y cajón de dinero dependen de compatibilidad del sistema operativo, conexión y modelo del periférico.
11. Roles: cajero, vendedor, supervisor y administrador con permisos comprobados en servidor, no solo ocultando botones en pantalla.
12. Cotizaciones: dirigidas a colegios y empresas, datos del cliente, líneas, cantidades, descuentos, impuestos, validez, estados, aprobación y conversión trazable a venta sin duplicar inventario.

## Criterios mínimos de aceptación
- Dos reintentos con la misma clave de idempotencia no crean dos ventas, pagos ni devoluciones.
- No se descuenta inventario por cotización, borrador ni venta no confirmada.
- Una devolución no supera cantidades vendidas menos cantidades ya devueltas.
- Un cajero no puede cerrar una caja ajena ni aprobar sus propios descuentos fuera de sus permisos.
- Una anulación no elimina registros; crea evento de auditoría.
- Si no hay internet, la operación queda marcada como pendiente y visible para sincronización.
- Si SUNAT no está configurada o rechaza un comprobante, el sistema muestra el estado real y no afirma que fue aceptado.
- Probar el flujo en cada uno de los 11 rubros y en Windows/Android antes de declarar el producto listo.

## Estado de entrega
Este documento fija el alcance. El esquema de base de datos asociado es supabase/migrations/20261024_common_pos_operations.sql. Crear una migración no significa que ya haya sido aplicada en Supabase ni que todos los flujos estén integrados en la interfaz; se requieren políticas RLS por empresa/sucursal, integración de servidor, interfaz, pruebas y configuración de SUNAT.
