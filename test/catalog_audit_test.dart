import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/ad_catalog.dart';
import 'package:hitasura_ads/models/ad_definition.dart';
import 'package:hitasura_ads/widgets/ad_experience_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AdCatalog catalog;

  setUpAll(() async {
    catalog = await AdCatalog.load();
  });

  test('151件の名称・説明内の固定数値がfixedValuesへ登録されている', () {
    final missing = <String>[];
    final numericPattern = RegExp(r'\d[\d,]*(?:\.\d+)?');

    for (final ad in catalog.all) {
      final source = '${ad.name} ${ad.description}';
      final expectedNumbers = numericPattern
          .allMatches(source)
          .map((match) => match.group(0)!)
          .toSet();
      final configured = ad.fixedValues.values.join(' ');
      for (final number in expectedNumbers) {
        if (!configured.contains(number)) {
          missing.add('${ad.id}: $number');
        }
      }
    }

    expect(missing, isEmpty, reason: 'fixedValues未登録: ${missing.join(', ')}');
  });

  test('151件のカテゴリ・表示型・操作型・レアリティが監査規則と一致する', () {
    for (final ad in catalog.all) {
      expect(ad.category, _expectedCategory(ad.number), reason: ad.id);
      expect(ad.displayType, _expectedDisplayType(ad.number), reason: ad.id);
      expect(
        ad.interactionType,
        _expectedInteraction(ad.number),
        reason: ad.id,
      );
      expect(
        const {'COMMON', 'UNCOMMON', 'RARE', 'SUPER RARE', 'SECRET'},
        contains(ad.rarity),
        reason: ad.id,
      );
      expect(ad.targetTags, contains(ad.category), reason: ad.id);
      expect(ad.targetTags, contains(ad.displayType.name), reason: ad.id);
      expect(ad.headline, ad.name, reason: ad.id);
      expect(ad.body, contains(ad.description), reason: ad.id);
      expect(ad.ctaText, isNotEmpty, reason: ad.id);
      expect(ad.resultText, isNotEmpty, reason: ad.id);
      expect(ad.minimumDisplaySeconds, inInclusiveRange(5, 20), reason: ad.id);
      expect(
        '${ad.name} ${ad.description} ${ad.body}',
        isNot(contains('Mega Sale')),
        reason: ad.id,
      );
      expect(ad.category, isNot('Travel'), reason: ad.id);
      if (!const {
        AdDisplayType.rescue,
        AdDisplayType.gate,
        AdDisplayType.slot,
        AdDisplayType.roulette,
        AdDisplayType.scratch,
        AdDisplayType.pack,
        AdDisplayType.secret,
      }.contains(ad.displayType)) {
        expect(ad.symbol, ad.name, reason: '${ad.id}: visual cue');
      }
    }

    expect(catalog['AD_037'].rarity, 'RARE');
    expect(
      catalog.all.where((ad) => ad.rarity == 'SECRET').map((ad) => ad.id),
      ['AD_151'],
    );
  });

  test('No.046と重点広告の固定値・演出設定が正本どおり', () {
    expect(catalog['AD_004'].minimumDisplaySeconds, 10);
    expect(catalog['AD_004'].fixedValues['countdown'], '残り10秒');
    expect(catalog['AD_005'].fixedValues['discount'], '1円OFF');
    expect(catalog['AD_006'].fixedValues['discount'], '0.5％OFF');
    expect(catalog['AD_023'].fixedValues, containsPair('reviews', '0件'));
    expect(catalog['AD_046'].fixedValues, {
      'leftGate': '＋10',
      'rightGate': '×2',
    });
    expect(catalog['AD_046'].ctaText, '＋10を選ぶ');
    expect(catalog['AD_052'].fixedValues['level'], 'LV.9999');
    expect(catalog['AD_086'].fixedValues['reelSequence'], '777');
    expect([
      catalog['AD_086'].fixedValues['reelA'],
      catalog['AD_086'].fixedValues['reelB'],
      catalog['AD_086'].fixedValues['reelC'],
    ], everyElement('7'));
    expect(catalog['AD_095'].fixedValues['initialStock'], '残り3口');
    expect(catalog['AD_099'].fixedValues['cardRarity'], 'UR');
    expect(catalog['AD_143'].fixedValues['discount'], '0.01％OFF');
    expect(catalog['AD_134'].animationPreset, AdAnimationPreset.glow);
    expect(catalog['AD_135'].animationPreset, AdAnimationPreset.shake);
  });

  test('No.151は専用音声とCOMPLETE表示を持つ', () {
    final secret = catalog['AD_151'];
    expect(secret.isSecret, isTrue);
    expect(secret.name, '幻の広告 ― アドゴン');
    expect(secret.fixedValues['completion'], '151 / 151');
    expect(secret.seIds, ['secret_se.wav']);
    expect(secret.bgmId, 'secret_bgm.wav');
    expect(File('assets/audio/secret_se.wav').existsSync(), isTrue);
    expect(File('assets/audio/secret_bgm.wav').existsSync(), isTrue);
    expect(File('assets/audio/ui_click.wav').existsSync(), isTrue);
  });

  testWidgets('AD_001〜AD_151をスマホ幅で描画・操作してoverflowしない', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final ad in catalog.all) {
      await tester.pumpWidget(
        MaterialApp(
          home: AdExperienceOverlay(key: ValueKey(ad.id), ad: ad),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.text(ad.name), findsWidgets, reason: ad.id);
      expect(find.text(ad.displayNumber), findsOneWidget, reason: ad.id);
      for (final value in ad.fixedValues.values.toSet()) {
        expect(
          find.byKey(Key('fixed-${ad.id}-$value')),
          findsOneWidget,
          reason: '${ad.id}: $value',
        );
      }
      expect(
        tester.takeException(),
        isNull,
        reason: '${ad.id}: initial render',
      );

      if (ad.interactionType != AdInteractionType.none) {
        final button = find.byKey(const Key('ad-interaction-button'));
        expect(button, findsOneWidget, reason: ad.id);
        final tapCount = ad.interactionType == AdInteractionType.scratch
            ? 3
            : 1;
        for (var tap = 0; tap < tapCount; tap++) {
          await tester.tap(button);
          await tester.pump(const Duration(milliseconds: 800));
        }
        expect(tester.takeException(), isNull, reason: '${ad.id}: interaction');
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

String _expectedCategory(int number) {
  if (number <= 10) return '古のWeb';
  if (number <= 20) return '怪しい通販';
  if (number <= 30) return 'ランキング';
  if (number <= 45) return '王様救出';
  if (number <= 55) return '数字ゲート';
  if (number <= 65) return 'パズル';
  if (number <= 75) return '変身';
  if (number <= 85) return '成長・マージ';
  if (number <= 92) return '抽選';
  if (number <= 100) return '広告パック';
  if (number <= 110) return 'AI・診断';
  if (number <= 120) return '動画・SNS風';
  if (number <= 130) return '警告';
  if (number <= 140) return '意味不明';
  if (number <= 150) return '高レア';
  return 'SECRET';
}

AdDisplayType _expectedDisplayType(int number) {
  if (number == 4 || number == 144) return AdDisplayType.warning;
  if (number == 5 || number == 6 || number == 143) return AdDisplayType.sale;
  if (number == 146) return AdDisplayType.diagnosis;
  if (number == 147) return AdDisplayType.rescue;
  if (number == 148) return AdDisplayType.pack;
  if (number == 149) return AdDisplayType.meta;
  if (number <= 10) return AdDisplayType.retro;
  if (number <= 20) return AdDisplayType.product;
  if (number <= 30) return AdDisplayType.review;
  if (number <= 45) return AdDisplayType.rescue;
  if (number <= 55) return AdDisplayType.gate;
  if (number <= 65) return AdDisplayType.puzzle;
  if (number <= 75) return AdDisplayType.makeover;
  if (number <= 85) return AdDisplayType.merge;
  if (number <= 90) return AdDisplayType.slot;
  if (number == 91) return AdDisplayType.roulette;
  if (number == 92) return AdDisplayType.scratch;
  if (number <= 100) return AdDisplayType.pack;
  if (number <= 110) return AdDisplayType.diagnosis;
  if (number <= 120) return AdDisplayType.social;
  if (number <= 130) return AdDisplayType.warning;
  if (number <= 140) return AdDisplayType.meta;
  if (number <= 150) return AdDisplayType.legendary;
  return AdDisplayType.secret;
}

AdInteractionType _expectedInteraction(int number) {
  if (number == 4 || number == 149 || number == 151) {
    return AdInteractionType.none;
  }
  if (number == 110 || number == 132) return AdInteractionType.tap;
  if (number == 146) return AdInteractionType.choice;
  if (number == 147) return AdInteractionType.pinPull;
  if (number == 148) return AdInteractionType.packOpen;
  if (number <= 20) return AdInteractionType.tap;
  if (number <= 30) return AdInteractionType.choice;
  if (number <= 45) return AdInteractionType.pinPull;
  if (number <= 55) return AdInteractionType.gate;
  if (number <= 65) return AdInteractionType.drag;
  if (number <= 75) return AdInteractionType.choice;
  if (number <= 85) return AdInteractionType.tap;
  if (number <= 91) return AdInteractionType.spin;
  if (number == 92) return AdInteractionType.scratch;
  if (number <= 100) return AdInteractionType.packOpen;
  if (number <= 110) return AdInteractionType.choice;
  if (number <= 130) return AdInteractionType.tap;
  if (number <= 140) return AdInteractionType.none;
  if (number <= 150) return AdInteractionType.tap;
  return AdInteractionType.none;
}
