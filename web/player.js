(() => {
  'use strict';
  const states = new WeakMap();
  const state = video => {
    if (!states.has(video)) states.set(video, {generation:0,hls:null,error:'',frames:0,frameHandle:null});
    return states.get(video);
  };
  // Opt in only for known local HTTP destinations, never public hosts.
  const localSpace = url => {
    const u = new URL(url);
    if (u.protocol !== 'http:' || location.protocol !== 'https:') return null;
    const host = u.hostname.toLowerCase();
    if (host === 'localhost' || host.endsWith('.localhost') || host === '[::1]' || /^127\./.test(host)) return 'loopback';
    const octets = host.split('.').map(Number);
    if (host.endsWith('.local') || (octets.length === 4 && octets.every(n => Number.isInteger(n) && n >= 0 && n <= 255) &&
      (octets[0] === 10 || (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31) ||
       (octets[0] === 192 && octets[1] === 168) || (octets[0] === 169 && octets[1] === 254)))) return 'local';
    return null;
  };
  const localRequest = (url, options) => {
    const space = localSpace(url);
    if (space) {
      // Older implementations may reject the newer enum. Fall back before
      // sending anything, so authentication is never retried automatically.
      for (const candidate of [space, 'private']) {
        try { return new Request(url, {...options, targetAddressSpace:candidate}); }
        catch (e) { if (!(e instanceof TypeError)) throw e; }
      }
    }
    return new Request(url, options);
  };
  window.jealouswinRequest = async (url,method,headers,body) => {
    const c = new AbortController(), timer=setTimeout(()=>c.abort(),25000);
    try {
      const r=await fetch(localRequest(url,{method,headers:JSON.parse(headers),body:body??undefined,
        credentials:'omit',redirect:'error',cache:'no-store',referrerPolicy:'no-referrer',signal:c.signal}));
      const text=await r.text();
      if(text.length>4*1024*1024) throw new Error('Response too large');
      return JSON.stringify({status:r.status,body:text});
    } catch(e) {
      // Do not serialize raw exception messages, URLs, or request bodies.
      return JSON.stringify({transportError:e?.name==='AbortError'?'timeout':'network'});
    } finally {clearTimeout(timer);}
  };
  window.jealouswinStop = video => {
    const s=state(video); s.generation++;
    if(s.hls){s.hls.destroy();s.hls=null;}
    if(s.frameHandle!==null && video.cancelVideoFrameCallback) video.cancelVideoFrameCallback(s.frameHandle);
    s.frameHandle=null;video.onloadedmetadata=null;video.onerror=null;
    video.pause();video.removeAttribute('src');video.load();s.error='';s.frames=0;
  };
  window.jealouswinPlay = video => {
    const s=state(video), g=s.generation;
    video.play().then(()=>{if(s.generation===g && s.error==='Press Play to allow playback.')s.error='';})
      .catch(()=>{if(s.generation===g)s.error='Press Play to allow playback.';});
  };
  window.jealouswinLoad = (video,raw) => {
    window.jealouswinStop(video);
    const s=state(video),g=s.generation,url=new URL(raw);
    const active=()=>s.generation===g;
    const fail=message=>{if(active())s.error=message;};
    video.onerror=()=>fail('Video delivery or browser codec error.');
    if(video.requestVideoFrameCallback){
      const frame=()=>{if(active()){s.frames++;s.frameHandle=video.requestVideoFrameCallback(frame);}};
      s.frameHandle=video.requestVideoFrameCallback(frame);
    }
    // Prefer MSE HLS on secure-to-local HTTP when available, to avoid
    // native media auto-upgrade and use the permission-aware network stack.
    const mseAvailable=Boolean(window.Hls && window.Hls.isSupported());
    if(video.canPlayType('application/vnd.apple.mpegurl') && !(localSpace(url.href) && mseAvailable)){
      video.crossOrigin='anonymous';video.src=url.href;
      video.onloadedmetadata=()=>{if(active())window.jealouswinPlay(video);};return;
    }
    if(!window.Hls||!window.Hls.isSupported()){fail('No supported HLS playback engine.');return;}
    const hls=new window.Hls({enableWorker:true,backBufferLength:30,maxBufferLength:30,
      xhrSetup:(xhr,target)=>{
        if(new URL(target,url).origin!==url.origin)throw new Error('Cross-origin media rejected');
        xhr.withCredentials=false;
      }});
    s.hls=hls;
    hls.on(window.Hls.Events.MEDIA_ATTACHED,()=>{if(active())hls.loadSource(url.href);});
    hls.on(window.Hls.Events.MANIFEST_PARSED,()=>{if(active())window.jealouswinPlay(video);});
    hls.on(window.Hls.Events.ERROR,(_,data)=>{
      if(data.fatal&&active()){
        fail(data.type===window.Hls.ErrorTypes.NETWORK_ERROR
          ?'HLS network delivery failed. Check LAN access and CORS.':'HLS playback or codec failure.');
        hls.stopLoad();
      }
    });
    hls.attachMedia(video);
  };
  window.jealouswinPlayerState=video=>{
    const s=state(video),frames=Math.max(s.frames,video.getVideoPlaybackQuality?.().totalVideoFrames||0);
    return JSON.stringify({position:Number.isFinite(video.currentTime)?video.currentTime:0,
      playing:!video.paused&&!video.ended&&video.readyState>=2&&!s.error,
      buffering:!video.paused&&video.readyState<3,frames,error:s.error,muted:video.muted});
  };
  window.jealouswinFullscreen=value=>{
    if(value&&!document.fullscreenElement)document.documentElement.requestFullscreen?.().catch(()=>{});
    if(!value&&document.fullscreenElement)document.exitFullscreen?.().catch(()=>{});
  };
})();
