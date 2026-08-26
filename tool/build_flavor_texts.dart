import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/data/ad_catalog.json');
  final ads = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final styles = <String>[
    '寓話',
    '企業文書',
    '不気味',
    '言葉遊び',
    '口コミ',
    '実験記録',
    '独白',
    '噂話',
    '日記',
    '警告文',
    '昔話',
    'ニュース',
    '説明書',
    '手紙',
    'メタ',
    '脱力',
    '研究記録',
    '王国史',
    '議事録',
    '辞書風',
    '神話風',
    '回収報告',
  ];
  for (final ad in ads) {
    final number = ad['number'] as int;
    final style = styles[(number - 1) % styles.length];
    ad['discoveryText'] = ad['description'];
    ad['flavorText'] = _flavor(ad, style);
    ad['flavorType'] = style;
  }
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(ads)}\n');
  final report = StringBuffer(
    '# 図鑑フレーバーテキスト監査\n\n'
    '|No.|タイトル|discoveryText|flavorText|文章タイプ|\n'
    '|---:|---|---|---|---|\n',
  );
  for (final ad in ads) {
    String cell(Object? value) =>
        value.toString().replaceAll('|', '｜').replaceAll('\n', '<br>');
    report.writeln(
      '|${ad['number']}|${cell(ad['name'])}|${cell(ad['discoveryText'])}|'
      '${cell(ad['flavorText'])}|${ad['flavorType']}|',
    );
  }
  File('docs/ad_flavor_text_audit.md').writeAsStringSync(report.toString());
}

String _flavor(Map<String, dynamic> ad, String style) {
  final number = ad['number'] as int;
  final title = ad['name'] as String;
  final discovery = ad['description'] as String;
  final headline = ad['headline'] as String;
  final result = ad['resultText'] as String;
  final category = ad['category'] as String;
  final interaction = ad['interactionType'] as String;
  final values = (ad['fixedValues'] as Map<String, dynamic>).values.toList();
  final figure = values.isEmpty ? '' : '\n\n帳簿には「${values.first}」とだけ残っている。';

  if (number == 151) {
    return '百五十の広告を閉じた者だけが、最後の一匹に会える。\n\n'
        'アドゴンは火を吐かない。代わりに、まだ見ていない広告の匂いを吐く。\n\n'
        '図鑑は完成した。広告のほうは、そう思っていない。';
  }

  return switch (style) {
    '寓話' =>
      '「$title」と書かれた看板を、旅人は疑わずにくぐった。\n\n$discovery\n\n疑うことを覚えたころ、入口はもう広告になっていた。',
    '企業文書' => '社内通達：$headline\n\n本件に関する質問は受け付けます。回答は受け付けません。$figure',
    '不気味' => '$titleを閉じた。\n\n翌朝、履歴には「まだ開いている」と記録されていた。\n\n$result',
    '言葉遊び' => '$categoryの担当者は「盛っていない」と言った。\n\n盛ったのは数字ではなく、話のほうらしい。$figure',
    '口コミ' => '★★★★★\n$titleのおかげで人生が変わりました。\n\nどちら向きに変わったかは、利用規約で回答を控えます。',
    '実験記録' =>
      '実験$number日目。被験者は「$headline」を信じ続けている。\n\n$discovery\n\n対照群も、なぜか同じ広告を見ていた。',
    '独白' => '私は$titleを選んだ。\n\n選ばされたのではない。そう書くようにも、選ばされていない。\n\n$result',
    '噂話' => 'この町では、$headlineを見た人ほど黙る。\n\nただし広告欄だけは、以前よりよくしゃべる。',
    '日記' => '$number日目。$titleにまた会った。\n昨日とは違う広告だと言われた。\n\n昨日も同じ説明を受けた。',
    '警告文' => '警告：$headline\n\n危険の内容は、安全のため非公開です。\n閉じる場合は、まず開いてください。',
    '昔話' => 'むかしむかし、$titleを本当に信じた人がいました。\n\n幸せになったかは不明です。レビューだけは満点でした。',
    'ニュース' =>
      '本日、$headlineと発表されました。\n\n専門家は「$discovery」と分析。\n提供元は次の広告へ移動しています。',
    '説明書' => '使用方法：画面の指示に従ってください。\n失敗した場合：あなたの操作です。\n成功した場合：$titleの実績です。',
    '手紙' => '拝啓、あの日見た$titleを覚えていますか。\n\n私は忘れました。広告のほうは、私を覚えているようです。',
    'メタ' =>
      '$interactionを終えると、広告を遊んだことになる。\n\n広告を閉じると、広告に遊ばれていたことが分かる。\n\n$result',
    '脱力' => '$headline\n\n会議は三時間続いた。\n決まったのは、ボタンを赤くすることだけだった。',
    '研究記録' => '第7研究所・資料$number。\n$titleは再現に成功したが、目的は再現できなかった。$figure',
    '王国史' => '王国暦$number年、布告「$headline」。\n\n民は歓声を上げた。歓声を上げなかった者には、もう一度表示された。',
    '議事録' => '議題：$title\n結論：$result\n\nなお、誰が提案したかは全員が否定した。',
    '辞書風' => '$title【名】\n信じる直前が最も魅力的に見える現象。\n用例：「$discovery」',
    '神話風' => 'はじめに広告があり、広告は「$headline」と告げた。\n\n人はボタンを押した。神々は計測を開始した。',
    _ => '回収票 No.$number\n品名：$title\n状態：$discovery\n\n返却理由の欄だけ、最初から塗りつぶされていた。',
  };
}
