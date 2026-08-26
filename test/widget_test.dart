import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/app.dart';
import 'package:hitasura_ads/data/ad_catalog.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/ad_selection_service.dart';
import 'package:hitasura_ads/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AdCatalog catalog;

  setUpAll(() async {
    catalog = await AdCatalog.load();
  });

  test('広告図鑑は001〜151の固定データを欠番・重複なく持つ', () async {
    expect(catalog.all, hasLength(151));
    expect(catalog.all.map((ad) => ad.id).toSet(), hasLength(151));
    expect(
      catalog.all.map((ad) => ad.number).toList(),
      List.generate(151, (index) => index + 1),
    );
    expect(
      catalog.all.every(
        (ad) => ad.name.isNotEmpty && ad.description.isNotEmpty,
      ),
      isTrue,
    );
    expect(catalog.all.where((ad) => ad.isSecret).single.id, 'AD_151');
    expect(catalog['AD_151'].name, '幻の広告 ― アドゴン');
    expect(
      catalog.all.where((ad) => ad.rarity == 'SECRET').map((ad) => ad.id),
      ['AD_151'],
    );
  });

  test('No.151は001〜150コンプリート後だけ選ばれる', () async {
    final service = AdSelectionService(random: Random(151));

    for (var i = 0; i < 500; i++) {
      expect(service.select(catalog.all, const {}).isSecret, isFalse);
    }

    final first150 = catalog.all
        .where((ad) => !ad.isSecret)
        .map((ad) => ad.id)
        .toSet();
    expect(service.select(catalog.all, first150).id, 'AD_151');

    first150.add('AD_151');
    expect(service.select(catalog.all, first150).isSecret, isFalse);
  });

  testWidgets('初回設定後は日本語の3画面ナビゲーションを表示する', (tester) async {
    final controller = await AppController.create(
      store: MemoryAppStore(),
      catalog: catalog,
      random: Random(1),
    );
    await tester.pumpWidget(HitasuraAdsApp(controller: controller));

    expect(find.text('ひたすら\n広告'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '広告王');
    await tester.enterText(find.byType(TextFormField).at(1), '24');
    await tester.tap(find.text('はじめる'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('記録'), findsOneWidget);
    expect(find.text('広告探索'), findsOneWidget);
    expect(find.byKey(const Key('play-ad-button')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('HOMEは統計を置かず広告再生を主操作として表示する', (tester) async {
    final snapshot = AppSnapshot(
      user: UserProfile(
        id: 'test',
        nickname: '広告王',
        age: 24,
        createdAt: DateTime(2026),
      ),
    );
    final controller = await AppController.create(
      store: MemoryAppStore(snapshot),
      catalog: catalog,
      random: Random(2),
    );
    await tester.pumpWidget(HitasuraAdsApp(controller: controller));

    expect(find.text('広告を再生する'), findsOneWidget);
    expect(find.text('今日の探索時間'), findsNothing);

    await tester.tap(find.byKey(const Key('play-ad-button')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('架空広告'), findsOneWidget);
    expect(find.byKey(const Key('ad-countdown')), findsOneWidget);
    expect(find.byKey(const Key('close-ad-button')), findsNothing);

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byKey(const Key('close-ad-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-ad-button')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.watchCount, 1);
    expect(controller.discoveredCount, 1);
    expect(find.text('新しい広告！'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
