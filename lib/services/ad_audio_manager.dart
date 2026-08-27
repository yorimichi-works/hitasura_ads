import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../models/ad_definition.dart';

class AdAudioManager {
  final AudioPlayer _sePlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();
  bool _ambientStarted = false;
  bool _ambientStarting = false;
  bool _ambientDesired = false;

  /// Quiet looping background music for browsing screens. Credit: 魔王魂.
  Future<void> startAmbient({bool enabled = true}) async {
    if (!enabled) return;
    _ambientDesired = true;
    if (_ambientStarted || _ambientStarting) return;
    _ambientStarting = true;
    try {
      await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
      await _ambientPlayer.play(
        AssetSource('audio/bgm_ambient.mp3'),
        volume: .12,
      );
      if (_ambientDesired) {
        _ambientStarted = true;
      } else {
        await _ambientPlayer.stop();
      }
    } on Exception {
      // Browsers may reject autoplay. A later user action can retry playback.
    } finally {
      _ambientStarting = false;
    }
  }

  Future<void> stopAmbient() async {
    _ambientDesired = false;
    _ambientStarted = false;
    _ambientStarting = false;
    await _safely(_ambientPlayer.stop);
  }

  Future<void> setAmbientEnabled(bool enabled) async {
    if (enabled) {
      await startAmbient();
    } else {
      await stopAmbient();
    }
  }

  Future<void> duckAmbient() async {
    await _safely(() => _ambientPlayer.setVolume(.03));
  }

  Future<void> unduckAmbient() async {
    await _safely(() => _ambientPlayer.setVolume(.12));
  }

  Future<void> playInteraction(AdDefinition ad, {bool enabled = true}) async {
    if (!enabled || ad.seIds.isEmpty) return;
    await _safely(() => _sePlayer.play(AssetSource('audio/${ad.seIds.first}')));
  }

  Future<void> playSecretSequence(
    AdDefinition ad, {
    bool soundEffectsEnabled = true,
  }) async {
    await _safely(_bgmPlayer.stop);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (soundEffectsEnabled && ad.seIds.isNotEmpty) {
      await _safely(
        () => _sePlayer.play(AssetSource('audio/${ad.seIds.first}')),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final bgmId = ad.bgmId;
    if (bgmId == null) return;
    await _safely(() async {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('audio/$bgmId'), volume: .28);
    });
  }

  Future<void> playDiscovery({bool enabled = true}) async {
    if (!enabled) return;
    await _safely(
      () => _sePlayer.play(AssetSource('audio/discovery_se.wav'), volume: .68),
    );
  }

  Future<void> dispose() async {
    await _safely(_sePlayer.dispose);
    await _safely(_bgmPlayer.dispose);
    await _safely(_ambientPlayer.dispose);
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } on Exception {
      // Audio must never prevent an exploration ad from completing.
    }
  }
}
