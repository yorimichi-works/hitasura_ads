import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'audio.dart';
import 'draw.dart';
import 'fx.dart';
import 'game.dart';
import 'sfx.dart';

/// Hooks the engine uses for localization (set by the app at startup).
abstract final class EngineText {
  static String lang = 'en';
  static String Function(String key, String english) word = (k, e) => e;

  /// UI strings used by the runtime HUD.
  static String Function(String key) ui = (k) => switch (k) {
        'clear' => 'CLEAR!!',
        'fail' => 'FAILED…',
        'ad' => 'AD',
        _ => k,
      };
}

enum SessionPhase { intro, play, ending, done }

/// Runs one mini-game: owns the clock, effects, HUD and the [GameHost] API.
class GameSession extends GameHost {
  GameSession({
    required this.game,
    required this.duration,
    required this.verb,
    this.hook = '',
    this.speed = 1,
    this.introSeconds = 1.1,
    int? seed,
    ArcadeAudio? audio,
    this.onFinished,
    this.accent = Pal.yellow,
  })  : rng = math.Random(seed ?? DateTime.now().microsecondsSinceEpoch),
        _audio = audio ?? ArcadeAudio.instance {
    fx = Fx(rng);
    game.host = this;
    game.init();
  }

  final MiniGame game;
  @override
  final double duration;
  @override
  final double speed;
  @override
  final math.Random rng;
  @override
  late final Fx fx;
  final String verb;
  final String hook;
  final double introSeconds;
  final Color accent;
  final ArcadeAudio _audio;
  void Function(GameResult result)? onFinished;

  SessionPhase phase = SessionPhase.intro;
  double _time = 0;
  double _phaseTime = 0;
  double _realTime = 0;
  bool _won = false;
  int _stars = 0;
  bool _timeUpCalled = false;
  double _shake = 0;
  double _shakeDur = 0;
  double _shakeLeft = 0;
  Color? _flashColor;
  double _flashDur = 0;
  double _flashLeft = 0;
  double _hitStop = 0;
  double _punch = 0;
  Offset _shakeOffset = Offset.zero;

  @override
  bool pointerDown = false;
  @override
  Offset pointer = Offset.zero;

  @override
  double get time => _time;
  @override
  bool get finished => phase == SessionPhase.ending || phase == SessionPhase.done;
  bool get won => _won;
  int get stars => _stars;

  @override
  String get lang => EngineText.lang;

  @override
  String tr(String key, String english) => EngineText.word(key, english);

  @override
  void win({int stars = 3}) {
    if (finished) return;
    _won = true;
    _stars = stars.clamp(1, 3);
    _enterEnding();
    sfx(Sfx.jingleWin, volume: .9);
    fx.confetti(count: 60);
  }

  @override
  void lose() {
    if (finished) return;
    _won = false;
    _stars = 0;
    _enterEnding();
    sfx(Sfx.jingleLose, volume: .9);
  }

  void _enterEnding() {
    phase = SessionPhase.ending;
    _phaseTime = 0;
    pointerDown = false;
  }

  @override
  void addScore(int n, [Offset? at]) {
    score += n;
    if (at != null) fx.pop(n >= 0 ? '+$n' : '$n', at, color: n >= 0 ? Pal.yellow : Pal.red);
  }

  @override
  void sfx(String name, {double volume = 1, double rate = 1}) => _audio.sfx(name, volume: volume, rate: rate);

  @override
  void setMusicVolume(double v) => _audio.setBgmVolume(v);

  @override
  void shake(double intensity, [double seconds = .25]) {
    if (intensity >= _shake * (_shakeLeft / math.max(_shakeDur, 1e-6))) {
      _shake = intensity;
      _shakeDur = seconds;
      _shakeLeft = seconds;
    }
  }

  @override
  void flash(Color color, [double seconds = .18]) {
    _flashColor = color;
    _flashDur = seconds;
    _flashLeft = seconds;
  }

  @override
  void hitStop(double seconds) => _hitStop = math.max(_hitStop, seconds);

  @override
  void punch([double amount = .04]) => _punch = math.max(_punch, amount);

  /// Advances the session by real elapsed [dt] seconds.
  void tick(double dt) {
    dt = dt.clamp(0, 1 / 20);
    _realTime += dt;
    _phaseTime += dt;
    // effects run in real time
    if (_shakeLeft > 0) {
      _shakeLeft -= dt;
      final k = (_shakeLeft / _shakeDur).clamp(0.0, 1.0);
      _shakeOffset = Offset((rng.nextDouble() * 2 - 1) * _shake * k, (rng.nextDouble() * 2 - 1) * _shake * k);
    } else {
      _shakeOffset = Offset.zero;
    }
    if (_flashLeft > 0) _flashLeft -= dt;
    _punch = M.approach(_punch, 0, 12, dt);

    switch (phase) {
      case SessionPhase.intro:
        if (_phaseTime >= introSeconds) {
          phase = SessionPhase.play;
          _phaseTime = 0;
          sfx(Sfx.go, volume: .7);
        }
      case SessionPhase.play:
        if (_hitStop > 0) {
          _hitStop -= dt;
        } else {
          _time += dt;
          game.update(dt);
          fx.update(dt);
        }
        if (!finished && _time >= duration && !_timeUpCalled) {
          _timeUpCalled = true;
          pointerDown = false;
          game.onTimeUp();
          if (!finished) lose();
        }
      case SessionPhase.ending:
        if (_hitStop > 0) {
          _hitStop -= dt;
        } else {
          game.update(dt);
        }
        fx.update(dt);
        if (_phaseTime >= 1.5) {
          phase = SessionPhase.done;
          onFinished?.call(GameResult(won: _won, stars: _stars, score: score, seconds: _time));
        }
      case SessionPhase.done:
        fx.update(dt);
    }
  }

  bool get acceptsInput => phase == SessionPhase.play;

  void down(Offset p) {
    if (!acceptsInput) return;
    pointerDown = true;
    pointer = p;
    game.onDown(p);
  }

  void move(Offset p) {
    if (!acceptsInput) return;
    pointer = p;
    game.onMove(p);
  }

  void up(Offset p) {
    if (!acceptsInput) return;
    pointerDown = false;
    pointer = p;
    game.onUp(p);
  }

  void key(String k, bool isDown) {
    if (!acceptsInput) return;
    game.onKey(k, isDown);
  }

  /// Renders game + effects + HUD into the 360x640 virtual space.
  void render(Canvas c, {bool hud = true}) {
    c.save();
    c.clipRect(GameHost.bounds);
    c.save();
    if (_punch > .001) {
      final s = 1 + _punch;
      c.translate(180, 320);
      c.scale(s);
      c.translate(-180, -320);
    }
    c.translate(_shakeOffset.dx, _shakeOffset.dy);
    game.render(c);
    fx.render(c);
    c.restore();
    if (_flashLeft > 0 && _flashColor != null) {
      final a = (_flashLeft / _flashDur).clamp(0.0, 1.0);
      c.drawRect(GameHost.bounds, Paint()..color = _flashColor!.withValues(alpha: _flashColor!.a * a * .8));
    }
    if (hud) _renderHud(c);
    c.restore();
  }

  void _renderHud(Canvas c) {
    // Timer bar (ad progress style)
    if (game.showTimer) {
      final t = phase == SessionPhase.intro ? 1.0 : (timeLeft / duration);
      c.drawRect(const Rect.fromLTWH(0, 0, 360, 6), Paint()..color = const Color(0x66000000));
      final col = t < .25 ? Color.lerp(Pal.red, Pal.yellow, M.wave(_realTime, 4))! : accent;
      c.drawRect(Rect.fromLTWH(0, 0, 360 * t, 6), Paint()..color = col);
    }
    // "AD" pill + countdown "close" button (can't actually close: it's the joke)
    D.rrect(c, const Rect.fromLTWH(8, 12, 34, 18), 5, const Color(0xCCFFD23F), border: Pal.ink, borderWidth: 1.5);
    D.text(c, EngineText.ui('ad'), const Offset(25, 21.5), size: 11, color: Pal.ink, weight: FontWeight.w900);
    final secs = phase == SessionPhase.intro ? duration.ceil() : timeLeft.ceil();
    D.circle(c, const Offset(338, 22), 12, const Color(0x99000000), border: const Color(0xAAFFFFFF), borderWidth: 1.5);
    if (finished) {
      D.line(c, const Offset(333, 17), const Offset(343, 27), Pal.white, 2.2);
      D.line(c, const Offset(343, 17), const Offset(333, 27), Pal.white, 2.2);
    } else {
      D.text(c, '$secs', const Offset(338, 22), size: 12, color: Pal.white);
    }
    if (showScore) {
      D.text(c, '${EngineText.word('score', 'Score')} $score', const Offset(180, 24),
          size: 18, color: Pal.white, stroke: Pal.ink);
    }

    switch (phase) {
      case SessionPhase.intro:
        _renderIntro(c);
      case SessionPhase.ending || SessionPhase.done:
        _renderEnding(c);
      case SessionPhase.play:
        if (_phaseTime < .5) {
          // verb lingers briefly as the game starts
          final a = 1 - _phaseTime / .5;
          c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
          D.title(c, verb, const Offset(180, 300), size: 52, scale: 1 + _phaseTime * .6, color: accent);
          c.restore();
        }
    }
  }

  void _renderIntro(Canvas c) {
    final t = (_phaseTime / introSeconds).clamp(0.0, 1.0);
    c.drawRect(GameHost.bounds, Paint()..color = Color.fromRGBO(10, 6, 30, .55 * (1 - t * .5)));
    D.rays(c, const Offset(180, 300), 520, const Color(0x22FFFFFF), count: 14, t: _realTime * .8);
    final s = M.easeOutElastic((_phaseTime / .5).clamp(0, 1));
    D.title(c, verb, const Offset(180, 300), size: 58, scale: s, rotate: math.sin(_realTime * 6) * .04, color: accent);
    if (hook.isNotEmpty) {
      final ht = ((_phaseTime - .15) / .3).clamp(0.0, 1.0);
      c.save();
      c.translate(0, (1 - M.easeOut(ht)) * 30);
      D.rrect(c, Rect.fromCenter(center: const Offset(180, 382), width: 320, height: 44), 14,
          Color.fromRGBO(255, 255, 255, .95 * ht),
          border: Pal.ink.withValues(alpha: ht), borderWidth: 3);
      D.text(c, hook, const Offset(180, 382),
          size: 15, color: Pal.ink.withValues(alpha: ht), maxWidth: 300, weight: FontWeight.w800);
      c.restore();
    }
  }

  void _renderEnding(Canvas c) {
    final t = _phaseTime;
    final s = t < .35 ? M.easeOutBack(t / .35) * 1.0 : 1.0;
    final label = EngineText.ui(_won ? 'clear' : 'fail');
    if (_won) {
      D.rays(c, const Offset(180, 290), 420, const Color(0x33FFE066), count: 16, t: t * 1.2);
    } else {
      c.drawRect(GameHost.bounds, Paint()..color = Color.fromRGBO(20, 0, 30, (t * .6).clamp(0, .35)));
    }
    D.title(c, label, const Offset(180, 290),
        size: 54, scale: s * (1 + .06 * math.sin(t * 10)), rotate: _won ? -.08 : .06,
        color: _won ? Pal.yellow : const Color(0xFFB8B3D6));
    if (_won && t > .3) {
      for (var i = 0; i < 3; i++) {
        final on = i < _stars;
        final st = ((t - .3 - i * .12) / .25).clamp(0.0, 1.0);
        if (st <= 0) continue;
        D.star(c, Offset(130 + i * 50.0, 352 - (i == 1 ? 10 : 0)), 20 * M.easeOutBack(st),
            on ? Pal.gold : const Color(0x55FFFFFF), border: Pal.ink);
      }
    }
  }
}

/// Widget that runs a [GameSession] fitted into any box (9:16 letterboxed).
class GameView extends StatefulWidget {
  const GameView({super.key, required this.session, this.hud = true, this.backdrop});

  final GameSession session;
  final bool hud;
  final Widget? backdrop;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _repaint = _Repaint();
  final _focus = FocusNode();
  Rect _viewport = Rect.zero;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero ? 1 / 60 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    widget.session.tick(dt);
    _repaint.ping();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  Offset _toGame(Offset local) => (local - _viewport.topLeft) / _scale;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final down = e is KeyDownEvent || e is KeyRepeatEvent;
    if (e is KeyRepeatEvent) return KeyEventResult.handled;
    final k = switch (e.logicalKey) {
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA => 'left',
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.keyD => 'right',
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => 'up',
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS => 'down',
      LogicalKeyboardKey.space || LogicalKeyboardKey.enter => 'action',
      _ => null,
    };
    if (k == null) return KeyEventResult.ignored;
    widget.session.key(k, down);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: LayoutBuilder(builder: (context, box) {
        final scale = math.min(box.maxWidth / GameHost.w, box.maxHeight / GameHost.h);
        final w = GameHost.w * scale, h = GameHost.h * scale;
        _scale = scale;
        _viewport = Rect.fromLTWH((box.maxWidth - w) / 2, (box.maxHeight - h) / 2, w, h);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => widget.session.down(_toGame(e.localPosition)),
          onPointerMove: (e) => widget.session.move(_toGame(e.localPosition)),
          onPointerUp: (e) => widget.session.up(_toGame(e.localPosition)),
          onPointerCancel: (e) => widget.session.up(_toGame(e.localPosition)),
          child: Stack(fit: StackFit.expand, children: [
            if (widget.backdrop != null) widget.backdrop!,
            CustomPaint(
              painter: _GamePainter(widget.session, _repaint, () => _viewport, () => _scale, widget.hud),
              size: Size(box.maxWidth, box.maxHeight),
            ),
          ]),
        );
      }),
    );
  }
}

class _Repaint extends ChangeNotifier {
  void ping() => notifyListeners();
}

class _GamePainter extends CustomPainter {
  _GamePainter(this.session, Listenable repaint, this.viewport, this.scale, this.hud) : super(repaint: repaint);
  final GameSession session;
  final Rect Function() viewport;
  final double Function() scale;
  final bool hud;

  @override
  void paint(Canvas canvas, Size size) {
    final vp = viewport();
    canvas.save();
    canvas.translate(vp.left, vp.top);
    canvas.scale(scale());
    session.render(canvas, hud: hud);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) => old.session != session;
}

/// Renders a still frame of [game] after simulating [seconds] without input.
/// Used for collection thumbnails. Returns null if the game throws.
Future<ui.Image?> renderGameThumbnail(MiniGame game,
    {double seconds = 1.2, int width = 180, int height = 320, double duration = 20}) async {
  try {
    final session = GameSession(
      game: game,
      duration: duration,
      verb: '',
      introSeconds: 0,
      seed: 7,
      audio: SilentAudio(),
    );
    session.tick(0.0001);
    final steps = (seconds * 30).round();
    for (var i = 0; i < steps; i++) {
      session.tick(1 / 30);
    }
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.scale(width / GameHost.w, height / GameHost.h);
    session.render(c, hud: false);
    final pic = rec.endRecording();
    final img = await pic.toImage(width, height);
    pic.dispose();
    return img;
  } catch (e, st) {
    debugPrintThumb('thumbnail failed: $e\n$st');
    return null;
  }
}

void debugPrintThumb(String s) {
  assert(() {
    // ignore: avoid_print
    print(s);
    return true;
  }());
}
