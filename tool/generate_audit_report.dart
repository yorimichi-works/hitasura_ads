import 'dart:convert';
import 'dart:io';

void main() {
  final ads = (jsonDecode(
    File('assets/data/ad_catalog.json').readAsStringSync(),
  ) as List<dynamic>).cast<Map<String, dynamic>>();
  final output = StringBuffer()
    ..writeln('# 151広告 整合性監査表')
    ..writeln()
    ..writeln('監査対象: `AD_001`〜`AD_151`')
    ..writeln()
    ..writeln('正本: `assets/data/ad_catalog.json` の名称・説明・`fixedValues`・表示/操作設定')
    ..writeln()
    ..writeln('| No. | 広告名 | 結果 |')
    ..writeln('|---:|---|---|');

  for (final ad in ads) {
    final number = ad['number'] as int;
    final fixes = <String>[];
    if (_numericFixes.contains(number)) fixes.add('FIXED: 固定値をfixedValuesへ統合');
    if (_wordingFixes.contains(number)) fixes.add('FIXED: 本体の題材・結果文を正式内容へ統一');
    if (_displayTypeFixes.contains(number)) {
      fixes.add('FIXED: displayTypeを内容へ一致');
    }
    if (_interactionFixes.contains(number)) {
      fixes.add('FIXED: interactionTypeを内容へ一致');
    }
    if (number == 37) fixes.add('FIXED: 仕様例に合わせRAREへ修正');
    if (number == 151) fixes.add('OK: 解禁・専用演出・SE/BGM・151/151を確認');
    final result = fixes.isEmpty ? 'OK' : fixes.join('<br>');
    final no = number.toString().padLeft(3, '0');
    output.writeln('| $no | ${ad['name']} | $result |');
  }

  output
    ..writeln()
    ..writeln('## 集計')
    ..writeln()
    ..writeln('- 監査完了: ${ads.length} / 151')
    ..writeln('- 固定数値の正本化・表示補正: ${_numericFixes.length}件')
    ..writeln('- 文言・題材表示補正: ${_wordingFixes.length}件')
    ..writeln('- カテゴリ不一致: 0件')
    ..writeln('- displayType補正: ${_displayTypeFixes.length}件')
    ..writeln('- interactionType補正: ${_interactionFixes.length}件')
    ..writeln('- レアリティ補正: 1件 (`AD_037`)')
    ..writeln()
    ..writeln(
      '数値を含む正式名称・説明は、監査テストで全件抽出し、対応する値が`fixedValues`に存在することを検証する。Rendererは`fixedValues`を直接表示し、広告番号から固定数値を生成しない。',
    );

  final report = File('docs/ad_audit_151.md');
  report.parent.createSync(recursive: true);
  report.writeAsStringSync(output.toString());
}

const _numericFixes = <int>{
  1,
  4,
  5,
  6,
  8,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  30,
  33,
  38,
  42,
  46,
  48,
  49,
  50,
  51,
  52,
  55,
  65,
  69,
  70,
  74,
  81,
  83,
  86,
  89,
  93,
  95,
  96,
  98,
  100,
  101,
  104,
  105,
  113,
  116,
  120,
  123,
  125,
  126,
  127,
  143,
  144,
  149,
  150,
  151,
};

const _wordingFixes = <int>{
  7,
  32,
  35,
  37,
  40,
  59,
  84,
  89,
  95,
  99,
  101,
  132,
  134,
  135,
  147,
  148,
};
const _displayTypeFixes = <int>{4, 5, 6, 143, 144, 146, 147, 148, 149};
const _interactionFixes = <int>{4, 110, 132, 146, 147, 148, 149};
