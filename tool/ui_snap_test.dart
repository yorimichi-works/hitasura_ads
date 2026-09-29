// Screenshots of the shell UI for visual review (not part of CI).
//   flutter test tool/ui_snap_test.dart   → build/ui_snaps/*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/app.dart';
import 'package:hitasura_ads/arcade/registry.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/l10n/l10n.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';
import 'package:hitasura_ads/state/app_controller.dart';
import 'package:hitasura_ads/ui/collection.dart';

class _NoAds extends RewardedAdService {
  @override
  RewardedAdStatus get status => RewardedAdStatus.ready;
  @override
  bool get isSupported => true;
  @override
  bool get usesTestAds => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<RewardedAdResult> show({String placementName = 'reward'}) async => RewardedAdResult.unavailable;
}

final _key = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: 1);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/ui_snaps/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('ui snapshots', (tester) async {
    await tester.runAsync(() async {
      final bytes = File('assets/fonts/KosugiMaru-Regular.ttf').readAsBytesSync();
      await (FontLoader('KosugiMaru')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final lang in ['ja', 'en']) {
      L10n.code = lang;
      final now = DateTime.now();
      final c = await AppController.create(
        store: MemoryAppStore(AppSnapshot(
          user: UserProfile(id: 'u', nickname: 'ドパガキ', age: 0, createdAt: now),
          discoveredIds: {for (final g in allGames.take(40)) g.id},
          searchEnergy: 3,
          searchEnergyRecoveryAnchor: now,
          arcade: ArcadeState(language: lang, coins: 1234, xp: 900, stars: {'AD_001': 3, 'AD_004': 2}),
        )),
      );
      await tester.pumpWidget(RepaintBoundary(key: _key, child: HitasuraAdsApp(controller: c, rewardedAdService: _NoAds())));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      await _shot(tester, 'home_$lang');
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute<void>(builder: (_) => CollectionScreen(controller: c)));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      await _shot(tester, 'collection_$lang');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }
  });
}
