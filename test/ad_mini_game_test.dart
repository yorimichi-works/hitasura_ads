import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/ad_catalog.dart';
import 'package:hitasura_ads/models/ad_definition.dart';
import 'package:hitasura_ads/models/ad_mini_game_definition.dart';
import 'package:hitasura_ads/widgets/ad_mini_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AdCatalog catalog;

  setUpAll(() async {
    catalog = await AdCatalog.load();
  });

  test('all 151 ads have a playable data-driven mini game definition', () {
    final games = catalog.all.map(AdMiniGameDefinition.forAd).toList();

    expect(games, hasLength(151));
    expect(games.every((game) => game.instruction.isNotEmpty), isTrue);
    expect(games.every((game) => game.successCondition.isNotEmpty), isTrue);
    expect(games.every((game) => game.failureCondition.isNotEmpty), isTrue);
    expect(games.map((game) => game.type).toSet(), hasLength(12));
    expect(
      AdMiniGameDefinition.forAd(catalog['AD_031']).assetPath,
      'assets/images/ad_parts/sheet1/sheet1_02.png',
    );
    expect(
      AdMiniGameDefinition.forAd(catalog['AD_151']).type,
      AdMiniGameType.finale,
    );
  });

  testWidgets('tap game changes with input, clears, and resets', (
    tester,
  ) async {
    await _pumpGame(tester, catalog['AD_001']);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('mini-game-tap-target')));
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mini-game-reset')));
    await tester.pump();
    expect(find.byKey(const Key('mini-game-playing')), findsOneWidget);
  });

  testWidgets('choice game can fail and retry', (tester) async {
    final ad = catalog['AD_021'];
    await _pumpGame(tester, ad);
    final wrongChoice = ad.number.isEven ? 1 : 0;

    await tester.tap(find.byKey(Key('mini-game-choice-$wrongChoice')));
    await tester.pump();
    expect(find.byKey(const Key('mini-game-failure')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mini-game-reset')));
    await tester.pump();
    final correctChoice = ad.number.isEven ? 0 : 1;
    await tester.tap(find.byKey(Key('mini-game-choice-$correctChoice')));
    await tester.pump();
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);
  });

  testWidgets('pin game requires the configured order and shows king asset', (
    tester,
  ) async {
    final ad = catalog['AD_031'];
    await _pumpGame(tester, ad);
    final first = ad.number % 3;

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.endsWith('sheet1_02.png'),
      ),
      findsOneWidget,
    );
    for (final pin in [first, (first + 1) % 3, (first + 2) % 3]) {
      await tester.tap(find.byKey(Key('mini-game-pin-$pin')));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);
  });

  testWidgets('draw game uses a real pointer path and validates endpoints', (
    tester,
  ) async {
    await _pumpGame(tester, catalog['AD_058']);
    final area = find.byKey(const Key('mini-game-draw-area'));
    final rect = tester.getRect(area);
    final gesture = await tester.startGesture(
      Offset(rect.left + 10, rect.center.dy),
    );
    await gesture.moveTo(Offset(rect.right - 10, rect.center.dy));
    await gesture.up();
    await tester.pump();

    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);
  });

  testWidgets('game stage integrates semantic background and target images', (
    tester,
  ) async {
    await _pumpGame(tester, catalog['AD_059']);

    expect(find.byType(AdGameStage), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.endsWith(
              'sunny_grassland.jpg',
            ),
      ),
      findsOneWidget,
    );
    for (final filename in ['rescue_dog.png', 'bee_swarm.png']) {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName.endsWith(filename),
        ),
        findsOneWidget,
      );
    }

    await _pumpGame(tester, catalog['AD_061']);
    expect(find.byIcon(Icons.directions_car), findsOneWidget);
  });

  testWidgets('gate, drag, pack, reveal, and finale respond to direct input', (
    tester,
  ) async {
    await _pumpGame(tester, catalog['AD_046']);
    await tester.tap(find.byKey(const Key('mini-game-gate-0')));
    await tester.pump();
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);

    await _pumpGame(tester, catalog['AD_056']);
    await tester.drag(
      find.byKey(const Key('mini-game-draggable')),
      tester.getCenter(find.byKey(const Key('mini-game-drop-0'))) -
          tester.getCenter(find.byKey(const Key('mini-game-draggable'))),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);

    await _pumpGame(tester, catalog['AD_093']);
    await tester.drag(
      find.byKey(const Key('mini-game-pack')),
      const Offset(0, -120),
    );
    await tester.pump();
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);

    await _pumpGame(tester, catalog['AD_131']);
    await tester.tap(find.byKey(const Key('mini-game-reveal-target')));
    await tester.pump();
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);

    await _pumpGame(tester, catalog['AD_151']);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('mini-game-finale')));
      await tester.pump();
    }
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);
  });

  testWidgets('timing game can succeed inside its visible green zone', (
    tester,
  ) async {
    await _pumpGame(tester, catalog['AD_086']);
    await tester.pump(const Duration(milliseconds: 750));
    await tester.tap(find.byKey(const Key('mini-game-timing-stop')));
    await tester.pump();
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);
  });

  testWidgets('all 151 ads accept their assigned input, clear, and reset', (
    tester,
  ) async {
    for (final ad in catalog.all) {
      await _pumpGame(tester, ad);
      final type = AdMiniGameDefinition.forAd(ad).type;
      await _clearAssignedGame(tester, ad, type);
      expect(
        find.byKey(const Key('mini-game-success')),
        findsOneWidget,
        reason: '${ad.id}: ${type.name}',
      );
      await tester.tap(find.byKey(const Key('mini-game-reset')));
      await tester.pump();
      expect(
        find.byKey(const Key('mini-game-playing')),
        findsOneWidget,
        reason: '${ad.id}: reset',
      );
    }
  });
}

Future<void> _clearAssignedGame(
  WidgetTester tester,
  AdDefinition ad,
  AdMiniGameType type,
) async {
  switch (type) {
    case AdMiniGameType.tapChallenge:
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('mini-game-tap-target')));
        await tester.pump(const Duration(milliseconds: 230));
      }
    case AdMiniGameType.choice:
      final correct = ad.number.isEven ? 0 : 1;
      await tester.tap(find.byKey(Key('mini-game-choice-$correct')));
      await tester.pump();
    case AdMiniGameType.pinPull:
      final first = ad.number % 3;
      for (final pin in [first, (first + 1) % 3, (first + 2) % 3]) {
        await tester.tap(find.byKey(Key('mini-game-pin-$pin')));
        await tester.pump(const Duration(milliseconds: 280));
      }
    case AdMiniGameType.numberGate:
      final labels = ad.fixedValues.values.toSet().take(2).toList();
      while (labels.length < 2) {
        labels.add(labels.isEmpty ? '＋10' : '×2');
      }
      final correct = _gateValue(labels[0]) >= _gateValue(labels[1]) ? 0 : 1;
      await tester.tap(find.byKey(Key('mini-game-gate-$correct')));
      await tester.pump();
    case AdMiniGameType.drawPath:
      final area = find.byKey(const Key('mini-game-draw-area'));
      final rect = tester.getRect(area);
      final gesture = await tester.startGesture(
        Offset(rect.left + 8, rect.center.dy),
      );
      await gesture.moveTo(Offset(rect.right - 8, rect.center.dy));
      await gesture.up();
      await tester.pump();
    case AdMiniGameType.dragSort:
      final correct = ad.number.isEven ? 0 : 1;
      await tester.drag(
        find.byKey(const Key('mini-game-draggable')),
        tester.getCenter(find.byKey(Key('mini-game-drop-$correct'))) -
            tester.getCenter(find.byKey(const Key('mini-game-draggable'))),
      );
      await tester.pumpAndSettle();
    case AdMiniGameType.timing:
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.byKey(const Key('mini-game-timing-stop')));
      await tester.pump();
    case AdMiniGameType.scratch:
      final area = find.byKey(const Key('mini-game-scratch-area'));
      final rect = tester.getRect(area);
      for (var row = 0; row < 6; row++) {
        final y = rect.top + (row + .5) * rect.height / 6;
        final gesture = await tester.startGesture(Offset(rect.left + 2, y));
        for (var column = 1; column < 10; column++) {
          await gesture.moveTo(
            Offset(rect.left + (column + .5) * rect.width / 10, y),
          );
        }
        await gesture.up();
      }
      await tester.pump();
    case AdMiniGameType.packOpen:
      await tester.drag(
        find.byKey(const Key('mini-game-pack')),
        const Offset(0, -120),
      );
      await tester.pump();
    case AdMiniGameType.countdownStop:
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.tap(find.byKey(const Key('mini-game-countdown-stop')));
      await tester.pump();
    case AdMiniGameType.reveal:
      await tester.tap(find.byKey(const Key('mini-game-reveal-target')));
      await tester.pump();
    case AdMiniGameType.finale:
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('mini-game-finale')));
        await tester.pump();
      }
  }
}

int _gateValue(String label) {
  final number =
      int.tryParse(RegExp(r'\d+').firstMatch(label)?.group(0) ?? '0') ?? 0;
  if (label.contains('×')) return 10 * number;
  if (label.contains('÷')) return number == 0 ? 0 : 10 ~/ number;
  if (label.contains('－') || label.contains('-')) return 10 - number;
  return 10 + number;
}

Future<void> _pumpGame(WidgetTester tester, AdDefinition ad) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 390,
          height: 500,
          child: AdMiniGame(key: ValueKey(ad.id), ad: ad, onInteraction: () {}),
        ),
      ),
    ),
  );
  await tester.pump();
}
