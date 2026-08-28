import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/data/ad_catalog.json');
  final ads = (jsonDecode(file.readAsStringSync()) as List<dynamic>)
      .cast<Map<String, dynamic>>();

  for (final ad in ads) {
    final number = ad['number'] as int;
    final name = ad['name'] as String;
    final description = ad['description'] as String;
    final format = _formatFor(number);
    final data = _contentFor(number, name, description, format);
    ad['experienceFormat'] = format;
    ad['experienceData'] = data;
    ad['flavorType'] = _flavorType(format, number);
    ad['flavorText'] = _flavorFor(number, name, description, format, data);
  }

  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(ads)}\n',
  );
  _writeAudit(ads);
}

void _writeAudit(List<Map<String, dynamic>> ads) {
  final counts = <String, int>{};
  for (final ad in ads) {
    final format = ad['experienceFormat'] as String;
    counts[format] = (counts[format] ?? 0) + 1;
  }
  final buffer = StringBuffer()
    ..writeln('# 151広告 体験形式監査')
    ..writeln()
    ..writeln('ゲームだけに固定せず、内容に応じて操作可能な広告形式へ割り当てた正本。')
    ..writeln()
    ..writeln('## 集計')
    ..writeln();
  for (final entry in counts.entries) {
    buffer.writeln('- `${entry.key}`: ${entry.value}件');
  }
  buffer
    ..writeln()
    ..writeln('## 全件対応表')
    ..writeln()
    ..writeln('|No.|タイトル|カテゴリ|体験形式|操作|フレーバー種別|')
    ..writeln('|---:|---|---|---|---|---|');
  for (final ad in ads) {
    buffer.writeln(
      '|${(ad['number'] as int).toString().padLeft(3, '0')}'
      '|${_cell(ad['name'])}|${_cell(ad['category'])}'
      '|`${ad['experienceFormat']}`|`${ad['interactionType']}`'
      '|${_cell(ad['flavorType'])}|',
    );
  }
  File('docs/ad_experience_overhaul_audit.md')
      .writeAsStringSync(buffer.toString());
}

String _cell(Object? value) => value.toString().replaceAll('|', '\\|');

String _formatFor(int number) {
  if (number >= 11 && number <= 20 ||
      number >= 66 && number <= 75 ||
      number == 143) {
    return 'productDemo';
  }
  if (number >= 21 && number <= 30 || const {1, 6, 8, 150}.contains(number)) {
    return 'factCheck';
  }
  if (number >= 101 && number <= 109 || number == 146) {
    return 'personalityQuiz';
  }
  if (number >= 111 && number <= 120 && number != 112 || number == 149) {
    return 'storyReel';
  }
  if (const {4, 10, 112, 121, 124, 125, 130, 144}.contains(number)) {
    return 'newsBulletin';
  }
  if (const {122, 126, 127, 128, 129}.contains(number)) {
    return 'systemScan';
  }
  if (number <= 10 || number == 110 || number >= 131 && number <= 141) {
    return 'webTrap';
  }
  return 'playable';
}

Map<String, String> _contentFor(
  int number,
  String name,
  String description,
  String format,
) {
  final serial = number.toString().padLeft(3, '0');
  return switch (format) {
    'productDemo' => {
      'instruction': number >= 66 && number <= 75
          ? '3つの改善を選び、広告のAFTERを完成させよう'
          : '商品の3つの機能を試し、誇大さを確かめよう',
      'step1': number >= 66 && number <= 75 ? '片づける' : '触ってみる',
      'step2': number >= 66 && number <= 75 ? '着替える' : '比較する',
      'step3': number >= 66 && number <= 75 ? '仕上げる' : '価格を見る',
      'verdict': '$name の実演完了。$description',
    },
    'factCheck' => {
      'instruction': '広告の主張を3枚の証拠で検証しよう',
      'claim': name,
      'evidence1': '広告主資料：$description',
      'evidence2': '調査番号 $serial：比較対象は広告側が選定',
      'evidence3': '編集部判定：数字は本当でも意味は別問題',
      'verdict': '検証終了。「$name」は広告表現として保存されました。',
    },
    'personalityQuiz' => {
      'instruction': '直感で3問答えると、この広告専用の診断結果が出ます',
      'question1': '広告を閉じるボタンが見つからない。どうする？',
      'question2': '$name と表示された。最初に疑うのは？',
      'question3': '結果が期待と違ったときの反応は？',
      'resultA': '慎重派：説明を最後まで読む広告耐性タイプ',
      'resultB': '直感派：光った場所を先に押す探索タイプ',
      'resultC': '観察派：広告そのものを楽しむ図鑑タイプ',
    },
    'storyReel' => {
      'instruction': 'タップで3カットの縦型広告を進めよう',
      'scene1': '0:00　「$name」を知らなかった昨日',
      'scene2': '0:03　$description',
      'scene3': '0:06　そして肝心なことはCMのあとへ',
      'verdict': '視聴完了。映像は終わりましたが、疑問は続きます。',
    },
    'newsBulletin' => {
      'instruction': '続報を開いて、見出しの真相を確認しよう',
      'ticker': '速報 $serial　広告局から臨時ニュース',
      'lead': name,
      'update1': '現場からの第一報：$description',
      'update2': '専門家は「広告なので落ち着いて」とコメント',
      'verdict': '続報：緊急性は確認されませんでした。',
    },
    'systemScan' => {
      'instruction': '3項目を検査して、警告の正体を突き止めよう',
      'scan1': '端末の安全性',
      'scan2': '広告の鮮度',
      'scan3': 'あおり文句の濃度',
      'verdict': '$name の原因は、端末ではなく広告でした。',
    },
    'webTrap' => {
      'instruction': '怪しいページを調べ、本物の終了ボタンを見つけよう',
      'bait1': number.isEven ? '今すぐ開く' : '無料で続ける',
      'bait2': number % 3 == 0 ? '同意して閉じる' : 'あとで閉じる',
      'safe': '広告の仕組みを見る',
      'verdict': '$name の罠を回避。$description',
    },
    _ => {
      'instruction': '画面の対象を直接操作して広告の結末を変えよう',
      'verdict': '$name をプレイ完了。$description',
    },
  };
}

String _flavorType(String format, int number) {
  final variants = switch (format) {
    'productDemo' => const ['実演記録', '使用報告', '通販検証'],
    'factCheck' => const ['広告検証', '数字監査', '比較調査'],
    'personalityQuiz' => const ['診断カルテ', 'AI所見', '回答分析'],
    'storyReel' => const ['映像台本', '視聴記録', 'SNS記録'],
    'newsBulletin' => const ['広告ニュース', '速報記録', '取材メモ'],
    'systemScan' => const ['検査ログ', '警告解析', '端末診断'],
    'webTrap' => const ['Web考古学', '誘導調査', 'バナー標本'],
    _ => const ['プレイ記録', '攻略メモ', '操作報告'],
  };
  return variants[number % variants.length];
}

String _flavorFor(
  int number,
  String name,
  String description,
  String format,
  Map<String, String> data,
) {
  final no = number.toString().padLeft(3, '0');
  final text = switch (format) {
    'productDemo' =>
      '実演記録 No.$no「$name」\n\n担当者は、広告で約束された機能を三つとも試した。$description\n\n${data['verdict']} 売れたのは商品よりも、試したくなる気持ちだった。',
    'factCheck' =>
      '広告検証ファイル No.$no「$name」\n\n見出し、数字、比較条件を一つずつ調べた。$description\n\n${data['evidence3']} 判定後も見出しだけは自信満々に点滅している。',
    'personalityQuiz' =>
      '診断カルテ No.$no「$name」\n\n三つの質問に正解はない。それでも広告は迷わず性格を決めた。$description\n\n結果より、どの選択肢で迷ったかのほうが本人らしい。',
    'storyReel' =>
      '映像広告台本 No.$no「$name」\n\n冒頭三秒で事件が起き、六秒目で奇跡が起きた。$description\n\n映像はそこで終了した。続きより先に、閉じるボタンが現れた。',
    'newsBulletin' =>
      '広告局速報 No.$no「$name」\n\n速報音とともに全国へ伝えられた。$description\n\n取材班が確認できた事実は、広告が予定どおり表示されたことだけだった。',
    'systemScan' =>
      '検査ログ No.$no「$name」\n\n端末、通信、広告の順に検査した。$description\n\n異常値を示したのは端末ではなく、あおり文句の濃度だった。',
    'webTrap' =>
      'Web考古学標本 No.$no「$name」\n\n押したくなるボタンと、押してはいけないボタンが同じ色で並ぶ。$description\n\n無事に戻れた閲覧者だけが、これも広告だったと気づく。',
    _ =>
      'プレイ記録 No.$no「$name」\n\n説明を読む前に画面へ触れた。$description\n\n操作の結果は手元で変わったが、広告の自信だけは最初から最後まで最大だった。',
  };
  return number == 151 ? '百五十の広告を越えた先の記録。\n\n$text' : text;
}
