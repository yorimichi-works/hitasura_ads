import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/ad_catalog.dart';
import 'package:hitasura_ads/models/ad_definition.dart';
import 'package:hitasura_ads/widgets/ad_experience_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AdCatalog catalog;

  setUpAll(() async {
    catalog = await AdCatalog.load();
  });

  test('151 ads have an explicit complete experience definition', () {
    expect(catalog.all, hasLength(151));
    expect(catalog.all.every((ad) => ad.experienceData.isNotEmpty), isTrue);

    final counts = <AdExperienceFormat, int>{
      for (final format in AdExperienceFormat.values)
        format: catalog.all.where((ad) => ad.experienceFormat == format).length,
    };
    expect(
      counts.values.every((count) => count > 0),
      isTrue,
      reason: '$counts',
    );
    expect(counts[AdExperienceFormat.playable], lessThan(90));
    expect(
      counts.entries
          .where((entry) => entry.key != AdExperienceFormat.playable)
          .fold<int>(0, (sum, entry) => sum + entry.value),
      greaterThan(60),
    );

    for (final ad in catalog.all) {
      expect(ad.experienceData['instruction'], isNotEmpty, reason: ad.id);
      final requiredKeys = switch (ad.experienceFormat) {
        AdExperienceFormat.playable => const ['verdict'],
        AdExperienceFormat.productDemo => const [
          'step1',
          'step2',
          'step3',
          'verdict',
        ],
        AdExperienceFormat.factCheck => const [
          'claim',
          'evidence1',
          'evidence2',
          'evidence3',
          'verdict',
        ],
        AdExperienceFormat.personalityQuiz => const [
          'question1',
          'question2',
          'question3',
          'resultA',
          'resultB',
          'resultC',
        ],
        AdExperienceFormat.storyReel => const [
          'scene1',
          'scene2',
          'scene3',
          'verdict',
        ],
        AdExperienceFormat.newsBulletin => const [
          'ticker',
          'lead',
          'update1',
          'update2',
          'verdict',
        ],
        AdExperienceFormat.systemScan => const [
          'scan1',
          'scan2',
          'scan3',
          'verdict',
        ],
        AdExperienceFormat.webTrap => const [
          'bait1',
          'bait2',
          'safe',
          'verdict',
        ],
      };
      for (final key in requiredKeys) {
        expect(ad.experienceData[key], isNotEmpty, reason: '${ad.id}: $key');
      }
    }
  });

  test('editorial formats use content-specific flavor text', () {
    for (final ad in catalog.all) {
      expect(ad.flavorText, contains(ad.name), reason: ad.id);
      expect(ad.flavorText, contains(ad.description), reason: ad.id);
      expect(ad.flavorText.length, greaterThan(70), reason: ad.id);
    }
    expect(const {
      '診断カルテ',
      'AI所見',
      '回答分析',
    }, contains(catalog['AD_101'].flavorType));
    expect(const {
      '広告ニュース',
      '速報記録',
      '取材メモ',
    }, contains(catalog['AD_112'].flavorType));
    expect(const {
      '検査ログ',
      '警告解析',
      '端末診断',
    }, contains(catalog['AD_127'].flavorType));
  });

  testWidgets('all non-playable ads complete and reset their assigned format', (
    tester,
  ) async {
    final editorialAds = catalog.all.where(
      (ad) => ad.experienceFormat != AdExperienceFormat.playable,
    );
    for (final ad in editorialAds) {
      await _pumpExperience(tester, ad);
      await _completeExperience(tester, ad);
      expect(
        find.byKey(const Key('experience-success')),
        findsOneWidget,
        reason: '${ad.id}: ${ad.experienceFormat.name}',
      );
      await tester.tap(find.byKey(const Key('experience-reset')));
      await tester.pump();
      expect(
        find.byKey(const Key('experience-instruction')),
        findsOneWidget,
        reason: '${ad.id}: reset',
      );
    }
  });

  testWidgets('product image itself drives the live demo', (tester) async {
    await _pumpExperience(tester, catalog['AD_011']);
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.byKey(const Key('experience-product-object')));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const Key('experience-success')), findsOneWidget);
  });
}

Future<void> _completeExperience(WidgetTester tester, AdDefinition ad) async {
  if (ad.experienceFormat == AdExperienceFormat.personalityQuiz) {
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.byKey(const Key('experience-choice-1')));
      await tester.pump();
    }
    return;
  }
  if (ad.experienceFormat == AdExperienceFormat.storyReel) {
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.byKey(const Key('experience-story-next')));
      await tester.pump();
    }
    return;
  }
  if (ad.experienceFormat == AdExperienceFormat.webTrap) {
    await tester.tap(find.byKey(const Key('experience-bait-1')));
    await tester.pump();
  }
  for (var step = 0; step < 3; step++) {
    await tester.tap(find.byKey(Key('experience-step-$step')));
    await tester.pump();
  }
}

Future<void> _pumpExperience(WidgetTester tester, AdDefinition ad) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 390,
          height: 500,
          child: AdExperienceHost(
            key: ValueKey(ad.id),
            ad: ad,
            onInteraction: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
