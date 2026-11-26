(() => {
  'use strict';
  const publicOrigin='https://jealouswin.pages.dev';
  const peers=new Map(), pendingPairs=new Map();
  const maxResponse=8*1024*1024;
  const error=code=>Object.assign(new Error(code),{code});
  const canRoute=raw=>{
    try{
      const u=new URL(raw);
      if(location.origin!==publicOrigin||u.protocol!=='http:'||!['18796','18797'].includes(u.port))return false;
      const a=u.hostname.split('.').map(Number);
      return a.length===4&&a.every(n=>Number.isInteger(n)&&n>=0&&n<=255)&&
        (a[0]===10||(a[0]===172&&a[1]>=16&&a[1]<=31)||(a[0]===192&&a[1]===168));
    }catch(_){return false;}
  };
  const waitIce=pc=>new Promise((resolve,reject)=>{
    if(pc.iceGatheringState==='complete'){resolve();return;}
    const done=()=>{clearTimeout(timer);pc.removeEventListener('icegatheringstatechange',change);resolve();};
    const change=()=>{if(pc.iceGatheringState==='complete')done();};
    const timer=setTimeout(done,6000);
    pc.addEventListener('icegatheringstatechange',change);
  });
  class Peer {
    constructor(host,pc,channel){
      this.host=host;this.pc=pc;this.channel=channel;this.pending=new Map();this.sequence=0;
      channel.binaryType='arraybuffer';
      channel.addEventListener('message',e=>this.receive(e.data));
      channel.addEventListener('close',()=>this.close());
      pc.addEventListener('connectionstatechange',()=>{if(['failed','closed'].includes(pc.connectionState))this.close();});
    }
    get open(){return this.channel.readyState==='open';}
    close(){
      if(this.closed)return;
      this.closed=true;
      if(peers.get(this.host)===this)peers.delete(this.host);
      for(const p of this.pending.values()){clearTimeout(p.timer);p.reject(error('rtc-disconnected'));}
      this.pending.clear();this.pc.close();
    }
    receive(data){
      try{
        if(typeof data==='string'){
          const h=JSON.parse(data),p=this.pending.get(h.id);
          if(!p)return;
          if(p.bytes||!Number.isInteger(h.length)||h.length<0||h.length>maxResponse||!Number.isInteger(h.status)){this.close();return;}
          p.meta=h;p.bytes=new Uint8Array(h.length);p.offset=0;
          if(!h.length)this.complete(h.id,p);
        }else if(data instanceof ArrayBuffer){
          if(data.byteLength<4){this.close();return;}
          const id=new DataView(data).getUint32(0),p=this.pending.get(id);
          if(!p)return;
          const chunk=new Uint8Array(data,4);
          if(!p.bytes||p.offset+chunk.length>p.bytes.length){this.close();return;}
          p.bytes.set(chunk,p.offset);p.offset+=chunk.length;
          if(p.offset===p.bytes.length)this.complete(id,p);
        }else this.close();
      }catch(_){this.close();}
    }
    complete(id,p){
      clearTimeout(p.timer);this.pending.delete(id);
      p.resolve({status:p.meta.status,headers:p.meta.headers||{},bytes:p.bytes});
    }
    request(url,method,headers,body){
      if(!this.open)return Promise.reject(error('rtc-disconnected'));
      const u=new URL(url);
      if(!canRoute(url)||u.hostname!==this.host||this.pending.size>=12)return Promise.reject(error('rtc-request-rejected'));
      const id=(++this.sequence)>>>0;
      if(!id){this.close();return Promise.reject(error('rtc-disconnected'));}
      return new Promise((resolve,reject)=>{
        const timer=setTimeout(()=>{this.pending.delete(id);reject(error('timeout'));},50000);
        this.pending.set(id,{resolve,reject,timer,bytes:null});
        try{this.channel.send(JSON.stringify({id,port:Number(u.port),method,path:u.pathname+u.search,headers,body:body??null}));}
        catch(_){clearTimeout(timer);this.pending.delete(id);reject(error('rtc-disconnected'));}
      });
    }
  }
  const establish=host=>{
    if(typeof RTCPeerConnection!=='function')return Promise.reject(error('rtc-unsupported'));
    const origin='http://'+host+':18800';
    // Open synchronously during the user-initiated Connect gesture.
    const popup=window.open(origin+'/pair','jealouswin-pair-'+host.replaceAll('.','-'));
    if(!popup)return Promise.reject(error('rtc-popup-blocked'));
    const pc=new RTCPeerConnection({iceServers:[]});
    const ch=pc.createDataChannel('jealouswin-rpc',{ordered:true});
    const peer=new Peer(host,pc,ch);
    const id=crypto.randomUUID();
    return new Promise((resolve,reject)=>{
      let offer=null,ready=false,finished=false,answered=false;
      const send=()=>{if(ready&&offer&&!finished&&!answered)popup.postMessage({type:'jw-rtc-offer',id,sdp:offer},origin);};
      const cleanup=()=>{clearTimeout(timer);window.removeEventListener('message',message);ch.removeEventListener('open',open);ch.removeEventListener('close',closed);};
      const fail=code=>{if(finished)return;finished=true;cleanup();peer.close();try{popup.close();}catch(_){}reject(error(code));};
      const open=()=>{if(finished)return;finished=true;cleanup();peers.set(host,peer);try{popup.close();}catch(_){}resolve(peer);};
      const closed=()=>fail('rtc-disconnected');
      const message=async e=>{
        if(e.origin!==origin||e.source!==popup||finished)return;
        if(e.data?.type==='jw-rtc-ready'){ready=true;send();return;}
        if(e.data?.type!=='jw-rtc-answer'||e.data.id!==id||typeof e.data.sdp!=='string'||answered)return;
        answered=true;
        try{await pc.setRemoteDescription({type:'answer',sdp:e.data.sdp});}
        catch(_){fail('rtc-pairing-failed');}
      };
      const timer=setTimeout(()=>fail('rtc-pairing-timeout'),150000);
      window.addEventListener('message',message);ch.addEventListener('open',open);ch.addEventListener('close',closed);
      (async()=>{
        try{
          await pc.setLocalDescription(await pc.createOffer());
          await waitIce(pc);
          // Retain only UDP host candidates. No public STUN/TURN services.
          const prefix=host.split('.').slice(0,3).join('.')+'.';
          offer=pc.localDescription.sdp.split(/\r?\n/).filter(line=>{
            if(!line.startsWith('a=candidate:'))return true;
            const parts=line.split(/\s+/),address=parts[4]||'';
            return parts[2]?.toLowerCase()==='udp'&&parts[6]==='typ'&&parts[7]==='host'&&
              (address.startsWith(prefix)&&/^\d+\.\d+\.\d+\.\d+$/.test(address)||/^[a-f0-9-]{36}\.local$/i.test(address));
          }).join('\r\n');
          send();
        }catch(_){fail('rtc-pairing-failed');}
      })();
    });
  };
  const getPeer=async (url,allowPair)=>{
    const host=new URL(url).hostname,existing=peers.get(host);
    if(existing?.open)return existing;
    if(pendingPairs.has(host))return pendingPairs.get(host);
    if(!allowPair)throw error('rtc-disconnected');
    const promise=establish(host);pendingPairs.set(host,promise);
    try{return await promise;}finally{pendingPairs.delete(host);}
  };
  const request=async(url,method,headers,body,allowPair=false)=>{
    const peer=await getPeer(url,allowPair);
    return peer.request(url,method,headers,body);
  };
  const stats=()=>({aborted:false,loaded:0,total:0,retry:0,chunkCount:0,bwEstimate:0,
    loading:{start:0,first:0,end:0},parsing:{start:0,end:0},buffering:{start:0,first:0,end:0}});
  class RtcLoader {
    constructor(){this.stats=stats();this.generation=0;this.context=null;this.headers={};}
    load(context,config,callbacks){
      this.context=context;this.stats=stats();this.headers={};
      const g=++this.generation,s=this.stats;
      s.loading.start=performance.now();
      const headers={...(context.headers||{})};
      if(Number.isFinite(context.rangeEnd)&&context.rangeEnd>context.rangeStart)headers.Range='bytes='+context.rangeStart+'-'+(context.rangeEnd-1);
      const timeout=config?.loadPolicy?.maxLoadTimeMs||config?.timeout||50000;
      this.timer=setTimeout(()=>{if(g!==this.generation)return;this.generation++;s.loading.end=performance.now();callbacks.onTimeout(s,context,null);},Math.min(timeout,50000));
      request(context.url,'GET',headers,null).then(r=>{
        if(g!==this.generation)return;clearTimeout(this.timer);this.headers=r.headers;
        s.loading.first=s.loading.end=performance.now();s.loaded=s.total=r.bytes.byteLength;
        s.chunkCount=1;s.bwEstimate=s.loaded*8000/Math.max(1,s.loading.end-s.loading.start);
        if(r.status<200||r.status>=300){callbacks.onError({code:r.status,text:'LAN media response '+r.status},context,null,s);return;}
        const data=context.responseType==='arraybuffer'?r.bytes.buffer:new TextDecoder().decode(r.bytes);
        if(callbacks.onProgress&&context.responseType==='arraybuffer')callbacks.onProgress(s,context,data,null);
        callbacks.onSuccess({url:context.url,data,code:r.status},s,context,null);
      }).catch(e=>{
        if(g!==this.generation)return;clearTimeout(this.timer);s.loading.end=performance.now();
        callbacks.onError({code:0,text:'WebRTC media transport failed'},context,null,s);
      });
    }
    abort(){this.generation++;clearTimeout(this.timer);this.stats.aborted=true;}
    destroy(){this.abort();this.context=null;this.headers={};}
    getCacheAge(){return null;}
    getResponseHeader(name){return this.headers[name.toLowerCase()]||null;}
  }
  window.jealouswinRtc={canRoute,request,Loader:RtcLoader};
})();
