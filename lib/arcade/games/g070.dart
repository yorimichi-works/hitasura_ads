import '../engine/engine.dart';

/// No.070 Dodge It! — three bullies hurl dodgeballs down 3 lanes. Tap a lane
/// (or swipe) to hop out of the way. Survive to win.
class G070 extends MiniGame {
  double _t = 0;
  int _lane = 1;
  double _px = 180;
  double _hop = 0;
  final List<_Throw> _throws = [];
  final List<double> _schedule = [];
  int _next = 0;
  bool _hit = false;
  double _hitT = 0;
  Offset _flyVel = Offset.zero;
  Offset _flyPos = Offset.zero;
  int _nice = 0;
  Offset? _swipeFrom;
  final List<double> _windUp = [0, 0, 0];
  final List<Color> _shirts = [Pal.red, Pal.purple, Pal.orange];

  static const _laneX = [80.0, 180.0, 280.0];
  static const _playerY = 560.0;
  static const _srcY = 196.0;

  double get _tel => .55 / pow(host.speed, .6);
  double get _flight => .6 / pow(host.speed, .5);

  @override
  void init() {
    _shirts.shuffle(host.rng);
    var t = .25;
    final gap = .78 / pow(host.speed, .6);
    while (t + _tel + _flight < host.duration - .15) {
      _schedule.add(t);
      t += gap * rand(.85, 1.15);
    }
  }

  double _srcX(int lane) => 180 + (_laneX[lane] - 180) * .5;

  @override
  void update(double dt) {
    _t += dt;
    _hop = M.approach(_hop, 0, 9, dt);
    if (_hit) {
      _hitT += dt;
      _flyVel += Offset(0, 1400 * dt);
      _flyPos += _flyVel * dt;
    } else {
      _px = M.approach(_px, _laneX[_lane], 22, dt);
    }
    // spawn telegraphs
    while (_next < _schedule.length && host.time >= _schedule[_next] && !host.finished) {
      _next++;
      final targets = <int>{};
      targets.add(chance(.65) ? _lane : randInt(3));
      if (host.speed >= 1.3 && chance(.4)) {
        int other;
        do {
          other = randInt(3);
        } while (targets.contains(other));
        targets.add(other);
      }
      for (final tl in targets) {
        final from = chance(.6) ? tl : randInt(3);
        _throws.add(_Throw(from, tl));
        host.sfx(Sfx.beep, rate: 1.4, volume: .5);
      }
    }
    for (final th in _throws) {
      th.t += dt;
      if (th.t < _tel) {
        _windUp[th.from] = th.t / _tel;
        continue;
      }
      if (!th.thrown) {
        th.thrown = true;
        _windUp[th.from] = 0;
        host.sfx(Sfx.throwIt, rate: rand(.9, 1.2));
      }
      final k = (th.t - _tel) / _flight;
      th.k = k;
      if (!th.checked && k >= .92 && !_hit && !host.finished) {
        th.checked = true;
        final dx = (_bx(th) - _px).abs();
        if (dx < 50) {
          _knockOut(th);
        } else if ((_laneX[th.to] - _px).abs() < 110) {
          _nice++;
          host.sfx(Sfx.whoosh, rate: 1.2 + _nice * .05);
          host.sfx(Sfx.combo, rate: 1 + _nice * .1, volume: .6);
          host.fx.pop(_nice > 2 ? host.tr('great', 'GREAT!') : host.tr('nice', 'NICE!'), Offset(_px, _playerY - 150),
              color: Pal.lime, size: 26 + min(_nice, 4) * 3.0);
          host.addScore(10 * _nice);
        }
      }
    }
    _throws.removeWhere((th) => th.k > 1.6);
  }

  double _bx(_Throw th) => M.lerp(_srcX(th.from), _laneX[th.to], M.clamp01(th.k));

  void _knockOut(_Throw th) {
    _hit = true;
    th.bounced = true;
    _flyPos = Offset(_px, _playerY);
    _flyVel = Offset(_px < 180 ? 220 : -220, -900);
    host.sfx(Sfx.hitHeavy);
    host.sfx(Sfx.boing, rate: .8);
    host.shake(14);
    host.flash(Pal.white, .15);
    host.hitStop(.12);
    host.punch(.08);
    host.fx.burst(Offset(_px, _playerY - 70), Pal.yellow, count: 14, speed: 280, shape: PartShape.star);
    host.fx.pop(host.tr('out', 'OUT!'), const Offset(180, 330), color: Pal.red, size: 48);
    host.lose();
  }

  void _moveTo(int l) {
    if (_hit || host.finished) return;
    l = l.clamp(0, 2);
    if (l == _lane) return;
    _lane = l;
    _hop = 1;
    host.sfx(Sfx.jump, rate: 1.3, volume: .6);
    host.fx.smoke(Offset(_px, _playerY), count: 3, size: 10);
  }

  @override
  void onDown(Offset p) {
    _swipeFrom = p;
    _moveTo(p.dx < 130 ? 0 : (p.dx < 230 ? 1 : 2));
  }

  @override
  void onMove(Offset p) {
    final s = _swipeFrom;
    if (s == null) return;
    final dx = p.dx - s.dx;
    if (dx.abs() > 50) {
      _swipeFrom = p;
      _moveTo(_lane + (dx > 0 ? 1 : -1));
    }
  }

  @override
  void onUp(Offset p) => _swipeFrom = null;

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'left') _moveTo(_lane - 1);
    if (key == 'right') _moveTo(_lane + 1);
  }

  @override
  void onTimeUp() {
    host.sfx(Sfx.cheer);
    host.fx.pop(host.tr('win', 'WIN!'), const Offset(180, 330), color: Pal.yellow, size: 48);
    host.win(stars: _nice >= 2 ? 3 : 2);
  }

  @override
  void render(Canvas c) {
    // gym back wall
    D.gradientBg(c, const [Color(0xFF3D6BFF), Color(0xFF8C4DFF), Color(0xFFFF5FC8)]);
    D.rays(c, const Offset(180, 200), 700, const Color(0x1FFFFFFF), count: 18, t: _t * .35);
    // pennant banners
    for (var i = 0; i < 9; i++) {
      final x = 10.0 + i * 40;
      final p = Path()
        ..moveTo(x, 44)
        ..lineTo(x + 34, 44)
        ..lineTo(x + 17, 74)
        ..close();
      c.drawPath(p, D.fill(Pal.candy[i % 8]));
      c.drawPath(p, D.stroke(Pal.ink, 2.5));
    }
    D.line(c, const Offset(0, 44), const Offset(360, 44), Pal.ink, 3);
    // floor trapezoid
    final floor = Path()
      ..moveTo(95, 180)
      ..lineTo(265, 180)
      ..lineTo(420, 640)
      ..lineTo(-60, 640)
      ..close();
    c.drawPath(floor, Paint()
      ..shader = const LinearGradient(
              colors: [Color(0xFFD9954A), Color(0xFFF2C07A)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
          .createShader(const Rect.fromLTWH(0, 180, 360, 460)));
    // wood planks
    for (var i = 0; i < 12; i++) {
      final x0 = 95 + i * 170 / 11;
      final x1 = -60 + i * 480 / 11;
      D.line(c, Offset(x0, 180), Offset(x1, 640), const Color(0x22000000), 2);
    }
    // lane lines
    for (final b in [130.0, 230.0]) {
      final top = 180 + (b - 180) * .5;
      D.line(c, Offset(top, 180), Offset(b + (b - 180) * .4, 640), const Color(0xAAFFFFFF), 5);
    }
    // center court line
    c.drawRect(const Rect.fromLTWH(80, 250, 200, 6), D.fill(const Color(0x88FFFFFF)));
    c.drawPath(floor, D.stroke(Pal.ink, 4));

    // telegraph targets
    for (final th in _throws) {
      if (th.k > .95) continue;
      final lx = _laneX[th.to];
      final blink = th.thrown ? 1.0 : (sin(th.t * 30) > 0 ? 1.0 : .4);
      final r = Rect.fromCenter(center: Offset(lx, _playerY + 16), width: 96, height: 30);
      c.drawOval(r, D.fill(Pal.red.withValues(alpha: .35 * blink)));
      c.drawOval(r, D.stroke(Pal.red.withValues(alpha: blink), 4));
      if (!th.thrown) {
        D.text(c, '!', Offset(lx, _playerY - 170), size: 40, color: Pal.red, stroke: Pal.ink);
      }
    }

    // throwers
    for (var i = 0; i < 3; i++) {
      final x = _srcX(i);
      final w = _windUp[i];
      D.person(c, Offset(x, 190), 70, _shirts[i],
          face: w > 0 ? Face.angry : Face.smug, armsUp: w > 0 ? 1 : 0, hair: const Color(0xFF2A1A10));
      if (w > 0) _ball(c, Offset(x - 4, 190 - 70 - 6 - w * 8), 13);
    }

    // balls in flight (far ones first)
    final flying = _throws.where((th) => th.thrown).toList()..sort((a, b) => a.k.compareTo(b.k));
    for (final th in flying) {
      final k = th.k;
      var x = _bx(th);
      var y = M.lerp(_srcY, _playerY - 60, k);
      if (k > 1) {
        if (th.bounced) {
          // bounces back up off the victim
          final b = k - 1;
          x += b * 200 * (x < 180 ? -1 : 1);
          y = _playerY - 60 - b * 500 + b * b * 700;
        } else {
          y = _playerY - 60 + (k - 1) * 400;
        }
      }
      final s = M.lerp(.45, 1.1, M.clamp01(k)) * (k > 1 ? 1 + (k - 1) * .5 : 1);
      // floor shadow
      D.shadow(c, Offset(x, M.lerp(_srcY + 4, _playerY + 18, M.clamp01(k))), 50 * s, 12 * s, .25);
      _ball(c, Offset(x, y), 26 * s, spin: th.t * 12);
      // speed lines
      if (k < 1) {
        for (var i = 1; i <= 3; i++) {
          final ky = y - i * 18 * s;
          D.line(c, Offset(x - 14 * s + i * 6, ky), Offset(x - 10 * s + i * 6, ky - 12 * s), const Color(0x88FFFFFF), 3);
        }
      }
    }

    _drawPlayer(c);

    if (host.time < 1.6 && !host.finished) {
      for (var i = 0; i < 3; i++) {
        if (i == _lane) continue;
        D.hand(c, Offset(_laneX[i], _playerY + 30), _t + i);
      }
      D.text(c, host.tr('tap', 'TAP!'), const Offset(180, 620), size: 22, stroke: Pal.ink);
    }
  }

  void _ball(Canvas c, Offset o, double r, {double spin = 0}) {
    c.drawCircle(o, r, D.fill(const Color(0xFFFF3B5C)));
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(spin);
    c.drawArc(Rect.fromCircle(center: Offset(-r * .9, 0), radius: r * .9), -.9, 1.8, false, D.stroke(const Color(0xFFB0203A), r * .12));
    c.drawArc(Rect.fromCircle(center: Offset(r * .9, 0), radius: r * .9), pi - .9, 1.8, false, D.stroke(const Color(0xFFB0203A), r * .12));
    c.restore();
    c.drawCircle(o + Offset(-r * .35, -r * .38), r * .26, D.fill(const Color(0x88FFFFFF)));
    c.drawCircle(o, r, D.stroke(Pal.ink, max(2.5, r * .14)));
  }

  void _drawPlayer(Canvas c) {
    if (_hit) {
      c.save();
      c.translate(_flyPos.dx, _flyPos.dy - 60);
      c.rotate(_hitT * 12);
      c.translate(0, 60);
      D.person(c, Offset.zero, 130, Pal.lime, face: Face.dead, hair: const Color(0xFFE0B040), armsUp: 1);
      c.restore();
      // spinning stars
      for (var i = 0; i < 3; i++) {
        final a = _t * 8 + i * 2.1;
        D.star(c, _flyPos + Offset(cos(a) * 40, -140 + sin(a) * 10), 9, Pal.yellow, border: Pal.ink);
      }
      return;
    }
    final danger = _throws.any((th) => !th.checked && th.t > _tel * .3 && (_laneX[th.to] - _px).abs() < 50);
    final won = host.finished;
    final y = _playerY - sin(_hop * pi) * 26;
    D.shadow(c, Offset(_px, _playerY + 4), 70, 14, .3);
    final sq = 1 + _hop * .15;
    c.save();
    c.translate(_px, y);
    c.scale(1 / sq, sq);
    D.person(c, Offset.zero, 130, Pal.lime,
        face: won ? Face.happy : (danger ? Face.shocked : Face.neutral),
        hair: const Color(0xFFE0B040),
        armsUp: won ? 1 : (danger ? .6 : 0),
        running: _hop > .1,
        run: _t * 20);
    c.restore();
    if (danger && !won) {
      // sweat drops
      c.drawCircle(Offset(_px + 30, y - 120 + (_t * 50) % 14), 5, D.fill(const Color(0xFF7FD3FF)));
    }
  }
}

class _Throw {
  _Throw(this.from, this.to);
  final int from;
  final int to;
  double t = 0;
  double k = 0;
  bool thrown = false;
  bool checked = false;
  bool bounced = false;
}
