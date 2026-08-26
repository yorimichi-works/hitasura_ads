import 'ad_definition.dart';

class AdVisualAssets {
  const AdVisualAssets({
    required this.foregroundAsset,
    required this.secondaryAsset,
    required this.backgroundAsset,
    required this.imageDecision,
    required this.backgroundDecision,
    required this.missingAsset,
  });

  factory AdVisualAssets.forAd(AdDefinition ad) {
    final foreground = _foregroundFor(ad);
    final background = _backgroundFor(ad);
    return AdVisualAssets(
      foregroundAsset: foreground,
      secondaryAsset: _secondaryFor(ad),
      backgroundAsset: background,
      imageDecision: foreground == null ? '適切な素材なし' : '反映可能',
      backgroundDecision: background.startsWith('assets/images/generated/')
          ? '専用背景を反映済み'
          : '差替え推奨',
      missingAsset: foreground == null ? _missingFor(ad) : null,
    );
  }

  final String? foregroundAsset;
  final String? secondaryAsset;
  final String backgroundAsset;
  final String imageDecision;
  final String backgroundDecision;
  final String? missingAsset;

  static String _part(int sheet, int index) =>
      'assets/images/ad_parts/sheet$sheet/sheet${sheet}_${index.toString().padLeft(2, '0')}.png';

  static String _background(int sheet, int index) =>
      'assets/images/ad_backgrounds/sheet$sheet/sheet${sheet}_${index.toString().padLeft(2, '0')}.png';

  static const _generated = 'assets/images/generated';

  static String? _foregroundFor(AdDefinition ad) {
    if (ad.category == '王様救出') return _part(1, 2);
    if (ad.category == '古のWeb') {
      return switch (ad.number) {
        4 => _part(1, 12),
        5 || 6 => _part(1, 16),
        7 => _part(1, 14),
        8 => _part(1, 9),
        9 => _part(2, 19),
        _ => null,
      };
    }
    if (ad.category == '怪しい通販') {
      const choices = [12, 10, 13, 11, 7];
      return _part(2, choices[(ad.number - 11) % choices.length]);
    }
    if (ad.category == 'ランキング') {
      final choices = [_part(1, 10), _part(2, 16), _part(2, 5), _part(1, 17)];
      return choices[(ad.number - 21) % choices.length];
    }
    if (ad.category == '数字ゲート') {
      const choices = [1, 3, 5, 16, 9];
      final item = choices[(ad.number - 46) % choices.length];
      return item == 9 ? _part(1, 9) : _part(2, item);
    }
    if (ad.category == 'パズル') {
      return switch (ad.number) {
        56 || 57 => _part(1, 3),
        59 => '$_generated/characters/rescue_dog.png',
        60 || 65 => _part(1, 14),
        63 => _part(2, 18),
        64 => _part(2, 14),
        _ => null,
      };
    }
    if (ad.category == '変身') {
      const choices = [4, 2, 12, 18, 19];
      return _part(2, choices[(ad.number - 66) % choices.length]);
    }
    if (ad.category == '成長・マージ') {
      const choices = [14, 15, 9, 18];
      return _part(2, choices[(ad.number - 76) % choices.length]);
    }
    if (ad.category == '抽選') {
      return ad.number <= 91 ? _part(1, 18) : _part(2, 19);
    }
    if (ad.category == '広告パック') {
      const choices = [14, 15, 11, 7];
      final item = choices[(ad.number - 93) % choices.length];
      return item == 7 ? _part(1, 7) : _part(2, item);
    }
    if (ad.category == 'AI・診断') {
      const choices = [7, 6, 2, 5];
      return _part(2, choices[(ad.number - 101) % choices.length]);
    }
    if (ad.category == '動画・SNS風') {
      const choices = [6, 2, 17, 5];
      final item = choices[(ad.number - 111) % choices.length];
      return item == 17 ? _part(1, 17) : _part(2, item);
    }
    if (ad.category == '警告') {
      const choices = [19, 17, 12, 13, 15];
      return _part(1, choices[(ad.number - 121) % choices.length]);
    }
    if (ad.category == '意味不明') {
      return switch (ad.number) {
        132 => _part(1, 14),
        134 => _part(2, 19),
        135 => _part(2, 20),
        136 => _part(1, 17),
        _ => null,
      };
    }
    if (ad.category == '高レア') {
      return switch (ad.number) {
        141 => _part(1, 14),
        142 || 147 => _part(1, 2),
        143 => _part(1, 16),
        144 => _part(2, 17),
        145 => _part(1, 7),
        146 => _part(2, 5),
        148 => _part(2, 15),
        150 => _part(1, 10),
        _ => null,
      };
    }
    if (ad.isSecret) return _part(1, 10);
    return null;
  }

  static String? _secondaryFor(AdDefinition ad) {
    if (ad.number == 59) return '$_generated/game/bee_swarm.png';
    if (ad.category == '王様救出') {
      if (ad.name.contains('ピン')) return _part(1, 3);
      if (ad.name.contains('燃') || ad.name.contains('炎')) {
        return _part(2, 20);
      }
      return _part(1, 1);
    }
    if (ad.category == 'AI・診断') return _part(1, 11);
    if (ad.category == '怪しい通販') return _part(2, 10);
    if (ad.category == '数字ゲート') return _part(2, 16);
    if (ad.category == '高レア' || ad.isSecret) return _part(2, 19);
    return null;
  }

  static String _backgroundFor(AdDefinition ad) {
    if (ad.number == 59) {
      return '$_generated/backgrounds/sunny_grassland.jpg';
    }
    if (ad.number == 61 || ad.number == 62) {
      return '$_generated/backgrounds/parking_lot.jpg';
    }
    if (ad.number >= 31 && ad.number <= 45) {
      return ad.number >= 41
          ? '$_generated/backgrounds/stone_dungeon.jpg'
          : '$_generated/backgrounds/palace_treasure_hall.jpg';
    }
    if (ad.number >= 66 && ad.number <= 75) {
      return ad.number.isEven
          ? '$_generated/backgrounds/dirty_room.jpg'
          : '$_generated/backgrounds/renovated_room.jpg';
    }
    if ((ad.number >= 93 && ad.number <= 100) || ad.number == 123) {
      return '$_generated/backgrounds/delivery_warehouse.jpg';
    }
    final choices = switch (ad.category) {
      '古のWeb' => [(5, 15), (4, 1), (4, 2)],
      '怪しい通販' => [(5, 11), (5, 19), (4, 18)],
      'ランキング' => [(5, 4), (4, 7), (5, 8)],
      '王様救出' => [(5, 1), (4, 13), (4, 14)],
      '数字ゲート' => [(4, 3), (5, 6), (5, 10)],
      'パズル' => [(4, 8), (4, 6), (5, 5)],
      '変身' => [(4, 5), (5, 7), (5, 14)],
      '成長・マージ' => [(4, 10), (5, 3), (5, 6)],
      '抽選' => [(4, 2), (5, 8), (4, 7)],
      '広告パック' => [(5, 8), (4, 9), (5, 19)],
      'AI・診断' => [(4, 6), (5, 2), (4, 8)],
      '動画・SNS風' => [(4, 17), (5, 16), (4, 16)],
      '警告' => [(4, 14), (5, 9), (5, 1)],
      '意味不明' => [(5, 17), (5, 15), (4, 10)],
      '高レア' => [(4, 9), (5, 4), (5, 20)],
      _ => [(4, 20), (5, 12), (5, 20)],
    };
    final choice = choices[ad.number % choices.length];
    return _background(choice.$1, choice.$2);
  }

  static String _missingFor(AdDefinition ad) {
    return switch (ad.number) {
      1 || 2 || 3 || 10 => 'レトロWeb用カーソル・バナー部品',
      58 => '透明なコップと水流',
      61 || 62 => '正面または俯瞰の車',
      131 || 133 || 137 || 138 || 139 || 140 || 149 => '広告メタ表現用の汎用バナー部品',
      _ => '${ad.name}に完全一致する専用商品・人物素材',
    };
  }
}
