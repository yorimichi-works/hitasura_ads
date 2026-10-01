import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/app.dart';
import 'package:hitasura_ads/arcade/engine/game.dart';
import 'package:hitasura_ads/arcade/registry.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/l10n/l10n.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';
import 'package:hitasura_ads/state/app_controller.dart';

class _NoAds extends RewardedAdService {
  @override
  RewardedAdStatus get status => RewardedAdStatus.unsupported;
  @override
  bool get isSupported => false;
  @override
  bool get usesTestAds => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<RewardedAdResult> show({String placementName = 'reward'}) async => RewardedAdResult.unavailable;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registry has 151 unique games with texts in every table', () {
    expect(allGames, hasLength(151));
    expect(allGames.map((g) => g.id).toSet(), hasLength(151));
    expect(allGames.last.isSecret, isTrue);
    for (final lang in languages) {
      L10n.code = lang.code;
      for (final g in allGames) {
        final t = L10n.game(g.no);
        expect(t.title, isNotEmpty, reason: '${lang.code} #${g.no}');
        expect(t.verb, isNotEmpty, reason: '${lang.code} #${g.no}');
      }
      expect(L10n.ui('watch_next'), isNot('watch_next'));
    }
    L10n.code = 'en';
  });

  test('picks favour undiscovered ads and the secret appears last', () async {
    final now = DateTime.utc(2026, 9, 30);
    final c = await AppController.create(
      store: MemoryAppStore(AppSnapshot(
        user: UserProfile(id: 'u', nickname: 't', age: 0, createdAt: now),
        discoveredIds: {for (final g in allGames.take(150)) g.id},
      )),
      clock: () => now,
    );
    expect(c.pickNextGame().isSecret, isTrue);
    final reward = await c.recordPlay(allGames.last, const GameResult(won: true, stars: 3, score: 10, seconds: 30));
    expect(reward.isNew, isTrue);
    expect(c.isComplete, isTrue);
    expect(c.starsOf(allGames.last), 3);
    expect(c.coins, greaterThan(0));
  });

  test('watch time starts a new daily total after midnight', () async {
    var now = DateTime(2026, 10, 1, 23, 59);
    final store = MemoryAppStore(AppSnapshot(
      todayWatchSeconds: 45,
      statsDate: '2026-10-1',
    ));
    final controller = await AppController.create(store: store, clock: () => now);

    now = DateTime(2026, 10, 2, 0, 1);
    await controller.recordPlay(
      allGames.first,
      const GameResult(won: true, stars: 1, score: 0, seconds: 8),
    );

    expect(store.snapshot.todayWatchSeconds, 8);
    expect(store.snapshot.statsDate, '2026-10-2');
    expect(store.snapshot.totalWatchSeconds, 8);
    controller.dispose();
  });

  testWidgets('first launch registers and shows home', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    L10n.code = 'en';
    final c = await AppController.create(store: MemoryAppStore(AppSnapshot(arcade: const ArcadeState(language: 'en'))));
    await tester.pumpWidget(HitasuraAdsApp(controller: c, rewardedAdService: _NoAds()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('START'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'Tester');
    await tester.tap(find.text('START').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.isRegistered, isTrue);
    expect(find.text('WATCH NEXT AD'), findsWidgets);
    // Let periodic timers settle before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
