import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/arcade/registry.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/l10n/l10n.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';
import 'package:hitasura_ads/state/app_controller.dart';
import 'package:hitasura_ads/ui/home.dart';

class NoNetworkAds extends DebugRewardedAdService {
  @override
  Future<void> preparePrivacy() async {}
}

void main() {
  test('unspaced collection fractions retain numeric order under RTL', () {
    for (final prefix in ['', 'المجموعة ']) {
      final text = '${prefix}40/151';
      final painter = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 20)),
        textDirection: TextDirection.rtl,
      )..layout();
      final offset = prefix.length;
      final found = painter
          .getBoxesForSelection(
            TextSelection(baseOffset: offset, extentOffset: offset + 2),
          )
          .single;
      final total = painter
          .getBoxesForSelection(
            TextSelection(baseOffset: offset + 3, extentOffset: offset + 6),
          )
          .single;
      expect(found.left, lessThan(total.left));
      painter.dispose();
    }
  });
  for (final code in ['ar', 'ur', 'fa']) {
    testWidgets('$code home counters keep discovered before total', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final previousCode = L10n.code;
      addTearDown(() => L10n.code = previousCode);
      L10n.code = code;
      final controller = await AppController.create(
        store: MemoryAppStore(
          AppSnapshot(
            discoveredIds: {for (final game in allGames.take(40)) game.id},
            soundEffectsEnabled: false,
            arcade: ArcadeState(language: code),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: HomeScreen(
              controller: controller,
              rewardedAdService: NoNetworkAds(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final counters = find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == '40 / 151',
      );
      // Two layers of the outlined progress count plus the collection subtitle.
      expect(counters, findsNWidgets(3));
      for (final element in counters.evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        expect(paragraph.textDirection, TextDirection.ltr);
        final discovered = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 2),
            )
            .single;
        final total = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 5, extentOffset: 8),
            )
            .single;
        expect(discovered.left, lessThan(total.left));
      }
      final heading = find.text(L10n.ui('discovered'));
      expect(heading, findsOneWidget);
      expect(Directionality.of(tester.element(heading)), TextDirection.rtl);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
