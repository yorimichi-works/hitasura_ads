import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../arcade/engine/audio.dart';
import '../arcade/engine/draw.dart';
import '../arcade/engine/game.dart';
import '../arcade/engine/game_view.dart';
import '../arcade/engine/sfx.dart';
import '../l10n/l10n.dart';
import '../state/app_controller.dart';
import 'kit.dart';

enum _RushPhase { lobby, between, playing, over }

/// AD RUSH: discovered short ads back to back, faster and faster, 4 lives.
class RushScreen extends StatefulWidget {
  const RushScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<RushScreen> createState() => _RushScreenState();
}

class _RushScreenState extends State<RushScreen> with SingleTickerProviderStateMixin {
  static const maxLives = 4;
  _RushPhase _phase = _RushPhase.lobby;
  int _stage = 0; // stages cleared
  int _lives = maxLives;
  bool? _lastWon;
  GameSession? _session;
  final _rng = math.Random();
  final List<int> _recent = [];
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
    ..addListener(() => setState(() {}));
  Timer? _timer;
  bool _newRecord = false;
  int _serial = 0;

  AppController get c => widget.controller;
  double get _speed => math.min(1.9, 1 + _stage * .07);

  @override
  void initState() {
    super.initState();
    ArcadeAudio.instance.bgm('rush');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    ArcadeAudio.instance.setBgmVolume(1);
    super.dispose();
  }

  void _start() {
    _stage = 0;
    _lives = maxLives;
    _lastWon = null;
    _newRecord = false;
    _recent.clear();
    ArcadeAudio.instance.bgm('rush');
    _between();
  }

  void _between() {
    _phase = _RushPhase.between;
    ArcadeAudio.instance.setBgmVolume(1);
    final speedUp = _stage > 0 && _stage % 4 == 0 && _lastWon == true;
    if (speedUp) ArcadeAudio.instance.sfx(Sfx.powerup);
    ArcadeAudio.instance.sfx(Sfx.count, volume: .8);
    final ms = (1500 / math.sqrt(_speed)).round() + (speedUp ? 500 : 0);
    _anim
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0);
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: ms), _playNext);
    setState(() {});
  }

  void _playNext() {
    if (!mounted) return;
    final pool = c.rushPool;
    var candidates = pool.where((g) => !_recent.contains(g.no)).toList();
    if (candidates.isEmpty) candidates = pool;
    final spec = candidates[_rng.nextInt(candidates.length)];
    _recent.add(spec.no);
    if (_recent.length > math.min(6, pool.length - 1)) _recent.removeAt(0);

    final text = L10n.game(spec.no);
    final serial = ++_serial;
    _session = GameSession(
      game: spec.create(),
      duration: spec.duration * (1 - (_speed - 1) * .3).clamp(.72, 1.0),
      verb: text.verb,
      speed: _speed,
      introSeconds: .75,
      accent: K.yellow,
      onFinished: (r) => _done(r, serial),
    );
    _phase = _RushPhase.playing;
    setState(() {});
  }

  void _done(GameResult r, int serial) {
    if (!mounted || serial != _serial) return;
    _lastWon = r.won;
    if (r.won) {
      _stage++;
    } else {
      _lives--;
      ArcadeAudio.instance.sfx(Sfx.hurt);
    }
    if (_lives <= 0) {
      _gameOver();
    } else {
      _between();
    }
  }

  Future<void> _gameOver() async {
    _phase = _RushPhase.over;
    _newRecord = _stage > c.arcade.rushBest;
    ArcadeAudio.instance.sfx(_newRecord ? Sfx.fanfare : Sfx.jingleLose);
    _anim
      ..duration = const Duration(milliseconds: 1200)
      ..forward(from: 0);
    setState(() {});
    await c.recordRush(_stage, _stage * 5);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase == _RushPhase.lobby || _phase == _RushPhase.over,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: switch (_phase) {
          _RushPhase.lobby => _lobby(),
          _RushPhase.between => _betweenView(),
          _RushPhase.playing => SafeArea(
              child: GameView(
                key: ValueKey(_serial),
                session: _session!,
                backdrop: ColoredBox(color: Color.lerp(_session!.game.backdrop, Colors.black, .3)!),
              ),
            ),
          _RushPhase.over => _overView(),
        },
      ),
    );
  }

  Widget _lobby() => NightBackground(
        hue: 320,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                  ),
                  Pulse(child: Transform.rotate(angle: -.06, child: InkText(L10n.ui('rush'), size: 56, color: K.yellow))),
                  const SizedBox(height: 16),
                  Sticker(
                    child: Column(children: [
                      Text(L10n.ui('rush_desc_long'), textAlign: TextAlign.center, style: K.t(15, color: K.ink)),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (var i = 0; i < maxLives; i++)
                          const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.favorite_rounded, color: K.red, size: 28)),
                      ]),
                      const SizedBox(height: 8),
                      Text('${L10n.ui('rush_best')}: ${c.arcade.rushBest}',
                          style: K.t(18, color: K.ink, weight: FontWeight.w900)),
                      Text('${c.rushPool.length} ${L10n.ui('discovered')}', style: K.t(12, color: K.ink.withValues(alpha: .6))),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  ChunkyButton(
                    onTap: _start,
                    color: K.red,
                    height: 70,
                    sound: Sfx.go,
                    child: InkText(L10n.ui('rush_start'), size: 28, shadow: false),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );

  Widget _betweenView() => SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          return CustomPaint(
            size: Size(box.maxWidth, box.maxHeight),
            painter: _BetweenPainter(
              t: _anim.value,
              stage: _stage + 1,
              lives: _lives,
              lastWon: _lastWon,
              speedUp: _stage > 0 && _stage % 4 == 0 && _lastWon == true,
              stageLabel: L10n.ui('rush_stage'),
              speedLabel: L10n.ui('speed_up'),
            ),
          );
        }),
      );

  Widget _overView() => NightBackground(
        hue: 200,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  InkText(L10n.ui('game_over'), size: 46, color: const Color(0xFFC9C3F0)),
                  const SizedBox(height: 18),
                  Transform.scale(
                    scale: Curves.elasticOut.transform(_anim.value),
                    child: InkText('$_stage', size: 96, color: K.yellow),
                  ),
                  Text(L10n.ui('rush_stage'), style: K.t(16)),
                  if (_newRecord) ...[
                    const SizedBox(height: 10),
                    Pulse(child: InkText(L10n.ui('new_record'), size: 28, color: K.lime)),
                  ],
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.monetization_on_rounded, color: K.yellow),
                    const SizedBox(width: 4),
                    Text('+${_stage * 5}', style: K.t(18, color: K.yellow, weight: FontWeight.w900)),
                  ]),
                  const SizedBox(height: 24),
                  ChunkyButton(
                    onTap: _start,
                    color: K.red,
                    child: InkText(L10n.ui('replay'), size: 24, shadow: false),
                  ),
                  const SizedBox(height: 10),
                  ChunkyButton(
                    onTap: () => Navigator.of(context).pop(),
                    color: Colors.white,
                    height: 50,
                    sound: Sfx.back,
                    child: Text(L10n.ui('home'), style: K.t(17, color: K.ink, weight: FontWeight.w900)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// WarioWare-style interstitial between rush stages.
class _BetweenPainter extends CustomPainter {
  _BetweenPainter({
    required this.t,
    required this.stage,
    required this.lives,
    required this.lastWon,
    required this.speedUp,
    required this.stageLabel,
    required this.speedLabel,
  });

  final double t;
  final int stage;
  final int lives;
  final bool? lastWon;
  final bool speedUp;
  final String stageLabel;
  final String speedLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 360, size.height / 640);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1B1140));
    canvas.save();
    canvas.translate((size.width - 360 * scale) / 2, (size.height - 640 * scale) / 2);
    canvas.scale(scale);
    final c = canvas;
    final hue = (stage * 47) % 360.0;
    D.gradientBg(c, [D.hsv(hue, .65, .95), D.hsv(hue + 50, .75, .55)]);
    D.rays(c, const Offset(180, 300), 600, const Color(0x22FFFFFF), count: 16, t: t * 2);
    // checker stripes scrolling
    final p = Paint()..color = const Color(0x18000000);
    for (var i = -2; i < 14; i++) {
      final x = i * 40.0 + (t * 160) % 80;
      c.drawPath(
          Path()
            ..moveTo(x, 0)
            ..lineTo(x + 20, 0)
            ..lineTo(x - 120, 640)
            ..lineTo(x - 140, 640)
            ..close(),
          p);
    }
    // mascot reacting to the last result
    final bounce = (math.sin(t * 20)).abs() * 12;
    final face = lastWon == null ? Face.happy : (lastWon! ? Face.love : Face.cry);
    D.blob(c, Offset(180, 470 - bounce), 60, lastWon == false ? Pal.sky : Pal.yellow, face: face, squash: 1 + (1 - bounce / 12) * .08);
    // stage number
    final pop = M.easeOutElastic((t * 2.2).clamp(0, 1));
    D.text(c, stageLabel, const Offset(180, 150), size: 26, color: Pal.white, stroke: Pal.ink);
    D.title(c, '$stage', const Offset(180, 240), size: 110, scale: pop, rotate: math.sin(t * 8) * .05);
    // lives
    for (var i = 0; i < 4; i++) {
      final alive = i < lives;
      final lostNow = i == lives && lastWon == false;
      final x = 108.0 + i * 48;
      final y = 580.0 + (lostNow ? t * 60 : 0);
      if (lostNow && t > .8) continue;
      D.heart(c, Offset(x, y), 36, alive ? Pal.red : (lostNow ? Pal.red.withValues(alpha: 1 - t) : const Color(0x44FFFFFF)), border: Pal.ink);
    }
    if (speedUp) {
      final s = M.easeOutBack(((t - .1) * 3).clamp(0, 1));
      c.save();
      c.translate(180, 355);
      c.rotate(-.12);
      D.rrect(c, Rect.fromCenter(center: Offset.zero, width: 300 * s, height: 56), 12, Pal.red, border: Pal.ink, borderWidth: 4);
      if (s > .5) D.text(c, speedLabel, Offset.zero, size: 30, color: Pal.yellow, stroke: Pal.ink);
      c.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BetweenPainter old) => true;
}
