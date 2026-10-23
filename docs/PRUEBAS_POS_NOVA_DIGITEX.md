# NOVA DIGITEX — pruebas de aceptación del POS

Este checklist debe completarse en un entorno de pruebas antes de usar el POS con dinero real. La aplicación local no requiere internet para registrar ventas después de cargar el archivo en un navegador compatible, pero esos datos permanecen en ese dispositivo.

## Pruebas locales

- [ ] Abrir `pos.html` con conexión HTTPS, esperar que termine de cargar y volver a abrirlo en modo avión.
- [ ] Crear un producto con precio positivo, costo no negativo y stock entero.
- [ ] Intentar registrar un producto con código duplicado; debe rechazarlo.
- [ ] Vender un producto con stock suficiente y confirmar que la venta aparece en el historial y el stock disminuye.
- [ ] Intentar vender más unidades que las disponibles; debe rechazarlo sin cambiar el stock.
- [ ] Intentar cobrar en efectivo con importe insuficiente; debe rechazarlo.
- [ ] Simular almacenamiento lleno o bloqueado. El POS no debe anunciar una venta como guardada si falla la persistencia.
- [ ] Exportar un respaldo JSON, importar el mismo archivo en un perfil de prueba y comparar productos, ventas y existencias.
- [ ] Probar impresión de ticket en papel/PDF y confirmar que el texto indica que es un ticket interno, no un comprobante SUNAT.
- [ ] Cerrar y volver a abrir el navegador; verificar que productos e historial siguen presentes.

## Pruebas de sincronización (pendientes)

- [ ] Implementar el procesador transaccional de `nexo_sync_operations` usando el esquema real de `nexo_pos_checkout`.
- [ ] Validar cada campo del payload en servidor y comprobar rol, empresa, plan y estado de la empresa.
- [ ] Procesar la misma clave de operación dos veces, incluso en solicitudes concurrentes; debe existir una sola venta y un solo descuento de stock.
- [ ] Simular caída de conexión antes, durante y después de la respuesta; reintentar sin duplicar operaciones.
- [ ] Verificar que errores permanentes se registren como fallidos y puedan diagnosticarse sin exponer secretos.
- [ ] Confirmar que los datos sincronizados desde un dispositivo aparecen en otro dispositivo autorizado.

## Pruebas SUNAT y despliegue (pendientes)

- [ ] Configurar proveedor/credenciales de emisión solo en el servidor.
- [ ] Emitir comprobantes de prueba, validar respuesta y XML/CDR según el flujo aplicable.
- [ ] Probar contingencia y regularización de comprobantes; no convertir tickets internos en comprobantes fiscales.
- [ ] Probar cuentas de empresa, superadministrador, permisos y aislamiento entre empresas.
- [ ] Probar copias de seguridad y restauración completa.
- [ ] Empaquetar y probar Windows y Android en dispositivos reales.

## Resultado actual

Se mejoró el caché de la interfaz y el flujo de cobro local para que primero intente persistir la venta completa; si la escritura falla, no confirma la venta ni descuenta el stock del estado en memoria. Estos cambios todavía requieren ejecución de las pruebas anteriores. La sincronización multi-dispositivo y la integración SUNAT no están terminadas.
