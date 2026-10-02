// Debug harness inputs travel through Flutter's actual hit-test/Listener path.
// This file never sets a game's score, clock, random seed, win state, or physics.
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:hitasura_ads/arcade/engine/game.dart';

class CapturePointerStep {
  const CapturePointerStep(this.at, this.kind, this.point, this.pointer);
  final double at;
  final String kind;
  final Offset point;
  final int pointer;
}

List<CapturePointerStep> captureInputPlan(int gameNo) {
  final steps = <CapturePointerStep>[];
  void tap(double t, double x, int pointer) {
    steps.add(CapturePointerStep(t, 'down', Offset(x, 430), pointer));
    steps.add(CapturePointerStep(t + .08, 'up', Offset(x, 430), pointer));
  }

  if (gameNo == 3) {
    // Select a real tube and pour into an initially empty tube, twice, then
    // try another real move. Invalid moves keep their ordinary game feedback.
    tap(.8, 44, 31);
    tap(1.5, 248, 32);
    tap(3.3, 112, 33);
    tap(4.0, 316, 34);
    tap(6.0, 180, 35);
    tap(6.7, 248, 36);
  } else if (gameNo == 8) {
    // Slow visible drags/drop attempts; outcomes stay random and unmodified.
    for (final (t, x, pointer) in [(1.0, 90.0, 81), (5.3, 260.0, 82)]) {
      steps.add(CapturePointerStep(t, 'down', const Offset(180, 170), pointer));
      for (var i = 1; i <= 10; i++) {
        steps.add(
          CapturePointerStep(
            t + i * .05,
            'move',
            Offset(180 + (x - 180) * i / 10, 170),
            pointer,
          ),
        );
      }
      steps.add(CapturePointerStep(t + .6, 'up', Offset(x, 170), pointer));
    }
  } else {
    throw ArgumentError('Only G003 and G008 have reviewed capture inputs');
  }
  return steps;
}

Offset captureGlobalPoint(RenderBox box, Offset virtualPoint) {
  final scale = math.min(
    box.size.width / GameHost.w,
    box.size.height / GameHost.h,
  );
  final origin = Offset(
    (box.size.width - GameHost.w * scale) / 2,
    (box.size.height - GameHost.h * scale) / 2,
  );
  return box.localToGlobal(origin + virtualPoint * scale);
}

void dispatchCapturePointer(
  CapturePointerStep step,
  Offset globalPoint,
  Duration timestamp, {
  Offset delta = Offset.zero,
}) {
  final PointerEvent event = switch (step.kind) {
    'down' => PointerDownEvent(
      pointer: step.pointer,
      position: globalPoint,
      timeStamp: timestamp,
      kind: PointerDeviceKind.touch,
    ),
    'move' => PointerMoveEvent(
      pointer: step.pointer,
      position: globalPoint,
      delta: delta,
      timeStamp: timestamp,
      kind: PointerDeviceKind.touch,
    ),
    'up' => PointerUpEvent(
      pointer: step.pointer,
      position: globalPoint,
      timeStamp: timestamp,
      kind: PointerDeviceKind.touch,
    ),
    _ => throw ArgumentError('Invalid pointer step'),
  };
  GestureBinding.instance.handlePointerEvent(event);
}
