import 'ad_definition.dart';
import 'ad_visual_assets.dart';

enum AdMiniGameType {
  tapChallenge,
  choice,
  pinPull,
  numberGate,
  drawPath,
  dragSort,
  timing,
  scratch,
  packOpen,
  countdownStop,
  reveal,
  finale,
}

class AdMiniGameDefinition {
  const AdMiniGameDefinition({
    required this.type,
    required this.instruction,
    required this.successCondition,
    required this.failureCondition,
    required this.assetPath,
  });

  factory AdMiniGameDefinition.forAd(AdDefinition ad) {
    final type =
        _specializedType(ad) ??
        switch (ad.interactionType) {
          AdInteractionType.tap => AdMiniGameType.tapChallenge,
          AdInteractionType.choice => AdMiniGameType.choice,
          AdInteractionType.pinPull => AdMiniGameType.pinPull,
          AdInteractionType.gate => AdMiniGameType.numberGate,
          AdInteractionType.drag when ad.number >= 58 && ad.number <= 60 =>
            AdMiniGameType.drawPath,
          AdInteractionType.drag => AdMiniGameType.dragSort,
          AdInteractionType.spin => AdMiniGameType.timing,
          AdInteractionType.scratch => AdMiniGameType.scratch,
          AdInteractionType.packOpen => AdMiniGameType.packOpen,
          AdInteractionType.none when ad.number == 4 =>
            AdMiniGameType.countdownStop,
          AdInteractionType.none when ad.isSecret => AdMiniGameType.finale,
          AdInteractionType.none => AdMiniGameType.reveal,
        };
    return AdMiniGameDefinition(
      type: type,
      instruction: _instruction(ad, type),
      successCondition: _success(type),
      failureCondition: _failure(type),
      assetPath: AdVisualAssets.forAd(ad).foregroundAsset,
    );
  }

  final AdMiniGameType type;
  final String instruction;
  final String successCondition;
  final String failureCondition;
  final String? assetPath;

  static AdMiniGameType? _specializedType(AdDefinition ad) {
    if (ad.number >= 31 && ad.number <= 45 || ad.number == 147) {
      return switch (ad.number) {
        32 || 36 || 37 => AdMiniGameType.timing,
        34 || 39 => AdMiniGameType.choice,
        35 || 40 => AdMiniGameType.drawPath,
        38 => AdMiniGameType.countdownStop,
        41 => AdMiniGameType.numberGate,
        42 => AdMiniGameType.dragSort,
        44 => AdMiniGameType.reveal,
        _ => AdMiniGameType.pinPull,
      };
    }
    if (ad.number >= 76 && ad.number <= 85) {
      return switch (ad.number) {
        76 || 77 => AdMiniGameType.timing,
        78 || 79 || 80 => AdMiniGameType.dragSort,
        84 => AdMiniGameType.packOpen,
        _ => AdMiniGameType.tapChallenge,
      };
    }
    return null;
  }

  static String _instruction(AdDefinition ad, AdMiniGameType type) {
    if (ad.number >= 31 && ad.number <= 45 || ad.number == 147) {
      return switch (type) {
        AdMiniGameType.pinPull => '王様へ宝を届ける順でピンを抜け',
        AdMiniGameType.timing => '炎が弱まった瞬間に王様を救出',
        AdMiniGameType.choice => '王様がいる安全な部屋を選べ',
        AdMiniGameType.drawPath => '水と敵を避けて王様まで道を描け',
        AdMiniGameType.countdownStop => '救出率が1になる瞬間を狙え',
        AdMiniGameType.numberGate => '王様の資産が増える門を選べ',
        AdMiniGameType.dragSort => '地下の宝を正しい階へ運べ',
        AdMiniGameType.reveal => '休日中の王様を3回見つけよう',
        _ => '王様を助けよう',
      };
    }
    if (ad.number >= 76 && ad.number <= 85) {
      return switch (type) {
        AdMiniGameType.timing => '大きい相手だけを狙って捕食',
        AdMiniGameType.dragSort => '同じ素材を正しい合体枠へドラッグ',
        AdMiniGameType.packOpen => '卵を上へスワイプして孵化',
        _ => '成長する対象を追って3段階進化',
      };
    }
    return switch (type) {
      AdMiniGameType.tapChallenge => '「${ad.name}」の対象を追いかけてタップ',
      AdMiniGameType.choice => '広告の内容に合う記号を3問選ぶ',
      AdMiniGameType.pinPull => '安全な順番でピンを抜く',
      AdMiniGameType.numberGate => '「${ad.name}」で増えるゲートを選ぶ',
      AdMiniGameType.drawPath => '守る対象まで指で安全な線を描く',
      AdMiniGameType.dragSort => '広告の商品を正しい場所へドラッグ',
      AdMiniGameType.timing => '「${ad.name}」の成功ゾーンで止める',
      AdMiniGameType.scratch => '銀色の面をこすって広告を暴く',
      AdMiniGameType.packOpen => 'パックを上へスワイプして3回開封',
      AdMiniGameType.countdownStop => '残り1秒で止める',
      AdMiniGameType.reveal => '移動する広告を3回見つける',
      AdMiniGameType.finale => 'Lv995からLv999へ進化させる',
    };
  }

  static String _success(AdMiniGameType type) => switch (type) {
    AdMiniGameType.tapChallenge => '3回タップする',
    AdMiniGameType.choice => '正解を選ぶ',
    AdMiniGameType.pinPull => '宝を王様へ届ける',
    AdMiniGameType.numberGate => '大きい結果のゲートを通る',
    AdMiniGameType.drawPath => '開始点からゴールまで線をつなぐ',
    AdMiniGameType.dragSort => '対象を正しい枠へ入れる',
    AdMiniGameType.timing => '針を緑の範囲で止める',
    AdMiniGameType.scratch => '表面を70%以上削る',
    AdMiniGameType.packOpen => '十分な距離を上へスワイプする',
    AdMiniGameType.countdownStop => '表示が1のとき止める',
    AdMiniGameType.reveal => '移動する対象を見つける',
    AdMiniGameType.finale => '3つの紋章を点灯する',
  };

  static String _failure(AdMiniGameType type) => switch (type) {
    AdMiniGameType.pinPull => '危険なピンを先に抜く',
    AdMiniGameType.choice => '不正解を選ぶ',
    AdMiniGameType.numberGate => '小さい結果のゲートを選ぶ',
    AdMiniGameType.drawPath => '線がゴールへ届かない',
    AdMiniGameType.dragSort => '違う枠へドロップする',
    AdMiniGameType.timing => '緑の範囲外で止める',
    AdMiniGameType.countdownStop => '1以外で止める',
    _ => '操作を完了できない',
  };
}
