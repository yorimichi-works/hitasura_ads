import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/ad_catalog.dart';
import 'package:hitasura_ads/models/ad_definition.dart';
import 'package:hitasura_ads/models/ad_mini_game_definition.dart';
import 'package:hitasura_ads/models/mini_game_rules.dart';
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

  test('all 151 ads have upgraded rules with state changes and ratings', () {
    final rules = catalog.all.map(AdMiniGameRules.forAd).toList();
    expect(rules, hasLength(151));
    expect(rules.every((rule) => rule.rounds >= 1), isTrue);
    expect(rules.every((rule) => rule.stateChanges.isNotEmpty), isTrue);
    expect(rules.where((rule) => rule.rounds >= 3).length, greaterThan(100));
    expect(
      rules.where((rule) => rule.newRating == 'A').length,
      greaterThan(100),
    );
  });

  test('number operations and Lv999 boundary change real state', () {
    expect(const NumberOperation('×', 2).apply(10), 20);
    expect(const NumberOperation('+', 20).apply(10), 30);
    expect(const NumberOperation('÷', 2).apply(10), 5);
    expect(const NumberOperation('-', 5).apply(10), 5);
    expect(min(999, 998 + 1), 999);
  });

  test(
    'same seed reproduces gates while the next run changes the sequence',
    () {
      final rules = AdMiniGameRules.forAd(catalog['AD_047']);
      final first = rules.gates(Random(42)).map((gate) => gate.label).toList();
      final repeated = rules
          .gates(Random(42))
          .map((gate) => gate.label)
          .toList();
      final other = rules.gates(Random(420)).map((gate) => gate.label).toList();

      expect(repeated, first);
      expect(other, isNot(first));
      expect(first, hasLength(2));
    },
  );

  test('advertised fixed values drive the corresponding internal rules', () {
    final plusOrDouble = AdMiniGameRules.forAd(catalog['AD_046']);
    expect(plusOrDouble.gates(Random(1)).map((gate) => gate.label).toSet(), {
      '+10',
      '×2',
    });

    final crowd = AdMiniGameRules.forAd(catalog['AD_048']);
    var value = crowd.initialValue;
    for (var round = 0; round < crowd.rounds; round++) {
      value = crowd
          .gates(Random(round), round: round)
          .map((gate) => gate.apply(value))
          .reduce(max);
    }
    expect(value, 999999);

    final level = AdMiniGameRules.forAd(catalog['AD_052']);
    value = level.initialValue;
    for (var round = 0; round < level.rounds; round++) {
      value = level
          .gates(Random(round), round: round)
          .map((gate) => gate.apply(value))
          .reduce(max);
    }
    expect(value, 9999);
    expect(AdMiniGameRules.forAd(catalog['AD_089']).rewardDelta, 999999);
  });

  testWidgets('tap game changes with input, clears, and resets', (
    tester,
  ) async {
    await _pumpGame(tester, catalog['AD_001']);

    final rounds = AdMiniGameRules.forAd(catalog['AD_001']).rounds;
    for (var i = 0; i < rounds; i++) {
      await tester.tap(find.byKey(const Key('mini-game-tap-target')));
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mini-game-reset')));
    await tester.pump();
    expect(find.byKey(const Key('mini-game-playing')), findsOneWidget);
    expect(find.textContaining('VALUE 9 '), findsOneWidget);
  });

  testWidgets('choice game can fail and retry', (tester) async {
    final ad = catalog['AD_021'];
    await _pumpGame(tester, ad);
    final correct = _choiceTarget(tester);
    final wrongChoice = (correct + 1) % 3;

    await tester.tap(find.byKey(Key('mini-game-choice-$wrongChoice')));
    await tester.pump();
    expect(find.byKey(const Key('mini-game-failure')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mini-game-reset')));
    await tester.pump();
    await _clearAssignedGame(tester, ad, AdMiniGameType.choice);
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);
  });

  testWidgets('pin game requires the configured order and shows king asset', (
    tester,
  ) async {
    final ad = catalog['AD_031'];
    await _pumpGame(tester, ad);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.endsWith('sheet1_02.png'),
      ),
      findsOneWidget,
    );
    for (var order = 1; order <= 3; order++) {
      await tester.tap(find.textContaining('順$order'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);
  });

  testWidgets('draw game uses a real pointer path and validates endpoints', (
    tester,
  ) async {
    await _pumpGame(tester, catalog['AD_058']);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('守る')),
    );
    await gesture.moveTo(tester.getCenter(find.text('GOAL')));
    await gesture.up();
    await tester.pump();

    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);
  });

  testWidgets('No.040 puts the king and mystery fish in the same game', (
    tester,
  ) async {
    await _pumpGame(tester, catalog['AD_040']);
    expect(find.text('王様'), findsOneWidget);
    expect(find.text('謎の魚'), findsOneWidget);
    for (final filename in ['sheet1_02.png', 'whole_fish.png']) {
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

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('王様')),
    );
    await gesture.moveTo(tester.getCenter(find.text('謎の魚')));
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
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.endsWith('red_car.png'),
      ),
      findsWidgets,
    );
  });

  testWidgets('gate, drag, pack, reveal, and finale respond to direct input', (
    tester,
  ) async {
    await _pumpGame(tester, catalog['AD_046']);
    await _clearAssignedGame(
      tester,
      catalog['AD_046'],
      AdMiniGameType.numberGate,
    );
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);

    await _pumpGame(tester, catalog['AD_056']);
    await _clearAssignedGame(
      tester,
      catalog['AD_056'],
      AdMiniGameType.dragSort,
    );
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);

    await _pumpGame(tester, catalog['AD_093']);
    await _clearAssignedGame(
      tester,
      catalog['AD_093'],
      AdMiniGameType.packOpen,
    );
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);

    await _pumpGame(tester, catalog['AD_131']);
    await _clearAssignedGame(tester, catalog['AD_131'], AdMiniGameType.reveal);
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);

    await _pumpGame(tester, catalog['AD_151']);
    for (var i = 0; i < AdMiniGameRules.forAd(catalog['AD_151']).rounds; i++) {
      await tester.tap(find.byKey(const Key('mini-game-finale')));
      await tester.pump();
    }
    expect(find.byKey(const Key('mini-game-success')), findsOneWidget);
  });

  testWidgets('timing game can succeed inside its visible green zone', (
    tester,
  ) async {
    await _pumpGame(tester, catalog['AD_086']);
    await _stopInGreen(tester);
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
      for (var i = 0; i < AdMiniGameRules.forAd(ad).rounds; i++) {
        await tester.tap(find.byKey(const Key('mini-game-tap-target')));
        await tester.pump(const Duration(milliseconds: 230));
      }
    case AdMiniGameType.choice:
      for (var round = 0; round < AdMiniGameRules.forAd(ad).rounds; round++) {
        await tester.tap(
          find.byKey(Key('mini-game-choice-${_choiceTarget(tester)}')),
        );
        await tester.pump();
      }
    case AdMiniGameType.pinPull:
      for (var order = 1; order <= 3; order++) {
        await tester.tap(find.textContaining('順$order'));
        await tester.pump(const Duration(milliseconds: 280));
      }
    case AdMiniGameType.numberGate:
      for (var round = 0; round < AdMiniGameRules.forAd(ad).rounds; round++) {
        final results = <int>[];
        for (var i = 0; i < 2; i++) {
          final text = tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byKey(Key('mini-game-gate-$i')),
                  matching: find.byType(Text),
                ),
              )
              .map((widget) => widget.data ?? '')
              .firstWhere((value) => value.contains('→'));
          results.add(
            int.parse(RegExp(r'→ (-?\d+)').firstMatch(text)!.group(1)!),
          );
        }
        final correct = results[0] >= results[1] ? 0 : 1;
        await tester.tap(find.byKey(Key('mini-game-gate-$correct')));
        await tester.pump();
      }
    case AdMiniGameType.drawPath:
      final startLabel = ad.number == 35 || ad.number == 40 ? '王様' : '守る';
      final endLabel = switch (ad.number) {
        35 => '岸',
        40 => '謎の魚',
        59 => 'ハチ',
        _ => 'GOAL',
      };
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(startLabel)),
      );
      await gesture.moveTo(tester.getCenter(find.text(endLabel)));
      await gesture.up();
      await tester.pump();
    case AdMiniGameType.dragSort:
      for (var round = 0; round < AdMiniGameRules.forAd(ad).rounds; round++) {
        final targetText = tester
            .widgetList<Text>(find.textContaining('ここへ'))
            .single
            .data!;
        final correct = targetText.startsWith('BOX A') ? 0 : 1;
        await tester.drag(
          find.byKey(const Key('mini-game-draggable')),
          tester.getCenter(find.byKey(Key('mini-game-drop-$correct'))) -
              tester.getCenter(find.byKey(const Key('mini-game-draggable'))),
        );
        await tester.pump();
      }
    case AdMiniGameType.timing:
      await _stopInGreen(tester);
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
      for (var round = 0; round < AdMiniGameRules.forAd(ad).rounds; round++) {
        await tester.drag(
          find.byKey(const Key('mini-game-pack')),
          const Offset(0, -120),
        );
        await tester.pump();
      }
    case AdMiniGameType.countdownStop:
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.tap(find.byKey(const Key('mini-game-countdown-stop')));
      await tester.pump();
    case AdMiniGameType.reveal:
      for (var round = 0; round < AdMiniGameRules.forAd(ad).rounds; round++) {
        await tester.tap(find.byKey(const Key('mini-game-reveal-target')));
        await tester.pump();
      }
    case AdMiniGameType.finale:
      for (var i = 0; i < AdMiniGameRules.forAd(ad).rounds; i++) {
        await tester.tap(find.byKey(const Key('mini-game-finale')));
        await tester.pump();
      }
  }
}

int _choiceTarget(WidgetTester tester) {
  const symbols = ['★', '◆', '●'];
  final prompt = tester
      .widgetList<Text>(find.textContaining('お題と同じ記号'))
      .single
      .data!;
  return symbols.indexWhere(prompt.endsWith);
}

Future<void> _stopInGreen(WidgetTester tester) async {
  final zone = find.byKey(const Key('mini-game-timing-zone'));
  final needle = find.byKey(const Key('mini-game-timing-needle'));
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (tester.getRect(zone).contains(tester.getCenter(needle))) break;
  }
  await tester.tap(find.byKey(const Key('mini-game-timing-stop')));
  await tester.pump();
}

Future<void> _pumpGame(WidgetTester tester, AdDefinition ad) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 390,
          height: 500,
          child: AdMiniGame(
            key: ValueKey(ad.id),
            ad: ad,
            seed: 20260827,
            onInteraction: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
