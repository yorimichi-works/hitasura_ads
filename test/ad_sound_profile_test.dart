import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/ad_catalog.dart';
import 'package:hitasura_ads/models/ad_sound_profile.dart';
import 'package:hitasura_ads/widgets/ad_experience_host.dart';
import 'package:hitasura_ads/widgets/ad_mini_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AdCatalog catalog;

  setUpAll(() async {
    catalog = await AdCatalog.load();
  });

  test('all 151 ads have complete contextual sound profiles', () {
    expect(catalog.all, hasLength(151));

    final profiles = catalog.all.map(AdSoundProfile.forAd).toList();
    for (var index = 0; index < profiles.length; index++) {
      final ad = catalog.all[index];
      final profile = profiles[index];
      expect(profile.reason, isNotEmpty, reason: ad.id);
      for (final event in AdSoundEvent.values) {
        final asset = profile.assetFor(event);
        expect(
          asset,
          startsWith('soundeffect_lab/'),
          reason: '${ad.id} $event',
        );
        expect(
          File('assets/audio/$asset').existsSync(),
          isTrue,
          reason: '${ad.id} $event -> $asset',
        );
      }
    }

    expect(profiles.map((profile) => profile.interaction).toSet().length, 15);
    expect(profiles.map((profile) => profile.success).toSet().length, 8);
    expect(profiles.map((profile) => profile.failure).toSet().length, 5);
  });

  test('high-context ads use matching sounds', () {
    expect(
      AdSoundProfile.forAd(catalog['AD_016']).interaction,
      endsWith('sword-slash2.mp3'),
    );
    expect(
      AdSoundProfile.forAd(catalog['AD_032']).failure,
      endsWith('magic-flame1.mp3'),
    );
    expect(
      AdSoundProfile.forAd(catalog['AD_059']).interaction,
      endsWith('dog1.mp3'),
    );
    expect(
      AdSoundProfile.forAd(catalog['AD_061']).interaction,
      endsWith('brake1.mp3'),
    );
    expect(
      AdSoundProfile.forAd(catalog['AD_092']).interaction,
      endsWith('dj-scratch1.mp3'),
    );
    expect(
      AdSoundProfile.forAd(catalog['AD_147']).success,
      endsWith('treasure-chest1.mp3'),
    );
  });

  testWidgets('playable reports interaction and success sound events', (
    tester,
  ) async {
    final events = <AdSoundEvent>[];
    final ad = catalog['AD_081'];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 600,
            child: AdMiniGame(
              ad: ad,
              seed: 1,
              onInteraction: () {},
              onSoundEvent: events.add,
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 4; i++) {
      if (find.byKey(const Key('mini-game-tap-target')).evaluate().isEmpty) {
        break;
      }
      await tester.tap(find.byKey(const Key('mini-game-tap-target')));
      await tester.pump();
    }

    expect(events.first, AdSoundEvent.interaction);
    expect(events.last, AdSoundEvent.success);
  });

  testWidgets('editorial experiences report progress and completion sounds', (
    tester,
  ) async {
    final events = <AdSoundEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 600,
            child: AdExperienceHost(
              ad: catalog['AD_001'],
              onInteraction: () {},
              onSoundEvent: events.add,
            ),
          ),
        ),
      ),
    );

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.byKey(Key('experience-step-$step')));
      await tester.pump();
    }

    expect(events, const [
      AdSoundEvent.interaction,
      AdSoundEvent.interaction,
      AdSoundEvent.success,
    ]);
  });
}
