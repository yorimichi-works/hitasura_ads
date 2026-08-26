import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/app.dart';
import 'package:hitasura_ads/data/ad_catalog.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/ad_selection_service.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';
import 'package:hitasura_ads/screens/app_shell.dart';
import 'package:hitasura_ads/screens/records_screen.dart';
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

  test('探索条件は性別と年齢境界を判定する', () {
    final service = AdSelectionService();
    expect(
      service.conditionsEligible(['男性', '20歳以上'], age: 20, gender: '男性'),
      isTrue,
    );
    expect(
      service.conditionsEligible(['男性', '20歳以上'], age: 19, gender: '男性'),
      isFalse,
    );
    expect(service.conditionsEligible(['女性'], age: 29, gender: '男性'), isFalse);
    expect(service.conditionsEligible(['女性'], age: 29, gender: '女性'), isTrue);
  });

  testWidgets('初回設定後は日本語の3画面ナビゲーションを表示する', (tester) async {
    final controller = await AppController.create(
      store: MemoryAppStore(),
      catalog: catalog,
      random: Random(1),
    );
    await tester.pumpWidget(HitasuraAdsApp(controller: controller));

    expect(find.text('ひたすら\n広告'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '広告大好き'), findsOneWidget);
    expect(find.byKey(const Key('first-launch-age')), findsOneWidget);
    expect(find.byKey(const Key('first-launch-gender')), findsOneWidget);
    await tester.tap(find.text('はじめる'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.user!.nickname, '広告大好き');
    expect(controller.user!.age, 29);
    expect(controller.profile.gender, '男性');
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

    expect(find.text('新しい広告を探す'), findsOneWidget);
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

  test('discovery state and sound setting persist together', () async {
    final store = MemoryAppStore();
    final controller = await AppController.create(
      store: store,
      catalog: catalog,
    );
    final ad = catalog['AD_001'];

    expect(await controller.completeAd(ad, 6), isTrue);
    expect(await controller.completeAd(ad, 6), isFalse);
    await controller.setSoundEffectsEnabled(false);

    expect(store.snapshot.discoveredIds, contains(ad.id));
    expect(store.snapshot.soundEffectsEnabled, isFalse);

    await controller.resetDiscoveryForDebug(ad.id);
    expect(controller.discoveredIds, isNot(contains(ad.id)));
    expect(await controller.completeAd(ad, 6), isTrue);
  });

  testWidgets('rewarded sponsor completion refills energy once', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 26, 12);
    final controller = await AppController.create(
      store: MemoryAppStore(
        AppSnapshot(
          user: UserProfile(
            id: 'reward-test',
            nickname: '広告王',
            age: 24,
            createdAt: now,
          ),
          searchEnergy: 2,
          searchEnergyRecoveryAnchor: now,
        ),
      ),
      catalog: catalog,
      clock: () => now,
    );
    final rewardedAds = _FakeRewardedAdService(RewardedAdResult.rewarded);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(controller: controller, rewardedAdService: rewardedAds),
      ),
    );
    await tester.tap(find.byKey(const Key('sponsor-reward-button')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.searchEnergy, 5);
    expect(rewardedAds.showCount, 1);
    expect(find.byKey(const Key('rewarded-ad-debug-status')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'catalog reward unlocks only the selected ad without refilling energy',
    (tester) async {
      final now = DateTime.utc(2026, 8, 26, 12);
      final controller = await AppController.create(
        store: MemoryAppStore(
          AppSnapshot(
            user: UserProfile(
              id: 'catalog-reward-test',
              nickname: 'tester',
              age: 24,
              createdAt: now,
            ),
            searchEnergy: 2,
            searchEnergyRecoveryAnchor: now,
          ),
        ),
        catalog: catalog,
        clock: () => now,
      );
      final rewardedAds = _FakeRewardedAdService(RewardedAdResult.rewarded);

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            controller: controller,
            rewardedAdService: rewardedAds,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.auto_stories_outlined));
      await tester.pump();
      await tester.tap(find.byKey(const Key('catalog-open-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-tile-AD_001')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reward-unlock-AD_001')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reward-unlock-AD_001')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(controller.discoveredIds, contains('AD_001'));
      expect(controller.discoveredCount, 1);
      expect(controller.searchEnergy, 2);
      expect(rewardedAds.showCount, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'zero energy disables only search and failed reward changes nothing',
    (tester) async {
      final now = DateTime.utc(2026, 8, 26, 12);
      final controller = await AppController.create(
        store: MemoryAppStore(
          AppSnapshot(
            user: UserProfile(
              id: 'empty-energy-test',
              nickname: '広告王',
              age: 24,
              createdAt: now,
            ),
            searchEnergy: 0,
            searchEnergyRecoveryAnchor: now,
          ),
        ),
        catalog: catalog,
        clock: () => now,
      );
      final rewardedAds = _FakeRewardedAdService(RewardedAdResult.notRewarded);

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            controller: controller,
            rewardedAdService: rewardedAds,
          ),
        ),
      );

      final playButton = tester.widget<FilledButton>(
        find.byKey(const Key('play-ad-button')),
      );
      expect(playButton.onPressed, isNull);
      expect(find.byKey(const Key('sponsor-reward-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sponsor-reward-button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.searchEnergy, 0);
      expect(rewardedAds.showCount, 1);

      await tester.tap(find.byIcon(Icons.auto_stories_outlined));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.auto_stories), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('No.151 never exposes a rewarded unlock action', (tester) async {
    final controller = await AppController.create(
      store: MemoryAppStore(),
      catalog: catalog,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogScreen(
          controller: controller,
          onReplay: (_) async {},
          onRewardUnlock: (_) async => true,
          rewardUnlockAvailable: true,
          rewardInProgress: false,
          rewardStatus: RewardedAdStatus.ready,
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('catalog-tile-AD_151')),
      800,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('catalog-tile-AD_151')));
    await tester.pumpAndSettle();

    expect(find.text('発見状況: 0 / 150'), findsOneWidget);
    expect(find.byKey(const Key('reward-unlock-AD_151')), findsNothing);
    expect(find.byKey(const Key('catalog-flavor-AD_151')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('discovered catalog detail shows its dedicated flavor text', (
    tester,
  ) async {
    final controller = await AppController.create(
      store: MemoryAppStore(),
      catalog: catalog,
    );
    await controller.unlockAdWithReward('AD_001');
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogScreen(
          controller: controller,
          onReplay: (_) async {},
          onRewardUnlock: (_) async => false,
          rewardUnlockAvailable: false,
          rewardInProgress: false,
          rewardStatus: RewardedAdStatus.unsupported,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('catalog-tile-AD_001')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-flavor-AD_001')), findsOneWidget);
    expect(find.text(catalog['AD_001'].flavorText), findsOneWidget);
    expect(find.byKey(const Key('catalog-replay-AD_001')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('debug panel exposes test environment and discovery controls', (
    tester,
  ) async {
    final controller = await AppController.create(
      store: MemoryAppStore(),
      catalog: catalog,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          controller: controller,
          rewardedAdService: _FakeRewardedAdService(RewardedAdResult.rewarded),
        ),
      ),
    );

    await tester.longPress(find.text('ひたすら広告'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('debug-ad-environment')), findsOneWidget);

    await tester.tap(find.byKey(const Key('debug-unlock-all-toggle')));
    await tester.pump();
    expect(controller.discoveredCount, 151);

    await tester.longPress(find.text('ひたすら広告'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('debug-unlock-all-toggle')));
    await tester.pump();
    expect(controller.discoveredCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakeRewardedAdService extends RewardedAdService {
  _FakeRewardedAdService(this.result);

  final RewardedAdResult result;
  int showCount = 0;

  @override
  RewardedAdStatus get status => RewardedAdStatus.ready;

  @override
  bool get isSupported => true;

  @override
  bool get usesTestAds => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<RewardedAdResult> show() async {
    showCount += 1;
    return result;
  }
}
