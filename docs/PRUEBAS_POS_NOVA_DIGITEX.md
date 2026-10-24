# NOVA DIGITEX — pruebas de aceptación del POS

Estas pruebas deben ejecutarse en un entorno de prueba antes de usar el POS con dinero real. Las pruebas automáticas de CI comprueban sintaxis JavaScript, sintaxis del service worker y formato JSON del manifiesto; no simulan un navegador ni certifican ventas reales.

## A. Pruebas locales manuales

- [ ] Publicar la rama en HTTPS y abrir `pos.html` con internet. Esperar a que termine de cargar y comprobar que el service worker queda registrado.
- [ ] Recargar una vez con internet para permitir que se almacene la interfaz y el manifiesto en caché.
- [ ] Activar modo avión y volver a abrir la URL del POS desde el mismo navegador/perfil. Debe mostrar la interfaz previamente cacheada.
- [ ] Confirmar que abrir el POS offline solo funciona después de la primera carga en línea y mientras el navegador conserve el caché y los datos del sitio.
- [ ] Crear un producto con precio positivo, costo no negativo y stock entero.
- [ ] Intentar registrar un producto con código duplicado; debe rechazarlo.
- [ ] Vender un producto con stock suficiente; comprobar que aparece en el historial y que el stock disminuye exactamente una vez.
- [ ] Intentar vender más unidades que las disponibles; debe rechazarlo sin cambiar el stock.
- [ ] Intentar cobrar en efectivo con importe insuficiente; debe rechazarlo.
- [ ] Probar almacenamiento lleno/bloqueado en un perfil desechable. El POS no debe confirmar ni imprimir una venta como guardada si falla la escritura.
- [ ] Exportar una copia JSON; restaurarla en un perfil de prueba y comparar productos, ventas y existencias.
- [ ] Imprimir ticket en papel/PDF y confirmar que dice “ticket interno” y “No es comprobante electrónico SUNAT”.
- [ ] Cerrar el navegador, volver a abrir el POS y confirmar que los datos locales siguen presentes.
- [ ] En DevTools/Application/Service Workers, comprobar que el service worker activo es v3 y que la caché contiene `pos.html` y `manifest.webmanifest`.

## B. Limitaciones offline conocidas

- La interfaz y los datos guardados en el almacenamiento local pueden usarse sin internet en ese mismo navegador/dispositivo.
- No existe todavía un contador ni una cola de ventas sincronizables conectada al servidor; no afirmar que hay “pendientes de sincronización”.
- El almacenamiento del navegador no es una base de datos central y puede perderse si se borran los datos del sitio. Descargar respaldos regularmente.
- La caché de la interfaz no permite sincronizar equipos entre sí ni emitir comprobantes SUNAT.

## C. Pruebas de sincronización (pendientes de implementación)

- [ ] Implementar el procesador transaccional de la bandeja `nexo_sync_operations` ajustado al esquema y RPC reales de la base de datos.
- [ ] Validar payload, rol, empresa, plan y estado de la empresa en servidor.
- [ ] Enviar dos veces la misma clave de operación, incluidas solicitudes concurrentes; debe resultar una sola venta y un solo descuento de stock.
- [ ] Simular pérdida de conexión antes, durante y después de la respuesta; reintentar sin duplicar operaciones.
- [ ] Comprobar que los datos de un dispositivo aparecen en otro dispositivo autorizado.
- [ ] Confirmar que los errores permanentes se registran sin exponer credenciales ni datos sensibles.

## D. SUNAT y despliegue (pendientes)

- [ ] Implementar un servicio servidor con credenciales y certificados privados guardados fuera del frontend.
- [ ] Probar emisión electrónica, XML, respuesta/CDR y contingencias según el tipo de comprobante y el flujo aplicable.
- [ ] Verificar aislamiento entre empresas, permisos y auditoría.
- [ ] Probar copia de seguridad y restauración completa.
- [ ] Empaquetar y probar Windows y Android en dispositivos reales.

## Resultado verificable actual

Se mejoró el flujo local para que la venta se escriba en almacenamiento antes de confirmar el cobro y se reforzó la estrategia de caché del shell del POS. La CI valida sintaxis y manifiesto; eso no sustituye las pruebas manuales en navegador. La sincronización multi-dispositivo, SUNAT y los instaladores Windows/Android siguen pendientes.
