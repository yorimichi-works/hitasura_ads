import '../engine/engine.dart';

/// No.097 Hoop Flick 3D — street court at sunset. Flick the ball up into the
/// hoop (3D projectile, rim + backboard bounces, swishing net). Make 5.
class G097 extends MiniGame {
  static const _need = 5;
  static const _rimY = 3.05;
  static const _rimZ = 4.8;
  static const _rimR = .34;
  static const _tube = .035;
  static const _ballR = .17;
  static const _g = 9.8;
  static const _start = V3(0, 1.25, .55);

  final scene = Scene3();
  final floor = Scene3();

  late final Mesh _ballMesh;
  late final Mesh _rimMesh;
  late final Mesh _board;
  late final Mesh _pole;
  late final Mesh _arm;
  late final Mesh _court;
  late final Mesh _cone;

  final List<_Ball> _balls = [];
  double _t = 0;
  double _hx = 0; // hoop x
  double _hoopPhase = 0;
  int _made = 0;
  int _streak = 0;
  int _swishes = 0;
  double _ready = 1; // 0..1 next ball in hand
  double _swish = 0; // net animation
  double _rimShake = 0;
  double _boardShake = 0;
  double _fire = 0;
  double _clangCd = 0;
  double _madeBump = 0;

  // input
  Offset? _downAt;
  double _downT = 0;
  Offset _cur = Offset.zero;

  double get _boardZ => _rimZ + _rimR + .17;
  V3 get _rimC => V3(_hx, _rimY, _rimZ);
  bool get _moving => _made >= 3;

  @override
  void init() {
    for (final s in [scene, floor]) {
      s
        ..ambient = .55
        ..diffuse = .6
        ..light = const V3(.5, .9, -.6).normalized
        ..fogColor = const Color(0xFF6A3C7A)
        ..fogNear = 9
        ..fogFar = 28;
    }
    _ballMesh = Mesh.sphere(_ballR, const Color(0xFFF07A22), lat: 6, lon: 10);
    for (var i = 0; i < _ballMesh.faces.length; i++) {
      final lat = i ~/ 10, lon = i % 10;
      if (lon == 0 || lon == 5 || lat == 3) _ballMesh.faces[i].color = const Color(0xFF3A1A0C);
    }
    _rimMesh = Mesh.torus(_rimR, _tube, const Color(0xFFFF4A1C), seg: 16, side: 4);
    _board = Mesh.box(1.8, 1.05, .06, const Color(0xFFE9F4FF),
        colors: const [Color(0xFFB8C4D8), Color(0xFFB8C4D8), Color(0xFFF4FAFF), Color(0xFFD8E2F0), Color(0xFF9AA6BC), Color(0xFF9AA6BC)]);
    _pole = Mesh.cylinder(.09, 3.5, const Color(0xFF3F4E6E), seg: 8);
    _arm = Mesh.box(.12, .12, .7, const Color(0xFF3F4E6E));
    _court = Mesh.grid(16, 30, 10, 20, (i, j) {
      final inPaint = i >= 4 && i <= 5 && j >= 3 && j <= 5;
      if (inPaint) return const Color(0xFFB0485A);
      return (i + j).isEven ? const Color(0xFF4A5A86) : const Color(0xFF45547E);
    });
    _cone = Mesh.cone(.18, .45, const Color(0xFFFF7A1A), seg: 6);
    _balls.add(_Ball(_start));
  }

  // ------------------------------------------------------------ gameplay ---

  void _shoot(Offset from, Offset to, double secs) {
    final ball = _balls.lastOrNull;
    if (ball == null || ball.flying || _ready < 1 || host.finished) return;
    final dy = from.dy - to.dy;
    final dx = to.dx - from.dx;
    // power from flick length (and a bit of speed)
    final speed = (to - from).distance / max(secs, .06);
    var p = ((dy / 180) * .8 + (speed / 1500) * .2).clamp(.55, 1.6);
    p = 1 + (p - 1) * .1; // generous assist
    const flight = 1.0;
    final hxAtArrival = _hoopXAt(host.time + flight);
    var aimX = (dx / max(dy, 30)) * 2.2;
    if ((aimX - hxAtArrival).abs() < 1.4) aimX += (hxAtArrival - aimX) * .72;
    final target = V3(aimX, _rimY + .02, _rimZ + .05);
    final d = target - _start;
    final vy = (d.y + .5 * _g * flight * flight) / flight;
    ball
      ..flying = true
      ..vel = V3(d.x / flight, vy, d.z / flight * p)
      ..spin = -8;
    ball.vel = V3(ball.vel.x, ball.vel.y * (.95 + .05 * p), ball.vel.z);
    _ready = 0;
    host.sfx(Sfx.throwIt, volume: .9, rate: .9 + p * .2);
    host.sfx(Sfx.whoosh, volume: .4);
    host.punch(.015);
  }

  double _hoopXAt(double t) => _moving ? sin((t - _hoopPhase) * 1.7 * host.speed) * 1.05 : 0;

  @override
  void update(double dt) {
    _t += dt;
    _clangCd -= dt;
    _hx = _hoopXAt(host.time);
    if (!_moving) _hoopPhase = host.time;
    _swish = M.approach(_swish, 0, 3.5, dt);
    _rimShake = M.approach(_rimShake, 0, 6, dt);
    _boardShake = M.approach(_boardShake, 0, 6, dt);
    _madeBump = M.approach(_madeBump, 0, 5, dt);
    _fire = M.approach(_fire, _streak >= 3 ? 1 : 0, 4, dt);

    if (_ready < 1) {
      _ready = min(1, _ready + dt / .38);
      if (_ready >= 1 && !host.finished) _balls.add(_Ball(_start));
    }

    const steps = 3;
    final h = dt / steps;
    for (final b in _balls) {
      if (!b.flying) continue;
      b.age += dt;
      b.rot += b.spin * dt;
      for (var s = 0; s < steps; s++) {
        _step(b, h);
      }
      if (_fire > .5 && !b.done) {
        final sp = scene.cam.project(b.pos);
        if (sp != null && chance(.7)) {
          host.fx.add(Particle(
            pos: sp + Offset(rand(-6, 6), rand(-6, 6)),
            vel: Offset(rand(-20, 20), rand(-90, -30)),
            life: rand(.2, .4),
            color: pick(const [Pal.orange, Pal.yellow, Pal.red]),
            size: rand(5, 10),
            shape: PartShape.circle,
            drag: 1,
          ));
        }
      }
    }
    _balls.removeWhere((b) => b.flying && (b.age > 3.2 || b.pos.z > 9 || b.pos.z < -3));
  }

  void _step(_Ball b, double dt) {
    final prev = b.pos;
    b.vel = V3(b.vel.x, b.vel.y - _g * dt, b.vel.z);
    b.pos = b.pos + b.vel * dt;
    final c = _rimC;
    // rim (a ring of radius R): nearest point on the circle
    final q = b.pos - c;
    final hl = sqrt(q.x * q.x + q.z * q.z);
    if (hl > 1e-6) {
      final k = V3(c.x + q.x / hl * _rimR, c.y, c.z + q.z / hl * _rimR);
      final d = b.pos - k;
      final dist = d.length;
      if (dist < _ballR + _tube) {
        final n = d / max(dist, 1e-6);
        final vn = b.vel.dot(n);
        if (vn < 0) {
          b.vel = (b.vel - n * (1.55 * vn)) * .88;
          b.rimHits++;
          _rimShake = 1;
          if (_clangCd <= 0) {
            _clangCd = .08;
            host.sfx(Sfx.clang, volume: .7, rate: rand(.9, 1.15));
          }
        }
        b.pos = k + n * (_ballR + _tube + .002);
      }
    }
    // backboard
    final bz = _boardZ;
    if (b.vel.z > 0 && b.pos.z + _ballR > bz && prev.z + _ballR <= bz + .05 && (b.pos.x - _hx).abs() < .9 + _ballR * .5 &&
        b.pos.y > _rimY - .2 && b.pos.y < _rimY + 1.0) {
      b.pos = V3(b.pos.x, b.pos.y, bz - _ballR);
      b.vel = V3(b.vel.x * .85, b.vel.y * .9, -b.vel.z * .45);
      b.boardHits++;
      _boardShake = 1;
      host.sfx(Sfx.thud, volume: .8, rate: 1.2);
    }
    // score: crossing the rim plane downward inside the ring
    if (!b.done && prev.y > c.y && b.pos.y <= c.y && b.vel.y < 0) {
      final hx = b.pos.x - c.x, hz = b.pos.z - c.z;
      if (hx * hx + hz * hz < (_rimR - _ballR * .35) * (_rimR - _ballR * .35)) {
        _score(b);
      }
    }
    // net drag
    if (b.scored && b.pos.y < c.y && b.pos.y > c.y - .5) {
      b.vel = V3(b.vel.x * .9 + (c.x - b.pos.x) * .5, b.vel.y * .96, b.vel.z * .9 + (c.z - b.pos.z) * .5);
    }
    // floor
    if (b.pos.y < _ballR) {
      b.pos = V3(b.pos.x, _ballR, b.pos.z);
      if (b.vel.y < -1.2) {
        host.sfx(Sfx.bounce, volume: .45, rate: .8);
      }
      b.vel = V3(b.vel.x * .85, -b.vel.y * .55, b.vel.z * .85);
      if (!b.done) _miss(b);
    }
    // fell behind/below the rim without scoring
    if (!b.done && b.vel.y < 0 && b.pos.y < c.y - .6) _miss(b);
  }

  void _score(_Ball b) {
    b.done = true;
    b.scored = true;
    _made++;
    _streak++;
    _swish = 1;
    _madeBump = 1;
    final at = scene.cam.project(_rimC) ?? const Offset(180, 290);
    final swish = b.rimHits == 0 && b.boardHits == 0;
    final bank = b.boardHits > 0;
    host.addScore(swish ? 3 : 2, at + const Offset(0, 30));
    if (swish) {
      _swishes++;
      host.fx.pop(host.tr('swish', 'SWISH!'), at + const Offset(0, -60), color: Pal.teal, size: 36);
      host.sfx(Sfx.swipe, volume: .9, rate: 1.2);
      host.sfx(Sfx.perfect, volume: .8, rate: 1 + _streak * .06);
      host.fx.ring(at, Pal.teal, size: 110, life: .45);
    } else if (bank) {
      host.fx.pop(host.tr('bank', 'BANK!'), at + const Offset(0, -60), color: Pal.sky, size: 32);
      host.sfx(Sfx.correct, volume: .8, rate: 1 + _streak * .05);
    } else {
      host.fx.pop(host.tr('nice', 'NICE!'), at + const Offset(0, -60), color: Pal.yellow, size: 30);
      host.sfx(Sfx.correct, volume: .8, rate: 1 + _streak * .05);
    }
    host.sfx(Sfx.splash, volume: .35, rate: 1.8);
    if (_streak >= 3) {
      host.fx.pop(host.tr('on_fire', 'ON FIRE!'), at + const Offset(0, -100), color: Pal.orange, size: 30);
      host.sfx(Sfx.fire, volume: .6);
    }
    host.fx.burst(at, Pal.white, count: 20, speed: 240, colors: const [Pal.yellow, Pal.white, Pal.orange, Pal.teal]);
    host.fx.sparkle(at, count: 10, radius: 40);
    host.shake(swish ? 6 : 4);
    host.punch(.03);
    if (_made == 3) {
      host.fx.pop(host.tr('danger', 'DANGER!'), const Offset(180, 200), color: Pal.red, size: 28, life: 1.2);
      host.sfx(Sfx.powerup, volume: .6);
    }
    if (_made >= _need) {
      host.fx.coins(at, count: 26);
      final t = host.time;
      host.win(stars: _swishes >= 2 || t < 9 ? 3 : (t < 13 ? 2 : 1));
    }
  }

  void _miss(_Ball b) {
    b.done = true;
    _streak = 0;
    final at = scene.cam.project(b.pos) ?? const Offset(180, 300);
    if (b.rimHits > 0 || b.boardHits > 0) {
      host.fx.pop(host.tr('brick', 'BRICK!'), _clampPop(at), color: Pal.orange, size: 26);
      host.sfx(Sfx.oops, volume: .6);
    } else {
      host.fx.pop(host.tr('airball', 'AIRBALL'), _clampPop(at), color: Pal.gray, size: 26);
      host.sfx(Sfx.aww, volume: .6);
    }
  }

  Offset _clampPop(Offset at) => Offset(at.dx.clamp(80.0, 280.0), (at.dy - 30).clamp(120.0, 560.0));

  @override
  void onTimeUp() => host.lose();

  // --------------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    _downAt = p;
    _downT = _t;
    _cur = p;
  }

  @override
  void onMove(Offset p) {
    _cur = p;
    final d = _downAt;
    if (d == null) return;
    // shoot as soon as the flick is long enough (feels snappier)
    if (d.dy - p.dy > 150) {
      _shoot(d, p, _t - _downT);
      _downAt = null;
    }
  }

  @override
  void onUp(Offset p) {
    final d = _downAt;
    _downAt = null;
    if (d == null) return;
    if (d.dy - p.dy > 35) _shoot(d, p, _t - _downT);
  }

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action') {
      final dx = _hoopXAt(host.time + 1) / 2.6 * 210;
      _shoot(const Offset(180, 560), Offset(180 + dx, 350), .2);
    }
  }

  // -------------------------------------------------------------- render ---

  void _setCam(Scene3 s) {
    s.cam
      ..center = const Offset(180, 330)
      ..focal = 600
      ..pos = const V3(0, 1.9, -1.6)
      ..lookAt(const V3(0, 2.6, _rimZ));
  }

  Offset? _pr(V3 p) => scene.cam.project(p);

  @override
  void render(Canvas c) {
    _setCam(scene);
    _setCam(floor);
    _renderSky(c);

    floor.clear();
    floor.add(_court, pos: const V3(0, 0, 12));
    floor.render(c);
    _renderCourtLines(c);

    scene.clear();
    final sh = sin(_t * 60) * .02 * _boardShake;
    scene.add(_pole, pos: V3(_hx, 1.75, _boardZ + .75));
    scene.add(_arm, pos: V3(_hx, 3.3, _boardZ + .38));
    scene.add(_board, pos: V3(_hx + sh, _rimY + .35, _boardZ + .03));
    scene.addSprite(V3(_hx, _rimY + .35, _boardZ - .01), (c, s, k) => _boardMarks(c));
    scene.add(_rimMesh, pos: _rimC + V3(0, sin(_t * 50) * .015 * _rimShake, 0), rotX: pi / 2);
    scene.addSprite(_rimC + const V3(0, -.12, -.02), (c, s, k) => _net(c));
    for (final x in [-2.8, 2.9]) {
      scene.add(_cone, pos: V3(x, .22, 3.2));
    }
    for (final b in _balls) {
      final pos = b.flying ? b.pos : _handPos(b);
      final grow = b.flying ? 1.0 : M.easeOutBack(_ready.clamp(0.0, 1.0));
      if (grow <= .01) continue;
      scene.add(_ballMesh, pos: pos, rotX: b.rot, rotY: .4, scale: grow);
      final toCam = (scene.cam.pos - pos).normalized;
      scene.addSprite(pos + toCam * (_ballR * 1.05), (c, s, k) {
        c.drawCircle(s + Offset(-_ballR * .4 * k, -_ballR * .42 * k), _ballR * .22 * k * grow, Paint()..color = const Color(0x77FFFFFF));
      });
    }
    scene.render(c);
    _renderHud(c);
  }

  V3 _handPos(_Ball b) => _start + V3(0, sin(_t * 3) * .02 - (1 - _ready) * .3, 0);

  void _renderSky(Canvas c) {
    final hz = scene.cam.center.dy - tan(scene.cam.pitch) * scene.cam.focal;
    D.gradientBg(c, const [Color(0xFF2B1B5E), Color(0xFF8E3B8A), Color(0xFFFF7A5A), Color(0xFFFFC46B)],
        rect: Rect.fromLTRB(0, 0, 360, hz + 1));
    // sun
    c.drawCircle(Offset(250, hz - 95), 64, Paint()..color = const Color(0x55FFE08A));
    c.drawCircle(Offset(250, hz - 95), 44, Paint()..color = const Color(0xFFFFE9A8));
    // skyline
    final rnd = Random(97);
    final far = Paint()..color = const Color(0xFF6A3478);
    final near = Paint()..color = const Color(0xFF3A2152);
    final win = Paint();
    var x = -10.0;
    while (x < 370) {
      final w = 26 + rnd.nextDouble() * 30;
      final h = 90 + rnd.nextDouble() * 110;
      c.drawRect(Rect.fromLTWH(x, hz - h, w - 3, h), far);
      x += w;
    }
    x = -20;
    while (x < 370) {
      final w = 34 + rnd.nextDouble() * 40;
      final h = 50 + rnd.nextDouble() * 80;
      c.drawRect(Rect.fromLTWH(x, hz - h, w - 4, h), near);
      for (var wy = hz - h + 8; wy < hz - 10; wy += 12) {
        for (var wx = x + 5; wx < x + w - 10; wx += 9) {
          if (rnd.nextDouble() < .35) {
            final tw = .5 + .5 * M.wave(_t * .3 + wx * .1 + wy, .2);
            c.drawRect(Rect.fromLTWH(wx, wy, 4, 5), win..color = Color.fromRGBO(255, 216, 107, .5 + tw * .5));
          }
        }
      }
      x += w;
    }
    // chain-link fence along the far side of the court
    final top = hz - 72;
    c.drawRect(Rect.fromLTRB(0, top, 360, hz), Paint()..color = const Color(0x22101030));
    final fence = D.stroke(const Color(0x66C8D0E8), 1);
    for (var i = -80.0; i < 380; i += 14) {
      c.drawLine(Offset(i, top), Offset(i + 72, hz), fence);
      c.drawLine(Offset(i + 72, top), Offset(i, hz), fence);
    }
    c.drawLine(Offset(0, top), Offset(360, top), D.stroke(const Color(0xAAC8D0E8), 2.5));
    for (var i = 0; i < 6; i++) {
      c.drawLine(Offset(i * 72.0 + 10, top - 4), Offset(i * 72.0 + 10, hz), D.stroke(const Color(0xCC9AA2C0), 3));
    }
    // ground beyond the court
    c.drawRect(Rect.fromLTRB(0, hz, 360, 640), Paint()..color = const Color(0xFF5A4A78));
    // string lights
    for (var i = 0; i < 14; i++) {
      final lx = i * 27.0 + 6;
      final ly = 70 + sin(i / 13 * pi) * 26;
      final on = M.wave(_t * 1.5 + i * .3, .5);
      c.drawCircle(Offset(lx, ly), 7, Paint()..color = Color.fromRGBO(255, 220, 120, .18 + on * .15));
      c.drawCircle(Offset(lx, ly), 2.6, Paint()..color = const Color(0xFFFFF0B0));
    }
    final wire = Path()..moveTo(0, 70);
    for (var i = 0; i <= 14; i++) {
      wire.lineTo(i * 27.0 + 6, 70 + sin(i / 13 * pi) * 26);
    }
    c.drawPath(wire, D.stroke(const Color(0x88221433), 1.2));
  }

  void _renderCourtLines(Canvas c) {
    final line = D.stroke(const Color(0xDDF4F0FF), 2.2);
    Path poly(List<V3> pts) {
      final path = Path();
      var first = true;
      for (final p in pts) {
        final s = _pr(p);
        if (s == null) continue;
        if (first) {
          path.moveTo(s.dx, s.dy);
          first = false;
        } else {
          path.lineTo(s.dx, s.dy);
        }
      }
      return path;
    }

    // key / paint
    c.drawPath(poly(const [V3(-.95, 0, 5.8), V3(-.95, 0, 1.2), V3(.95, 0, 1.2), V3(.95, 0, 5.8)]), line);
    // free-throw circle
    c.drawPath(poly([for (var i = 0; i <= 24; i++) V3(cos(i / 24 * pi * 2) * .95, 0, 1.2 + sin(i / 24 * pi * 2) * .95)]), line);
    // three-point arc
    c.drawPath(poly([for (var i = 0; i <= 30; i++) V3(cos(i / 30 * pi) * 4.6, 0, 5.0 - sin(i / 30 * pi) * 4.6)]), line);
    // shadows
    for (final b in _balls) {
      final p = b.flying ? b.pos : _handPos(b);
      final s = _pr(V3(p.x, 0, p.z));
      if (s == null) continue;
      final k = scene.cam.scaleAt(V3(p.x, 0, p.z));
      final a = (.35 - p.y * .06).clamp(.08, .35);
      D.shadow(c, s, _ballR * 2.4 * k, _ballR * .9 * k, a);
    }
    final ps = _pr(V3(_hx, 0, _boardZ + .75));
    if (ps != null) D.shadow(c, ps, 60, 12, .3);
  }

  void _boardMarks(Canvas c) {
    final bx = _hx + sin(_t * 60) * .02 * _boardShake, bz = _boardZ - .005;
    Offset? p(double x, double y) => _pr(V3(bx + x, y, bz));
    final a = p(-.3, _rimY + .05), b = p(.3, _rimY + .05), cc = p(.3, _rimY + .5), d = p(-.3, _rimY + .5);
    final o1 = p(-.9, _rimY - .17), o2 = p(.9, _rimY - .17), o3 = p(.9, _rimY + .87), o4 = p(-.9, _rimY + .87);
    if (a == null || b == null || cc == null || d == null || o1 == null || o2 == null || o3 == null || o4 == null) return;
    c.drawPath(Path()..addPolygon([o1, o2, o3, o4], true), D.stroke(const Color(0xFFFF4A1C), 3));
    c.drawPath(Path()..addPolygon([a, b, cc, d], true), D.stroke(const Color(0xFFFF4A1C), 3));
    // glossy streak
    final g1 = p(-.7, _rimY + .8), g2 = p(-.45, _rimY + .8), g3 = p(-.75, _rimY - .1), g4 = p(-.95, _rimY - .1);
    if (g1 != null && g2 != null && g3 != null && g4 != null) {
      c.drawPath(Path()..addPolygon([g1, g2, g3, g4], true), Paint()..color = const Color(0x44FFFFFF));
    }
  }

  void _net(Canvas c) {
    final cc = _rimC;
    const n = 12;
    final drop = .5 + _swish * .18;
    final pinch = .55 - _swish * .12;
    final top = <Offset?>[];
    final mid = <Offset?>[];
    final bot = <Offset?>[];
    for (var i = 0; i < n; i++) {
      final a = i / n * pi * 2;
      final wob = sin(_t * 18 + i) * .03 * _swish;
      top.add(_pr(V3(cc.x + cos(a) * _rimR, cc.y, cc.z + sin(a) * _rimR)));
      mid.add(_pr(V3(cc.x + cos(a) * _rimR * .8 + wob, cc.y - drop * .5, cc.z + sin(a) * _rimR * .8)));
      bot.add(_pr(V3(cc.x + cos(a) * _rimR * pinch + wob, cc.y - drop, cc.z + sin(a) * _rimR * pinch)));
    }
    final p = D.stroke(const Color(0xEEFFFFFF), 1.6);
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final t0 = top[i], m0 = mid[i], b0 = bot[i], t1 = top[j], m1 = mid[j], b1 = bot[j];
      if (t0 == null || m0 == null || b0 == null || t1 == null || m1 == null || b1 == null) continue;
      c.drawLine(t0, m1, p);
      c.drawLine(t1, m0, p);
      c.drawLine(m0, b1, p);
      c.drawLine(m1, b0, p);
      c.drawLine(b0, b1, p);
    }
  }

  void _renderHud(Canvas c) {
    // made counter
    final pulse = 1 + _madeBump * .25;
    c.save();
    c.translate(180, 78);
    c.scale(pulse);
    D.rrect(c, const Rect.fromLTWH(-92, -22, 184, 44), 22, const Color(0xCC1B1238), border: Pal.white, borderWidth: 2.5);
    for (var i = 0; i < _need; i++) {
      final o = Offset(-68 + i * 34.0, 0);
      if (i < _made) {
        D.circle(c, o, 13, Pal.orange, border: Pal.ink, borderWidth: 2);
        c.drawLine(o + const Offset(-13, 0), o + const Offset(13, 0), D.stroke(Pal.ink, 1.5));
        c.drawLine(o + const Offset(0, -13), o + const Offset(0, 13), D.stroke(Pal.ink, 1.5));
      } else {
        D.circle(c, o, 13, const Color(0x33FFFFFF), border: const Color(0x66FFFFFF), borderWidth: 2);
      }
    }
    c.restore();
    if (_fire > .05) {
      D.text(c, host.tr('on_fire', 'ON FIRE!'), const Offset(180, 118), size: 18,
          color: Color.lerp(Pal.orange, Pal.yellow, M.wave(_t, 4))!.withValues(alpha: _fire), stroke: Pal.ink, strokeWidth: 4);
    }
    if (_moving && !host.finished) {
      final hs = _pr(V3(_hx, _rimY + 1.05, _boardZ));
      if (hs != null) {
        D.arrow(c, hs + const Offset(-34, 0), const Offset(-1, 0), 18, Pal.yellow.withValues(alpha: .8), width: 6);
        D.arrow(c, hs + const Offset(34, 0), const Offset(1, 0), 18, Pal.yellow.withValues(alpha: .8), width: 6);
      }
    }
    // flick guide
    if (_made == 0 && _balls.length <= 1 && host.time < 3 && _balls.isNotEmpty && !_balls.first.flying) {
      final k = (_t * 1.1) % 1;
      D.hand(c, Offset(180, 560 - M.easeOut(k) * 180), 0);
      D.arrow(c, const Offset(180, 430), const Offset(0, -1), 60, const Color(0xAAFFFFFF), width: 10);
    }
    // aim trace while dragging
    final d = _downAt;
    if (d != null && host.pointerDown) {
      c.drawLine(d, _cur, D.stroke(const Color(0x88FFFFFF), 6));
      D.circle(c, d, 8, const Color(0x66FFFFFF));
    }
  }
}

class _Ball {
  _Ball(this.pos);
  V3 pos;
  V3 vel = V3.zero;
  bool flying = false;
  bool done = false;
  bool scored = false;
  int rimHits = 0;
  int boardHits = 0;
  double age = 0;
  double rot = 0;
  double spin = 0;
}

extension on List<_Ball> {
  _Ball? get lastOrNull => isEmpty ? null : last;
}
