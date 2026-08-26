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
  final entries = <Map<String, Object?>>[];
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

Map<String, Object?> _entry(int number, String name, String description) {
  final experience = _experience(number);
  final fixedValues = _fixedValues(number);
  final rarity = switch (number) {
    151 => 'SECRET',
    >= 141 => 'SUPER RARE',
    37 => 'RARE',
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
    'minimumDisplaySeconds': number == 4
        ? 10
        : experience.seconds + (number % 3),
    'headline': name,
    'body': _body(number, description),
    'ctaText': _cta(number, experience.interaction, fixedValues),
    'animationPreset': _animationFor(number, experience, animations),
    'interactionType': experience.interaction,
    'symbol': _symbolFor(number, experience, name),
    'accentColor': number == 151
        ? 'FFFFD54F'
        : colors[(number - 1) % colors.length],
    'fixedValues': fixedValues,
    'resultText': _resultText(number, experience.interaction, description),
    'imageAssets': <String>[],
    'seIds': experience.interaction == 'none'
        ? number == 151
              ? ['secret_se.wav']
              : <String>[]
        : ['ui_click.wav'],
    'bgmId': number == 151 ? 'secret_bgm.wav' : null,
    'targetTags': [
      experience.category,
      experience.displayType,
      rarity.toLowerCase(),
    ],
    'unlockCondition': number == 151 ? 'AD_001〜AD_150をすべて発見' : '通常抽選で出現',
  };
}

_Experience _experience(int number) {
  if (number == 4) {
    return const _Experience('古のWeb', 'warning', 'none', 10, ['10秒']);
  }
  if (number == 5 || number == 6) {
    return const _Experience('古のWeb', 'sale', 'tap', 6, ['OFF']);
  }
  if (number == 143) {
    return const _Experience('高レア', 'sale', 'tap', 10, ['0.01％']);
  }
  if (number == 144) {
    return const _Experience('高レア', 'warning', 'tap', 10, ['残り1個']);
  }
  if (number == 146) {
    return const _Experience('高レア', 'diagnosis', 'choice', 10, ['博士']);
  }
  if (number == 147) {
    return const _Experience('高レア', 'rescue', 'pinPull', 12, ['王']);
  }
  if (number == 148) {
    return const _Experience('高レア', 'pack', 'packOpen', 12, ['究極']);
  }
  if (number == 149) {
    return const _Experience('高レア', 'meta', 'none', 10, ['あと2']);
  }
  if (number == 110) {
    return const _Experience('AI・診断', 'diagnosis', 'tap', 8, ['AI']);
  }
  if (number == 132) {
    return const _Experience('意味不明', 'meta', 'tap', 6, ['詳細']);
  }
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

Map<String, String> _fixedValues(int number) => switch (number) {
  1 => {'visitorNumber': '999,999人目'},
  4 => {'countdown': '残り10秒'},
  5 => {'discount': '1円OFF'},
  6 => {'discount': '0.5％OFF'},
  8 => {'downloadRate': '120％'},
  20 => {'edition': '2026'},
  21 => {'experts': '100人', 'recommended': '1人'},
  22 => {'rank': '第1位', 'products': '1商品'},
  23 => {'stars': '★★★★★', 'reviews': '0件'},
  24 => {'satisfaction': '101％'},
  25 => {'repeatRate': '300％'},
  26 => {'humanRate': '99％', 'otherRate': '1％'},
  30 => {'reviews': '口コミ1件'},
  33 => {'pins': '3本のピン'},
  38 => {'rescueRate': '救出率2％'},
  42 => {'floor': '地下100階'},
  46 => {'leftGate': '＋10', 'rightGate': '×2'},
  48 => {'startCount': '1人', 'endCount': '999999人'},
  49 => {'gate': '×100'},
  50 => {'gate': '＋5'},
  51 => {'startLevel': 'LV.1', 'duration': '12秒'},
  52 => {'level': 'LV.9999'},
  55 => {'duration': '20秒'},
  65 => {'duration': '3秒', 'iq': 'IQ999'},
  69 => {'duration': '15秒'},
  70 => {'money': '所持金3円'},
  74 => {'cleaningPower': '掃除力9999'},
  81 => {'level': 'LV.1'},
  83 => {'elapsed': '8秒目'},
  86 => {'reelSequence': '777', 'reelA': '7', 'reelB': '7', 'reelC': '7'},
  89 => {'reward': '＋999999'},
  93 => {'price': '1口0円'},
  94 => {'packClaim': 'SSR大量封入', 'reveal': 'R'},
  95 => {'initialStock': '残り3口'},
  96 => {'marketPrice': '999999円相当'},
  98 => {'remaining': '42口'},
  99 => {'cardRarity': 'UR'},
  100 => {'catalogNumber': '100番'},
  101 => {'predictedAge': '27歳'},
  104 => {'duration': '3秒'},
  105 => {'iq': 'IQ999', 'problem': '1＋1'},
  113 => {'duration': '4秒'},
  116 => {'duration': '3日'},
  120 => {'views': '1000万再生'},
  123 => {'stock': '残り1個'},
  125 => {'day': '第438日目'},
  126 => {'countdown': 'あと5秒'},
  127 => {'progress': '99％'},
  143 => {'discount': '0.01％OFF'},
  144 => {'stock': '残り1個'},
  145 => {'rank': 'SSRより上'},
  149 => {'position': '最後から2番目'},
  150 => {'remaining': 'あと一つ'},
  151 => {'completion': '151 / 151'},
  _ => <String, String>{},
};

String _symbolFor(int number, _Experience experience, String name) =>
    switch (number) {
      31 => 'PIN',
      32 => '炎',
      33 => 'PIN×3',
      34 => '王 vs 宝',
      35 => '水',
      36 => '溶岩',
      37 => '炎',
      38 => '2％',
      39 => '王？',
      40 => '魚',
      41 => '金貨',
      42 => '100F',
      43 => '禁PIN',
      44 => '休日',
      45 => 'FINAL?',
  86 => '777',
      89 => '＋999999',
      95 => '残り3口',
      99 => 'UR 水',
      147 => '王',
      148 => '究極',
      151 => 'ADGON',
      _ => switch (experience.displayType) {
        'rescue' ||
        'gate' ||
        'slot' ||
        'roulette' ||
        'scratch' ||
        'pack' ||
        'secret' =>
          experience.symbols[(number - 1) % experience.symbols.length],
        _ => name,
      },
    };

String _animationFor(
  int number,
  _Experience experience,
  List<String> fallback,
) => switch (number) {
  6 || 32 || 37 || 135 => 'shake',
  7 || 141 => 'slide',
  5 || 143 || 147 => 'confetti',
  9 || 10 || 121 => 'blink',
  82 => 'pulse',
  87 || 134 || 142 || 145 || 148 || 151 => 'glow',
  _ => switch (experience.displayType) {
    'retro' => 'blink',
    'sale' => 'confetti',
    'product' => 'bounce',
    'review' => 'pulse',
    'rescue' => 'shake',
    'gate' => 'slide',
    'puzzle' => 'rotate',
    'makeover' => 'glow',
    'merge' => 'pulse',
    'slot' => 'shake',
    'roulette' => 'rotate',
    'scratch' => 'slide',
    'pack' => 'glow',
    'diagnosis' => 'pulse',
    'social' => 'slide',
    'warning' => 'blink',
    'meta' => 'blink',
    'legendary' || 'secret' => 'glow',
    _ => fallback[(number - 1) % fallback.length],
  },
};

String _resultText(int number, String interaction, String description) {
  return switch (number) {
    37 => 'FAIL!! 正解を選んだはずなのに、王様はまた燃えました。',
    86 => '+999999　何が増えたのかは分かりません。',
    89 => '＋999999　使い道はありません。',
    93 => 'SUPER RARE!?　1口0円の広告カードでした。',
    95 => '残り4口！ 本当に増えました。',
    101 => 'AI診断結果：27歳。根拠はありません。',
    105 => '正解は2。IQ999かもしれません。',
    147 => 'SUCCESS! 王様、ついに助かる。',
    148 => '究極開封！ 中身は広告でした。',
    151 => 'COMPLETE　151 / 151',
    _ => switch (interaction) {
      'pinPull' => '操作完了。$description',
      'gate' => 'ゲート通過。$description',
      'drag' => 'パズル完了。$description',
      'spin' => '抽選終了。$description',
      'scratch' => '削った結果、広告でした。',
      'packOpen' => '開封結果：広告カード。$description',
      'choice' => '診断・選択完了。$description',
      'tap' => '詳しく見ても、$description',
      _ => description,
    },
  };
}

String _body(int number, String description) {
  const endings = ['今だけかもしれない。', '専門家も首をかしげた。', '詳しくは広告の中で。', '効果には広告差があります。'];
  if (number == 151) {
    return '$description\nすべての広告を見たあなたへ。';
  }
  return '$description\n${endings[(number - 1) % endings.length]}';
}

String _cta(int number, String interaction, Map<String, String> fixedValues) {
  if (number == 151) return '幻を見る';
  if (number == 7) return '×を探す';
  if (number == 110) return 'AIボタンを押す';
  if (number == 132) return '詳しく見る';
  if (number == 141) return '伝説の×を押す';
  return switch (interaction) {
    'pinPull' => number.isEven ? '右のピンを抜く' : '左のピンを抜く',
    'gate' => fixedValues.isEmpty ? 'ゲートを選ぶ' : '${fixedValues.values.first}を選ぶ',
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
