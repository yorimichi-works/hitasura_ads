import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../models/ad_definition.dart';
import '../models/ad_semantic_profile.dart';

class AdAudioManager {
  static const gameBgmIds = <String>[
    'maou_loop_bgm_8bit27.mp3',
    'maou_loop_bgm_8bit28.mp3',
    'maou_loop_bgm_neorock82.mp3',
    'maou_bgm_piano04.mp3',
    'maou_bgm_piano17.mp3',
    'maou_loop_bgm_cyber41.mp3',
    'maou_loop_bgm_cyber44.mp3',
    'maou_loop_bgm_cyber45.mp3',
  ];

  final AudioPlayer _sePlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();

  static AdBgmMood moodFor(AdDefinition ad) => ad.semantic.mood;

  static String gameBgmFor(AdDefinition ad) {
    if (ad.bgmId != null) return ad.bgmId!;
    return switch (moodFor(ad)) {
      AdBgmMood.energetic => switch (ad.number % 3) {
        0 => 'maou_loop_bgm_8bit27.mp3',
        1 => 'maou_loop_bgm_neorock82.mp3',
        _ => 'maou_loop_bgm_8bit28.mp3',
      },
      AdBgmMood.retro =>
        ad.number.isEven
            ? 'maou_loop_bgm_8bit28.mp3'
            : 'maou_loop_bgm_8bit27.mp3',
      AdBgmMood.relaxed => 'maou_bgm_piano04.mp3',
      AdBgmMood.serious => 'maou_bgm_piano17.mp3',
      AdBgmMood.silly => 'maou_loop_bgm_cyber41.mp3',
      AdBgmMood.puzzle => 'maou_loop_bgm_cyber44.mp3',
      AdBgmMood.ominous => 'maou_loop_bgm_cyber45.mp3',
      AdBgmMood.cyber => 'maou_loop_bgm_cyber44.mp3',
    };
  }

  static double gameBgmVolumeFor(AdDefinition ad) => switch (moodFor(ad)) {
    AdBgmMood.relaxed => .18,
    AdBgmMood.serious || AdBgmMood.ominous => .20,
    _ => .24,
  };

  Future<void> playGameBgm(AdDefinition ad, {bool enabled = true}) async {
    if (!enabled) return;
    await _safely(() async {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(
        AssetSource('audio/${gameBgmFor(ad)}'),
        volume: gameBgmVolumeFor(ad),
      );
    });
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
    if (!soundEffectsEnabled) return;
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
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } on Exception {
      // Audio must never prevent an exploration ad from completing.
    }
  }
}
