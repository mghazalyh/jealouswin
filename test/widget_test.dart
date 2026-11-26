import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jealouswin/main.dart';
import 'package:jealouswin/domain.dart';
import 'package:jealouswin/client.dart';

class ProbeTransport implements LanTransport {
  final paths=<String>[];
  final HttpResult probe;
  final HttpResult login;
  ProbeTransport(this.probe,this.login);
  @override
  Future<HttpResult> request(Uri uri,String method,Map<String,String> headers,String? body) async {
    paths.add(uri.path);
    if(uri.path=='/System/Info/Public'){
      expect(method,'GET');
      expect(body,isNull);
      expect(headers.containsKey('X-Emby-Token'),isFalse);
      return probe;
    }
    return login;
  }
}

void main(){
  test('gateway discovery precedes authentication and failure sends no credentials',() async {
    final t=ProbeTransport(const HttpResult(503,'{}'),const HttpResult(200,'{}'));
    final c=JellyfinClient(ServerAddress('http://192.168.1.2:18796'),t);
    await expectLater(c.connect('fixture','fixture'),throwsA(isA<ServerFault>().having((e)=>e.status,'status',503)));
    expect(t.paths,['/System/Info/Public']);
  });
  test('successful discovery distinguishes rejected login',() async {
    final t=ProbeTransport(const HttpResult(200,'{"Id":"fixture","ServerName":"Gateway"}'),const HttpResult(401,'{}'));
    final c=JellyfinClient(ServerAddress('http://192.168.1.2:18796'),t);
    await expectLater(c.connect('fixture','fixture'),throwsA(isA<ServerFault>().having((e)=>e.message,'message',contains('Login rejected'))));
    expect(t.paths,['/System/Info/Public','/Users/AuthenticateByName']);
  });
  testWidgets('LAN connection and live TV controls are present', (tester) async {
    await tester.pumpWidget(const JealouswinApp());
    expect(find.text('Connect to your LAN gateway'),findsOneWidget);
    expect(find.text('Connect English'),findsOneWidget);
    expect(find.text('Connect Malay'),findsOneWidget);
    await tester.tap(find.text('Connect English'));
    await tester.pump();
    expect(find.text('Enter the server address and username.'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('gateway policy must be complete and excluded channels stay excluded',(){
    final now=DateTime.now();
    final result=decodeCatalogue({
      'Items':[{'Id':'a','Name':'One','CurrentProgram':{'Name':'Show'},'UserData':{'IsFavorite':true}},
        {'Id':'b','Name':'Two'}],
      'JealousfinPolicy':{'revision':'sqlite-policy-v2','channels':{
        'a':{'banned':false,'hiatusUntil':0,'successes':2},
        'b':{'banned':false,'hiatusUntil':now.millisecondsSinceEpoch/1000+86400}
      }}
    });
    expect(result.first.favorite,isTrue);
    expect(result.first.programme,'Show');
    expect(result.last.matches(ChannelFilter.hiatus,now),isTrue);
    expect(result.last.matches(ChannelFilter.all,now),isFalse);
    expect(()=>decodeCatalogue({'Items':[]}),throwsFormatException);
  });
  test('rotation exhausts eligible IDs and rejects cross-origin media',(){
    final r=Rotation();
    final channels=[const Channel(id:'a',name:'A'),const Channel(id:'b',name:'B')];
    expect(r.next(channels),'a');
    expect(r.next(channels,current:'a'),'b');
    expect(r.remaining(channels),0);
    expect(r.next(channels,current:'b'),'a');
    expect(r.cycle,2);
    final server=ServerAddress('http://192.168.1.2:18796');
    expect(server.endpoint('/media/token/id.m3u8').host,'192.168.1.2');
    expect(()=>server.endpoint('https://example.com/media'),throwsFormatException);
    expect(()=>ServerAddress('http://example.com'),throwsFormatException);
  });
}
