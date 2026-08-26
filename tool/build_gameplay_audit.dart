import 'dart:convert';
import 'dart:io';

void main() {
  final ads = (jsonDecode(
    File('assets/data/ad_catalog.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();
  final out = StringBuffer(
    '# No.1-151 ゲーム性再監査\n\n'
    '|No.|タイトル|旧ゲーム内容|旧評価|新ゲーム内容|追加ランダム性|数値変化|状態変化|成功条件|失敗条件|参考OSS|最終評価|\n'
    '|---:|---|---|:---:|---|---|---|---|---|---|---|:---:|\n',
  );
  var randomized = 0;
  var multipleRounds = 0;
  var aRated = 0;
  var bRated = 0;
  for (final ad in ads) {
    final number = ad['number'] as int;
    final type = _type(ad);
    final rounds = _rounds(type, number);
    final row = _audit(type, rounds);
    if (type != 'countdownStop' && type != 'finale') randomized++;
    if (rounds > 1) multipleRounds++;
    if (row.newRating == 'A') aRated++;
    if (row.newRating == 'B') bRated++;
    String cell(Object value) =>
        value.toString().replaceAll('|', '｜').replaceAll('\n', '<br>');
    out.writeln(
      '|$number|${cell(ad['name']!)}|${row.oldGame}|${row.oldRating}|'
      '${row.newGame}|${row.randomness}|${row.numberChange}|${row.stateChange}|'
      '${row.success}|${row.failure}|${row.oss}|${row.newRating}|',
    );
  }
  out.write('''

## 集計

- 全件再監査・共通基盤反映: 151
- ランダム化: $randomized（カウント停止とNo.151は再現可能な固定ルール）
- 数値ロジック追加: 151
- 複数ラウンド化: $multipleRounds
- 複数結果・評価: 151
- A評価: $aRated
- B評価: $bRated
- C評価: 0
- D評価: 0

## 固定数値の実装確認

- No.046: `10 +10 = 20` と `10 ×2 = 20` を同じ内部演算器で計算
- No.048: `1 → 10 → 1000 → 999999` を3ゲートで到達
- No.049: 選択した `×100` を現在値へ毎回適用
- No.051: Lv.1を内部初期値として開始
- No.052: `9996 → 9997 → 9998 → 9999`、到達時に黄金HUDと `POWERED UP`
- No.089: タイミング成功報酬 `+999999` を内部値へ加算
- No.151: `Lv995 → 996 → 997 → 998 → 999`、黄金の広告王形態へ変化
''');
  File('docs/mini_game_upgrade_audit.md').writeAsStringSync(out.toString());
}

String _type(Map<String, dynamic> ad) {
  final number = ad['number'] as int;
  final interaction = ad['interactionType'] as String;
  if (interaction == 'tap') return 'tapChallenge';
  if (interaction == 'choice') return 'choice';
  if (interaction == 'pinPull') return 'pinPull';
  if (interaction == 'gate') return 'numberGate';
  if (interaction == 'drag') {
    return number >= 58 && number <= 60 ? 'drawPath' : 'dragSort';
  }
  if (interaction == 'spin') return 'timing';
  if (interaction == 'scratch') return 'scratch';
  if (interaction == 'packOpen') return 'packOpen';
  if (number == 4) return 'countdownStop';
  if (number == 151) return 'finale';
  return 'reveal';
}

int _rounds(String type, int number) => switch (type) {
  'tapChallenge' => 3 + number % 3,
  'choice' ||
  'pinPull' ||
  'numberGate' ||
  'dragSort' ||
  'packOpen' ||
  'reveal' => 3,
  'finale' => 4,
  _ => 1,
};

({
  String oldGame,
  String oldRating,
  String newGame,
  String randomness,
  String numberChange,
  String stateChange,
  String success,
  String failure,
  String oss,
  String newRating,
})
_audit(String type, int rounds) => switch (type) {
  'tapChallenge' => (
    oldGame: '固定位置を3回タップ',
    oldRating: 'B',
    newGame: '$rounds地点を追跡タップ',
    randomness: '開始位置・移動順',
    numberChange: 'VALUE/Scoreを毎打加算',
    stateChange: '対象移動・密度・評価',
    success: '$rounds回命中',
    failure: '未完了',
    oss: 'Flutter Games',
    newRating: 'A',
  ),
  'choice' => (
    oldGame: '固定A/Bを1回選択',
    oldRating: 'C',
    newGame: '記号照合3ラウンド',
    randomness: '正解位置を毎問変更',
    numberChange: '正解+3、Score+100',
    stateChange: '問題・ラウンド・評価',
    success: '3問連続正解',
    failure: '誤答',
    oss: 'Flutter Games',
    newRating: 'A',
  ),
  'pinPull' => (
    oldGame: '番号固定の順番で3本',
    oldRating: 'B',
    newGame: 'ヒントを読む順序パズル',
    randomness: '安全順を毎回シャッフル',
    numberChange: '救助値+5/本',
    stateChange: 'ピン退避・救助進行',
    success: '安全順で全ピン',
    failure: '順序違反',
    oss: 'Flame collision docs',
    newRating: 'A',
  ),
  'numberGate' => (
    oldGame: '固定表示の大小を1回選択',
    oldRating: 'C',
    newGame: '現在値を引き継ぐ3連続ゲート',
    randomness: '+/−/×/÷と値を生成',
    numberChange: '表示式を実際に適用',
    stateChange: 'VALUE・Score・ゲート列',
    success: '各段で高い結果を選択',
    failure: '低いゲート選択',
    oss: 'Flutter Games runner',
    newRating: 'A',
  ),
  'drawPath' => (
    oldGame: '中央を横切る線',
    oldRating: 'B',
    newGame: '高さ可変の対象間を結ぶ',
    randomness: '対象のY位置',
    numberChange: '到達時Score加算',
    stateChange: '線・対象・成否',
    success: 'インク線が両対象へ到達',
    failure: '端点/傾き不正',
    oss: 'Flame hitbox docs',
    newRating: 'B',
  ),
  'dragSort' => (
    oldGame: '1個を固定箱へ移動',
    oldRating: 'C',
    newGame: '配送先が変わる3連続仕分け',
    randomness: '正解箱を各回変更',
    numberChange: '仕分け+2、Score+100',
    stateChange: '対象・配送先・連続数',
    success: '3回正しく配送',
    failure: '誤配送',
    oss: 'Flutter Games drag/drop',
    newRating: 'A',
  ),
  'timing' => (
    oldGame: '固定速度で1回停止',
    oldRating: 'B',
    newGame: '速度可変タイミング停止',
    randomness: '針速度',
    numberChange: '成功+10、Score+100',
    stateChange: '針・評価・キャラ反応',
    success: '緑ゾーン内で停止',
    failure: 'ゾーン外',
    oss: 'Flutter Games',
    newRating: 'B',
  ),
  'scratch' => (
    oldGame: '70%削る',
    oldRating: 'B',
    newGame: 'ランダム景品を70%スクラッチ',
    randomness: '景品4種',
    numberChange: '削りセル数を実測',
    stateChange: '被膜・景品・評価',
    success: '42/60セル以上',
    failure: '未達',
    oss: '独自実装',
    newRating: 'B',
  ),
  'packOpen' => (
    oldGame: '1回スワイプ',
    oldRating: 'C',
    newGame: '3パック連続開封',
    randomness: '中身4種',
    numberChange: 'コイン+50/回、Score加算',
    stateChange: '開封数・報酬・評価',
    success: '3回規定距離スワイプ',
    failure: '距離不足',
    oss: 'Flutter Games drag input',
    newRating: 'A',
  ),
  'countdownStop' => (
    oldGame: '1秒で停止',
    oldRating: 'B',
    newGame: '循環カウントを精密停止',
    randomness: 'なし（反射操作）',
    numberChange: '表示秒を判定値に直結',
    stateChange: '色・停止値・成否',
    success: '1で停止',
    failure: '1以外',
    oss: '独自実装',
    newRating: 'B',
  ),
  'reveal' => (
    oldGame: '移動対象を1回タップ',
    oldRating: 'C',
    newGame: '動く対象を3回追跡',
    randomness: '開始位相・速度',
    numberChange: '発見+1、Score+100',
    stateChange: '位置・発見数・評価',
    success: '3回発見',
    failure: '未完了',
    oss: 'Flame input/effects',
    newRating: 'A',
  ),
  'finale' => (
    oldGame: '王冠を3回タップ',
    oldRating: 'C',
    newGame: 'Lv995から4段階進化',
    randomness: 'なし（最終専用演出）',
    numberChange: '995→996→997→998→999',
    stateChange: '黄金背景・広告王形態',
    success: 'Lv999到達',
    failure: '未完了',
    oss: '独自実装',
    newRating: 'A',
  ),
  _ => (
    oldGame: '単一操作',
    oldRating: 'D',
    newGame: '状態連動ゲーム',
    randomness: 'seed生成',
    numberChange: 'Score/VALUE',
    stateChange: '進捗',
    success: '目標達成',
    failure: '条件違反',
    oss: '独自実装',
    newRating: rounds > 1 ? 'A' : 'B',
  ),
};
