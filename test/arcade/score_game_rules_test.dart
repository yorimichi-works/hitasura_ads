import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/arcade/engine/fx.dart';
import 'package:hitasura_ads/arcade/engine/game.dart';
import 'package:hitasura_ads/arcade/games/g114.dart';

class _Host extends GameHost {
  _Host(int seed) : rng = Random(seed) {
    fx = Fx(rng);
  }
  @override
  final Random rng;
  @override
  late final Fx fx;
  @override
  double time = 0;
  @override
  double get duration => 30;
  @override
  double get speed => 1;
  @override
  bool finished = false;
  bool won = false;
  final gains = <int>[];
  @override
  bool get pointerDown => false;
  @override
  Offset get pointer => Offset.zero;
  @override
  String get lang => 'en';
  @override
  void win({int stars = 3}) { finished = true; won = true; }
  @override
  void lose() { finished = true; }
  @override
  void addScore(int n, [Offset? at]) { gains.add(n); score += n; }
  @override
  void sfx(String name, {double volume = 1, double rate = 1}) {}
  @override
  void setMusicVolume(double v) {}
  @override
  void shake(double v, [double seconds = .25]) {}
  @override
  void flash(Color color, [double seconds = .18]) {}
  @override
  void hitStop(double seconds) {}
  @override
  void punch([double amount = .04]) {}
  @override
  String tr(String key, String english) => english;
}

void _advance(G114 game, _Host host, double seconds) {
  const dt = .01;
  for (var i = 0; i < (seconds / dt).round(); i++) {
    host.time += dt;
    game.update(dt);
    host.fx.update(dt);
  }
}

void _attempt(G114 game, _Host host, double hold) {
  game.onDown(Offset.zero);
  _advance(game, host, hold);
  game.onUp(Offset.zero);
  _advance(game, host, 3.6);
}

void main() {
  test('wheel misses preserve earned score and exhaust only the three attempts', () {
    final host = _Host(1);
    final game = G114()..host = host;
    game.init();
    _attempt(game, host, .30);
    final earned = host.score;
    expect(earned, greaterThan(0));
    expect(earned, lessThan(100));
    expect(host.finished, isFalse);
    _attempt(game, host, .70);
    expect(host.score, earned);
    expect(host.finished, isFalse);
    _attempt(game, host, .70);
    expect(host.score, earned);
    expect(host.finished, isTrue);
    expect(host.won, isFalse);
    expect(host.gains, [earned, 0, 0]);
    _attempt(game, host, .45);
    expect(host.gains, [earned, 0, 0]);
  });

  test('the same wheel timing gives the same score regardless of random seed', () {
    for (final seed in [1, 2, 20, 999]) {
      final host = _Host(seed);
      final game = G114()..host = host;
      game.init();
      _attempt(game, host, .45);
      expect(host.gains, [100]);
      expect(host.score, 100);
      expect(host.won, isTrue);
    }
  });
}
