import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'audio.dart';

@JS('arcadeAudio')
external _JsAudio? get _jsAudio;

extension type _JsAudio(JSObject _) implements JSObject {
  external void preload(JSArray<JSString> urls);
  external void sfx(JSString url, JSNumber volume, JSNumber rate);
  external void bgm(JSString url);
  external void stopBgm(JSNumber fade);
  external void setBgmVolume(JSNumber v);
  external void setMuted(JSBoolean m);
}

ArcadeAudio createAudio() => _WebAudio();

class _WebAudio implements ArcadeAudio {
  bool _muted = false;
  double _bgmVolume = .55;
  final Map<String, String> _urls = {};

  String _url(String asset) => _urls[asset] ??= ui_web.assetManager.getAssetUrl(asset);

  @override
  bool get muted => _muted;

  @override
  set muted(bool value) {
    _muted = value;
    _jsAudio?.setMuted(value.toJS);
  }

  @override
  void preload(Iterable<String> sfxNames) {
    _jsAudio?.preload([for (final n in sfxNames) _url(ArcadeAudio.sfxAsset(n)).toJS].toJS);
  }

  @override
  void sfx(String name, {double volume = 1, double rate = 1}) {
    if (_muted) return;
    _jsAudio?.sfx(_url(ArcadeAudio.sfxAsset(name)).toJS, volume.toJS, rate.clamp(.25, 4.0).toJS);
  }

  @override
  void bgm(String name) => _jsAudio?.bgm(_url(ArcadeAudio.bgmAsset(name)).toJS);

  @override
  void stopBgm({double fade = .4}) => _jsAudio?.stopBgm(fade.toJS);

  @override
  void setBgmVolume(double v) {
    if (v == _bgmVolume) return;
    _bgmVolume = v;
    _jsAudio?.setBgmVolume((v * .55).toJS);
  }
}
