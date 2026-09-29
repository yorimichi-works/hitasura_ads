import '../engine/engine.dart';

/// No.147 Loading... 99% — the bar races to 99% and freezes. Push the last
/// percent through 4 silly micro-tasks: hit RETRY (it dodges), SHAKE the bar,
/// DRAG the missing pixel chunk home, and swat the spinning beach ball.
class G147 extends MiniGame {
  static const _bar = Rect.fromLTWH(40, 290, 280, 38);

  double _t = 0;
  double _fill = 0; // shown 0..1 of bar (intro race)
  int _done = 0; // tasks done 0..4
  late final List<int> _order;
  double _taskT = 0;
  double _sweat = 0;
  double _barFlash = 0;
  double _winT = -1;
  double _nope = 0;

  // retry
  Offset _retry = const Offset(180, 470);
  int _retryDodges = 0;
  double _retryPress = 0;
  // shake
  int _shakes = 0;
  double _shakeDir = 0;
  double _shakeTravel = 0;
  double _barWob = 0;
  Offset? _lastMove;
  // drag chunk
  Offset _chunk = const Offset(100, 500);
  Offset _chunkV = const Offset(90, -60);
  bool _dragChunk = false;
  // spinner
  Offset _spin = const Offset(180, 480);
  Offset _spinTarget = const Offset(180, 480);
  int _spinHits = 0;
  double _spinHurt = 0;

  @override
  Color get backdrop => const Color(0xFF101830);

  @override
  void init() {
    _order = [0, 1, 2, 3]..shuffle(rng);
    _chunk = Offset(rand(70, 290), rand(420, 560));
  }

  int get _task => _done < 4 ? _order[_done] : -1;
  bool get _racing => host.time < 1.3;

  double get _pct => _racing ? _fill * 99 : 99 + _done * .25;

  void _complete() {
    _done++;
    _taskT = 0;
    _barFlash = 1;
    host.sfx(Sfx.powerup, rate: 1 + _done * .08);
    host.fx.pop('+0.25%', Offset(_bar.right - 30, _bar.top - 20), color: Pal.lime, size: 24);
    host.fx.burst(Offset(_bar.left + _bar.width * .99, _bar.center.dy), Pal.lime, count: 14, speed: 200, shape: PartShape.star);
    host.addScore(100);
    host.punch(.02);
    if (_done == 4) {
      _winT = 0;
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.explode, volume: .5);
      host.flash(Pal.white, .3);
      host.shake(8);
      for (var i = 0; i < 5; i++) {
        host.fx.burst(Offset(rand(40, 320), rand(90, 250)), pick(Pal.candy), count: 26, speed: 280, shape: PartShape.star, gravity: 120,
            colors: Pal.candy);
      }
      host.win(stars: host.time < 9 ? 3 : (host.time < 13 ? 2 : 1));
    } else {
      if (_task == 3) _spin = const Offset(180, 470);
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _taskT += dt;
    _barFlash = M.approach(_barFlash, 0, 4, dt);
    _retryPress = M.approach(_retryPress, 0, 10, dt);
    _barWob = M.approach(_barWob, 0, 5, dt);
    _spinHurt = M.approach(_spinHurt, 0, 6, dt);
    _nope = max(0, _nope - dt);
    if (_winT >= 0) _winT += dt;
    if (_racing) {
      final prev = _fill;
      final k = (host.time / 1.2).clamp(0.0, 1.0);
      _fill = M.easeOut(k) + (k < 1 ? sin(k * 30) * .01 : 0);
      _fill = _fill.clamp(0, .99);
      if ((prev * 20).floor() != (_fill * 20).floor()) host.sfx(Sfx.tick, volume: .4, rate: 1 + _fill);
      if (host.time + dt >= 1.3) host.sfx(Sfx.buzzer, volume: .5);
      return;
    }
    _sweat += dt;
    if (host.finished) return;
    switch (_task) {
      case 2:
        if (!_dragChunk) {
          _chunk += _chunkV * dt * host.speed;
          if (_chunk.dx < 30 || _chunk.dx > 330) _chunkV = Offset(-_chunkV.dx, _chunkV.dy);
          if (_chunk.dy < 390 || _chunk.dy > 590) _chunkV = Offset(_chunkV.dx, -_chunkV.dy);
          _chunk = Offset(_chunk.dx.clamp(30, 330), _chunk.dy.clamp(390, 590));
        }
      case 3:
        if ((_spin - _spinTarget).distance < 10) _spinTarget = Offset(rand(50, 310), rand(390, 590));
        _spin = M.approachO(_spin, _spinTarget, 2.2 * host.speed, dt);
    }
  }

  @override
  void onDown(Offset p) {
    _lastMove = p;
    if (_racing || host.finished) return;
    switch (_task) {
      case 0:
        if (Rect.fromCenter(center: _retry, width: 150, height: 58).contains(p)) {
          _retryPress = 1;
          if (_retryDodges < 2 && chance(.7)) {
            _retryDodges++;
            host.sfx(Sfx.boing, rate: 1.2);
            _nope = .7;
            var np = _retry;
            while ((np - _retry).distance < 110) {
              np = Offset(rand(90, 270), rand(400, 580));
            }
            _retry = np;
          } else {
            host.sfx(Sfx.click);
            _complete();
          }
        }
      case 2:
        if ((p - _chunk).distance < 38) {
          _dragChunk = true;
          host.sfx(Sfx.pickup);
        }
      case 3:
        if ((p - _spin).distance < 40) {
          _spinHits++;
          _spinHurt = 1;
          host.sfx(Sfx.slap, rate: 1 + _spinHits * .1);
          host.shake(4);
          host.fx.burst(_spin, Pal.white, count: 10, speed: 200, shape: PartShape.star);
          if (_spinHits >= 3) {
            host.sfx(Sfx.explodeSmall);
            host.fx.burst(_spin, Pal.red, count: 20, speed: 260, colors: const [Pal.red, Pal.yellow, Pal.lime, Pal.sky, Pal.purple]);
            _complete();
          } else {
            _spin = Offset(rand(50, 310), rand(390, 590));
            _spinTarget = Offset(rand(50, 310), rand(390, 590));
          }
        }
    }
  }

  @override
  void onMove(Offset p) {
    final last = _lastMove ?? p;
    _lastMove = p;
    if (_racing || host.finished) return;
    if (_task == 1) {
      final dx = p.dx - last.dx;
      if (dx.abs() > 2) {
        final dir = dx.sign;
        if (dir != _shakeDir) {
          if (_shakeTravel > 40) _shakeOnce();
          _shakeDir = dir;
          _shakeTravel = 0;
        }
        _shakeTravel += dx.abs();
      }
    } else if (_task == 2 && _dragChunk) {
      _chunk = p;
    }
  }

  void _shakeOnce() {
    _shakes++;
    _barWob = 1;
    host.sfx(Sfx.shake, volume: .6, rate: 1 + _shakes * .06);
    host.shake(3);
    host.fx.burst(Offset(_bar.right - 6, _bar.center.dy), Pal.yellow, count: 5, speed: 120, shape: PartShape.square);
    if (_shakes >= 6) _complete();
  }

  @override
  void onUp(Offset p) {
    _lastMove = null;
    if (_task == 1 && _shakeTravel > 40) _shakeOnce();
    _shakeTravel = 0;
    if (_dragChunk) {
      _dragChunk = false;
      if ((p - _slot).distance < 44) {
        _chunk = _slot;
        host.sfx(Sfx.clang, rate: 1.4);
        _complete();
      } else {
        host.sfx(Sfx.boing, volume: .5);
        _chunkV = Offset(rand(-100, 100), rand(-100, 100));
      }
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down || _racing) return;
    if (_task == 1 && (key == 'left' || key == 'right')) _shakeOnce();
    if (_task == 0 && key == 'action') onDown(_retry);
  }

  Offset get _slot => Offset(_bar.left + _bar.width * .985, _bar.center.dy);

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFF3B2A8C), Color(0xFF1E6BD0), Color(0xFF12B5C9)]);
    // drifting ghost spinners in the background
    for (var i = 0; i < 7; i++) {
      final p = Offset((i * 71 + _t * 12) % 420 - 30, 60 + (i * 97) % 560.0);
      for (var k = 0; k < 8; k++) {
        final a = k / 8 * pi * 2 + _t * 3;
        c.drawCircle(p + Offset.fromDirection(a, 14), 3, D.fill(Color.fromRGBO(255, 255, 255, .05 + k * .015)));
      }
    }
    _renderMascot(c, const Offset(180, 160));
    // percentage
    final pctStr = _winT >= 0 ? '100%' : '${_pct.toStringAsFixed(_racing ? 0 : 2)}%';
    final ps = 1 + _barFlash * .2 + (_winT >= 0 ? .2 * M.easeOutElastic(min(1, _winT * 2)) : 0);
    c.save();
    c.translate(180, 256);
    c.scale(ps);
    D.text(c, pctStr, Offset.zero, size: 46, color: _winT >= 0 ? Pal.yellow : Pal.white, stroke: Pal.ink, strokeWidth: 8);
    c.restore();
    _renderBar(c);
    // status text
    final msgs = [
      host.tr('almost', 'Almost...'),
      host.tr('please_wait', 'Please wait'),
      host.tr('dont_close', "Don't close"),
    ];
    if (_winT < 0) {
      D.text(c, _racing ? host.tr('loading', 'Loading') : msgs[(_t / 1.6).floor() % 3], const Offset(180, 354),
          size: 16, color: const Color(0xDDFFFFFF));
    }
    if (!_racing && _winT < 0) _renderTask(c);
    if (_winT >= 0) _renderWin(c);
  }

  void _renderBar(Canvas c) {
    final wob = _barWob > 0 ? sin(_t * 50) * 10 * _barWob : 0.0;
    final stuckJitter = !_racing && _winT < 0 ? sin(_t * 23) * .6 : 0.0;
    c.save();
    c.translate(180 + wob + stuckJitter, _bar.center.dy);
    c.rotate(wob * .01);
    c.translate(-180, -_bar.center.dy);
    D.rrect(c, _bar.inflate(5), 24, Pal.ink);
    D.rrect(c, _bar, 19, const Color(0xFF2A2F4A));
    final full = _winT >= 0 ? 1.0 : (_racing ? _fill : .97 + _done * .0);
    final w = _bar.width * full;
    final fillR = Rect.fromLTWH(_bar.left, _bar.top, w, _bar.height);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(_bar, const Radius.circular(19)));
    c.drawRect(
        fillR,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFF3DFF9A), Color(0xFF14C9C9), Color(0xFF3FB8FF)])
              .createShader(_bar));
    // barber stripes
    for (var x = _bar.left - 40 + (_t * 40) % 24; x < _bar.left + w; x += 24) {
      c.drawPath(
          Path()
            ..moveTo(x, _bar.bottom)
            ..lineTo(x + 12, _bar.bottom)
            ..lineTo(x + 24, _bar.top)
            ..lineTo(x + 12, _bar.top)
            ..close(),
          D.fill(const Color(0x33FFFFFF)));
    }
    c.drawRect(Rect.fromLTWH(_bar.left, _bar.top + 4, w, 8), D.fill(const Color(0x44FFFFFF)));
    if (!_racing && _winT < 0) {
      // the missing last piece segments (one per task)
      for (var i = 0; i < 4; i++) {
        final seg = Rect.fromLTWH(_bar.left + _bar.width * .97 + i * 2.1, _bar.top, 2.1, _bar.height);
        if (i < _done) c.drawRect(seg, D.fill(Pal.lime));
      }
    }
    if (_barFlash > 0) c.drawRect(_bar, D.fill(Color.fromRGBO(255, 255, 255, .6 * _barFlash)));
    c.restore();
    c.restore();
  }

  void _renderMascot(Canvas c, Offset o) {
    final panic = !_racing && _winT < 0;
    final flip = _winT >= 0 ? min(1.0, _winT * 2) * pi * 2 : 0.0;
    c.save();
    c.translate(o.dx, o.dy + (panic ? sin(_t * 20) * 1.5 : 0));
    c.rotate(flip + (panic ? sin(_t * 3) * .08 : 0));
    // glass
    final glass = Path()
      ..moveTo(-40, -52)
      ..lineTo(40, -52)
      ..quadraticBezierTo(40, -10, 6, 0)
      ..quadraticBezierTo(40, 10, 40, 52)
      ..lineTo(-40, 52)
      ..quadraticBezierTo(-40, 10, -6, 0)
      ..quadraticBezierTo(-40, -10, -40, -52)
      ..close();
    c.drawPath(glass, D.fill(const Color(0xCCE8F7FF)));
    // sand: top drains / bottom fills with _pct
    final k = (_pct / 100).clamp(0.0, 1.0);
    c.save();
    c.clipPath(glass);
    c.drawRect(Rect.fromLTRB(-40, -40 + k * 38, 40, 0), D.fill(const Color(0xFFFFC857)));
    c.drawRect(Rect.fromLTRB(-40, 52 - k * 40, 40, 52), D.fill(const Color(0xFFFFC857)));
    if (k < 1) c.drawRect(const Rect.fromLTRB(-2, 0, 2, 50), D.fill(const Color(0xFFFFC857)));
    c.restore();
    c.drawPath(glass, D.stroke(Pal.ink, 4));
    // caps
    D.rrect(c, const Rect.fromLTWH(-50, -64, 100, 14), 6, const Color(0xFFA0643A), border: Pal.ink, borderWidth: 3);
    D.rrect(c, const Rect.fromLTWH(-50, 50, 100, 14), 6, const Color(0xFFA0643A), border: Pal.ink, borderWidth: 3);
    // face
    final f = _winT >= 0 ? Face.love : (panic ? (_sweat > 6 ? Face.cry : Face.shocked) : Face.happy);
    D.face(c, const Offset(0, -26), 26, f);
    c.restore();
    if (panic) {
      for (var i = 0; i < 2; i++) {
        final ph = (_t * 1.4 + i * .5) % 1;
        final p = o + Offset(48 + i * 10.0, -40 + ph * 40);
        c.drawPath(
            Path()
              ..moveTo(p.dx, p.dy - 9)
              ..quadraticBezierTo(p.dx + 7, p.dy, p.dx, p.dy + 5)
              ..quadraticBezierTo(p.dx - 7, p.dy, p.dx, p.dy - 9),
            D.fill(Color.fromRGBO(127, 211, 255, 1 - ph)));
      }
    }
  }

  void _renderTask(Canvas c) {
    // task card
    const card = Rect.fromLTWH(20, 380, 320, 228);
    D.rrect(c, card, 22, const Color(0x33FFFFFF), border: const Color(0x55FFFFFF), borderWidth: 2);
    // progress pips
    for (var i = 0; i < 4; i++) {
      D.circle(c, Offset(150 + i * 20.0, 596), 6, i < _done ? Pal.lime : const Color(0x55FFFFFF), border: Pal.ink, borderWidth: 2);
    }
    switch (_task) {
      case 0:
        final s = 1 - _retryPress * .1 + sin(_t * 6) * .03;
        c.save();
        c.translate(_retry.dx, _retry.dy);
        c.scale(s);
        D.button(c, Rect.fromCenter(center: Offset.zero, width: 150, height: 54), host.tr('retry', 'RETRY'),
            color: Pal.orange, fontSize: 22);
        c.restore();
        if (_nope > 0) {
          D.text(c, host.tr('nope', 'NOPE!'), _retry + Offset(0, -46 - (1 - _nope) * 20), size: 22, color: Pal.red, stroke: Pal.white);
        }
        if (_taskT < 1.6) D.hand(c, _retry + const Offset(20, 10), _t, size: 38);
      case 1:
        D.text(c, host.tr('shake', 'SHAKE!'), const Offset(180, 420), size: 30, color: Pal.yellow, stroke: Pal.ink);
        final sway = sin(_t * 8) * 60;
        D.arrow(c, Offset(180 + sway, 500), const Offset(1, 0), 90, Pal.yellow, width: 14);
        D.arrow(c, Offset(180 + sway, 540), const Offset(-1, 0), 90, Pal.yellow, width: 14);
        D.hand(c, Offset(180 + sway, 470), _t, size: 36);
        D.bar(c, const Rect.fromLTWH(90, 568, 180, 14), _shakes / 6, Pal.yellow, border: Pal.ink);
      case 2:
        // empty slot marker
        final sp = _slot;
        final a = M.wave(_t, 2);
        c.drawRect(Rect.fromCenter(center: sp, width: 12, height: 34), D.stroke(Color.fromRGBO(255, 255, 0, .5 + .5 * a), 2));
        D.text(c, host.tr('drag', 'DRAG!'), const Offset(180, 404), size: 22, color: Pal.yellow, stroke: Pal.ink);
        // the chunk
        c.save();
        c.translate(_chunk.dx, _chunk.dy);
        c.rotate(_dragChunk ? 0 : sin(_t * 4) * .3);
        final s = _dragChunk ? 1.3 : 1.0;
        c.scale(s);
        D.rrect(c, const Rect.fromLTWH(-15, -18, 30, 36), 6, Pal.lime, border: Pal.ink, borderWidth: 3);
        D.face(c, const Offset(0, 2), 12, _dragChunk ? Face.happy : Face.smug);
        c.restore();
        if (!_dragChunk) {
          final hp = Offset.lerp(_chunk, sp, (_taskT * .7) % 1)!;
          if (_taskT < 3) D.hand(c, hp, _t, size: 34);
        }
      case 3:
        D.text(c, host.tr('tap', 'TAP!'), const Offset(180, 404), size: 22, color: Pal.yellow, stroke: Pal.ink);
        final r = 30 * (1 + _spinHurt * .3);
        const cols = [Pal.red, Pal.orange, Pal.yellow, Pal.lime, Pal.sky, Pal.purple];
        for (var i = 0; i < 6; i++) {
          c.drawArc(Rect.fromCircle(center: _spin, radius: r), i / 6 * pi * 2 + _t * 9, pi / 3 + .02, true, D.fill(cols[i]));
        }
        c.drawCircle(_spin, r, D.stroke(Pal.ink, 3));
        c.drawOval(Rect.fromCenter(center: _spin + Offset(-r * .35, -r * .4), width: r * .6, height: r * .35), D.fill(const Color(0x88FFFFFF)));
        D.face(c, _spin + const Offset(0, 4), r * .6, _spinHurt > .2 ? Face.dead : Face.angry, blush: false);
        for (var i = 0; i < 3; i++) {
          D.circle(c, Offset(160 + i * 20.0, 572), 6, i < _spinHits ? Pal.red : const Color(0x55FFFFFF), border: Pal.ink, borderWidth: 2);
        }
    }
  }

  void _renderWin(Canvas c) {
    D.rays(c, const Offset(180, 256), 500, const Color(0x22FFFFFF), count: 16, t: _t);
    if (_winT > .9) {
      final k = ((_winT - .9) / .3).clamp(0.0, 1.0);
      c.save();
      c.translate(180, 470);
      c.scale(M.easeOutBack(k));
      D.rrect(c, const Rect.fromLTWH(-130, -40, 260, 80), 16, Pal.white, border: Pal.ink, borderWidth: 3);
      D.text(c, '${host.tr('loading', 'Loading')} 2/2', const Offset(0, -16), size: 18, color: Pal.ink);
      D.bar(c, const Rect.fromLTWH(-110, 4, 220, 18), ((_winT - 1.1) * .05).clamp(0, 1), Pal.sky, border: Pal.ink);
      D.text(c, '0%', const Offset(0, 13), size: 12, color: Pal.ink);
      c.restore();
    }
  }
}
