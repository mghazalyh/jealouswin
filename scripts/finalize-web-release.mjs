import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
const release=process.env.GITHUB_SHA;
assert.match(release||'',/^[0-9a-f]{40}$/);
const base='build/web';
const read=name=>readFileSync(join(base,name),'utf8');
const write=(name,data)=>writeFileSync(join(base,name),data);
let index=read('index.html');
assert.equal(index.split('__JEALOUSWIN_RELEASE__').length,2,'release marker absent or duplicated');
index=index.replace('__JEALOUSWIN_RELEASE__',release);
for(const asset of ['hls.min.js','assets/jealouswin/rtc.js','player.js']){
  const marker='src="'+asset+'"';
  assert.ok(index.includes(marker),'missing script '+asset);
  index=index.replace(marker,'src="'+asset+'?release='+release+'"');
}
write('index.html',index);
let bootstrap=read('flutter_bootstrap.js');
assert.match(bootstrap,/"mainJsPath"\s*:\s*"main\.dart\.js"/,'Flutter entrypoint config missing');
bootstrap=bootstrap.replace(/("mainJsPath"\s*:\s*")main\.dart\.js"/,'$1main.dart.js?release='+release+'"');
write('flutter_bootstrap.js',bootstrap);
// Existing clients can update from the old worker URL without an offline app cache.
write('flutter_service_worker.js',`self.addEventListener('install',event=>event.waitUntil(self.skipWaiting()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  const names=await caches.keys();
  await Promise.all(names.filter(n=>['flutter-app-cache','flutter-temp-cache','flutter-app-manifest'].includes(n)).map(n=>caches.delete(n)));
  await self.clients.claim();
  await self.registration.unregister();
})()));
`);
write('_headers','/*\n  Cache-Control: no-store, max-age=0, must-revalidate\n');
console.log('Versioned web release and retired legacy worker:',release);
