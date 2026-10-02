import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/app_licenses.dart';
import 'package:hitasura_ads/state/app_controller.dart';
import 'package:hitasura_ads/ui/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'full font license and attribution are packaged and registered once',
    () async {
      final license = await rootBundle.loadString(
        'assets/fonts/KosugiMaru-LICENSE.txt',
      );
      final attribution = await rootBundle.loadString(
        'assets/fonts/KosugiMaru-ATTRIBUTION.txt',
      );
      expect(license, contains('Apache License'));
      expect(license, contains('END OF TERMS AND CONDITIONS'));
      expect(license.length, greaterThan(10000));
      expect(
        attribution,
        contains('Copyright 2010 The Kosugi Maru Project Authors'),
      );
      expect(attribution, contains('MOTOYA'));
      registerAppLicenses();
      registerAppLicenses();
      final entries = await LicenseRegistry.licenses
          .where((entry) => entry.packages.contains('Kosugi Maru'))
          .toList();
      expect(entries, hasLength(1));
      final text = entries.single.paragraphs
          .map((paragraph) => paragraph.text)
          .join('\n');
      expect(text, contains('Copyright 2010'));
      expect(text, contains('END OF TERMS AND CONDITIONS'));
    },
  );

  testWidgets('Settings has an accessible standard acknowledgements page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await AppController.create(
      store: MemoryAppStore(
        const AppSnapshot(arcade: ArcadeState(language: 'en')),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('Licenses'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Licenses'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Licenses').hitTestable());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LicensePage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
