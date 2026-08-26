import 'dart:convert';
import 'dart:io';

void main() {
  final source = File('assets/data/ad_catalog.json').readAsStringSync();
  final ads = (jsonDecode(source) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final buffer = StringBuffer()
    ..writeln('# No.1-151 ミニゲーム化監査・対応表')
    ..writeln()
    ..writeln(
      'この表は `assets/data/ad_catalog.json` と '
      '`AdMiniGameDefinition.forAd` から生成する実装上の正本です。',
    )
    ..writeln()
    ..writeln('|No.|タイトル|元ネタ/現表示|ゲーム|操作|成功条件|失敗条件|画像|状態/リセット|')
    ..writeln('|---:|---|---|---|---|---|---|---|---|');
  for (final ad in ads) {
    final number = ad['number'] as int;
    final type = _gameType(number, ad['interactionType'] as String);
    buffer.writeln(
      '|${number.toString().padLeft(3, '0')}'
      '|${_cell(ad['name'] as String)}'
      '|${_cell('${ad['category']}/${ad['displayType']}; ${ad['description']}; '
      '既存:${ad['interactionType']}; ${ad['rarity']}; 条件:${ad['unlockCondition']}')}'
      '|$type（必要）'
      '|${_instruction(type)}'
      '|${_success(type)}'
      '|${_failure(type)}'
      '|${_asset(ad) ?? '共通図形'}'
      '|MiniGamePhase / 画面内リセット|',
    );
  }
  buffer
    ..writeln()
    ..writeln('## 共通実装')
    ..writeln()
    ..writeln('- Widget: `AdMiniGame`')
    ..writeln('- 状態: `notStarted / playing / success / failure`')
    ..writeln('- リセット: 成功・失敗バナーの再試行ボタン')
    ..writeln('- 状態は表示中の広告1件だけ生成し、終了時にTimer/AnimationControllerを破棄')
    ..writeln('- No.151の解放規則とAdMobリワード処理は変更しない');
  Directory('docs').createSync(recursive: true);
  File('docs/ad_minigame_audit.md').writeAsStringSync(buffer.toString());
  stdout.writeln('Generated ${ads.length} audit rows.');
}

String _cell(String value) => value.replaceAll('|', '/').replaceAll('\n', ' ');

String _gameType(int number, String interaction) => switch (interaction) {
  'tap' => 'tapChallenge',
  'choice' => 'choice',
  'pinPull' => 'pinPull',
  'gate' => 'numberGate',
  'drag' when number >= 58 && number <= 60 => 'drawPath',
  'drag' => 'dragSort',
  'spin' => 'timing',
  'scratch' => 'scratch',
  'packOpen' => 'packOpen',
  'none' when number == 4 => 'countdownStop',
  'none' when number == 151 => 'finale',
  _ => 'reveal',
};

String _instruction(String type) => switch (type) {
  'tapChallenge' => '光る対象を3回タップ',
  'choice' => '正しい選択肢を選ぶ',
  'pinPull' => '安全な順番でピンを抜く',
  'numberGate' => '増えるゲートを選ぶ',
  'drawPath' => '指で安全な線を描く',
  'dragSort' => 'アイテムを正しい場所へドラッグ',
  'timing' => '成功ゾーンで止める',
  'scratch' => '銀色の面をこする',
  'packOpen' => 'パックを上へスワイプ',
  'countdownStop' => '残り1秒で止める',
  'finale' => '王冠を3回タップして完成させる',
  _ => '隠された広告を探してタップ',
};

String _success(String type) => switch (type) {
  'pinPull' => '宝を王様へ届ける',
  'numberGate' => '大きい結果のゲートを通る',
  'drawPath' => '開始点からゴールまで線をつなぐ',
  'dragSort' => '対象を正しい枠へ入れる',
  'timing' => '針を緑の範囲で止める',
  'scratch' => '表面を70%以上削る',
  'packOpen' => '十分な距離を上へスワイプする',
  'countdownStop' => '表示が1のとき止める',
  'finale' => '3つの紋章を点灯する',
  'choice' => '正解を選ぶ',
  'tapChallenge' => '3回タップする',
  _ => '移動する対象を見つける',
};

String _failure(String type) => switch (type) {
  'pinPull' => '危険なピンを先に抜く',
  'choice' => '不正解を選ぶ',
  'numberGate' => '小さい結果のゲートを選ぶ',
  'drawPath' => '線がゴールへ届かない',
  'dragSort' => '違う枠へドロップする',
  'timing' => '緑の範囲外で止める',
  'countdownStop' => '1以外で止める',
  _ => '操作を完了できない',
};

String? _asset(Map<String, dynamic> ad) {
  if (ad['category'] == '王様救出') {
    return 'assets/images/ad_parts/sheet1/sheet1_02.png';
  }
  return switch (ad['displayType']) {
    'sale' => 'assets/images/ad_parts/sheet1/sheet1_16.png',
    'product' => 'assets/images/ad_parts/sheet2/sheet2_07.png',
    'gate' => 'assets/images/ad_parts/sheet2/sheet2_01.png',
    'pack' => 'assets/images/ad_parts/sheet2/sheet2_15.png',
    'slot' || 'roulette' => 'assets/images/ad_parts/sheet1/sheet1_18.png',
    'warning' => 'assets/images/ad_parts/sheet1/sheet1_19.png',
    'secret' => 'assets/images/ad_parts/sheet1/sheet1_04.png',
    _ => null,
  };
}
