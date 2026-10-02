// Captures the production widgets at iPhone/iPad content sizes in flutter_test.
// These are Flutter-rendered previews, NOT native iOS simulator screenshots.
// flutter test tool/store_assets/localized_ui_snap_test.dart --dart-define=CAPTURE_LOCALES=en,ja
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
import 'package:hitasura_ads/ui/ad_player.dart';
import 'package:hitasura_ads/ui/collection.dart';
import 'package:hitasura_ads/ui/rush.dart';

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
  Future<RewardedAdResult> show({String placementName = 'reward'}) async =>
      RewardedAdResult.unavailable;
}

final Set<String> _loadedFonts = {};

Future<void> _fonts(String code) async {
  final fonts = <String, String>{
    'KosugiMaru': 'assets/fonts/KosugiMaru-Regular.ttf',
    'Noto Sans': '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
    if (const {'ar', 'ur', 'fa'}.contains(code))
      'Noto Sans Arabic':
          '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf',
    if (code == 'hi')
      'Noto Sans Devanagari':
          '/usr/share/fonts/truetype/noto/NotoSansDevanagari-Regular.ttf',
    if (code == 'bn')
      'Noto Sans Bengali':
          '/usr/share/fonts/truetype/noto/NotoSansBengali-Regular.ttf',
    if (code == 'th')
      'Noto Sans Thai':
          '/usr/share/fonts/truetype/noto/NotoSansThai-Regular.ttf',
    if (code == 'ko')
      'Noto Sans KR': '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    if (code == 'zh')
      'Noto Sans SC': '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    if (code == 'zh_TW')
      'Noto Sans TC': '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
  };
  for (final e in fonts.entries) {
    if (_loadedFonts.contains(e.key)) continue;
    final f = File(e.value);
    if (!f.existsSync()) throw StateError('Font required: ${e.value}');
    final bytes = f.readAsBytesSync();
    await (FontLoader(
      e.key,
    )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    _loadedFonts.add(e.key);
  }
  if (_loadedFonts.add('MaterialIcons')) {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  }
}

void main() {
  const selected = String.fromEnvironment('CAPTURE_LOCALES');
  final codes = selected.isEmpty
      ? languages.map((l) => l.code).toList()
      : selected.split(',');
  for (final code in codes) {
    for (final device in ['iphone_6_9', 'ipad_13']) {
      testWidgets(
        '$code $device production UI preview',
        (tester) async {
          final ratio = device == 'ipad_13' ? 2.0 : 3.0;
          tester.view.physicalSize = device == 'ipad_13'
              ? const Size(2048, 2732)
              : const Size(1290, 2796);
          tester.view.devicePixelRatio = ratio;
          addTearDown(tester.view.reset);
          await tester.runAsync(() => _fonts(code));
          L10n.code = code;
          final now = DateTime.now();
          final controller = await AppController.create(
            store: MemoryAppStore(
              AppSnapshot(
                user: UserProfile(
                  id: 'capture-preview',
                  nickname: 'PLAYER',
                  age: 0,
                  createdAt: now,
                ),
                discoveredIds: {for (final g in allGames.take(40)) g.id},
                soundEffectsEnabled: false,
                notificationsEnabled: false,
                searchEnergy: 5,
                searchEnergyRecoveryAnchor: now,
                arcade: ArcadeState(
                  language: code,
                  coins: 1234,
                  xp: 900,
                  stars: {'AD_001': 3, 'AD_004': 2},
                ),
              ),
            ),
          );
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: HitasuraAdsApp(
                controller: controller,
                rewardedAdService: _NoAds(),
              ),
            ),
          );
          Future<void> settle([int steps = 12]) async {
            for (var i = 0; i < steps; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
          }

          Future<void> shot(String scene) async {
            expect(
              tester.takeException(),
              isNull,
              reason: '$code $device $scene layout',
            );
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: ratio);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File(
                  'build/store_assets/flutter_previews/$code/$device/$scene.png',
                )
                ..createSync(recursive: true)
                ..writeAsBytesSync(data!.buffer.asUint8List());
              image.dispose();
            });
          }

          await settle();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 1)),
          );
          await settle();
          await shot('01_home');
          final nav = tester.state<NavigatorState>(
            find.byType(Navigator).first,
          );
          for (final scene in [
            '02_collection',
            '03_pin',
            '04_runner',
            '05_rush',
          ]) {
            final Widget page = switch (scene) {
              '02_collection' => CollectionScreen(controller: controller),
              '05_rush' => RushScreen(controller: controller),
              _ => AdPlayerScreen(
                controller: controller,
                first: allGames.firstWhere(
                  (g) => g.no == (scene == '03_pin' ? 1 : 18),
                ),
                roulette: false,
                replayMode: true,
              ),
            };
            nav.push(MaterialPageRoute<void>(builder: (_) => page));
            await settle(scene == '03_pin' || scene == '04_runner' ? 38 : 12);
            if (scene == '02_collection') {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(seconds: 2)),
              );
              await settle();
            }
            await shot(scene);
            nav.pop();
            await settle(8);
          }
          await tester.pumpWidget(const SizedBox());
          await settle();
          controller.dispose();
        },
        timeout: const Timeout(Duration(minutes: 3)),
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
}
