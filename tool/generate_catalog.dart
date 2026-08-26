import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/generate_catalog.dart <spec-6.txt> <output.json>',
    );
    exitCode = 64;
    return;
  }

  final lines = File(args[0]).readAsLinesSync();
  final entryPattern = RegExp(r'^\*\*AD_(\d{3})　(.+)\*\*$');
  final entries = <Map<String, Object>>[];
  for (var index = 0; index < lines.length; index++) {
    final match = entryPattern.firstMatch(lines[index]);
    if (match == null) continue;
    final number = int.parse(match.group(1)!);
    var description = '';
    for (
      var offset = 1;
      offset <= 5 && index + offset < lines.length;
      offset++
    ) {
      final candidate = lines[index + offset].trim();
      if (candidate.startsWith('「') && candidate.endsWith('」')) {
        description = candidate.substring(1, candidate.length - 1);
        break;
      }
    }
    entries.add(_entry(number, match.group(2)!, description));
  }
  entries.add(_entry(151, '幻の広告 ― アドゴン', '151種類を見つけた者だけが出会える、幻の広告。'));
  entries.sort((a, b) => (a['number']! as int).compareTo(b['number']! as int));

  if (entries.length != 151 ||
      entries.map((e) => e['number']).toSet().length != 151) {
    throw StateError('Expected 151 unique entries, got ${entries.length}.');
  }
  File(args[1]).parent.createSync(recursive: true);
  File(args[1])
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(entries));
}

Map<String, Object> _entry(int number, String name, String description) {
  final experience = _experience(number);
  final rarity = switch (number) {
    151 => 'SECRET',
    >= 141 => 'SUPER RARE',
    >= 101 => 'RARE',
    >= 56 => 'UNCOMMON',
    _ => 'COMMON',
  };
  const animations = [
    'blink',
    'pulse',
    'shake',
    'bounce',
    'slide',
    'rotate',
    'glow',
    'confetti',
  ];
  const colors = [
    'FFFFC107',
    'FFFF3D00',
    'FF00C853',
    'FF00B0FF',
    'FFFF4081',
    'FF7C4DFF',
    'FFFF6D00',
  ];
  return {
    'id': 'AD_${number.toString().padLeft(3, '0')}',
    'number': number,
    'name': name,
    'description': description,
    'category': experience.category,
    'rarity': rarity,
    'displayType': experience.displayType,
    'minimumDisplaySeconds': experience.seconds + (number % 3),
    'headline': name,
    'body': _body(number, description),
    'ctaText': _cta(number, experience.interaction),
    'animationPreset': number == 151
        ? 'glow'
        : animations[(number - 1) % animations.length],
    'interactionType': experience.interaction,
    'symbol': experience.symbols[(number - 1) % experience.symbols.length],
    'accentColor': number == 151
        ? 'FFFFD54F'
        : colors[(number - 1) % colors.length],
    'targetTags': [
      experience.category,
      experience.displayType,
      rarity.toLowerCase(),
    ],
    'unlockCondition': number == 151 ? 'AD_001〜AD_150をすべて発見' : '通常抽選で出現',
  };
}

_Experience _experience(int number) {
  if (number <= 10) {
    return const _Experience('古のWeb', 'retro', 'tap', 5, [
      '★',
      '→',
      'NEW!',
      'AD',
    ]);
  }
  if (number <= 20) {
    return const _Experience('怪しい通販', 'product', 'tap', 6, [
      '箱',
      '!?',
      '限定',
      'PR',
    ]);
  }
  if (number <= 30) {
    return const _Experience('ランキング', 'review', 'choice', 6, [
      '★',
      '1位',
      '99%',
      '声',
    ]);
  }
  if (number <= 45) {
    return const _Experience('王様救出', 'rescue', 'pinPull', 9, [
      '王',
      '炎',
      '水',
      '宝',
    ]);
  }
  if (number <= 55) {
    return const _Experience('数字ゲート', 'gate', 'gate', 8, [
      '+10',
      '×2',
      '人',
      '剣',
    ]);
  }
  if (number <= 65) {
    return const _Experience('パズル', 'puzzle', 'drag', 8, ['ネジ', '水', '線', '車']);
  }
  if (number <= 75) {
    return const _Experience('変身', 'makeover', 'choice', 8, [
      '汚',
      'キラ',
      '家',
      '服',
    ]);
  }
  if (number <= 85) {
    return const _Experience('成長・マージ', 'merge', 'tap', 8, [
      '魚',
      '卵',
      'LV',
      '合体',
    ]);
  }
  if (number <= 90) {
    return const _Experience('抽選', 'slot', 'spin', 10, ['7', '★', '謎', 'BAR']);
  }
  if (number == 91) {
    return const _Experience('抽選', 'roulette', 'spin', 10, [
      '当',
      '!?',
      '謎',
      '広告',
    ]);
  }
  if (number == 92) {
    return const _Experience('抽選', 'scratch', 'scratch', 10, [
      '削',
      '？',
      '当',
      '広告',
    ]);
  }
  if (number <= 100) {
    return const _Experience('広告パック', 'pack', 'packOpen', 10, [
      'SSR?',
      '袋',
      '光',
      'カード',
    ]);
  }
  if (number <= 110) {
    return const _Experience('AI・診断', 'diagnosis', 'choice', 7, [
      'AI',
      '診断',
      '脳',
      '27',
    ]);
  }
  if (number <= 120) {
    return const _Experience('動画・SNS風', 'social', 'tap', 6, [
      '▶',
      '再生',
      '♡',
      '話題',
    ]);
  }
  if (number <= 130) {
    return const _Experience('警告', 'warning', 'tap', 7, [
      '!',
      '残1',
      '99%',
      '速報',
    ]);
  }
  if (number <= 140) {
    return const _Experience('意味不明', 'meta', 'none', 6, ['広告', '無', '光', '？']);
  }
  if (number <= 150) {
    return const _Experience('高レア', 'legendary', 'tap', 10, [
      '王冠',
      'SR',
      '伝説',
      '虹',
    ]);
  }
  return const _Experience('SECRET', 'secret', 'none', 18, ['ADGON']);
}

String _body(int number, String description) {
  const endings = ['今だけかもしれない。', '専門家も首をかしげた。', '詳しくは広告の中で。', '効果には広告差があります。'];
  if (number == 151) return 'すべての広告を見たあなたへ。\n広告の向こう側が、いま開く。';
  return '$description\n${endings[(number - 1) % endings.length]}';
}

String _cta(int number, String interaction) {
  if (number == 151) return '幻を見る';
  return switch (interaction) {
    'pinPull' => number.isEven ? '右のピンを抜く' : '左のピンを抜く',
    'gate' => number.isEven ? '×2へ進む' : '＋10へ進む',
    'drag' => '動かして解決する',
    'spin' => number == 91 ? 'ルーレットを回す' : 'SPIN!',
    'scratch' => 'ここをこする',
    'packOpen' => number.isEven ? '豪快に開封する' : 'そっと開封する',
    'choice' => number.isEven ? 'たぶんこちら' : '絶対こちら',
    'tap' => number % 4 == 0 ? '今は押さない' : '詳しく見る',
    _ => '眺める',
  };
}

class _Experience {
  const _Experience(
    this.category,
    this.displayType,
    this.interaction,
    this.seconds,
    this.symbols,
  );

  final String category;
  final String displayType;
  final String interaction;
  final int seconds;
  final List<String> symbols;
}
