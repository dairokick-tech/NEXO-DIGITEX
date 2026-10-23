const CACHE_NAME='nova-digitex-pos-v1';
const ASSETS=['./pos.html','./manifest.webmanifest'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE_NAME).then(cache=>cache.addAll(ASSETS)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('nova-digitex-pos-')&&k!==CACHE_NAME).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;
  const url=new URL(request.url);
  if(url.origin!==self.location.origin)return;
  const isPosPage=url.pathname.endsWith('/pos.html') || url.pathname==='/pos.html';
  if(request.mode==='navigate' && isPosPage){
    event.respondWith(fetch(request).then(response=>{
      if(response.ok){const copy=response.clone();caches.open(CACHE_NAME).then(cache=>cache.put('./pos.html',copy));}
      return response;
    }).catch(()=>caches.match('./pos.html')));
  } else if(url.pathname.endsWith('/manifest.webmanifest') || url.pathname.endsWith('/pos.html')) {
    event.respondWith(caches.match(request).then(cached=>cached||fetch(request)));
  }
});