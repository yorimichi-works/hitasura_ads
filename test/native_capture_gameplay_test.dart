import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/arcade/engine/audio.dart';
import 'package:hitasura_ads/arcade/engine/game.dart';
import 'package:hitasura_ads/arcade/engine/game_view.dart';
import 'package:hitasura_ads/arcade/registry.dart';

import '../tool/store_assets/capture_gameplay.dart';

class _PointerProbe extends MiniGame {
  final List<Offset> downs = [], moves = [], ups = [];
  @override
  void update(double dt) {}
  @override
  void render(Canvas canvas) {}
  @override
  void onDown(Offset point) => downs.add(point);
  @override
  void onMove(Offset point) => moves.add(point);
  @override
  void onUp(Offset point) => ups.add(point);
}

void main() {
  testWidgets('real hit-test path maps a letterboxed game and delivers input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = _PointerProbe();
    final session = GameSession(
      game: game,
      duration: 25,
      verb: '',
      introSeconds: 0,
      audio: SilentAudio(),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GameView(session: session),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(session.phase, SessionPhase.play);
    final box =
        tester.element(find.byType(GameView)).findRenderObject()! as RenderBox;
    const point = Offset(90, 170);
    final global = captureGlobalPoint(box, point);
    expect(global.dx, closeTo(359.375, .001));
    expect(global.dy, closeTo(265.625, .001));
    dispatchCapturePointer(
      const CapturePointerStep(0, 'down', point, 81),
      global,
      Duration.zero,
    );
    dispatchCapturePointer(
      const CapturePointerStep(.1, 'move', point, 81),
      global,
      const Duration(milliseconds: 100),
    );
    dispatchCapturePointer(
      const CapturePointerStep(.2, 'up', point, 81),
      global,
      const Duration(milliseconds: 200),
    );
    expect(game.downs, [point]);
    expect(game.moves, [point]);
    expect(game.ups, [point]);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'input schedules contain complete touches and remain inside real canvas',
    () {
      for (final no in [3, 8]) {
        final active = <int>{};
        var previous = -1.0;
        for (final step in captureInputPlan(no)) {
          expect(step.at, greaterThanOrEqualTo(previous));
          expect(step.at, lessThan(10));
          expect(GameHost.bounds.contains(step.point), isTrue);
          if (step.kind == 'down') {
            expect(active.add(step.pointer), isTrue);
          } else {
            expect(active.contains(step.pointer), isTrue);
            if (step.kind == 'up') active.remove(step.pointer);
          }
          previous = step.at;
        }
        expect(active, isEmpty);
      }
      expect(() => captureInputPlan(18), throwsArgumentError);
    },
  );

  test('sample real games retain active gameplay through ten-second input schedule', () {
    for (final no in [3, 8]) {
      for (final seed in [1, 2, 3]) {
        final spec = allGames.firstWhere((game) => game.no == no);
        final session = GameSession(
          game: spec.create(),
          duration: spec.duration,
          verb: '',
          seed: seed,
          audio: SilentAudio(),
          introSeconds: 0,
        );
        session.tick(1 / 60);
        final steps = captureInputPlan(no);
        var next = 0;
        for (var frame = 0; frame < 600; frame++) {
          final elapsed = frame / 60;
          while (next < steps.length && steps[next].at <= elapsed) {
            final step = steps[next++];
            switch (step.kind) {
              case 'down':
                session.down(step.point);
              case 'move':
                session.move(step.point);
              case 'up':
                session.up(step.point);
            }
          }
          session.tick(1 / 60);
          expect(
            session.phase,
            SessionPhase.play,
            reason: 'G$no seed$seed at$elapsed',
          );
        }
      }
    }
  });
}
