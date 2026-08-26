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
    final type = switch (ad.interactionType) {
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
      instruction: _instruction(type),
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

  static String _instruction(AdMiniGameType type) => switch (type) {
    AdMiniGameType.tapChallenge => '光る対象を追いかけてタップ',
    AdMiniGameType.choice => 'お題と同じ記号を3問選ぶ',
    AdMiniGameType.pinPull => '安全な順番でピンを抜く',
    AdMiniGameType.numberGate => '増えるゲートを選ぶ',
    AdMiniGameType.drawPath => '指で安全な線を描く',
    AdMiniGameType.dragSort => '3個のアイテムを正しい場所へドラッグ',
    AdMiniGameType.timing => '成功ゾーンで止める',
    AdMiniGameType.scratch => '銀色の面をこする',
    AdMiniGameType.packOpen => '3つのパックを上へスワイプ',
    AdMiniGameType.countdownStop => '残り1秒で止める',
    AdMiniGameType.reveal => '移動する広告を3回見つける',
    AdMiniGameType.finale => 'Lv995からLv999へ進化させる',
  };

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
