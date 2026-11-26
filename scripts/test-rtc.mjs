import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { webcrypto } from 'node:crypto';
class Events{
  constructor(){this.events=new Map();}
  addEventListener(name,fn){const list=this.events.get(name)||[];list.push(fn);this.events.set(name,list);}
  removeEventListener(name,fn){this.events.set(name,(this.events.get(name)||[]).filter(x=>x!==fn));}
  emit(name,event={}){for(const fn of [...(this.events.get(name)||[])])fn(event);}
}
const window=new Events(), requests=[];
let openedPc, offerMessage;
const pairOrigin='http://192.168.31.40:18800';
const popup={postMessage(message,origin){assert.equal(origin,pairOrigin);offerMessage=message;
  queueMicrotask(()=>window.emit('message',{origin,source:popup,data:{type:'jw-rtc-answer',id:message.id,sdp:'answer'}}));},close(){}};
window.open=(url)=>{assert.equal(url,pairOrigin+'/pair');queueMicrotask(()=>window.emit('message',{origin:pairOrigin,source:popup,data:{type:'jw-rtc-ready'}}));return popup;};
class Channel extends Events{
  readyState='connecting';
  send(raw){
    const req=JSON.parse(raw);requests.push(req);
    const payload=req.path.includes('/media/')?Uint8Array.from({length:70000},(_,i)=>i%251):new TextEncoder().encode('{"Id":"fixture","ServerName":"Gateway"}');
    queueMicrotask(()=>{
      this.emit('message',{data:JSON.stringify({id:req.id,status:200,length:payload.length,headers:{'content-type':'application/octet-stream'}})});
      for(let i=0;i<payload.length;i+=16384){
        const part=payload.slice(i,i+16384),chunk=new Uint8Array(4+part.length);
        new DataView(chunk.buffer).setUint32(0,req.id);chunk.set(part,4);
        this.emit('message',{data:chunk.buffer});
      }
    });
  }
}
class PC extends Events{
  constructor(config){super();assert.equal(config.iceServers.length,0);this.iceGatheringState='complete';openedPc=this;}
  createDataChannel(label,options){assert.equal(label,'jealouswin-rpc');assert.equal(options.ordered,true);this.ch=new Channel();return this.ch;}
  async createOffer(){return {type:'offer',sdp:'v=0\r\na=candidate:1 1 udp 1 192.168.31.209 12345 typ host\r\na=candidate:2 1 udp 1 10.0.0.2 12345 typ host\r\na=candidate:3 1 udp 1 2001:db8::1 12345 typ host\r\n'};}
  async setLocalDescription(offer){this.localDescription=offer;}
  async setRemoteDescription(){this.connectionState='connected';this.ch.readyState='open';this.ch.emit('open');}
  close(){this.connectionState='closed';this.ch.readyState='closed';}
}
const context={window,location:{origin:'https://jealouswin.pages.dev'},RTCPeerConnection:PC,crypto:webcrypto,URL,ArrayBuffer,DataView,Uint8Array,TextDecoder,performance,setTimeout,clearTimeout};
vm.runInNewContext(fs.readFileSync('web/rtc.js','utf8'),context);
const rtc=window.jealouswinRtc;
const base='http://192.168.31.40:18796';
assert.equal(rtc.canRoute(base),true);
assert.equal(rtc.canRoute('http://example.org:18796'),false);
assert.equal(rtc.canRoute('http://192.168.31.40:22'),false);
assert.equal(rtc.canRoute('https://192.168.31.40:18796'),false);
const response=await rtc.request(base+'/System/Info/Public','GET',{},null,true);
assert.equal(response.status,200);
assert.match(new TextDecoder().decode(response.bytes),/fixture/);
assert.match(offerMessage.sdp,/192\.168\.31\.209/);
assert.doesNotMatch(offerMessage.sdp,/10\.0\.0\.2|2001:db8/);
const loader=new rtc.Loader();
await new Promise((resolve,reject)=>loader.load({url:base+'/media/token/segment.ts',responseType:'arraybuffer',rangeStart:0,rangeEnd:70000},{timeout:5000},{
  onSuccess:(r,s)=>{try{assert.equal(r.data.byteLength,70000);assert.equal(new Uint8Array(r.data)[69999],69999%251);assert.equal(s.loaded,70000);assert.equal(requests.at(-1).headers.Range,'bytes=0-69999');resolve();}catch(e){reject(e);}},
  onError:reject,onTimeout:()=>reject(new Error('timeout'))
}));
assert.equal(openedPc.connectionState,'connected');
loader.destroy();
context.location.origin='http://192.168.31.40:18796';assert.equal(rtc.canRoute(base),false);
console.log('WebRTC signaling, route filtering, RPC framing and HLS loader fixture tests passed');
