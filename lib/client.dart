import 'dart:convert';
import 'domain.dart';

class HttpResult {
  const HttpResult(this.status, this.body);
  final int status;
  final String body;
}
abstract class LanTransport {
  Future<HttpResult> request(Uri uri, String method, Map<String,String> headers, String? body);
}
class ServerFault implements Exception {
  const ServerFault(this.message, {this.status, this.excluded = false});
  final String message;
  final int? status;
  final bool excluded;
  @override
  String toString() => message;
}
class StreamSession {
  const StreamSession(this.url, this.itemId, this.mediaId, this.playId, this.liveId);
  final Uri url;
  final String itemId, mediaId, playId;
  final String? liveId;
}
class JellyfinClient {
  JellyfinClient(this.address, this.transport);
  final ServerAddress address;
  final LanTransport transport;
  String _token = '', userId = '';
  Future<Json> _request(String path, {String method = 'GET',
      Map<String,String> query = const {}, Json? body}) async {
    final r = await transport.request(address.endpoint(path,query),method,{
      'Accept':'application/json',
      if (_token.isNotEmpty) 'X-Emby-Token':_token,
      if (body != null) 'Content-Type':'application/json',
      'X-Emby-Authorization':'MediaBrowser Client="Jealouswin", Device="Web", DeviceId="Jealouswin-Web", Version="0.1.0"'
    }, body == null ? null : jsonEncode(body));
    Json data = {};
    if (r.body.isNotEmpty) {
      try { data = object(jsonDecode(r.body)); }
      on FormatException {
        if (r.status >= 200 && r.status < 300) throw const ServerFault('Invalid server JSON.');
      }
    }
    if (r.status < 200 || r.status >= 300) {
      if (r.status == 409 && data['JealousfinPolicyError'] == 'excluded') {
        throw const ServerFault('Channel excluded by gateway policy.',status:409,excluded:true);
      }
      if (r.status == 401 || r.status == 403) {
        final message=path=='Users/AuthenticateByName'&&r.status==401
          ?'Login rejected (HTTP 401). Check username and password.'
          :r.status==403?'Gateway access denied (HTTP 403).':'Authentication required (HTTP 401).';
        throw ServerFault(message,status:r.status);
      }
      if (r.status == 503 && data['JealousfinPolicyError'] == 'unavailable') {
        throw const ServerFault('Gateway policy unavailable. Try again.',status:503);
      }
      throw ServerFault('LAN server returned HTTP ${r.status}.',status:r.status);
    }
    return data;
  }
  Future<void> connect(String name, String password) async {
    _token = ''; userId = '';
    // A credential-free request distinguishes browser reachability from login.
    final probe=await transport.request(address.endpoint('System/Info/Public'),'GET',{'Accept':'application/json'},null);
    if(probe.status!=200)throw ServerFault('Gateway reachability returned HTTP ${probe.status}.',status:probe.status);
    Json info;
    try {info=object(jsonDecode(probe.body));}
    on FormatException {throw const ServerFault('Invalid gateway discovery response.');}
    if(info['Id'] is! String || info['ServerName'] is! String)throw const ServerFault('Invalid gateway discovery response.');
    final r = await _request('Users/AuthenticateByName',method:'POST',
      body:{'Username':name,'Pw':password});
    final t = r['AccessToken'], user = r['User'];
    if (t is! String || t.isEmpty || user is! Map || user['Id'] is! String ||
        (user['Id'] as String).isEmpty) throw const ServerFault('Invalid authentication response.');
    _token = t; userId = user['Id'] as String;
  }
  Future<List<Channel>> catalogue() async => decodeCatalogue(await _request('LiveTv/Channels',query:{
    'UserId':userId,'EnableImages':'true','EnableUserData':'true',
    'Fields':'Genres,Tags','JealousfinIncludePolicy':'true'
  }));
  Future<void> favorite(String id,bool value) async {
    await _request('Users/${Uri.encodeComponent(userId)}/FavoriteItems/${Uri.encodeComponent(id)}',
      method:value?'POST':'DELETE');
  }
  Future<StreamSession> stream(Channel channel) async {
    final r = await _request('Items/${Uri.encodeComponent(channel.id)}/PlaybackInfo',method:'POST',
      query:{'UserId':userId,'IsPlayback':'true','AutoOpenLiveStream':'true'},
      body:{'UserId':userId,'EnableDirectPlay':false,'EnableDirectStream':true,
        'EnableTranscoding':true,'AutoOpenLiveStream':true,'MaxStreamingBitrate':20000000,
        'DeviceProfile':{'Name':'Jealouswin Web','MaxStreamingBitrate':20000000,
          'DirectPlayProfiles':[],'TranscodingProfiles':[
            {'Type':'Video','Container':'ts','Protocol':'hls','VideoCodec':'h264',
              'AudioCodec':'aac','Context':'Streaming','MaxAudioChannels':'2'}],
          'CodecProfiles':[],'SubtitleProfiles':[]}});
    final sources = r['MediaSources'];
    if (sources is! List || sources.isEmpty) throw const ServerFault('No media source returned.');
    final source = object(sources.first), path = source['TranscodingUrl'];
    if (path is! String || path.isEmpty) throw const ServerFault('No browser-compatible HLS stream.');
    var url = address.endpoint(path);
    if (!url.path.startsWith('/media/') && !url.path.startsWith('/malay/media/')) {
      url = url.replace(queryParameters:{...url.queryParameters,'api_key':_token});
    }
    return StreamSession(url,channel.id,source['Id'] as String? ?? channel.id,
      r['PlaySessionId'] as String? ?? '',source['LiveStreamId'] as String?);
  }
  Future<void> report(StreamSession s,String action,double position,bool paused) async {
    await _request('Sessions/Playing${action.isEmpty ? '' : '/$action'}',method:'POST',body:{
      'ItemId':s.itemId,'MediaSourceId':s.mediaId,'PlaySessionId':s.playId,
      'PositionTicks':(position.isFinite && position >= 0 ? position*10000000 : 0).round(),
      'IsPaused':paused,'PlayMethod':'Transcode',
      if (s.liveId != null) 'LiveStreamId':s.liveId
    });
  }
  Future<void> close(StreamSession s,double position) async {
    try { await report(s,'Stopped',position,false); }
    finally {
      if(s.liveId != null) await _request('LiveStreams/Close',method:'POST',query:{'LiveStreamId':s.liveId!});
    }
  }
}
