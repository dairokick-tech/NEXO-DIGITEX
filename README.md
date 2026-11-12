# GESTOR DE PAGOS

Aplicación web para registrar y controlar pagos realizados, pendientes y vencidos, asociar personas o empresas y guardar comprobantes PDF e imágenes.

## Publicación

El proyecto está preparado como sitio estático para GitHub Pages. El archivo principal es `index.html`.

URL del sitio (cuando GitHub Pages termine de publicar el cambio):
https://dairokick-tech.github.io/NEXO-DIGITEX/

## Funciones incluidas

- Resumen de importes pagados, pendientes y vencidos.
- Registro y edición de pagos con concepto, importe, fecha, vencimiento, estado, método y número de operación.
- Asociación de pagos con personas o empresas.
- Adjuntar comprobantes PDF e imágenes (máximo 12 MB por archivo).
- Búsqueda y filtros por estado y mes.
- Directorio de personas y empresas.
- Reporte por período.
- Exportación de pagos a CSV.
- Respaldo completo e importación de datos y archivos adjuntos en JSON.

## Almacenamiento y privacidad

Esta versión **no utiliza Supabase ni otro backend**. Los registros y comprobantes se guardan en IndexedDB del navegador del dispositivo. GitHub Pages aloja el código de la aplicación, no los documentos personales ni financieros.

- Los datos no se sincronizan automáticamente entre dispositivos o navegadores.
- Si borras los datos del sitio, puedes perder los registros locales.
- Descarga copias de seguridad periódicas y guárdalas en un lugar privado.
- Los respaldos pueden contener información sensible: no los subas al repositorio ni los compartas públicamente.
- El almacenamiento del navegador no equivale a una bóveda cifrada ni a un sistema multiusuario.

## Alcance

Esta es la primera versión funcional de la aplicación estática. Antes de usarla para documentación financiera importante, prueba el registro, la edición, los adjuntos y la restauración de copias con información ficticia. No incluye sincronización en nube, cuentas de usuario, permisos multiusuario ni envío automático de notificaciones.

## Tecnología

HTML, CSS, JavaScript e IndexedDB. Sin dependencias de Supabase.
