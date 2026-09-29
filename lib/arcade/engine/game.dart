import 'dart:math' as math;
import 'dart:ui';

import 'fx.dart';

/// Result of one play of a mini-game.
class GameResult {
  const GameResult({required this.won, required this.stars, required this.score, required this.seconds});
  final bool won;
  final int stars; // 0..3 (0 when lost)
  final int score;
  final double seconds;
}

/// Services a running mini-game can use. Implemented by the game runtime.
///
/// The virtual canvas is ALWAYS 360 x 640 (portrait, like a phone ad).
abstract class GameHost {
  static const double w = 360;
  static const double h = 640;
  static const Offset center = Offset(180, 320);
  static const Rect bounds = Rect.fromLTWH(0, 0, 360, 640);

  /// Seconds since gameplay started (after the intro).
  double get time;

  /// Total play time for this game (seconds). The HUD shows a timer bar.
  double get duration;
  double get timeLeft => math.max(0, duration - time);

  /// Difficulty multiplier. 1.0 normally; grows (up to ~1.8) in RUSH mode.
  /// Scale enemy speeds / spawn rates / reaction windows with it.
  double get speed;

  /// Deterministic per-play random source.
  math.Random get rng;

  /// Particle / popup system (rendered on top of the game automatically).
  Fx get fx;

  /// True once win() or lose() was called.
  bool get finished;

  /// Is a pointer currently held down, and where (virtual coords).
  bool get pointerDown;
  Offset get pointer;

  /// Current score (shown in HUD if [showScore]).
  int score = 0;
  bool showScore = false;

  /// Ends the game as a success. [stars] 1..3 for quality of the win.
  void win({int stars = 3});

  /// Ends the game as a failure.
  void lose();

  /// Adds to [score]; with [at] also pops a "+n" text there.
  void addScore(int n, [Offset? at]);

  /// Plays a sound effect by name (use `Sfx.*` constants). [rate] pitches
  /// it (1.0 = normal; 1.5 higher) — great for combo chains.
  void sfx(String name, {double volume = 1, double rate = 1});

  /// Music volume 0..1 (e.g. 0 to "stop the music" in musical chairs).
  void setMusicVolume(double v);

  /// Camera shake in pixels.
  void shake(double intensity, [double seconds = .25]);

  /// Full-screen color flash.
  void flash(Color color, [double seconds = .18]);

  /// Freezes game updates for a few frames (impact feel). Rendering continues.
  void hitStop(double seconds);

  /// Haptic-like screen "pulse" zoom (1.0 = none). Brief punch-in.
  void punch([double amount = .04]);

  /// Localized short word. [key] is a lowercase snake_case id,
  /// [english] the English text used as fallback and translation source.
  /// Example: `host.tr('fuel', 'Fuel')`.
  String tr(String key, String english);

  /// Current language code ('en', 'ja', 'ar', ...).
  String get lang;
}

/// Base class of every mini-game.
///
/// Lifecycle: [host] is assigned → [init] → then every frame [update] (dt in
/// seconds, already clamped and scaled for hit-stop) and [render]. Input
/// callbacks receive virtual coordinates (360x640 space). When the timer
/// reaches zero [onTimeUp] is called once (default: lose).
///
/// After win()/lose() the game keeps receiving update/render for ~1.2s so
/// ending animations can play; input is no longer delivered.
abstract class MiniGame {
  late GameHost host;

  /// Called once before the first frame. Build your level here.
  void init() {}

  void update(double dt);

  void render(Canvas c);

  void onDown(Offset p) {}
  void onMove(Offset p) {}
  void onUp(Offset p) {}

  /// Keyboard (desktop): 'left', 'right', 'up', 'down', 'action'.
  void onKey(String key, bool down) {}

  /// Timer ran out. Survival-style games should call host.win() here.
  void onTimeUp() => host.lose();

  /// Background color outside the 9:16 area on wide screens.
  Color get backdrop => const Color(0xFF15102A);

  /// Hide the default timer bar (e.g. games with their own timer UI).
  bool get showTimer => true;

  /// Convenience accessors.
  math.Random get rng => host.rng;
  double rand(double a, double b) => a + host.rng.nextDouble() * (b - a);
  int randInt(int n) => host.rng.nextInt(n);
  T pick<T>(List<T> list) => list[host.rng.nextInt(list.length)];
  bool chance(double p) => host.rng.nextDouble() < p;
}

/// Small math helpers used across games.
abstract final class M {
  static double lerp(double a, double b, double t) => a + (b - a) * t;
  static double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  /// Frame-rate independent smoothing: approach [target] with [rate] 1/s.
  static double approach(double cur, double target, double rate, double dt) =>
      target + (cur - target) * math.exp(-rate * dt);
  static Offset approachO(Offset cur, Offset target, double rate, double dt) {
    final k = math.exp(-rate * dt);
    return target + (cur - target) * k;
  }

  static double easeOutBack(double t) {
    const c1 = 1.70158, c3 = c1 + 1;
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
  }

  static double easeOutElastic(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return math.pow(2, -10 * t) * math.sin((t * 10 - .75) * (2 * math.pi / 3)) + 1;
  }

  static double easeInOut(double t) => t < .5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
  static double easeOut(double t) => 1 - (1 - t) * (1 - t);

  /// Sine wobble helper 0..1.
  static double wave(double t, [double hz = 1]) => .5 + .5 * math.sin(t * hz * math.pi * 2);

  /// Distance from point [p] to segment [a]-[b].
  static double distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  /// Formats big numbers: 1234 → 1.2K, 5e6 → 5.0M, 3e9 → 3.0B.
  static String big(num v) {
    final a = v.abs();
    if (a >= 1e12) return '${(v / 1e12).toStringAsFixed(1)}T';
    if (a >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (a >= 1e4) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.round().toString();
  }
}
