import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/ad_catalog.dart';
import 'package:hitasura_ads/models/ad_mini_game_definition.dart';
import 'package:hitasura_ads/models/ad_visual_assets.dart';
import 'package:hitasura_ads/widgets/ad_thumbnail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AdCatalog catalog;

  setUpAll(() async {
    catalog = await AdCatalog.load();
  });

  test('all 151 thumbnail configs reuse their game visual config', () {
    expect(catalog.all, hasLength(151));
    for (final ad in catalog.all) {
      final thumbnail = AdThumbnailConfig.forAd(ad);
      final visual = AdVisualAssets.forAd(ad);
      final game = AdMiniGameDefinition.forAd(ad);

      expect(thumbnail.foregroundAsset, visual.foregroundAsset, reason: ad.id);
      expect(thumbnail.secondaryAsset, visual.secondaryAsset, reason: ad.id);
      expect(thumbnail.backgroundAsset, visual.backgroundAsset, reason: ad.id);
      expect(thumbnail.gameType, game.type, reason: ad.id);
      expect(thumbnail.experienceFormat, ad.experienceFormat, reason: ad.id);
      expect(File(thumbnail.backgroundAsset).existsSync(), isTrue);
      if (thumbnail.foregroundAsset case final path?) {
        expect(File(path).existsSync(), isTrue, reason: ad.id);
      }
      if (thumbnail.secondaryAsset case final path?) {
        expect(File(path).existsSync(), isTrue, reason: '${ad.id}: secondary');
      }
    }
  });

  test('semantic priority examples use the correct subjects', () {
    expect(
      AdThumbnailConfig.forAd(catalog['AD_011']).foregroundAsset,
      endsWith('water_glass.png'),
    );
    expect(
      AdThumbnailConfig.forAd(catalog['AD_031']).foregroundAsset,
      endsWith('sheet1_02.png'),
    );
    expect(
      AdThumbnailConfig.forAd(catalog['AD_059']).foregroundAsset,
      endsWith('rescue_dog.png'),
    );
    expect(
      AdThumbnailConfig.forAd(catalog['AD_059']).secondaryAsset,
      endsWith('bee_swarm.png'),
    );
    expect(
      AdThumbnailConfig.forAd(catalog['AD_061']).backgroundAsset,
      endsWith('parking_lot.jpg'),
    );
    expect(
      AdThumbnailConfig.forAd(catalog['AD_123']).backgroundAsset,
      endsWith('delivery_warehouse.jpg'),
    );
    expect(
      AdThumbnailConfig.forAd(catalog['AD_151']).gameType,
      AdMiniGameType.finale,
    );
  });

  testWidgets('locked thumbnails do not decode spoiler images', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 180,
          height: 120,
          child: AdThumbnail(ad: catalog['AD_031'], discovered: false),
        ),
      ),
    );

    expect(find.byKey(const Key('thumbnail-locked')), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 180,
          height: 120,
          child: AdThumbnail(ad: catalog['AD_151'], discovered: false),
        ),
      ),
    );
    expect(find.byKey(const Key('thumbnail-secret-locked')), findsOneWidget);
    expect(find.text('SECRET'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('discovered thumbnail renders a stage and game cue', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 180,
          height: 120,
          child: AdThumbnail(ad: catalog['AD_031'], discovered: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('thumbnail-stage-AD_031')), findsOneWidget);
    expect(find.byKey(const Key('thumbnail-cue-pinPull')), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('editorial thumbnails show their actual experience cue', (
    tester,
  ) async {
    for (final id in ['AD_011', 'AD_101', 'AD_112', 'AD_127']) {
      final ad = catalog[id];
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 180,
            height: 120,
            child: AdThumbnail(ad: ad, discovered: true),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(Key('thumbnail-cue-${ad.experienceFormat.name}')),
        findsOneWidget,
        reason: id,
      );
    }
  });
}
