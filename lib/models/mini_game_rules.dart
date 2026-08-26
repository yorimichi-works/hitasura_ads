import 'dart:math';

import 'ad_definition.dart';
import 'ad_mini_game_definition.dart';

enum MiniGameGrade { normal, great, perfect }

class NumberOperation {
  const NumberOperation(this.symbol, this.amount);

  final String symbol;
  final int amount;

  int apply(int value) => switch (symbol) {
    '=' => amount,
    '×' => value * amount,
    '÷' => amount == 0 ? value : value ~/ amount,
    '-' => value - amount,
    _ => value + amount,
  };

  String get label => symbol == '=' ? '→$amount' : '$symbol$amount';
}

class AdMiniGameRules {
  const AdMiniGameRules({
    required this.rounds,
    required this.initialValue,
    required this.hasRandomness,
    required this.stateChanges,
    required this.oldRating,
    required this.newRating,
    required this.adNumber,
    required this.rewardDelta,
  });

  factory AdMiniGameRules.forAd(AdDefinition ad) {
    final type = AdMiniGameDefinition.forAd(ad).type;
    final rounds = switch (type) {
      AdMiniGameType.tapChallenge => 3 + ad.number % 3,
      AdMiniGameType.choice => 3,
      AdMiniGameType.pinPull => 3,
      AdMiniGameType.numberGate => 3,
      AdMiniGameType.drawPath => 1,
      AdMiniGameType.dragSort => 3,
      AdMiniGameType.timing => 1,
      AdMiniGameType.scratch => 1,
      AdMiniGameType.packOpen => 3,
      AdMiniGameType.countdownStop => 1,
      AdMiniGameType.reveal => 3,
      AdMiniGameType.finale => 4,
    };
    return AdMiniGameRules(
      rounds: rounds,
      initialValue: switch (ad.number) {
        48 || 51 || 81 => 1,
        52 => 9996,
        89 => 0,
        151 => 995,
        _ => 8 + (ad.number % 8),
      },
      hasRandomness:
          type != AdMiniGameType.countdownStop && type != AdMiniGameType.finale,
      stateChanges: switch (type) {
        AdMiniGameType.numberGate => '値・人数密度・ゲート列',
        AdMiniGameType.pinPull => '安全順・ピン位置・救助状態',
        AdMiniGameType.choice => '正解位置・スコア・ラウンド',
        AdMiniGameType.dragSort => '配送先・連続仕分け数',
        AdMiniGameType.packOpen => '中身・獲得コイン・開封数',
        AdMiniGameType.finale => 'Lv995→999・黄金形態',
        _ => '進捗・評価・キャラクター反応',
      },
      oldRating: rounds == 1 ? 'C' : 'B',
      newRating: rounds == 1 ? 'B' : 'A',
      adNumber: ad.number,
      rewardDelta: ad.number == 89 ? 999999 : 10,
    );
  }

  final int rounds;
  final int initialValue;
  final bool hasRandomness;
  final String stateChanges;
  final String oldRating;
  final String newRating;
  final int adNumber;
  final int rewardDelta;

  List<NumberOperation> gates(Random random, {int round = 0}) {
    final preset = switch (adNumber) {
      46 => const [NumberOperation('+', 10), NumberOperation('×', 2)],
      48 => switch (round) {
        0 => const [NumberOperation('×', 10), NumberOperation('-', 1)],
        1 => const [NumberOperation('×', 100), NumberOperation('÷', 2)],
        _ => const [NumberOperation('=', 999999), NumberOperation('-', 5)],
      },
      49 => const [NumberOperation('×', 100), NumberOperation('+', 10)],
      51 => const [NumberOperation('×', 10), NumberOperation('+', 2)],
      52 => const [NumberOperation('+', 1), NumberOperation('-', 1)],
      _ => null,
    };
    if (preset != null) return [...preset]..shuffle(random);
    final positive = [
      NumberOperation('+', 5 + random.nextInt(16)),
      NumberOperation('×', 2 + random.nextInt(2)),
    ];
    final risky = [
      NumberOperation('-', 2 + random.nextInt(8)),
      const NumberOperation('÷', 2),
      NumberOperation('+', 1 + random.nextInt(5)),
    ];
    return [
      positive[random.nextInt(positive.length)],
      risky[random.nextInt(risky.length)],
    ]..shuffle(random);
  }

  MiniGameGrade grade({required int mistakes, required int score}) {
    if (mistakes == 0 && score >= rounds * 100) return MiniGameGrade.perfect;
    if (mistakes <= 1) return MiniGameGrade.great;
    return MiniGameGrade.normal;
  }
}
