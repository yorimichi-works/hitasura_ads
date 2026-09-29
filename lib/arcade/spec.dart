import 'engine/game.dart';

enum GameCat { hyper, strategy, tycoon, party, micro, retro, threeD, gacha, rpg, puzzle, sports, asmr, meta, secret }

enum ArtStyle { vector, pixel, threeD, neon }

enum Rarity { common, uncommon, rare, superRare, secret }

/// Static description of one of the 151 ad demos.
class GameSpec {
  const GameSpec({
    required this.no,
    required this.cat,
    required this.style,
    required this.rarity,
    required this.bgm,
    required this.duration,
    required this.create,
  });

  final int no;
  final GameCat cat;
  final ArtStyle style;
  final Rarity rarity;
  final String bgm;
  final double duration;
  final MiniGame Function() create;

  /// Stable id shared with saved progress from the original app.
  String get id => 'AD_${no.toString().padLeft(3, '0')}';
  String get label => 'No.${no.toString().padLeft(3, '0')}';
  bool get isSecret => no == 151;

  /// Short games are eligible for RUSH mode.
  bool get rushable => duration <= 16 && !isSecret;
}
