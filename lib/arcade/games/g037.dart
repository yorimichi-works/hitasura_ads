import '../engine/engine.dart';

/// No.037 Parking Lot Tycoon — top-down lot. Draw a path from the car at the
/// gate to a free spot (Flight-Control style); the car drives it. Don't draw
/// through other cars — CRASH! Parked cars pay on arrival, then leave and pay
/// the parking fee. Earn the goal before time runs out.
class G037 extends MiniGame {
  static const _goal = 1200;
  static const _gate = Offset(52, 520);
  static const _spotW = 54.0;
  static const _spotH = 86.0;
  static const _carR = 21.0;
  static const _cols = [Pal.red, Pal.sky, Pal.yellow, Pal.lime, Pal.pink, Pal.orange, Pal.purple, Pal.white];

  final List<_Spot> _spots = [];
  final List<_Car> _cars = [];
  _Car? _drawing;
  final List<Offset> _path = [];
  double _nextCarT = .1;
  double _gateArm = 0;
  double _t = 0;
  double _money = 0;
  double _shown = 0;
  double _bump = 0;
  int _crashes = 0;
  int _parked = 0;
  int _combo = 0;
  bool _won = false;

  @override
  void init() {
    for (var i = 0; i < 5; i++) {
      _spots.add(_Spot(Rect.fromLTWH(24 + i * (_spotW + 4), 100, _spotW, _spotH), true));
    }
    for (var i = 0; i < 5; i++) {
      _spots.add(_Spot(Rect.fromLTWH(24 + i * (_spotW + 4), 292, _spotW, _spotH), false));
    }
  }

  _Car? get _frontCar {
    for (final c in _cars) {
      if (c.state == _CarState.queue) return c;
    }
    return null;
  }

  @override
  void update(double dt) {
    _t += dt;
    _bump = M.approach(_bump, 0, 8, dt);
    _shown = M.approach(_shown, _money, 7, dt);

    // queue feeding: keep one car waiting at the gate (+ one behind)
    final queued = _cars.where((c) => c.state == _CarState.queue).length;
    if (!host.finished && queued < 2) {
      _nextCarT -= dt;
      if (_nextCarT <= 0) {
        _cars.add(_Car(pick(_cols), const Offset(52, 700))..heading = 0);
        _nextCarT = .35;
      }
    }
    var qi = 0;
    for (final car in _cars) {
      if (car.state != _CarState.queue) continue;
      final target = qi == 0 ? _gate : _gate + Offset(0, 74.0 * qi);
      car.pos = M.approachO(car.pos, target, 5, dt);
      qi++;
    }
    final gateBusy = _cars.any((c) => c.state == _CarState.drive && (c.pos - _gate).distance < 60);
    _gateArm = M.approach(_gateArm, gateBusy ? 1 : 0, 8, dt);

    final speed = 190 * host.speed;
    for (final car in _cars) {
      car.flash = M.approach(car.flash, 0, 6, dt);
      car.squash = M.approach(car.squash, 0, 8, dt);
      switch (car.state) {
        case _CarState.drive:
        case _CarState.leave:
          var move = speed * dt * (car.state == _CarState.leave ? 1.1 : 1);
          while (move > 0 && car.path.isNotEmpty) {
            final d = car.path.first - car.pos;
            final dist = d.distance;
            if (dist <= move) {
              car.pos = car.path.removeAt(0);
              move -= dist;
            } else {
              car.pos += d / dist * move;
              move = 0;
              car.heading = _approachAngle(car.heading, atan2(d.dx, -d.dy), 14, dt);
            }
          }
          if (car.path.isEmpty) _arrive(car);
        case _CarState.snap:
          final s = car.spot!;
          car.pos = M.approachO(car.pos, s.rect.center, 10, dt);
          car.heading = _approachAngle(car.heading, s.top ? 0 : pi, 10, dt);
          if ((car.pos - s.rect.center).distance < 1.5) {
            car.state = _CarState.parked;
            car.stay = rand(2.8, 4.2) / host.speed;
            car.squash = 1;
          }
        case _CarState.parked:
          car.stay -= dt;
          if (car.stay <= 0 && !host.finished) _startLeaving(car);
        case _CarState.crashed:
          car.spinT -= dt;
          car.heading += car.spinV * dt;
          car.spinV *= .9;
          if (car.spinT <= 0) car.state = _CarState.idle;
        default:
          break;
      }
    }
    // collisions: driving cars vs anything not leaving
    for (final a in _cars) {
      if (a.state != _CarState.drive) continue;
      for (final b in _cars) {
        if (identical(a, b) || b.state == _CarState.leave || b.state == _CarState.queue) continue;
        if (b.state == _CarState.gone) continue;
        if ((a.pos - b.pos).distance < _carR * 2 - 4) {
          _crash(a, b);
          break;
        }
      }
    }
    _cars.removeWhere((c) => c.state == _CarState.gone);
  }

  static double _approachAngle(double cur, double target, double rate, double dt) {
    var d = target - cur;
    while (d > pi) {
      d -= 2 * pi;
    }
    while (d < -pi) {
      d += 2 * pi;
    }
    return cur + d * (1 - exp(-rate * dt));
  }

  void _arrive(_Car car) {
    if (car.state == _CarState.leave) {
      car.state = _CarState.gone;
      return;
    }
    final s = car.target;
    car.target = null;
    if (s != null && s.car == null || s != null && identical(s.car, car)) {
      final off = (car.pos - s.rect.center).distance;
      s.car = car;
      car.spot = s;
      car.state = _CarState.snap;
      _parked++;
      _combo++;
      final bonus = (max(0.0, 1 - off / 40) * 50).round();
      final pay = 100 + bonus;
      host.sfx(Sfx.stamp, rate: 1.2);
      host.sfx(Sfx.coin, rate: 1 + min(_combo, 8) * .06);
      host.fx.burst(s.rect.center, Pal.lime, count: 12, speed: 200, shape: PartShape.star);
      if (bonus > 35) {
        host.fx.pop(host.tr('perfect', 'PERFECT!'), s.rect.center + const Offset(0, -56), color: Pal.lime, size: 22);
      }
      if (_combo >= 3) {
        host.fx.pop('${host.tr('combo', 'COMBO')} x$_combo', s.rect.center + const Offset(0, 50), color: Pal.pink, size: 20);
      }
      _earn(pay, s.rect.center);
    } else {
      car.state = _CarState.idle;
      host.sfx(Sfx.tap, volume: .4);
    }
  }

  void _startLeaving(_Car car) {
    final s = car.spot!;
    s.car = null;
    car.spot = null;
    car.state = _CarState.leave;
    final aisleY = s.top ? 238.0 : 440.0;
    car.path
      ..clear()
      ..add(Offset(s.rect.center.dx, aisleY))
      ..add(Offset(332, aisleY))
      ..add(const Offset(332, 520))
      ..add(const Offset(332, 700));
    host.sfx(Sfx.engine, volume: .4);
    _earn(100, s.rect.center, fee: true);
  }

  void _earn(int v, Offset at, {bool fee = false}) {
    _money += v;
    _bump = 1;
    host.addScore(v);
    host.sfx(Sfx.cash, volume: fee ? .7 : .5);
    host.fx.coins(at, count: fee ? 10 : 6, speed: 300);
    host.fx.pop('+$v', at + const Offset(0, -26), color: Pal.gold, size: fee ? 26 : 22);
    if (_money >= _goal && !_won && !host.finished) {
      _won = true;
      host.fx.confetti();
      host.sfx(Sfx.fanfare);
      host.win(stars: _crashes == 0 && host.time < 16 ? 3 : (_crashes <= 1 ? 2 : 1));
    }
  }

  void _crash(_Car a, _Car b) {
    _crashes++;
    _combo = 0;
    final mid = (a.pos + b.pos) / 2;
    a.path.clear();
    if (a.target != null && identical(a.target!.car, a)) a.target!.car = null;
    a.target = null;
    a.state = _CarState.crashed;
    a.spinT = .7;
    a.spinV = (chance(.5) ? 1 : -1) * 9;
    final push = a.pos - b.pos;
    a.pos += push / max(push.distance, 1) * 16;
    a.flash = 1;
    b.flash = 1;
    b.squash = 1;
    _money = max(0, _money - 50);
    host.sfx(Sfx.crash);
    host.sfx(Sfx.glass, volume: .5);
    host.shake(12);
    host.hitStop(.08);
    host.flash(const Color(0x55FF3B5C));
    host.fx.burst(mid, Pal.orange, count: 22, speed: 320, colors: const [Pal.orange, Pal.yellow, Pal.red]);
    host.fx.smoke(mid, count: 10, color: const Color(0xCC555566), size: 18);
    host.fx.pop(host.tr('crash', 'CRASH!'), mid + const Offset(0, -40), color: Pal.red, size: 34);
    host.fx.pop('-50', mid + const Offset(0, -6), color: Pal.red, size: 20);
    if (_crashes >= 3 && !host.finished) {
      host.sfx(Sfx.jingleLose, volume: .6);
      host.lose();
    }
  }

  _Spot? _spotAt(Offset p) {
    for (final s in _spots) {
      if (s.rect.inflate(6).contains(p)) return s;
    }
    return null;
  }

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    _Car? best;
    var bd = 40.0;
    for (final car in _cars) {
      final grabbable = car.state == _CarState.idle || identical(car, _frontCar) && (car.pos - _gate).distance < 30;
      if (!grabbable) continue;
      final d = (car.pos - p).distance;
      if (d < bd) {
        bd = d;
        best = car;
      }
    }
    if (best != null) {
      _drawing = best;
      _path
        ..clear()
        ..add(best.pos);
      best.flash = .5;
      host.sfx(Sfx.select, volume: .6);
    }
  }

  @override
  void onMove(Offset p) {
    if (_drawing == null) return;
    final q = Offset(p.dx.clamp(14.0, 346.0), p.dy.clamp(80.0, 600.0));
    if ((q - _path.last).distance >= 9 && _path.length < 200) _path.add(q);
  }

  @override
  void onUp(Offset p) {
    final car = _drawing;
    _drawing = null;
    if (car == null) return;
    if (_path.length < 3) {
      _path.clear();
      return;
    }
    final end = _path.last;
    final s = _spotAt(end);
    car.path
      ..clear()
      ..addAll(_path.skip(1));
    if (s != null && s.car == null) {
      car.target = s;
      s.car = car; // reserve
      car.path.add(s.rect.center);
    }
    car.state = _CarState.drive;
    _path.clear();
    host.sfx(Sfx.engine, volume: .5, rate: 1.2);
  }

  // ----------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    _drawLot(c);
    // path preview & driving paths
    for (final car in _cars) {
      if (car.state == _CarState.drive && car.path.isNotEmpty) {
        _dotted(c, [car.pos, ...car.path], car.color.withValues(alpha: .6));
      }
    }
    if (_path.length > 1) {
      final s = _spotAt(_path.last);
      final ok = s != null && s.car == null;
      _dotted(c, _path, ok ? Pal.lime : Pal.white, w: 5);
      c.drawCircle(_path.last, 9, D.stroke(ok ? Pal.lime : Pal.white, 3));
    }
    for (final car in _cars) {
      if (car.state != _CarState.gone) _drawCar(c, car);
    }
    _drawGateArm(c);
    _drawHud(c);
    if (host.time < 3 && _parked == 0 && _drawing == null && !host.finished) {
      final front = _frontCar;
      if (front != null) {
        final k = (_t * .6) % 1.0;
        final target = _spots[5].rect.center;
        final ctrl = Offset(front.pos.dx + 40, 470);
        final a = Offset.lerp(front.pos, ctrl, k)!;
        final b = Offset.lerp(ctrl, target, k)!;
        D.hand(c, Offset.lerp(a, b, k)!, 0);
        D.text(c, host.tr('drag', 'DRAG'), front.pos + const Offset(56, -10), size: 20, color: Pal.lime, stroke: Pal.ink);
      }
    }
  }

  void _dotted(Canvas c, List<Offset> pts, Color col, {double w = 4}) {
    final p = D.fill(col);
    var acc = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final d = (b - a).distance;
      var t = acc;
      while (t < d) {
        c.drawCircle(Offset.lerp(a, b, t / d)!, w / 2, p);
        t += 11;
      }
      acc = t - d;
    }
  }

  void _drawLot(Canvas c) {
    // grass border
    D.gradientBg(c, const [Color(0xFF7BCB5A), Color(0xFF5DA83E)]);
    for (var k = 0; k < 30; k++) {
      c.drawCircle(Offset((k * 83) % 360.0, (k * 131) % 640.0), 3, D.fill(const Color(0x335A8A2E)));
    }
    // asphalt
    D.rrect(c, const Rect.fromLTWH(12, 84, 336, 480), 14, const Color(0xFF3A3E49),
        gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4A4F5C), Color(0xFF34373F)]),
        border: const Color(0xFFCFD5DC), borderWidth: 4);
    // road at bottom
    c.drawRect(const Rect.fromLTWH(0, 560, 360, 80), D.fill(const Color(0xFF2E3138)));
    for (var k = 0; k < 7; k++) {
      c.drawRect(Rect.fromLTWH(k * 60.0 + 10, 606, 30, 4), D.fill(const Color(0x99FFD23F)));
    }
    c.drawRect(const Rect.fromLTWH(20, 556, 64, 12), D.fill(const Color(0xFF3A3E49)));
    c.drawRect(const Rect.fromLTWH(296, 556, 64, 12), D.fill(const Color(0xFF3A3E49)));
    // entrance / exit arrows
    D.arrow(c, const Offset(52, 440), const Offset(0, -1), 30, const Color(0x66FFFFFF), width: 8);
    D.arrow(c, const Offset(330, 500), const Offset(0, 1), 30, const Color(0x66FFFFFF), width: 8);
    // spots
    for (final s in _spots) {
      final r = s.rect;
      final line = D.stroke(Pal.white, 3);
      c.drawLine(r.topLeft, r.bottomLeft, line);
      c.drawLine(r.topRight, r.bottomRight, line);
      if (s.top) {
        c.drawLine(r.topLeft, r.topRight, line);
      } else {
        c.drawLine(r.bottomLeft, r.bottomRight, line);
      }
      if (s.car == null) {
        final pulse = .25 + .2 * M.wave(_t, 1.5);
        c.drawRect(r.deflate(4), D.fill(Pal.lime.withValues(alpha: pulse * .5)));
        D.text(c, 'P', r.center, size: 26, color: const Color(0x55FFFFFF));
      }
    }
    // aisle markings
    for (var x = 30.0; x < 330; x += 34) {
      c.drawRect(Rect.fromLTWH(x, 236, 18, 4), D.fill(const Color(0x55FFFFFF)));
      c.drawRect(Rect.fromLTWH(x, 440, 18, 4), D.fill(const Color(0x55FFFFFF)));
    }
    // trees on the grass edge
    for (final p in const [Offset(8, 200), Offset(352, 160), Offset(352, 380), Offset(8, 420)]) {
      c.drawCircle(p, 16, D.fill(const Color(0xFF3F8F2E)));
      c.drawCircle(p + const Offset(-4, -4), 9, D.fill(const Color(0xFF6CC04A)));
    }
    // booth
    D.rrect(c, const Rect.fromLTWH(96, 496, 34, 34), 5, const Color(0xFFFFF4DC), border: Pal.ink, borderWidth: 2);
    D.rrect(c, const Rect.fromLTWH(101, 502, 24, 12), 3, const Color(0xFF9FD8F0));
  }

  void _drawGateArm(Canvas c) {
    const pivot = Offset(90, 488);
    final a = -pi + _gateArm * -pi / 2 * -1;
    final end = pivot + Offset(cos(a) * 64, sin(a) * 64);
    c.drawLine(pivot, end, D.stroke(Pal.ink, 9));
    c.drawLine(pivot, end, D.stroke(Pal.white, 6));
    for (var k = 1; k < 4; k++) {
      final p = Offset.lerp(pivot, end, k / 4)!;
      c.drawCircle(p, 3, D.fill(Pal.red));
    }
    D.circle(c, pivot, 7, Pal.yellow, border: Pal.ink, borderWidth: 2);
  }

  void _drawCar(Canvas c, _Car car) {
    c.save();
    c.translate(car.pos.dx, car.pos.dy);
    c.rotate(car.heading);
    final sq = car.squash;
    c.scale(1 + sq * .1, 1 - sq * .08);
    D.rrect(c, const Rect.fromLTWH(-15, -24, 34, 54), 10, const Color(0x44000000));
    // wheels
    for (final w in const [Offset(-17, -15), Offset(13, -15), Offset(-17, 12), Offset(13, 12)]) {
      D.rrect(c, Rect.fromLTWH(w.dx, w.dy, 5, 11), 2, Pal.ink);
    }
    final col = car.flash > 0 ? Color.lerp(car.color, Pal.white, car.flash)! : car.color;
    D.rrect(c, const Rect.fromLTWH(-15, -27, 30, 54), 10, col, border: Pal.ink, borderWidth: 2.5);
    // windshield + roof
    D.rrect(c, const Rect.fromLTWH(-11, -15, 22, 10), 3, const Color(0xFF2B3A50));
    D.rrect(c, const Rect.fromLTWH(-11, -4, 22, 16), 4, Color.lerp(col, Pal.white, .3)!);
    D.rrect(c, const Rect.fromLTWH(-11, 13, 22, 7), 3, const Color(0xFF2B3A50));
    // headlights
    c.drawCircle(const Offset(-9, -24), 3, D.fill(const Color(0xFFFFF4A0)));
    c.drawCircle(const Offset(9, -24), 3, D.fill(const Color(0xFFFFF4A0)));
    c.drawRect(const Rect.fromLTWH(-12, 24, 6, 2), D.fill(Pal.red));
    c.drawRect(const Rect.fromLTWH(6, 24, 6, 2), D.fill(Pal.red));
    c.restore();
    // state marks
    if (car.state == _CarState.parked) {
      final k = (car.stay / 4.2).clamp(0.0, 1.0);
      c.drawArc(Rect.fromCircle(center: car.pos + const Offset(0, -4), radius: 12), -pi / 2, 2 * pi * k, false,
          D.stroke(Pal.gold, 4));
    }
    if (car.state == _CarState.idle && !identical(car, _drawing)) {
      D.text(c, '?', car.pos + Offset(0, -40 + sin(_t * 6) * 3), size: 22, color: Pal.yellow, stroke: Pal.ink);
    }
    if (car.state == _CarState.crashed) {
      for (var k = 0; k < 3; k++) {
        final a = _t * 6 + k * 2.1;
        D.star(c, car.pos + Offset(cos(a) * 20, -30 + sin(a) * 6), 6, Pal.yellow);
      }
    }
    if (identical(car, _frontCar) && (car.pos - _gate).distance < 30 && _drawing == null) {
      c.drawCircle(car.pos, 32 + M.wave(_t, 2) * 4, D.stroke(Pal.lime.withValues(alpha: .7), 3));
    }
  }

  void _drawHud(Canvas c) {
    final s = 1 + _bump * .12;
    c.save();
    c.translate(254, 60);
    c.scale(s);
    D.rrect(c, const Rect.fromLTWH(-96, -16, 192, 32), 16, const Color(0xDD1B1530), border: Pal.gold, borderWidth: 2);
    D.coin(c, const Offset(-78, 0), 10, spin: _t * .4);
    D.bar(c, const Rect.fromLTWH(-62, -6, 76, 12), _shown / _goal, Pal.gold);
    D.text(c, '${_shown.round()}/$_goal', const Offset(52, 0), size: 14, color: Pal.white, stroke: Pal.ink);
    c.restore();
    for (var i = 0; i < 3; i++) {
      D.heart(c, Offset(22 + i * 24.0, 60), 18, i < 3 - _crashes ? Pal.red : const Color(0x55000000), border: Pal.ink);
    }
  }
}

enum _CarState { queue, idle, drive, snap, parked, leave, crashed, gone }

class _Spot {
  _Spot(this.rect, this.top);
  final Rect rect;
  final bool top;
  _Car? car;
}

class _Car {
  _Car(this.color, this.pos);
  final Color color;
  Offset pos;
  double heading = 0;
  _CarState state = _CarState.queue;
  final List<Offset> path = [];
  _Spot? target;
  _Spot? spot;
  double stay = 0;
  double flash = 0;
  double squash = 0;
  double spinT = 0;
  double spinV = 0;
}
