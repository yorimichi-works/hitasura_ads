import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/l10n/l10n.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';
import 'package:hitasura_ads/state/app_controller.dart';
import 'package:hitasura_ads/ui/settings.dart';

class SettingsAds extends DebugRewardedAdService {
  bool required = true;
  bool busy = false;
  int opened = 0;
  @override
  bool get privacyOptionsRequired => required;
  @override
  bool get privacyBusy => busy;
  @override
  Future<void> showPrivacyOptions() async {
    opened++;
  }

  void refresh() => notifyListeners();
}

void main() {
  testWidgets(
    'Settings preserves restore and required privacy entry, hides unneeded entry',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await AppController.create(
        store: MemoryAppStore(
          const AppSnapshot(arcade: ArcadeState(language: 'en')),
        ),
      );
      final ads = SettingsAds();
      L10n.code = 'en';
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(controller: c, rewardedAdService: ads),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(find.text('Ad privacy choices'), findsOneWidget);
      await tester.tap(find.text('Ad privacy choices'));
      expect(ads.opened, 1);
      ads.busy = true;
      ads.refresh();
      await tester.pump();
      await tester.tap(find.text('Ad privacy choices'));
      expect(ads.opened, 1);
      ads.required = false;
      ads.refresh();
      await tester.pump();
      expect(find.text('Ad privacy choices'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      ads.dispose();
      c.dispose();
    },
  );

  testWidgets(
    'missing production URL gives an error without leaving Settings',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await AppController.create(
        store: MemoryAppStore(
          const AppSnapshot(arcade: ArcadeState(language: 'en')),
        ),
      );
      L10n.code = 'en';
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Privacy policy'));
      await tester.pump();
      expect(
        find.text(
          'This link is currently unavailable. Please try again later.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
