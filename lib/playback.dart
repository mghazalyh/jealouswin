import 'package:flutter/widgets.dart';
class PlaybackState {
  const PlaybackState({this.position=0,this.playing=false,this.frames=0,
    this.buffering=false,this.error='',this.muted=true});
  final double position;
  final int frames;
  final bool playing,buffering,muted;
  final String error;
}
abstract class PlaybackPort {
  Widget surface();
  PlaybackState get state;
  void load(Uri uri);
  void pause();
  void resume();
  void stop();
  void mute(bool value);
  void brightness(int value);
  void fullscreen(bool value);
  void dispose();
}
