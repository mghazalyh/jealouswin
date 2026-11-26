(() => {
  'use strict';
  const states = new WeakMap();
  const state = video => {
    if (!states.has(video)) states.set(video, {generation:0,hls:null,error:'',frames:0,frameHandle:null});
    return states.get(video);
  };
  window.jealouswinRequest = async (url,method,headers,body) => {
    const c = new AbortController(), timer=setTimeout(()=>c.abort(),25000);
    try {
      const r=await fetch(url,{method,headers:JSON.parse(headers),body:body??undefined,
        credentials:'omit',redirect:'error',cache:'no-store',referrerPolicy:'no-referrer',signal:c.signal});
      const text=await r.text();
      if(text.length>4*1024*1024) throw new Error('Response too large');
      return JSON.stringify({status:r.status,body:text});
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
    if(video.canPlayType('application/vnd.apple.mpegurl')){
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
