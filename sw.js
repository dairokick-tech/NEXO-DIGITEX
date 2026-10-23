/* NOVA DIGITEX POS — caché de aplicación para uso local sin conexión.
 * Solo cachea la interfaz pública. No almacena ventas ni credenciales.
 */
'use strict';
const CACHE_NAME = 'nova-digitex-pos-v2';
const APP_SHELL = ['./pos.html', './manifest.webmanifest'];

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await cache.addAll(APP_SHELL);
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys
      .filter(key => key.startsWith('nova-digitex-pos-') && key !== CACHE_NAME)
      .map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  const isPos = url.pathname.endsWith('/pos.html') || url.pathname === '/pos.html';
  const isManifest = url.pathname.endsWith('/manifest.webmanifest');
  if (!isPos && !isManifest) return;

  if (request.mode === 'navigate' && isPos) {
    event.respondWith((async () => {
      try {
        const response = await fetch(request);
        if (response && response.ok) {
          const cache = await caches.open(CACHE_NAME);
          await cache.put('./pos.html', response.clone());
        }
        return response;
      } catch {
        return (await caches.match('./pos.html')) || Response.error();
      }
    })());
    return;
  }

  event.respondWith((async () => {
    const cached = await caches.match(request) || await caches.match(isPos ? './pos.html' : './manifest.webmanifest');
    if (cached) {
      fetch(request).then(async response => {
        if (response && response.ok) {
          const cache = await caches.open(CACHE_NAME);
          await cache.put(isPos ? './pos.html' : './manifest.webmanifest', response);
        }
      }).catch(() => {});
      return cached;
    }
    return fetch(request);
  })());
});
