import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio.dart';

ArcadeAudio createAudio() => _NativeAudio();

/// Mobile/desktop fallback built on audioplayers: a small round-robin pool
/// for effects and one looping player for music.
class _NativeAudio implements ArcadeAudio {
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  AudioPlayer? _music;
  String? _musicName;
  bool _muted = false;
  double _bgmVolume = .55;
  final Map<String, DateTime> _last = {};

  static final bool _inTest = Platform.environment.containsKey('FLUTTER_TEST');
  bool get _disabled => kIsWeb || _inTest;

  AudioPlayer _voice() {
    if (_pool.length < 8) {
      final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      unawaited(p.setPlayerMode(PlayerMode.lowLatency));
      _pool.add(p);
      return p;
    }
    return _pool[_next++ % _pool.length];
  }

  @override
  bool get muted => _muted;

  @override
  set muted(bool value) {
    _muted = value;
    unawaited(_music?.setVolume(value ? 0 : _bgmVolume * .55));
  }

  @override
  void preload(Iterable<String> sfxNames) {}

  @override
  void sfx(String name, {double volume = 1, double rate = 1}) {
    if (_muted || _disabled) return;
    final now = DateTime.now();
    final last = _last[name];
    if (last != null && now.difference(last).inMilliseconds < 30) return;
    _last[name] = now;
    final p = _voice();
    unawaited(() async {
      try {
        await p.stop();
        await p.setPlaybackRate(rate.clamp(.5, 2.0));
        await p.play(AssetSource('audio/sfx/$name.mp3'), volume: volume);
      } catch (_) {}
    }());
  }

  @override
  void bgm(String name) {
    if (_disabled || _musicName == name) return;
    _musicName = name;
    unawaited(() async {
      try {
        final m = _music ??= AudioPlayer();
        await m.stop();
        await m.setReleaseMode(ReleaseMode.loop);
        await m.play(AssetSource('audio/bgm/$name.mp3'), volume: _muted ? 0 : _bgmVolume * .55);
      } catch (_) {}
    }());
  }

  @override
  void stopBgm({double fade = .4}) {
    _musicName = null;
    unawaited(_music?.stop());
  }

  @override
  void setBgmVolume(double v) {
    _bgmVolume = v;
    unawaited(_music?.setVolume(_muted ? 0 : v * .55));
  }
}
