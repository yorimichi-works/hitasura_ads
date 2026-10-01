import 'audio_native.dart' as impl;

/// Global audio for the arcade: sound effects + one looping music track.
abstract class ArcadeAudio {
  static final ArcadeAudio instance = impl.createAudio();

  bool get muted;
  set muted(bool value);

  /// Starts loading sounds so the first play has no delay.
  void preload(Iterable<String> sfxNames);

  void sfx(String name, {double volume = 1, double rate = 1});

  /// Crossfades to music [name] (see `Bgm`). Same track keeps playing.
  void bgm(String name);
  void stopBgm({double fade = .4});

  /// 0..1 relative music volume (games may duck or silence it).
  void setBgmVolume(double v);

  static String sfxAsset(String name) => 'assets/audio/sfx/$name.mp3';
  static String bgmAsset(String name) => 'assets/audio/bgm/$name.mp3';
}

/// Silent implementation for tests.
class SilentAudio implements ArcadeAudio {
  @override
  bool muted = false;
  @override
  void preload(Iterable<String> sfxNames) {}
  @override
  void sfx(String name, {double volume = 1, double rate = 1}) {}
  @override
  void bgm(String name) {}
  @override
  void stopBgm({double fade = .4}) {}
  @override
  void setBgmVolume(double v) {}
}
