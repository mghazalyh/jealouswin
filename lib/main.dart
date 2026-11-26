import 'dart:async';
import 'package:flutter/material.dart';
import 'client.dart';
import 'domain.dart';
import 'platform.dart';
import 'playback.dart';

void main()=>runApp(const JealouswinApp());

class JealouswinApp extends StatelessWidget {
  const JealouswinApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'Jealousfin • Web',debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,
      colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff8495ab),brightness:Brightness.dark),
      scaffoldBackgroundColor:const Color(0xff111318)),
    home:const LiveTv());
}

class LiveTv extends StatefulWidget {
  const LiveTv({super.key});
  @override State<LiveTv> createState()=>_LiveTvState();
}
class _LiveTvState extends State<LiveTv> {
  final _english=TextEditingController(text:readPreference('jf.english')??'');
  final _malay=TextEditingController(text:readPreference('jf.malay')??'');
  final _name=TextEditingController();
  final _password=TextEditingController();
  final _search=TextEditingController();
  final _player=createPlayback();
  final _rotations=<String,Rotation>{};
  List<Channel> _channels=[];
  final _history=<String>[];
  JellyfinClient? _client;
  StreamSession? _session;
  Profile _profile=Profile.english;
  ChannelFilter _filter=ChannelFilter.all;
  String _currentId='',_error='',_status='Disconnected';
  bool _busy=false,_refreshing=false,_surf=false,_rotationPaused=false,_fullscreen=false;
  bool _reported=false,_muted=true,_disposed=false,_manualPause=false;
  int _generation=0,_dwell=60,_remaining=60,_brightness=0,_ticks=0;
  Timer? _timer;
  PlaybackState _playback=const PlaybackState();
  DateTime? _lastRefresh;
  double _lastPosition=0;
  int _lastFrames=0,_stalled=0;
  String get _key=>'${_client?.address.uri}|${_profile.name}|${_filter.name}';
  Rotation get _rotation=>_rotations.putIfAbsent(_key,Rotation.new);
  Channel? get _current {
    for(final c in _channels) {if(c.id==_currentId)return c;}
    return null;
  }
  List<Channel> get _pool=>_channels.where((c)=>c.matches(_filter,DateTime.now())&&c.health.eligible(DateTime.now())).toList();
  List<Channel> get _visible {
    final q=_search.text.trim().toLowerCase();
    return _channels.where((c)=>c.matches(_filter,DateTime.now()) &&
      (q.isEmpty||'${c.name} ${c.programme}'.toLowerCase().contains(q))).toList();
  }
  @override void initState(){
    super.initState();
    _timer=Timer.periodic(const Duration(seconds:1),(_)=>_tick());
  }
  @override void dispose(){
    _disposed=true;_generation++;_timer?.cancel();
    final c=_client,s=_session;
    if(c!=null&&s!=null)unawaited(_quietClose(c,s,_playback.position));
    _player.dispose();
    for(final c in [_english,_malay,_name,_password,_search]){c.dispose();}
    super.dispose();
  }
  void _change(VoidCallback fn){if(mounted&&!_disposed)setState(fn);}
  String _message(Object e)=>e is ServerFault||e is FormatException?e.toString():'Operation failed. Check LAN connectivity and try again.';
  Future<void> _quietClose(JellyfinClient c,StreamSession s,double pos) async {
    try{await c.close(s,pos);}catch(_){}
  }
  Future<void> _close() async {
    final c=_client,s=_session,pos=_playback.position;
    _session=null;_reported=false;_player.stop();
    if(c!=null&&s!=null)await _quietClose(c,s,pos);
  }
  Future<void> _connect(Profile profile) async {
    if(_busy||_refreshing)return;
    final raw=profile==Profile.english?_english.text:_malay.text;
    if(raw.trim().isEmpty||_name.text.trim().isEmpty){
      _change(()=>_error='Enter the server address and username.');return;
    }
    final generation=++_generation;
    _change((){_busy=true;_error='';_surf=false;_status='Connecting…';});
    try{
      final c=JellyfinClient(ServerAddress(raw),createTransport());
      await c.connect(_name.text.trim(),_password.text);
      final rows=await c.catalogue();
      if(_disposed||generation!=_generation)return;
      await _close();
      if(_disposed||generation!=_generation)return;
      writePreference(profile==Profile.english?'jf.english':'jf.malay',raw.trim());
      _change((){
        _client=c;_profile=profile;_channels=rows;_currentId='';_history.clear();
        _filter=ChannelFilter.all;_status='Connected';_lastRefresh=DateTime.now();
        _playback=const PlaybackState();
      });
    }catch(e){_change((){_error=_message(e);_status=_client==null?'Disconnected':'Connected';});}
    finally{if(generation==_generation)_change(()=>_busy=false);}
  }
  Future<void> _refresh({bool silent=false}) async {
    final c=_client;
    if(c==null||_refreshing||_busy)return;
    _change(()=>_refreshing=true);
    try{
      final rows=await c.catalogue();
      if(_disposed||c!=_client)return;
      _change((){_channels=rows;_lastRefresh=DateTime.now();if(!silent)_error='';});
      if(_currentId.isNotEmpty&&(_current==null||!_current!.health.eligible(DateTime.now()))){
        await _stop();
        _change(()=>_error='Current channel is now excluded by server policy.');
      }
    }catch(e){_change((){_error=_message(e);_surf=false;});}
    finally{_change(()=>_refreshing=false);}
  }
  Future<void> _stop() async {
    ++_generation;
    _change((){_surf=false;_rotationPaused=false;_busy=false;_currentId='';_status=_client==null?'Disconnected':'Connected';});
    await _close();
    _change(()=>_playback=const PlaybackState());
  }
  Future<void> _open(Channel channel,{bool fromHistory=false}) async {
    final client=_client;
    if(client==null||_busy||_refreshing||!channel.health.eligible(DateTime.now()))return;
    final generation=++_generation,previous=_currentId;
    _change((){_busy=true;_error='';_status='Opening '+channel.name;});
    try{
      await _close();
      if(_disposed||generation!=_generation)return;
      final session=await client.stream(channel);
      if(_disposed||generation!=_generation){await _quietClose(client,session,0);return;}
      _session=session;
      _player.load(session.url);_player.mute(_muted);_player.brightness(_brightness);
      _change((){
        if(!fromHistory&&previous.isNotEmpty&&previous!=channel.id){_history.add(previous);if(_history.length>100)_history.removeAt(0);}
        _currentId=channel.id;_rotation.attempted.add(channel.id);_status='Buffering';_remaining=_dwell;
        _lastPosition=0;_lastFrames=0;_stalled=0;_manualPause=false;
      });
    }catch(e){
      if(generation!=_generation)return;
      _change((){_error=_message(e);_status='Playback unavailable';_currentId=channel.id;});
      // A browser cannot reliably attribute network/codec errors to a channel.
      // Never create shared failure penalties from client-side uncertainty.
      if(e is! ServerFault||!e.excluded)_change(()=>_surf=false);
    }finally{if(generation==_generation)_change(()=>_busy=false);}
  }
  Future<void> _next() async {
    if(_busy||_refreshing||_client==null)return;
    final pool=_pool;
    final id=_rotation.next(pool,current:_currentId);
    if(id==null){_change((){_surf=false;_error='No eligible channels in this category.';});return;}
    await _open(pool.firstWhere((c)=>c.id==id));
  }
  Future<void> _previous() async {
    if(_busy)return;
    while(_history.isNotEmpty){
      final id=_history.removeLast();
      for(final c in _channels){
        if(c.id==id&&c.health.eligible(DateTime.now())){await _open(c,fromHistory:true);return;}
      }
    }
  }
  Future<void> _toggleFavorite(Channel channel) async {
    final c=_client;
    if(c==null||_busy||_refreshing)return;
    _change(()=>_busy=true);
    try{
      await c.favorite(channel.id,!channel.favorite);
      if(c!=_client)return;
      _change(()=>_channels=_channels.map((x)=>x.id==channel.id?x.withFavorite(!channel.favorite):x).toList());
    }catch(e){_change(()=>_error=_message(e));}
    finally{_change(()=>_busy=false);}
  }
  void _tick(){
    if(_disposed)return;
    final state=_player.state;
    final advanced=state.position>_lastPosition+.05&&state.frames>_lastFrames;
    _lastPosition=state.position;_lastFrames=state.frames;
    _change((){
      _playback=state;_ticks++;
      if(_session!=null&&!_busy){
        if(state.error.isNotEmpty){
          _status='Playback unavailable';_error=state.error;_surf=false;
        }else if(state.playing&&advanced){
          _stalled=0;_status='Live';
          if(_surf&&!_rotationPaused&&_remaining>0)_remaining--;
        }else if(!_manualPause){
          _stalled++;_status='Buffering';
          if(_stalled>=45){_error='No decoded playback progress. Check connection or retry.';_surf=false;}
        }
      }
    });
    final c=_client,s=_session;
    if(c!=null&&s!=null&&state.playing&&advanced&&!_reported){
      _reported=true;unawaited(_report(c,s,'',state));
    }else if(c!=null&&s!=null&&_reported&&_ticks%15==0){
      unawaited(_report(c,s,'Progress',state));
    }
    if(_surf&&!_rotationPaused&&!_busy&&!_refreshing&&
       (_remaining<=0||(_session==null&&_error.isNotEmpty)))unawaited(_next());
    if(_ticks%45==0&&!_busy&&!_refreshing&&c!=null)unawaited(_refresh(silent:true));
  }
  Future<void> _report(JellyfinClient c,StreamSession s,String action,PlaybackState p) async {
    try{await c.report(s,action,p.position,!p.playing);}catch(_){}
  }
  void _toggleSurf(){
    if(_surf){_change(()=>_surf=false);return;}
    if(_filter==ChannelFilter.hiatus)return;
    _change((){_surf=true;_rotationPaused=false;_remaining=_dwell;_error='';});
    if(_session==null)unawaited(_next());
  }
  Widget _icon(IconData icon,String tip,VoidCallback? fn)=>IconButton(tooltip:tip,onPressed:fn,icon:Icon(icon));
  Widget _settings()=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Connect to your LAN gateway',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      const Text('Use the same Jealousfin login. On the public website, Connect opens a LAN pairing tab: approve the WebRTC connection and return here. Video stays on your LAN.'),
      const SizedBox(height:12),
      TextField(controller:_english,decoration:const InputDecoration(labelText:'English gateway URL',hintText:'http://192.168.x.x:18796'),keyboardType:TextInputType.url),
      TextField(controller:_malay,decoration:const InputDecoration(labelText:'Malay gateway URL',hintText:'http://192.168.x.x:18797'),keyboardType:TextInputType.url),
      TextField(controller:_name,decoration:const InputDecoration(labelText:'Username'),autocorrect:false),
      TextField(controller:_password,decoration:const InputDecoration(labelText:'Password'),obscureText:true,enableSuggestions:false,autocorrect:false),
      const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[
        FilledButton(onPressed:_busy||_refreshing?null:()=>_connect(Profile.english),child:const Text('Connect English')),
        OutlinedButton(onPressed:_busy||_refreshing?null:()=>_connect(Profile.malay),child:const Text('Connect Malay')),
      ]),
      const Text('Credentials are held in memory only. Server addresses are saved locally.',style:TextStyle(fontSize:12,color:Colors.grey))
    ])));
  Widget _playerPanel()=>Card(color:const Color(0xff090b10),clipBehavior:Clip.antiAlias,
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Padding(padding:const EdgeInsets.all(12),child:Row(children:[
        Expanded(child:Text(_current?.name??'Choose a channel',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold),overflow:TextOverflow.ellipsis)),
        Text(_status,style:TextStyle(color:_playback.playing?Colors.greenAccent:Colors.grey)),
        _icon(_fullscreen?Icons.fullscreen_exit:Icons.fullscreen,'Fullscreen',(){
          _change(()=>_fullscreen=!_fullscreen);_player.fullscreen(_fullscreen);
        }),
      ])),
      AspectRatio(aspectRatio:16/9,child:ColoredBox(color:Colors.black,child:_player.surface())),
      Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(_current?.programme.isNotEmpty==true?_current!.programme:'Programme information unavailable',style:const TextStyle(fontSize:16,color:Color(0xffb9bec7))),
        const SizedBox(height:8),
        Wrap(spacing:4,runSpacing:4,crossAxisAlignment:WrapCrossAlignment.center,children:[
          _icon(Icons.skip_previous,'Previous channel',_history.isEmpty||_busy?null:()=>_previous()),
          _icon(_playback.playing?Icons.pause:Icons.play_arrow,'Play / Pause',_session==null?null:(){
            if(_playback.playing){_manualPause=true;_player.pause();}else{_manualPause=false;_player.resume();}
          }),
          _icon(Icons.skip_next,'Next channel',_client==null||_busy?null:()=>_next()),
          _icon(Icons.stop,'Stop',_session==null&&!_busy?null:()=>_stop()),
          _icon(_current?.favorite==true?Icons.favorite:Icons.favorite_border,'Favorite',_current==null||_busy?null:()=>_toggleFavorite(_current!)),
          _icon(_muted?Icons.volume_off:Icons.volume_up,'Mute / Unmute',(){_change(()=>_muted=!_muted);_player.mute(_muted);}),
          FilledButton.tonal(onPressed:_client==null||_busy||_filter==ChannelFilter.hiatus?null:_toggleSurf,child:Text(_surf?'Stop Surf':'Start Surf')),
          if(_surf) _icon(_rotationPaused?Icons.play_circle:Icons.pause_circle,'Pause / resume rotation',()=>_change(()=>_rotationPaused=!_rotationPaused)),
          if(_surf) Text('${_remaining~/60}:${(_remaining%60).toString().padLeft(2,'0')}'),
        ]),
        Row(children:[
          const Icon(Icons.brightness_6,size:18),const SizedBox(width:8),const Text('Brightness'),
          Expanded(child:Slider(min:-20,max:10,divisions:30,value:_brightness.toDouble(),onChanged:(v){_change(()=>_brightness=v.round());_player.brightness(_brightness);})),
          TextButton(onPressed:(){_change(()=>_brightness=0);_player.brightness(0);},child:const Text('Reset')),
        ]),
        Wrap(spacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
          const Text('Dwell'),
          DropdownButton<int>(value:_dwell,items:[30,60,90,120,180,300].map((n)=>DropdownMenuItem(value:n,child:Text('$n s'))).toList(),
            onChanged:(n){if(n!=null)_change((){_dwell=n;_remaining=n;});}),
          Text('Cycle ${_rotation.cycle} • ${_rotation.remaining(_pool)} remaining'),
          if(_playback.buffering) const Text('Buffering…'),
        ]),
      ]))
    ]));
  Widget _catalogue()=>Card(child:Column(children:[
    Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Expanded(child:Text('Live TV',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold))),
        _icon(Icons.refresh,'Refresh server catalogue',_client==null||_busy||_refreshing?null:()=>_refresh()),
      ]),
      Wrap(spacing:6,runSpacing:6,children:Profile.values.map((p)=>ChoiceChip(
        label:Text(p==Profile.english?'American / English':'Malay'),selected:_profile==p,
        onSelected:_busy||_refreshing||_client==null?null:(v){if(v&&p!=_profile)unawaited(_connect(p));})).toList()),
      const SizedBox(height:8),
      Wrap(spacing:6,runSpacing:6,children:ChannelFilter.values.map((f)=>ChoiceChip(
        label:Text(f.label),selected:_filter==f,onSelected:(v){if(v)_change((){_filter=f;_surf=false;});})).toList()),
      TextField(controller:_search,onChanged:(_)=>_change((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Search channels or programmes')),
      const SizedBox(height:8),
      Text('${_channels.length} channels • ${_channels.where((c)=>c.health.eligible(DateTime.now())).length} eligible • ${_channels.where((c)=>!c.health.eligible(DateTime.now())).length} excluded',
        style:const TextStyle(color:Colors.grey,fontSize:12)),
      if(_lastRefresh!=null) Text('Server policy synced ${_lastRefresh!.toLocal().toString().substring(11,19)}',style:const TextStyle(color:Colors.grey,fontSize:12)),
    ])),
    const Divider(height:1),
    SizedBox(height:520,child:_visible.isEmpty?const Center(child:Text('No channels in this view')):
      ListView.builder(itemCount:_visible.length,itemBuilder:(context,i){
        final c=_visible[i],eligible=c.health.eligible(DateTime.now());
        return ListTile(
          selected:_currentId==c.id,enabled:eligible&&!_busy&&!_refreshing,
          leading:Icon(eligible?Icons.live_tv:Icons.block,color:eligible?null:Colors.orangeAccent),
          title:Text(c.name,maxLines:1,overflow:TextOverflow.ellipsis),
          subtitle:Text([if(c.programme.isNotEmpty)c.programme,c.health.label(DateTime.now()),
            if(!eligible&&c.health.reason.isNotEmpty)c.health.reason,'Failures: ${c.health.failures} • Proven: ${c.health.successes}'].join('\n'),maxLines:4,overflow:TextOverflow.ellipsis),
          trailing:IconButton(tooltip:c.favorite?'Remove favorite':'Add favorite',icon:Icon(c.favorite?Icons.favorite:Icons.favorite_border),
            onPressed:_busy||_refreshing?null:()=>_toggleFavorite(c)),
          onTap:eligible&&!_busy&&!_refreshing?(){_change(()=>_surf=false);unawaited(_open(c));}:null);
      })),
  ]));
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:_fullscreen?null:AppBar(title:const Text('Jealousfin • Web'),actions:[
      if(_client!=null)_icon(Icons.logout,'Disconnect',_busy?null:()async{
        await _stop();_change((){_client=null;_channels=[];_password.clear();_status='Disconnected';});
      }),
      _icon(Icons.settings,'Connection settings',_busy?null:()=>showDialog<void>(context:context,builder:(ctx)=>Dialog(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:560),child:SingleChildScrollView(child:_settings()))))),
    ]),
    body:SafeArea(child:LayoutBuilder(builder:(context,box){
      final player=_playerPanel(),catalogue=_catalogue();
      return SingleChildScrollView(padding:const EdgeInsets.all(12),child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          if(_client==null&&!_fullscreen)_settings(),
          if(_busy||_refreshing)const LinearProgressIndicator(),
          if(_error.isNotEmpty)Card(color:const Color(0xff392722),child:Padding(padding:const EdgeInsets.all(12),child:Text(_error))),
          if(_fullscreen)player
          else if(box.maxWidth>=1050)Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:3,child:player),const SizedBox(width:12),Expanded(flex:2,child:catalogue)])
          else ...[player,catalogue],
        ]));
    })));
}
