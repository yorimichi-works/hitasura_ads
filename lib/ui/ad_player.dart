import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../arcade/engine/audio.dart';
import '../arcade/engine/game.dart';
import '../arcade/engine/game_view.dart';
import '../arcade/engine/sfx.dart';
import '../arcade/registry.dart';
import '../arcade/spec.dart';
import '../l10n/l10n.dart';
import '../state/app_controller.dart';
import 'kit.dart';
import 'reveal.dart';
import 'thumbs.dart';

enum _Phase { roulette, title, playing, endcard }

/// Full-screen "ad break": roulette → title card → game → fake store page.
///
/// [nextGame] is asked for another ad when the player taps NEXT AD; it
/// returns null when there are no tickets left.
class AdPlayerScreen extends StatefulWidget {
  const AdPlayerScreen({
    super.key,
    required this.controller,
    required this.first,
    this.nextGame,
    this.roulette = true,
    this.replayMode = false,
  });

  final AppController controller;
  final GameSpec first;
  final Future<GameSpec?> Function()? nextGame;
  final bool roulette;
  final bool replayMode;

  @override
  State<AdPlayerScreen> createState() => _AdPlayerScreenState();
}

class _AdPlayerScreenState extends State<AdPlayerScreen> with TickerProviderStateMixin {
  late GameSpec _spec = widget.first;
  _Phase _phase = _Phase.roulette;
  GameSession? _session;
  GameResult? _result;
  PlayReward? _reward;
  bool _replay = false;
  bool _nextBusy = false;
  int _playSerial = 0;
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..addListener(() => setState(() {}));
  Timer? _timer;
  final _rng = math.Random();

  AppController get c => widget.controller;
  GameText get _text => L10n.game(_spec.no);

  @override
  void initState() {
    super.initState();
    _replay = widget.replayMode;
    _start(roulette: widget.roulette);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    ArcadeAudio.instance.setBgmVolume(1);
    ArcadeAudio.instance.bgm('menu');
    super.dispose();
  }

  void _start({required bool roulette}) {
    _timer?.cancel();
    _result = null;
    _reward = null;
    ArcadeAudio.instance.setBgmVolume(1);
    if (roulette) {
      _phase = _Phase.roulette;
      ArcadeAudio.instance.stopBgm(fade: .2);
      ArcadeAudio.instance.sfx(Sfx.spin, volume: .8);
      _anim
        ..duration = const Duration(milliseconds: 1500)
        ..forward(from: 0);
      _timer = Timer(const Duration(milliseconds: 1550), () {
        ArcadeAudio.instance.sfx(Sfx.reelStop);
        if (_spec.rarity == Rarity.superRare || _spec.rarity == Rarity.secret) {
          ArcadeAudio.instance.sfx(Sfx.rarityUp);
        }
        _showTitle();
      });
    } else {
      _showTitle();
    }
    setState(() {});
  }

  void _showTitle() {
    if (!mounted) return;
    _phase = _Phase.title;
    ArcadeAudio.instance.sfx(Sfx.whoosh);
    _anim
      ..duration = const Duration(milliseconds: 1300)
      ..forward(from: 0);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1400), _play);
    setState(() {});
  }

  void _play() {
    if (!mounted || _phase == _Phase.playing) return;
    _timer?.cancel();
    final serial = ++_playSerial;
    ArcadeAudio.instance.bgm(_spec.bgm);
    final text = _text;
    _session = GameSession(
      game: _spec.create(),
      duration: _spec.duration,
      verb: text.verb,
      hook: text.hook,
      accent: K.category(_spec.cat) == Colors.white ? K.yellow : Color.lerp(K.category(_spec.cat), Colors.white, .15)!,
      onFinished: (r) => _finished(r, serial),
    );
    _phase = _Phase.playing;
    setState(() {});
  }

  Future<void> _finished(GameResult r, int serial) async {
    if (serial != _playSerial || !mounted) return;
    _result = r;
    final reward = await c.recordPlay(_spec, r, discover: !_replay);
    if (!mounted) return;
    _reward = reward;
    ArcadeAudio.instance.setBgmVolume(.45);
    if (reward.isNew) {
      await showDiscoveryReveal(context, _spec);
      if (!mounted) return;
    }
    _phase = _Phase.endcard;
    _anim
      ..duration = const Duration(milliseconds: 1600)
      ..forward(from: 0);
    ArcadeAudio.instance.sfx(r.won ? Sfx.coins : Sfx.pop, volume: .7);
    if (reward.leveledUp) {
      Future.delayed(const Duration(milliseconds: 900), () => ArcadeAudio.instance.sfx(Sfx.levelup));
    }
    setState(() {});
  }

  Future<void> _next() async {
    if (_nextBusy) return;
    _nextBusy = true;
    try {
      final g = await widget.nextGame?.call();
      if (!mounted) return;
      if (g == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.ui('out_of_tickets'))));
        return;
      }
      _spec = g;
      _replay = false;
      _start(roulette: true);
    } finally {
      _nextBusy = false;
    }
  }

  void _again() {
    _replay = true;
    _start(roulette: false);
  }

  void _install() {
    ArcadeAudio.instance.sfx(Sfx.ding);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(L10n.ui('installed_joke'), style: K.t(15)),
        backgroundColor: K.ink,
        duration: const Duration(milliseconds: 1400),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != _Phase.playing,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: switch (_phase) {
          _Phase.roulette => _roulette(),
          _Phase.title => _titleCard(),
          _Phase.playing => _gameView(),
          _Phase.endcard => _endCard(),
        },
      ),
    );
  }

  // --------------------------------------------------------------- roulette

  Widget _roulette() {
    final t = _anim.value;
    // decelerating index through random games, landing on _spec
    final eased = 1 - math.pow(1 - t, 3).toDouble();
    final steps = (eased * 22).floor();
    final landed = t >= .98;
    final shown = landed ? _spec : allGames[(steps * 37 + _spec.no * 11) % 150];
    final col = K.category(shown.cat);
    final text = L10n.game(shown.no);
    return NightBackground(
      hue: steps * 25.0,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              InkText(L10n.ui('now_showing'), size: 20, color: K.cyan),
              const SizedBox(height: 18),
              // TV set
              Transform.rotate(
                angle: landed ? 0 : math.sin(t * 60) * .02,
                child: Sticker(
                  color: const Color(0xFF3A2C5E),
                  radius: 28,
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    width: 280,
                    height: 190,
                    decoration: BoxDecoration(
                      color: Color.lerp(col, K.ink, .35),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: K.ink, width: 3),
                    ),
                    child: Stack(children: [
                      if (!landed) Positioned.fill(child: CustomPaint(painter: _StaticPainter(_rng, t))),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Pill('${L10n.ui('channel')} ${shown.no.toString().padLeft(3, '0')}', color: col),
                            const SizedBox(height: 10),
                            InkText(text.title, size: 26, maxLines: 2),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (landed) RarityBadge(_spec.rarity, label: L10n.ui('rarity_${_spec.rarity.name}'), size: 14),
            ]),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ title card

  Widget _titleCard() {
    final t = _anim.value;
    final col = K.category(_spec.cat);
    final text = _text;
    final pop = Curves.elasticOut.transform((t * 1.6).clamp(0, 1));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _play,
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(colors: [Color.lerp(col, Colors.white, .15)!, Color.lerp(col, K.ink, .7)!], radius: 1.1),
        ),
        child: SafeArea(
          child: Stack(children: [
            Positioned(top: 12, left: 12, child: Pill(L10n.ui('sponsored'), color: K.yellow)),
            Positioned(
                top: 12,
                right: 12,
                child: Pill(L10n.ui('cat_${_spec.cat.name}'), color: Colors.white)),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Transform.scale(
                    scale: .4 + .6 * pop,
                    child: Transform.rotate(angle: -.05, child: InkText(text.title, size: 40, color: Colors.white, maxLines: 3)),
                  ),
                  const SizedBox(height: 20),
                  Opacity(
                    opacity: ((t - .25) * 3).clamp(0, 1),
                    child: Sticker(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(text.hook, textAlign: TextAlign.center, style: K.t(17, color: K.ink)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  RarityBadge(_spec.rarity, label: '${_spec.label}  ${L10n.ui('rarity_${_spec.rarity.name}')}', size: 13),
                ]),
              ),
            ),
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Center(child: Text(L10n.ui('tap_skip'), style: K.t(13, color: Colors.white70))),
            ),
          ]),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ game

  Widget _gameView() {
    final s = _session!;
    return ColoredBox(
      color: s.game.backdrop,
      child: SafeArea(
        child: GameView(
          key: ValueKey(_playSerial),
          session: s,
          backdrop: _Letterbox(color: s.game.backdrop, accent: K.category(_spec.cat)),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- endcard

  Widget _endCard() {
    final r = _result!;
    final reward = _reward!;
    final t = _anim.value;
    final text = _text;
    final col = K.category(_spec.cat);
    final reviewNo = 1 + (_spec.no * 7 + c.playsOf(_spec)) % 8;
    final reviews = 12000 + (_spec.no * 7919) % 980000;
    final rating = 4.5 + (_spec.no % 5) / 10;
    double stagger(int i) => Curves.easeOutBack.transform(((t - i * .08) * 3).clamp(0.0, 1.0));
    Widget slide(int i, Widget w) =>
        Opacity(opacity: ((t - i * .08) * 3).clamp(0, 1), child: Transform.translate(offset: Offset(0, 30 * (1 - stagger(i))), child: w));
    return NightBackground(
      hue: (_spec.no * 23) % 360.0,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 24), children: [
              // result banner
              slide(
                  0,
                  Center(
                    child: Transform.rotate(
                      angle: -.03,
                      child: InkText(r.won ? L10n.ui('result_win') : L10n.ui('result_lose'),
                          size: 30, color: r.won ? K.yellow : const Color(0xFFC9C3F0)),
                    ),
                  )),
              const SizedBox(height: 8),
              slide(
                  1,
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Transform.scale(
                          scale: Curves.elasticOut.transform(((t - .15 - i * .1) * 2.5).clamp(0, 1)),
                          child: Icon(Icons.star_rounded,
                              size: i == 1 ? 58 : 46, color: i < r.stars ? K.yellow : Colors.white24,
                              shadows: const [Shadow(color: K.ink, offset: Offset(0, 3))]),
                        ),
                      ),
                  ])),
              const SizedBox(height: 10),
              // store listing
              slide(
                  2,
                  Sticker(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        SizedBox(
                          width: 70,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14), border: Border.all(color: K.ink, width: 3)),
                            child: GameThumb(spec: _spec, unlocked: true, radius: 11),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(text.title, style: K.t(19, color: K.ink, weight: FontWeight.w900), maxLines: 2),
                            const SizedBox(height: 4),
                            Row(children: [
                              Pill(L10n.ui('cat_${_spec.cat.name}'), color: col, size: 10),
                              const SizedBox(width: 6),
                              RarityBadge(_spec.rarity, label: L10n.ui('rarity_${_spec.rarity.name}'), size: 10),
                            ]),
                            const SizedBox(height: 6),
                            Row(children: [
                              Text(rating.toStringAsFixed(1), style: K.t(15, color: K.ink, weight: FontWeight.w900)),
                              const SizedBox(width: 4),
                              for (var i = 0; i < 5; i++) Icon(Icons.star_rounded, size: 16, color: i < 4 ? K.orange : K.orange.withValues(alpha: .5)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(L10n.ui('reviews', {'n': _fmt(reviews)}),
                                    style: K.t(11, color: K.ink.withValues(alpha: .6)), overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Text(L10n.ui('review_$reviewNo'),
                          style: K.t(13, color: K.ink.withValues(alpha: .75), weight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      ChunkyButton(
                        onTap: _install,
                        color: K.lime,
                        height: 46,
                        sound: Sfx.pop,
                        child: Text(L10n.ui('install'), style: K.t(18, color: K.ink, weight: FontWeight.w900)),
                      ),
                    ]),
                  )),
              const SizedBox(height: 14),
              // rewards
              slide(
                  3,
                  Sticker(
                    color: const Color(0xFF2B1F55),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                        _rewardChip(Icons.monetization_on_rounded, K.yellow, '+${(reward.coins * M.clamp01((t - .3) * 2)).round()}'),
                        _rewardChip(Icons.bolt_rounded, K.cyan, '+${(reward.xp * M.clamp01((t - .35) * 2)).round()} ${L10n.ui('xp')}'),
                        if (r.score > 0) _rewardChip(Icons.emoji_events_rounded, K.pink, '${r.score}'),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Text('${L10n.ui('level')} ${c.level}', style: K.t(14, weight: FontWeight.w900)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: c.arcade.levelProgress,
                              minHeight: 10,
                              backgroundColor: Colors.white12,
                              color: K.cyan,
                            ),
                          ),
                        ),
                      ]),
                      if (reward.leveledUp && t > .55) ...[
                        const SizedBox(height: 8),
                        Pulse(child: InkText(L10n.ui('level_up'), size: 22, color: K.lime)),
                      ],
                    ]),
                  )),
              const SizedBox(height: 16),
              slide(
                  4,
                  Column(children: [
                    if (widget.nextGame != null)
                      Pulse(
                        amount: .025,
                        child: ChunkyButton(
                          onTap: _next,
                          color: K.pink,
                          height: 62,
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                            const SizedBox(width: 6),
                            Flexible(child: InkText(L10n.ui('next_ad'), size: 22, shadow: false)),
                            const SizedBox(width: 8),
                            Pill('${c.searchEnergy}', icon: Icons.confirmation_number_rounded, color: K.yellow, size: 12),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: ChunkyButton(
                          onTap: _again,
                          color: K.cyan,
                          height: 50,
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.replay_rounded, color: K.ink),
                            const SizedBox(width: 6),
                            Flexible(child: Text(L10n.ui('replay'), style: K.t(16, color: K.ink, weight: FontWeight.w900))),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChunkyButton(
                          onTap: () => Navigator.of(context).pop(),
                          color: Colors.white,
                          height: 50,
                          sound: Sfx.back,
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.home_rounded, color: K.ink),
                            const SizedBox(width: 6),
                            Flexible(child: Text(L10n.ui('home'), style: K.t(16, color: K.ink, weight: FontWeight.w900))),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(L10n.ui('free_replay'), style: K.t(11, color: Colors.white54)),
                  ])),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _rewardChip(IconData icon, Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 4),
        Text(label, style: K.t(18, color: color, weight: FontWeight.w900)),
      ]);

  static String _fmt(int n) {
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}

class _StaticPainter extends CustomPainter {
  _StaticPainter(this.rng, this.t);
  final math.Random rng;
  final double t;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint();
    for (var i = 0; i < 260; i++) {
      final v = rng.nextInt(255);
      p.color = Color.fromARGB(90, v, v, v);
      c.drawRect(Rect.fromLTWH(rng.nextDouble() * s.width, rng.nextDouble() * s.height, 3 + rng.nextDouble() * 8, 2), p);
    }
    p.color = Colors.white.withValues(alpha: .08);
    final y = (t * 900) % s.height;
    c.drawRect(Rect.fromLTWH(0, y, s.width, 14), p);
  }

  @override
  bool shouldRepaint(covariant _StaticPainter old) => true;
}

/// Decorative area around the 9:16 game on wide screens.
class _Letterbox extends StatelessWidget {
  const _Letterbox({required this.color, required this.accent});
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(colors: [Color.lerp(color, accent, .25)!, Color.lerp(color, Colors.black, .5)!], radius: 1.2),
        ),
      );
}
