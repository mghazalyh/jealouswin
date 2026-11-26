// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js;
import 'dart:ui_web' as ui;
import 'package:flutter/widgets.dart';
import 'playback.dart';
import 'client.dart';
LanTransport createTransport()=>_Transport();
PlaybackPort createPlayback()=>_Player();
String? readPreference(String key) {
  try { return html.window.localStorage[key]; } catch (_) { return null; }
}
void writePreference(String key,String value) {
  try { html.window.localStorage[key]=value; } catch (_) {}
}
class _Transport implements LanTransport {
  @override
  Future<HttpResult> request(Uri uri,String method,Map<String,String> headers,String? body) async {
    try {
      final promise=js.callMethod<Object>(html.window,'jealouswinRequest',
        [uri.toString(),method,jsonEncode(headers),body]);
      final raw=await js.promiseToFuture<String>(promise);
      final d=jsonDecode(raw) as Map<String,dynamic>;
      if(d['transportError']!=null){
        final phase=uri.path=='/System/Info/Public'?'Gateway reachability':
          uri.path=='/Users/AuthenticateByName'?'Login transport':'Gateway request';
        final transportError=d['transportError'];
        final detail=transportError=='rtc-popup-blocked'?'Allow pop-ups for Jealouswin, then press Connect again.':
          transportError=='rtc-pairing-timeout'?'LAN pairing timed out. Approve the pairing tab and return to Jealouswin.':
          transportError=='rtc-unsupported'?'This browser does not support WebRTC.':
          transportError=='rtc-disconnected'?'WebRTC disconnected. Reconnect to the gateway.':
          transportError is String&&transportError.startsWith('rtc-')?'WebRTC pairing or transport failed. Ensure you are on the same Wi-Fi and retry.':
          transportError=='timeout'?'Request timed out.':
          html.window.location.protocol=='https:'&&uri.scheme=='http'
            ?'Browser blocked or could not reach the HTTP LAN endpoint. Allow Local Network Access if prompted. If unsupported, this browser requires a trusted HTTPS gateway or the LAN-local entry point.'
            :'Check LAN connectivity and the gateway address.';
        throw ServerFault('$phase: $detail');
      }
      return HttpResult(d['status'] as int,d['body'] as String);
    } on ServerFault {rethrow;}
    catch (_) {
      throw const ServerFault('Browser transport bridge failed.');
    }
  }
}
class _Player implements PlaybackPort {
  _Player() {
    video..autoplay=true..muted=true..controls=false
      ..setAttribute('playsinline','')..setAttribute('aria-label','Live television')
      ..style.width='100%'..style.height='100%'..style.objectFit='contain'
      ..style.backgroundColor='#000'..style.pointerEvents='none';
    _view='jealouswin-video-${_sequence++}';
    ui.platformViewRegistry.registerViewFactory(_view,(_)=>video);
  }
  static int _sequence=0;
  final video=html.VideoElement();
  late final String _view;
  void call(String name,[List<Object?> args=const []]) {
    js.callMethod<Object?>(html.window,name,[video,...args]);
  }
  @override Widget surface()=>HtmlElementView(viewType:_view);
  @override PlaybackState get state {
    final raw=js.callMethod<String>(html.window,'jealouswinPlayerState',[video]);
    final d=jsonDecode(raw) as Map<String,dynamic>;
    return PlaybackState(position:(d['position'] as num).toDouble(),
      frames:(d['frames'] as num).toInt(),playing:d['playing']==true,
      buffering:d['buffering']==true,muted:d['muted']==true,error:d['error'] as String);
  }
  @override void load(Uri uri)=>call('jealouswinLoad',[uri.toString()]);
  @override void pause()=>video.pause();
  @override void resume()=>call('jealouswinPlay');
  @override void stop()=>call('jealouswinStop');
  @override void mute(bool value){video.muted=value;}
  @override void brightness(int value){
    video.style.filter='brightness(${(1+value.clamp(-20,10)/30).toStringAsFixed(3)})';
  }
  @override void fullscreen(bool value){
    js.callMethod<Object?>(html.window,'jealouswinFullscreen',[value]);
  }
  @override void dispose(){stop();video.remove();}
}
