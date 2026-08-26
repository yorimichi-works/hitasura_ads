import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../models/ad_definition.dart';

class AdAudioManager {
  final AudioPlayer _sePlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();

  Future<void> playInteraction(AdDefinition ad) async {
    if (ad.seIds.isEmpty) return;
    await _safely(() => _sePlayer.play(AssetSource('audio/${ad.seIds.first}')));
  }

  Future<void> playSecretSequence(AdDefinition ad) async {
    await _safely(_bgmPlayer.stop);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (ad.seIds.isNotEmpty) {
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
