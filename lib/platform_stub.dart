import 'package:flutter/widgets.dart';
import 'playback.dart';
import 'client.dart';
LanTransport createTransport()=>_Transport();
PlaybackPort createPlayback()=>_Player();
String? readPreference(String key)=>null;
void writePreference(String key,String value){}
class _Transport implements LanTransport {
  @override
  Future<HttpResult> request(Uri uri,String method,Map<String,String> headers,String? body) async {
    throw const ServerFault('Browser transport is only available on web.');
  }
}
class _Player implements PlaybackPort {
  @override Widget surface()=>const ColoredBox(color:Color(0xff000000));
  @override PlaybackState get state=>const PlaybackState();
  @override void load(Uri uri){}
  @override void pause(){}
  @override void resume(){}
  @override void stop(){}
  @override void mute(bool value){}
  @override void brightness(int value){}
  @override void fullscreen(bool value){}
  @override void dispose(){}
}
