import '../engine/engine.dart';

/// No.029 Clash Lane — Clash Royale parody. Drag cards (knight, archers,
/// giant, fireball) into your half; units march over the bridges and fight.
/// Destroy the enemy king tower, or lead in crowns when time runs out.
class G029 extends MiniGame {
  static const _riverY = 305.0;
  static const _bridges = [80.0, 280.0];
  static const _blue = Color(0xFF3D7BFF);
  static const _red = Color(0xFFFF4060);
  static const _elixirC = Color(0xFFD04DFF);
  static const _cost = [3, 3, 5, 4];

  final List<_Tower> _towers = [];
  final List<_Unit> _units = [];
  final List<_Proj> _projs = [];
  double _t = 0;
  double _elixir = 6;
  double _aiElixir = 5;
  double _aiT = 3.5;
  int _crownsBlue = 0, _crownsRed = 0;
  int? _dragCard;
  Offset _dragPos = Offset.zero;
  int _deploys = 0;
  final List<double> _cardPop = [0, 0, 0, 0];
  double _fireballFx = 0;
  Offset _fireballAt = Offset.zero;
  bool _over = false;

  static Rect _cardRect(int i) => Rect.fromLTWH(12 + i * 85.0, 586, 78, 50);

  @override
  void init() {
    _towers
      ..add(_Tower(2, const Offset(80, 128), false))
      ..add(_Tower(2, const Offset(280, 128), false))
      ..add(_Tower(2, const Offset(180, 78), true))
      ..add(_Tower(1, const Offset(80, 482), false))
      ..add(_Tower(1, const Offset(280, 482), false))
      ..add(_Tower(1, const Offset(180, 532), true));
  }

  // ------------------------------------------------------------------ units

  void _deploy(int owner, int card, Offset at) {
    if (card == 3) {
      _fireball(owner, at);
      return;
    }
    final n = card == 1 ? 2 : 1;
    for (var i = 0; i < n; i++) {
      final off = n == 2 ? Offset(i == 0 ? -12 : 12, 0) : Offset.zero;
      _units.add(_Unit(owner, card, at + off, owner == 2 ? .85 : 1));
    }
    host.fx.smoke(at + const Offset(0, 8), count: 5, color: const Color(0xCCFFFFFF));
    host.fx.ring(at, owner == 1 ? _blue : _red, size: 34, life: .3);
    host.sfx(owner == 1 ? Sfx.land : Sfx.thud, volume: owner == 1 ? .8 : .45);
  }

  void _fireball(int owner, Offset at) {
    _fireballFx = .45;
    _fireballAt = at;
    host.sfx(Sfx.fire);
    for (final u in _units) {
      if (u.owner != owner && (u.pos - at).distance < 46) _hurtUnit(u, 60);
    }
    for (final t in _towers) {
      if (t.owner != owner && !t.dead && (t.pos - at).distance < 50) _hurtTower(t, 36);
    }
    host.sfx(Sfx.explode);
    host.shake(8);
    host.fx.burst(at, Pal.orange, count: 30, speed: 260, size: 8, colors: const [Pal.orange, Pal.yellow, Pal.red]);
    host.fx.ring(at, Pal.orange, size: 60);
    host.fx.smoke(at, count: 6, color: const Color(0xAA555555));
  }

  static double _speed(int k) => [52.0, 54.0, 40.0][k];
  static double _range(int k) => [18.0, 84.0, 20.0][k];
  static double _dmg(int k) => [13.0, 7.0, 30.0][k];
  static double _rate(int k) => [.8, .75, 1.3][k];
  static double _rad(int k) => [11.0, 8.0, 16.0][k];

  Object? _findTarget(_Unit u) {
    if (u.kind != 2) {
      _Unit? best;
      var bd = 95.0;
      for (final o in _units) {
        if (o.owner == u.owner || o.dead) continue;
        final d = (o.pos - u.pos).distance;
        if (d < bd) {
          bd = d;
          best = o;
        }
      }
      if (best != null) return best;
    }
    final left = u.pos.dx < 180;
    _Tower? princess;
    _Tower? king;
    for (final t in _towers) {
      if (t.owner == u.owner || t.dead) continue;
      if (t.king) {
        king = t;
      } else if ((t.pos.dx < 180) == left) {
        princess = t;
      }
    }
    // crossed lane with no princess: go for the king (or the other princess)
    if (princess != null) return princess;
    if (king != null) return king;
    return _towers.where((t) => t.owner != u.owner && !t.dead).firstOrNull;
  }

  void _hurtUnit(_Unit u, double d) {
    if (u.dead) return;
    u.hp -= d;
    u.hit = 1;
    if (u.hp <= 0) {
      u.dead = true;
      host.fx.burst(u.pos, u.owner == 1 ? _blue : _red, count: 10, speed: 160, size: 5);
      host.fx.smoke(u.pos, count: 3);
      host.sfx(Sfx.pop, volume: .5, rate: rand(.8, 1.2));
      if (u.owner == 2) host.addScore(30, u.pos);
    }
  }

  void _hurtTower(_Tower t, double d) {
    if (t.dead) return;
    t.hp -= d;
    t.hit = 1;
    if (t.hp <= 0) {
      t.hp = 0;
      t.dead = true;
      host.sfx(Sfx.crash);
      host.sfx(Sfx.explode);
      host.shake(12);
      host.hitStop(.1);
      host.fx.burst(t.pos, const Color(0xFFB9B8C8), count: 30, speed: 300, size: 9, shape: PartShape.square);
      host.fx.smoke(t.pos, count: 10, size: 24);
      if (t.owner == 2) {
        _crownsBlue += t.king ? 3 - _crownsBlue : 1;
        host.flash(const Color(0x66FFFFFF));
        host.sfx(Sfx.fanfare);
        host.fx.coins(t.pos, count: 16);
        host.fx.pop(host.tr('ko', 'K.O.!'), t.pos + const Offset(0, 30), size: 36);
        host.addScore(t.king ? 1000 : 400, t.pos);
      } else {
        _crownsRed += t.king ? 3 - _crownsRed : 1;
        host.flash(const Color(0x66FF2040));
        host.sfx(Sfx.aww);
      }
      if (t.king && !_over) {
        _over = true;
        if (t.owner == 2) {
          host.fx.confetti(count: 100);
          host.win(stars: 3);
        } else {
          host.lose();
        }
      }
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _fireballFx = max(0, _fireballFx - dt);
    for (var i = 0; i < 4; i++) {
      _cardPop[i] = max(0, _cardPop[i] - dt * 4);
    }
    if (_over) return;
    final before = _elixir.floor();
    _elixir = min(10, _elixir + dt / .8);
    if (_elixir.floor() > before) {
      for (var i = 0; i < 4; i++) {
        if (_cost[i] == _elixir.floor()) _cardPop[i] = 1;
      }
    }
    _aiElixir = min(10, _aiElixir + dt / 1.05 * host.speed);
    _ai(dt);

    for (final u in _units) {
      if (u.dead) continue;
      u.hit = max(0, u.hit - dt * 5);
      u.cool -= dt;
      u.anim += dt;
      u.swing = max(0, u.swing - dt * 4);
      final tgt = _findTarget(u);
      if (tgt == null) continue;
      final tp = tgt is _Unit ? tgt.pos : (tgt as _Tower).pos;
      final tr = tgt is _Unit ? _rad(tgt.kind) : (tgt as _Tower).radius;
      final dist = (tp - u.pos).distance - tr - _rad(u.kind);
      if (dist <= _range(u.kind)) {
        u.moving = false;
        if (u.cool <= 0) {
          u.cool = _rate(u.kind);
          u.swing = 1;
          final dmg = _dmg(u.kind) * u.power;
          if (u.kind == 1) {
            _projs.add(_Proj(u.pos, tgt, dmg, 1));
            host.sfx(Sfx.arrow, volume: .3, rate: rand(1, 1.3));
          } else {
            if (tgt is _Unit) {
              _hurtUnit(tgt, dmg);
            } else {
              _hurtTower(tgt as _Tower, dmg);
            }
            host.sfx(u.kind == 2 ? Sfx.hitHeavy : Sfx.slash, volume: u.owner == 1 ? .5 : .3, rate: rand(.9, 1.2));
            host.fx.burst(Offset.lerp(u.pos, tp, .6)!, Pal.white, count: 4, speed: 120, size: 4, gravity: 0, life: .25);
            if (u.kind == 2) host.shake(2);
          }
        }
      } else {
        u.moving = true;
        var goal = tp;
        final needCross = (u.pos.dy > _riverY) != (tp.dy > _riverY);
        if (needCross) {
          final bx = _bridges[u.pos.dx < 180 ? 0 : 1];
          final down = u.pos.dy > _riverY;
          goal = (u.pos.dx - bx).abs() > 5 ? Offset(bx, _riverY + (down ? 26 : -26)) : Offset(bx, _riverY + (down ? -30 : 30));
        }
        final d = goal - u.pos;
        final l = d.distance;
        if (l > .5) u.pos += d / l * min(l, _speed(u.kind) * dt * (u.owner == 2 ? host.speed * .9 : 1));
        u.face = d.dx < 0 ? -1 : 1;
      }
    }
    // separate overlapping units a bit
    for (var i = 0; i < _units.length; i++) {
      final a = _units[i];
      if (a.dead) continue;
      for (var j = i + 1; j < _units.length; j++) {
        final b = _units[j];
        if (b.dead) continue;
        final d = b.pos - a.pos;
        final md = _rad(a.kind) + _rad(b.kind);
        final l = d.distance;
        if (l < md && l > .01) {
          final push = d / l * (md - l) * .5;
          a.pos -= push;
          b.pos += push;
        }
      }
    }
    _units.removeWhere((u) => u.dead);

    // towers shoot
    for (final t in _towers) {
      t.hit = max(0, t.hit - dt * 5);
      if (t.dead) continue;
      t.cool -= dt;
      if (t.cool > 0) continue;
      _Unit? best;
      var bd = t.range;
      for (final u in _units) {
        if (u.owner == t.owner) continue;
        final d = (u.pos - t.pos).distance;
        if (d < bd) {
          bd = d;
          best = u;
        }
      }
      if (best != null) {
        t.cool = t.king ? 1.0 : .8;
        _projs.add(_Proj(t.pos + const Offset(0, -22), best, t.king ? 12 : 8, 0));
        if (t.owner == 2) host.sfx(Sfx.shoot, volume: .15, rate: 1.5);
      }
    }
    // projectiles
    for (final p in _projs) {
      final tgt = p.target;
      final tp = tgt is _Unit ? tgt.pos : (tgt as _Tower).pos;
      final alive = tgt is _Unit ? !tgt.dead : !(tgt as _Tower).dead;
      final d = tp - p.pos;
      final l = d.distance;
      final step = 360 * dt;
      if (!alive) {
        p.dead = true;
      } else if (l <= step + 3) {
        p.dead = true;
        if (tgt is _Unit) {
          _hurtUnit(tgt, p.dmg);
        } else {
          _hurtTower(tgt as _Tower, p.dmg);
        }
      } else {
        p.pos += d / l * step;
      }
    }
    _projs.removeWhere((p) => p.dead);
  }

  void _ai(double dt) {
    _aiT -= dt * host.speed;
    if (_aiT > 0) return;
    // defend: if a blue unit crossed, answer with a knight / archers next to it
    final intruder = _units.where((u) => u.owner == 1 && u.pos.dy < _riverY + 10).firstOrNull;
    int card;
    Offset at;
    if (intruder != null && _aiElixir >= 3) {
      card = chance(.5) ? 0 : 1;
      at = Offset((intruder.pos.dx + rand(-20, 20)).clamp(30, 330), (intruder.pos.dy - 40).clamp(60, 280));
    } else {
      card = pick(const [0, 1, 2, 0, 1]);
      at = Offset(_bridges[randInt(2)] + rand(-24, 24), rand(190, 250));
    }
    if (_aiElixir < _cost[card]) {
      _aiT = .5;
      return;
    }
    _aiElixir -= _cost[card];
    _deploy(2, card, at);
    _aiT = rand(3.2, 4.6);
  }

  // ------------------------------------------------------------------ input

  @override
  void onDown(Offset p) {
    if (_over) return;
    for (var i = 0; i < 4; i++) {
      if (_cardRect(i).inflate(4).contains(p)) {
        if (_elixir < _cost[i]) {
          host.sfx(Sfx.wrong, volume: .5);
          _cardPop[i] = .6;
          return;
        }
        _dragCard = i;
        _dragPos = p;
        host.sfx(Sfx.select, volume: .7);
        return;
      }
    }
  }

  @override
  void onMove(Offset p) {
    if (_dragCard != null) _dragPos = p;
  }

  bool _validDrop(int card, Offset p) => card == 3 ? (p.dy > 44 && p.dy < 570) : (p.dy > _riverY + 24 && p.dy < 566);

  @override
  void onUp(Offset p) {
    final card = _dragCard;
    _dragCard = null;
    if (card == null) return;
    if (!_validDrop(card, p) || _elixir < _cost[card]) {
      if (p.dy < 570) host.sfx(Sfx.wrong, volume: .5);
      return;
    }
    _elixir -= _cost[card];
    _deploys++;
    _deploy(1, card, Offset(p.dx.clamp(20, 340), p.dy));
    host.punch(.015);
  }

  @override
  void onTimeUp() {
    if (_crownsBlue > _crownsRed) {
      host.fx.confetti();
      host.win(stars: _crownsBlue.clamp(1, 2));
    } else {
      host.lose();
    }
  }

  // ----------------------------------------------------------------- render

  @override
  void render(Canvas c) {
    // grass checker
    final g1 = D.fill(const Color(0xFF7CC860)), g2 = D.fill(const Color(0xFF6DBB52));
    for (var y = 40.0; y < 580; y += 30) {
      for (var x = 0.0; x < 360; x += 30) {
        c.drawRect(Rect.fromLTWH(x, y, 30, 30), (((x + y) / 30).round().isEven) ? g1 : g2);
      }
    }
    // lane paths
    final path = D.fill(const Color(0x44FFF1C8));
    for (final bx in _bridges) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx - 22, 110, 44, 400), const Radius.circular(20)), path);
    }
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(60, 60, 240, 50), const Radius.circular(20)), path);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(60, 500, 240, 50), const Radius.circular(20)), path);
    // river
    c.drawRect(const Rect.fromLTWH(0, _riverY - 16, 360, 32), D.fill(const Color(0xFF3FA9F5)));
    c.drawRect(const Rect.fromLTWH(0, _riverY - 18, 360, 4), D.fill(const Color(0xFF2A7FC0)));
    c.drawRect(const Rect.fromLTWH(0, _riverY + 14, 360, 4), D.fill(const Color(0xFF2A7FC0)));
    final wv = D.stroke(const Color(0x77FFFFFF), 2);
    for (var i = 0; i < 9; i++) {
      final x = (i * 46 + _t * 30) % 400 - 20;
      c.drawArc(Rect.fromCenter(center: Offset(x, _riverY + (i.isEven ? -5 : 6)), width: 16, height: 6), pi, pi, false, wv);
    }
    // bridges
    for (final bx in _bridges) {
      D.rrect(c, Rect.fromLTWH(bx - 22, _riverY - 22, 44, 44), 4, const Color(0xFFB27A45), border: Pal.ink, borderWidth: 2.5);
      for (var k = 0; k < 4; k++) {
        D.line(c, Offset(bx - 20, _riverY - 13 + k * 9.0), Offset(bx + 20, _riverY - 13 + k * 9.0), const Color(0xFF7A4A22), 1.5);
      }
    }
    // deploy zone hint
    if (_dragCard != null && _dragCard != 3) {
      c.drawRect(const Rect.fromLTWH(0, 40, 360, _riverY + 24 - 40), D.fill(const Color(0x55FF2040)));
      for (var x = -40.0; x < 400; x += 24) {
        c.drawLine(Offset(x, 40), Offset(x + 60, _riverY + 24), D.stroke(const Color(0x33FFFFFF), 6));
      }
    }

    // towers + units depth sorted
    final items = <(double, Object)>[
      for (final t in _towers) (t.pos.dy, t),
      for (final u in _units) (u.pos.dy, u),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final it in items) {
      final o = it.$2;
      if (o is _Tower) {
        _drawTower(c, o);
      } else {
        _drawUnit(c, o as _Unit);
      }
    }
    // projectiles
    for (final p in _projs) {
      if (p.kind == 1) {
        final tgt = p.target;
        final tp = tgt is _Unit ? tgt.pos : (tgt as _Tower).pos;
        final d = tp - p.pos;
        final dir = d / max(d.distance, 1);
        D.line(c, p.pos - dir * 8, p.pos, const Color(0xFF7A4A22), 2);
        c.drawCircle(p.pos, 2, D.fill(Pal.white));
      } else {
        D.circle(c, p.pos, 4, Pal.ink);
      }
    }
    // fireball
    if (_fireballFx > 0) {
      final k = _fireballFx / .45;
      c.drawCircle(_fireballAt, 50 * (1.2 - k * .5), D.fill(Color.fromRGBO(255, 140, 40, k * .5)));
      c.drawCircle(_fireballAt, 50 * (1.2 - k * .5), D.stroke(Color.fromRGBO(255, 230, 120, k), 4));
    }

    // drag ghost
    if (_dragCard != null) {
      final ok = _validDrop(_dragCard!, _dragPos);
      final col = ok ? Pal.white : Pal.red;
      if (_dragCard == 3) {
        c.drawCircle(_dragPos, 46, D.fill(const Color(0x33FF8A1F)));
        c.drawCircle(_dragPos, 46, D.stroke(col, 2.5));
        _drawFireballIcon(c, _dragPos, 1);
      } else {
        c.drawCircle(_dragPos, 22, D.stroke(col, 2.5));
        c.save();
        c.translate(_dragPos.dx, _dragPos.dy);
        c.scale(1.2);
        _drawUnitBody(c, Offset.zero, _dragCard!, 1, Face.happy, 0, 1);
        c.restore();
      }
    }

    _drawHud(c);

    if (_deploys == 0 && host.time < 5 && _dragCard == null) {
      final from = _cardRect(2).center;
      const to = Offset(260, 390);
      final k = (_t * .7) % 1;
      D.hand(c, Offset.lerp(from, to, M.easeInOut(M.clamp01(k * 1.4)))!, 0);
      D.text(c, host.tr('drag', 'DRAG!'), const Offset(180, 420), size: 26, color: Pal.yellow, stroke: Pal.ink);
    }
  }

  void _drawHud(Canvas c) {
    // card tray
    D.rrect(c, const Rect.fromLTWH(0, 560, 360, 80), 0, const Color(0xFF3A2A5A));
    c.drawRect(const Rect.fromLTWH(0, 560, 360, 3), D.fill(Pal.ink));
    // elixir bar
    const bar = Rect.fromLTWH(40, 566, 310, 14);
    D.rrect(c, bar, 7, const Color(0xFF1B1530));
    final w = bar.width * _elixir / 10;
    D.rrect(c, Rect.fromLTWH(bar.left, bar.top, max(w, 14), bar.height), 7, _elixirC);
    for (var i = 1; i < 10; i++) {
      c.drawRect(Rect.fromLTWH(bar.left + bar.width * i / 10 - 1, bar.top, 2, bar.height), D.fill(const Color(0x66000000)));
    }
    _drawDrop(c, const Offset(22, 572), 11);
    D.text(c, '${_elixir.floor()}', const Offset(22, 574), size: 13, stroke: Pal.ink);
    for (var i = 0; i < 4; i++) {
      if (_dragCard == i) continue;
      final r = _cardRect(i).translate(0, -_cardPop[i] * 6);
      final can = _elixir >= _cost[i];
      D.rrect(c, r, 8, can ? const Color(0xFF6B8CFF) : const Color(0xFF55506A), border: Pal.ink, borderWidth: 2.5);
      D.rrect(c, Rect.fromLTWH(r.left + 3, r.top + 3, r.width - 6, r.height * .35), 6, const Color(0x33FFFFFF));
      if (i == 3) {
        _drawFireballIcon(c, r.center + const Offset(6, 2), .8);
      } else {
        c.save();
        c.translate(r.center.dx + 6, r.center.dy + (i == 2 ? -2 : 4));
        c.scale(i == 2 ? .75 : 1);
        _drawUnitBody(c, Offset.zero, i, 1, Face.smug, 0, 1);
        if (i == 1) _drawUnitBody(c, const Offset(14, 4), 1, 1, Face.smug, 0, 1);
        c.restore();
      }
      if (!can) {
        final k = (_elixir / _cost[i]).clamp(0.0, 1.0);
        D.rrect(c, Rect.fromLTWH(r.left, r.top, r.width, r.height * (1 - k)), 8, const Color(0x88000000));
      }
      _drawDrop(c, Offset(r.left + 10, r.top + 12), 11);
      D.text(c, '${_cost[i]}', Offset(r.left + 10, r.top + 14), size: 13, stroke: Pal.ink);
    }
    // crowns
    D.rrect(c, const Rect.fromLTWH(262, 42, 92, 30), 15, const Color(0xAA1B1530));
    _drawCrown(c, const Offset(280, 57), _blue);
    D.text(c, '$_crownsBlue', const Offset(298, 57), size: 18, stroke: Pal.ink);
    _drawCrown(c, const Offset(322, 57), _red);
    D.text(c, '$_crownsRed', const Offset(340, 57), size: 18, stroke: Pal.ink);
  }

  void _drawDrop(Canvas c, Offset o, double r) {
    final p = Path()
      ..moveTo(o.dx, o.dy - r * 1.1)
      ..quadraticBezierTo(o.dx + r, o.dy, o.dx + r * .8, o.dy + r * .4)
      ..arcToPoint(Offset(o.dx - r * .8, o.dy + r * .4), radius: Radius.circular(r * .85))
      ..quadraticBezierTo(o.dx - r, o.dy, o.dx, o.dy - r * 1.1)
      ..close();
    c.drawPath(p, D.fill(_elixirC));
    c.drawPath(p, D.stroke(Pal.ink, 2));
  }

  void _drawCrown(Canvas c, Offset o, Color col) {
    final p = Path()
      ..moveTo(o.dx - 9, o.dy + 6)
      ..lineTo(o.dx - 9, o.dy - 5)
      ..lineTo(o.dx - 4.5, o.dy)
      ..lineTo(o.dx, o.dy - 8)
      ..lineTo(o.dx + 4.5, o.dy)
      ..lineTo(o.dx + 9, o.dy - 5)
      ..lineTo(o.dx + 9, o.dy + 6)
      ..close();
    c.drawPath(p, D.fill(col));
    c.drawPath(p, D.stroke(Pal.ink, 2));
  }

  void _drawFireballIcon(Canvas c, Offset o, double s) {
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s);
    c.rotate(-.6);
    D.flame(c, const Offset(0, 16), 34, _t);
    D.circle(c, const Offset(0, 4), 10, Pal.orange, border: Pal.ink, borderWidth: 2);
    c.drawCircle(const Offset(-3, 1), 3.5, D.fill(Pal.yellow));
    c.restore();
  }

  void _drawTower(Canvas c, _Tower t) {
    final o = t.pos;
    final col = t.owner == 1 ? _blue : _red;
    if (t.dead) {
      D.shadow(c, o + const Offset(0, 14), 60, 18, .3);
      for (var i = 0; i < 5; i++) {
        D.rrect(c, Rect.fromCenter(center: o + Offset(-16 + i * 8.0, 8 + (i % 2) * 5.0), width: 14, height: 10), 3,
            const Color(0xFF8E8AA3), border: Pal.ink, borderWidth: 1.5);
      }
      return;
    }
    final w = t.king ? 60.0 : 46.0, h = t.king ? 48.0 : 42.0;
    final sh = t.hit > 0 ? sin(_t * 70) * 2 * t.hit : 0.0;
    D.shadow(c, o + const Offset(0, 16), w + 14, 18, .3);
    final body = Rect.fromCenter(center: o + Offset(sh, 0), width: w, height: h);
    D.rrect(c, body, 8, t.hit > .6 ? Pal.white : const Color(0xFFBDB7CC), border: Pal.ink, borderWidth: 3);
    // bricks
    final bp = D.stroke(const Color(0xFF8E8AA3), 1.5);
    for (var k = 1; k < 3; k++) {
      c.drawLine(Offset(body.left + 4, body.top + k * h / 3), Offset(body.right - 4, body.top + k * h / 3), bp);
    }
    // roof band with team color
    D.rrect(c, Rect.fromLTWH(body.left - 4, body.top - 8, w + 8, 14), 5, col, border: Pal.ink, borderWidth: 2.5);
    for (var k = 0; k < (t.king ? 5 : 4); k++) {
      D.rrect(c, Rect.fromLTWH(body.left - 3 + k * (w + 6) / (t.king ? 5 : 4), body.top - 16, 9, 9), 2, col,
          border: Pal.ink, borderWidth: 2);
    }
    // occupant
    final face = t.hit > .3 ? Face.shocked : (t.hp < t.maxHp * .4 ? Face.cry : (t.owner == 1 ? Face.happy : Face.angry));
    final head = o + Offset(sh, -h / 2 - 16);
    D.blob(c, head, t.king ? 13 : 9, t.king ? Pal.skin : const Color(0xFFFFD1E8), face: face);
    if (t.king) {
      _drawCrown(c, head + const Offset(0, -15), Pal.gold);
    }
    // hp bar
    final bw = w + 6;
    final br = Rect.fromLTWH(o.dx - bw / 2, o.dy + h / 2 + 4, bw, 9);
    D.bar(c, br, t.hp / t.maxHp, col, back: const Color(0xAA1B1530));
    D.text(c, '${t.hp.ceil()}', br.center, size: 9, stroke: Pal.ink, strokeWidth: 2);
  }

  void _drawUnit(Canvas c, _Unit u) {
    final col = u.owner == 1 ? _blue : _red;
    final r = _rad(u.kind);
    c.drawOval(Rect.fromCenter(center: u.pos + Offset(0, r * .8), width: r * 2.4, height: r * .9), D.fill(D.withAlpha(col, .45)));
    c.drawOval(Rect.fromCenter(center: u.pos + Offset(0, r * .8), width: r * 2.4, height: r * .9), D.stroke(col, 2));
    final hop = u.moving ? -(sin(u.anim * 14).abs() * 3) : 0.0;
    final face = u.hit > .5 ? Face.shocked : (u.swing > .5 ? Face.angry : (u.owner == 1 ? Face.happy : Face.angry));
    _drawUnitBody(c, u.pos + Offset(0, hop), u.kind, u.owner, face, u.swing, u.face);
    if (u.hp < u.maxHp) {
      D.bar(c, Rect.fromLTWH(u.pos.dx - r, u.pos.dy - r * 2 - 10, r * 2, 4), u.hp / u.maxHp, col);
    }
  }

  void _drawUnitBody(Canvas c, Offset o, int kind, int owner, Face face, double swing, double dir) {
    final col = owner == 1 ? _blue : _red;
    switch (kind) {
      case 0: // knight
        D.blob(c, o, 11, u2(col), face: face);
        c.drawArc(Rect.fromCircle(center: o + const Offset(0, -4), radius: 11.5), pi, pi, true, D.fill(const Color(0xFFB9C0D0)));
        c.drawArc(Rect.fromCircle(center: o + const Offset(0, -4), radius: 11.5), pi, pi, true, D.stroke(Pal.ink, 2));
        D.rrect(c, Rect.fromLTWH(o.dx - 2, o.dy - 20, 4, 6), 2, col);
        final a = -1.2 + swing * 1.8;
        final hand = o + Offset(10 * dir, 2);
        D.line(c, hand, hand + Offset(cos(a) * 14 * dir, sin(a) * 14), Pal.ink, 4.5);
        D.line(c, hand, hand + Offset(cos(a) * 14 * dir, sin(a) * 14), const Color(0xFFE8E8F0), 2.5);
      case 1: // archer
        D.blob(c, o, 8, const Color(0xFFFFD1A6), face: face);
        c.drawArc(Rect.fromCircle(center: o + const Offset(0, -3), radius: 8.5), pi, pi, true, D.fill(Pal.pink));
        c.drawCircle(o + Offset(-7 * dir, -2), 3.5, D.fill(Pal.pink));
        final bow = Rect.fromCircle(center: o + Offset(9 * dir, 0), radius: 7);
        c.drawArc(bow, dir > 0 ? -1.2 : pi - 1.2, 2.4, false, D.stroke(const Color(0xFF7A4A22), 2.5));
        D.rrect(c, Rect.fromLTWH(o.dx - 5, o.dy + 5, 10, 4), 2, col);
      default: // giant
        D.blob(c, o, 16, const Color(0xFFFFC08A), face: face, squash: 1 + swing * .1);
        D.rrect(c, Rect.fromLTWH(o.dx - 15, o.dy + 4, 30, 6), 3, col, border: Pal.ink, borderWidth: 2);
        c.drawArc(Rect.fromCenter(center: o + const Offset(0, 6), width: 18, height: 12), 0, pi, true, D.fill(const Color(0xFF9A5B34)));
        final fist = o + Offset(16 * dir, 2 - swing * 8);
        D.circle(c, fist, 5.5, const Color(0xFFFFC08A), border: Pal.ink, borderWidth: 2);
    }
  }

  static Color u2(Color team) => Color.lerp(team, Pal.white, .25)!;
}

class _Tower {
  _Tower(this.owner, this.pos, this.king) : maxHp = king ? 230 : 150 {
    hp = maxHp;
  }
  final int owner;
  final Offset pos;
  final bool king;
  final double maxHp;
  double hp = 0;
  double cool = 0;
  double hit = 0;
  bool dead = false;
  double get range => king ? 96 : 112;
  double get radius => king ? 26 : 20;
}

class _Unit {
  _Unit(this.owner, this.kind, this.pos, this.power) : maxHp = [70.0, 26.0, 200.0][kind] * power {
    hp = maxHp;
  }
  final int owner;
  final int kind; // 0 knight, 1 archer, 2 giant
  Offset pos;
  final double power;
  final double maxHp;
  double hp = 0;
  double cool = 0;
  double hit = 0;
  double anim = 0;
  double swing = 0;
  double face = 1;
  bool moving = true;
  bool dead = false;
}

class _Proj {
  _Proj(this.pos, this.target, this.dmg, this.kind);
  Offset pos;
  final Object target;
  final double dmg;
  final int kind;
  bool dead = false;
}
