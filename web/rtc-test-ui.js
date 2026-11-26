(() => {
  'use strict';
  const base='http://192.168.31.40:18802';
  const $=id=>document.getElementById(id);
  const video=$('video'),start=$('start'),stop=$('stop'),status=$('status'),result=$('result');
  let generation=0,active=false,passed=false,connected=false,startedAt=0;
  const reset=()=>{
    passed=false;result.textContent='Waiting for decoded video';result.dataset.pass='false';
    $('frames').textContent='0';$('position').textContent='0.0 s';$('resolution').textContent='—';
  };
  start.addEventListener('click',async()=>{
    const g=++generation;
    active=false;start.disabled=true;stop.disabled=false;reset();
    $('connection').textContent='Pairing';status.textContent='Approve LAN connection in the pairing tab.';
    try{
      if(!window.jealouswinRtc?.canRoute(base)||!window.Hls?.isSupported())throw new Error('This browser cannot play this WebRTC HLS test.');
      const response=await window.jealouswinRtc.request(base+'/System/Info/Public','GET',{},null,true);
      if(g!==generation)return;
      if(response.status!==200)throw new Error('Test gateway returned HTTP '+response.status);
      connected=true;$('connection').textContent='WebRTC connected';
      status.textContent='Connected. Loading test video…';active=true;startedAt=performance.now();
      video.muted=true;
      window.jealouswinLoad(video,base+'/media/fixture/index.m3u8');
    }catch(e){
      if(g!==generation)return;
      const code=e?.code;
      status.textContent=code==='rtc-popup-blocked'?'Allow pop-ups and try again.':code==='rtc-pairing-timeout'?'Pairing timed out. Check home Wi-Fi and approve the pairing tab.':code?'WebRTC connection failed: '+code:String(e?.message||'Connection failed');
      $('connection').textContent='Failed';result.textContent='Not played';active=false;stop.disabled=true;start.disabled=false;
    }
  });
  stop.addEventListener('click',()=>{
    generation++;active=false;window.jealouswinStop(video);start.disabled=false;stop.disabled=true;
    status.textContent=passed?'Test passed. Video stopped.':'Video stopped.';
  });
  video.addEventListener('ended',()=>{
    active=false;start.disabled=false;stop.disabled=true;
    status.textContent=passed?'Test passed. Video finished. Press Play test video to replay.':'Video ended without confirmed decoded playback.';
  });
  setInterval(()=>{
    if(!active)return;
    const state=JSON.parse(window.jealouswinPlayerState(video));
    $('frames').textContent=String(state.frames);
    $('position').textContent=state.position.toFixed(1)+' s';
    $('resolution').textContent=video.videoWidth?video.videoWidth+' × '+video.videoHeight:'—';
    if(state.position>=2&&state.frames>0&&video.videoWidth>0){
      passed=true;result.textContent='PASS — video decoded';result.dataset.pass='true';status.textContent='Success: video is playing over WebRTC.';
    }else if(state.error){
      result.textContent='Playback error';status.textContent=state.error;
      start.disabled=false;
    }else if(performance.now()-startedAt>30000){
      status.textContent='No decoded playback yet. Use the video play control or retry.';start.disabled=false;
    }
  },250);
})();