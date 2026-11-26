import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
const requests=[];
class MockRequest {
  constructor(url,options){this.url=url;this.options=options;}
}
const context={window:{},location:{protocol:'https:'},URL,Request:MockRequest,AbortController,setTimeout,clearTimeout,
  fetch:async request=>{requests.push(request);return {status:200,text:async()=>'{}'};}};
vm.runInNewContext(fs.readFileSync('web/player.js','utf8'),context);
const send=url=>context.window.jealouswinRequest(url,'GET','{}',null);
await send('http://192.168.31.40:18796/System/Info/Public');
assert.equal(requests.at(-1).options.targetAddressSpace,'local');
await send('https://example.com/');
assert.equal(requests.at(-1).options.targetAddressSpace,undefined);
context.location.protocol='http:';
await send('http://192.168.31.40:18796/System/Info/Public');
assert.equal(requests.at(-1).options.targetAddressSpace,undefined);
assert.equal(requests.at(-1).options.credentials,'omit');
context.fetch=async()=>{throw new Error('sensitive-url');};
assert.deepEqual(JSON.parse(await send('http://192.168.31.40:18796/System/Info/Public')),{transportError:'network'});
console.log('Browser transport fixture tests passed');
