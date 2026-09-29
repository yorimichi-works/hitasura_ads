import 'dart:math' as math;
import 'dart:ui' as ui;

import '../engine/engine.dart';

/// No.020 Last Squad Standing — Last-War style 3D squad shooter.
///
/// Drag left/right to move the squad. It fires automatically. Shoot the
/// upgrade gates to raise their numbers, then walk through the best one
/// (+soldiers or +fire rate). Blow up red barrels, hold back the zombie horde
/// and take down the giant boss zombie before it reaches you.
class G020 extends MiniGame {
  final scene = Scene3();
  static const _roadHalf = 4.0;
  static const _bulletSpeed = 34.0;

  double _t = 0;
  double _squadX = 0;
  double _targetX = 0;
  int _soldiers = 3;
  double _rate = 2.6; // shots per soldier per second
  double _fireAcc = 0;
  double _scroll = 0;
  double _spawnClock = .6;
  double _dragAnchor = 0;
  double _dragSquad = 0;
  bool _moved = false;
  double _hurt = 0;
  double _gateBanner = 0;
  _Zombie? _boss;
  bool _bossSpawned = false;
  bool _bossDead = false;
  double _muzzle = 0;

  final List<_Zombie> _zombies = [];
  final List<_Bullet> _bullets = [];
  final List<_GatePair> _gates = [];
  final List<_Barrel> _barrels = [];
  final List<_Prop> _props = [];

  // meshes (built once)
  late final Mesh _road;
  late final Mesh _side;
  late final Mesh _soldier;
  late final Mesh _zombie;
  late final Mesh _bossMesh;
  late final Mesh _barrel;
  late final Mesh _car;
  late final Mesh _barrier;
  late final Mesh _post;
  late final Mesh _panel;
  late final Mesh _deadTree;

  @override
  void init() {
    scene
      ..ambient = .5
      ..diffuse = .6
      ..light = const V3(-.5, 1, -.6).normalized
      ..fogColor = const Color(0xFF3A2440)
      ..fogNear = 22
      ..fogFar = 46;
    _road = Mesh.grid(_roadHalf * 2, 60, 4, 30, (i, j) {
      final lane = i == 1 || i == 2;
      final dark = j.isEven;
      return lane
          ? (dark ? const Color(0xFF4A4A58) : const Color(0xFF55556A))
          : (dark ? const Color(0xFF414150) : const Color(0xFF4C4C5E));
    });
    _side = Mesh.grid(8, 60, 2, 15, (i, j) => (i + j).isEven ? const Color(0xFF5A4A3A) : const Color(0xFF65533F));
    const army = Color(0xFF3D7BFF);
    _soldier = Mesh.merge([
      (Models.person(army, pants: const Color(0xFF2A3A5A)), V3.zero),
      (Mesh.box(.5, .2, .5, const Color(0xFF2E5A2E)), const V3(0, 1.82, 0)), // helmet
      (Mesh.box(.14, .14, .8, const Color(0xFF222230)), const V3(.22, 1.05, .45)), // rifle
    ]);
    const zskin = Color(0xFF8FC45A);
    Mesh zombieOf(Color shirt, Color skin) => Mesh.merge([
          (Models.person(shirt, skin: skin, pants: const Color(0xFF4A3F5A)), V3.zero),
          (Mesh.box(.16, .16, .7, skin), const V3(-.32, 1.15, .38)),
          (Mesh.box(.16, .16, .7, skin), const V3(.32, 1.15, .38)),
          (Mesh.box(.1, .1, .05, const Color(0xFFFF3030)), const V3(-.1, 1.6, .22)),
          (Mesh.box(.1, .1, .05, const Color(0xFFFF3030)), const V3(.1, 1.6, .22)),
        ]);
    _zombie = zombieOf(const Color(0xFF7A6A52), zskin);
    _bossMesh = zombieOf(const Color(0xFF6A2A5A), const Color(0xFF6AA84A));
    _barrel = Mesh.merge([
      (Mesh.cylinder(.42, 1.0, const Color(0xFFE0302E), seg: 10, cap: const Color(0xFFB02020)), const V3(0, .5, 0)),
      (Mesh.cylinder(.44, .1, const Color(0xFFFFD23F), seg: 10), const V3(0, .7, 0)),
    ]);
    _car = Mesh.merge([
      (Models.car(const Color(0xFF6A5A5A), glass: const Color(0xFF2A2A3A)), V3.zero),
    ]);
    _barrier = Mesh.merge([
      (Mesh.box(1.6, .5, .3, const Color(0xFFFF8A1F)), const V3(0, .7, 0)),
      (Mesh.box(.12, .7, .12, const Color(0xFF444444)), const V3(-.6, .35, 0)),
      (Mesh.box(.12, .7, .12, const Color(0xFF444444)), const V3(.6, .35, 0)),
    ]);
    _post = Mesh.box(.22, 2.4, .22, const Color(0xFFDDE3F0));
    _panel = Mesh.box(1, 1, .08, const Color(0xFFFFFFFF));
    _deadTree = Mesh.merge([
      (Mesh.cylinder(.14, 2.2, const Color(0xFF3A2A22), seg: 5), const V3(0, 1.1, 0)),
      (Mesh.box(.9, .1, .1, const Color(0xFF3A2A22)), const V3(.3, 1.8, 0)),
    ]);
    for (var i = 0; i < 14; i++) {
      _props.add(_Prop(chance(.5) ? -1 : 1, i * 4.0 + rand(0, 2), randInt(3), rand(0, 6)));
    }
    // gate schedule
    _gates.add(_GatePair(30, _gateOptions(0)));
    _gates.add(_GatePair(30, _gateOptions(1))..spawnAt = 5.4);
    _barrels.add(_Barrel(-1.8, 20));
    _barrels.add(_Barrel(2.0, 34));
  }

  List<_GateSide> _gateOptions(int n) {
    final a = _GateSide(true, n == 0 ? -rand(1, 3).roundToDouble() : rand(1, 2).roundToDouble());
    final b = _GateSide(false, n == 0 ? rand(10, 20).roundToDouble() : -rand(8, 16).roundToDouble());
    return chance(.5) ? [a, b] : [b, a];
  }

  // ------------------------------------------------------------ update ---

  double get _scrollSpeed => 3.2 * host.speed;

  @override
  void update(double dt) {
    _t += dt;
    final sp = host.speed;
    _hurt = M.approach(_hurt, 0, 4, dt);
    _gateBanner = math.max(0, _gateBanner - dt);
    _muzzle = M.approach(_muzzle, 0, 20, dt);
    _squadX = M.approach(_squadX, _targetX, 14, dt);
    final scroll = host.finished ? _scrollSpeed * .2 : _scrollSpeed;
    _scroll += scroll * dt;

    for (final p in _props) {
      p.z -= scroll * dt;
      if (p.z < -4) p.z += 56;
    }

    if (!host.finished) {
      // zombie spawns (the horde grows)
      _spawnClock -= dt * sp;
      if (_spawnClock <= 0) {
        final n = 1 + (_t > 6 ? 1 : 0) + (_t > 13 ? 1 : 0);
        for (var i = 0; i < n; i++) {
          _zombies.add(_Zombie(rand(-_roadHalf + .6, _roadHalf - .6), 40 + rand(0, 6), hp: 3 + (_t > 9 ? 1 : 0)));
        }
        _spawnClock = math.max(.5, 1.05 - _t * .025);
      }
      if (!_bossSpawned && _t >= 9.5) {
        _bossSpawned = true;
        _boss = _Zombie(0, 32, hp: 110, boss: true);
        _zombies.add(_boss!);
        host.sfx(Sfx.horror);
        host.sfx(Sfx.hitHeavy, volume: .6);
        host.shake(8, .6);
        host.flash(const Color(0xFF8C1030), .25);
      }
      // firing
      _fireAcc += dt * _rate * _soldiers;
      var shots = 0;
      while (_fireAcc >= 1) {
        _fireAcc -= 1;
        final i = randInt(_soldiers);
        final off = _formation(i);
        _bullets.add(_Bullet(_squadX + off.x + .22, off.z + .9));
        shots++;
      }
      if (shots > 0) {
        _muzzle = 1;
        if (chance(.35)) host.sfx(Sfx.shoot, volume: .22, rate: rand(1.3, 1.7));
      }
    }

    // bullets
    for (var i = _bullets.length - 1; i >= 0; i--) {
      final b = _bullets[i];
      final prevZ = b.z;
      b.z += _bulletSpeed * dt;
      var hit = false;
      // gates
      for (final g in _gates) {
        if (!g.active || g.passed) continue;
        if (prevZ <= g.z && b.z >= g.z) {
          final side = b.x < 0 ? 0 : 1;
          final gs = g.sides[side];
          gs.value += gs.soldiers ? .25 : 1.5;
          gs.flash = 1;
          hit = true;
          if (chance(.3)) host.sfx(Sfx.tick, volume: .35, rate: 1.4 + (gs.value > 0 ? .3 : 0));
          break;
        }
      }
      if (!hit) {
        for (final z in _zombies) {
          if (z.dead) continue;
          final r = z.boss ? 1.3 : .5;
          if ((b.x - z.x).abs() < r && b.z >= z.z - .3 && prevZ <= z.z + .3) {
            _damageZombie(z, 1);
            hit = true;
            break;
          }
        }
      }
      if (!hit) {
        for (final br in _barrels) {
          if (br.dead || br.z > 40) continue;
          if ((b.x - br.x).abs() < .5 && b.z >= br.z - .3 && prevZ <= br.z + .3) {
            br.hp--;
            br.flash = 1;
            hit = true;
            host.sfx(Sfx.clang, volume: .4, rate: 1.4);
            if (br.hp <= 0) _explodeBarrel(br);
            break;
          }
        }
      }
      if (hit || b.z > 46) _bullets.removeAt(i);
    }

    // zombies
    for (var i = _zombies.length - 1; i >= 0; i--) {
      final z = _zombies[i];
      z.flash = math.max(0, z.flash - dt * 6);
      if (z.dead) {
        z.deadT += dt;
        z.z -= scroll * dt;
        if (z.deadT > .7) _zombies.removeAt(i);
        continue;
      }
      z.anim += dt * 7;
      if (host.finished) continue;
      final walk = (z.boss ? 1.25 : 1.1 + (z.x.abs() * .05)) * sp;
      z.z -= (scroll + walk) * dt * (z.boss ? .74 : 1);
      // shamble toward the squad
      z.x += ((_squadX - z.x).sign * .45 * sp * dt) * (z.boss ? .4 : 1);
      if (z.z < 1.0) {
        final contact = (z.x - _squadX).abs() < (z.boss ? 3.5 : 1.3);
        if (contact) {
          if (z.boss) {
            _soldiers = 0;
          } else {
            _soldiers--;
            z.dead = true;
          }
          _hurt = 1;
          host.sfx(Sfx.hurt);
          host.sfx(Sfx.splat, volume: .7);
          host.shake(8);
          host.flash(Pal.red, .15);
          final p = scene.cam.project(V3(_squadX, 1, .5));
          if (p != null) host.fx.pop('-1', p + const Offset(0, -40), color: Pal.red, size: 28);
          if (_soldiers <= 0) {
            _soldiers = 0;
            host.sfx(Sfx.jingleLose);
            host.lose();
          }
        } else if (z.z < -2) {
          _zombies.removeAt(i);
        }
      }
    }

    // gates
    for (final g in _gates) {
      if (!g.active && _t >= g.spawnAt && !host.finished) {
        g.active = true;
        g.z = 28;
      }
      if (!g.active || g.passed) continue;
      g.z -= scroll * dt;
      for (final s in g.sides) {
        s.flash = M.approach(s.flash, 0, 10, dt);
      }
      if (g.z <= .4) {
        g.passed = true;
        final side = _squadX < 0 ? 0 : 1;
        final s = g.sides[side];
        g.chosen = side;
        _applyGate(s);
      }
    }
    _gates.removeWhere((g) => g.passed && g.z < -6);
    for (final g in _gates.where((g) => g.passed)) {
      g.z -= scroll * dt;
    }

    // barrels
    for (final br in _barrels) {
      br.flash = M.approach(br.flash, 0, 10, dt);
      if (br.dead) continue;
      br.z -= scroll * dt;
      if (br.z < -2) br.dead = true;
    }

    if (_boss != null && _boss!.dead && !_bossDead) {
      _bossDead = true;
      host.sfx(Sfx.explode);
      host.sfx(Sfx.fanfare);
      host.hitStop(.15);
      host.shake(18, .7);
      host.flash(Pal.white, .25);
      host.fx.confetti();
      final p = scene.cam.project(V3(_boss!.x, 2.5, _boss!.z));
      if (p != null) {
        host.fx.coins(p, count: 24);
        host.fx.burst(p, Pal.lime, count: 40, speed: 420, size: 9, colors: const [Pal.lime, Pal.green, Pal.yellow]);
        host.fx.pop('KO!', p + const Offset(0, -60), color: Pal.yellow, size: 48, life: 1.2);
      }
      host.addScore(500);
      host.win(stars: _soldiers >= 8 ? 3 : (_soldiers >= 4 ? 2 : 1));
    }
  }

  V3 _formation(int i) {
    const cols = 4;
    final row = i ~/ cols;
    final inRow = math.min(cols, _soldiers - row * cols);
    final col = i % cols;
    return V3((col - (inRow - 1) / 2) * .5, 0, -row * .55);
  }

  void _damageZombie(_Zombie z, int dmg) {
    z.hp -= dmg;
    z.flash = 1;
    if (z.hp <= 0) {
      z.dead = true;
      final p = scene.cam.project(V3(z.x, 1.2, z.z));
      if (p != null && !z.boss) {
        host.fx.burst(p, Pal.lime, count: 8, speed: 140, size: 5, colors: const [Pal.lime, Color(0xFF6AA84A), Pal.red]);
        host.addScore(10);
      }
      if (!z.boss) host.sfx(Sfx.squish, volume: .5, rate: rand(.9, 1.3));
    } else if (z.boss && chance(.2)) {
      host.sfx(Sfx.hit, volume: .4, rate: rand(.6, .8));
    }
  }

  void _explodeBarrel(_Barrel br) {
    br.dead = true;
    host.sfx(Sfx.explode);
    host.shake(12, .4);
    host.hitStop(.06);
    final p = scene.cam.project(V3(br.x, .6, br.z));
    if (p != null) {
      host.fx.burst(p, Pal.orange, count: 30, speed: 360, size: 9, gravity: -60,
          colors: const [Pal.yellow, Pal.orange, Pal.red, Color(0xFF444444)]);
      host.fx.ring(p, Pal.yellow, size: 120, life: .4);
      host.fx.smoke(p, count: 8, size: 26, color: const Color(0xAA444450));
    }
    var kills = 0;
    for (final z in _zombies) {
      if (z.dead) continue;
      final d = math.sqrt((z.x - br.x) * (z.x - br.x) + (z.z - br.z) * (z.z - br.z));
      if (d < 3.4) {
        if (z.boss) {
          z.hp -= 30;
          z.flash = 1;
          if (z.hp <= 0) z.dead = true;
        } else {
          z.dead = true;
          kills++;
        }
      }
    }
    if (kills > 0 && p != null) {
      host.fx.pop('x$kills ${host.tr('ko', 'KO')}', p + const Offset(0, -50), color: Pal.yellow, size: 28);
      host.addScore(kills * 20);
    }
  }

  void _applyGate(_GateSide s) {
    final v = s.value.round();
    final p = scene.cam.project(V3(_squadX, 2.5, .5)) ?? const Offset(180, 400);
    _gateBanner = 1.2;
    if (s.soldiers) {
      final before = _soldiers;
      _soldiers = (_soldiers + v).clamp(1, 16);
      final gain = _soldiers - before;
      if (gain > 0) {
        host.sfx(Sfx.powerup);
        host.sfx(Sfx.cheer, volume: .5);
        host.fx.pop('+$gain', p, color: Pal.sky, size: 40, life: 1);
        host.fx.burst(p, Pal.sky, count: 24, speed: 300, shape: PartShape.star, colors: const [Pal.sky, Pal.white]);
        host.punch(.04);
      } else {
        host.sfx(Sfx.wrong);
        host.fx.pop('$gain', p, color: Pal.red, size: 40, life: 1);
        host.shake(6);
      }
    } else {
      final k = 1 + v / 100;
      _rate = (_rate * k).clamp(1.2, 12);
      if (v >= 0) {
        host.sfx(Sfx.levelup);
        host.fx.pop('+$v%', p, color: Pal.yellow, size: 40, life: 1);
        host.fx.burst(p, Pal.yellow, count: 24, speed: 300, shape: PartShape.star, colors: const [Pal.yellow, Pal.white]);
        host.punch(.04);
      } else {
        host.sfx(Sfx.wrong);
        host.fx.pop('$v%', p, color: Pal.red, size: 40, life: 1);
        host.shake(6);
      }
    }
  }

  // ------------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    _dragAnchor = p.dx;
    _dragSquad = _targetX;
  }

  @override
  void onMove(Offset p) {
    if (host.finished) return;
    _moved = true;
    _targetX = (_dragSquad + (p.dx - _dragAnchor) / 40).clamp(-_roadHalf + .7, _roadHalf - .7);
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'left') _targetX = math.max(-_roadHalf + .7, _targetX - 1.2);
    if (key == 'right') _targetX = math.min(_roadHalf - .7, _targetX + 1.2);
    _moved = true;
  }

  @override
  void onTimeUp() {
    if (_soldiers > 0) {
      host.sfx(Sfx.jingleWin);
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    // apocalyptic dusk sky
    D.gradientBg(c, const [Color(0xFF1E1030), Color(0xFF5A2440), Color(0xFFC8583A), Color(0xFF3A2440)],
        rect: const Rect.fromLTWH(0, 0, 360, 260));
    c.drawRect(const Rect.fromLTWH(0, 258, 360, 400), D.fill(const Color(0xFF3A2440)));
    // sun
    c.drawCircle(const Offset(250, 196), 46, Paint()
      ..shader = ui.Gradient.radial(const Offset(250, 196), 46, [const Color(0xFFFFB070), const Color(0x00FF7040)]));
    c.drawCircle(const Offset(250, 196), 22, D.fill(const Color(0xFFFFC890)));
    // ruined skyline
    final sky = Paint()..color = const Color(0xFF26142E);
    for (var i = 0; i < 14; i++) {
      final w = 20.0 + (i * 13 % 18);
      final h = 26.0 + (i * 37 % 60);
      final x = i * 27.0 - 6;
      c.drawRect(Rect.fromLTWH(x, 250 - h, w, h + 10), sky);
      if (i % 3 == 0) {
        c.drawRect(Rect.fromLTWH(x + 4, 250 - h + 6, 3, 3), D.fill(const Color(0x88FFB070)));
      }
    }

    scene.clear();
    scene.cam
      ..center = const Offset(180, 350)
      ..focal = 430
      ..pos = V3(_squadX * .35, 8.2, -9.5)
      ..lookAt(V3(_squadX * .25, 0, 9));

    final roadOff = -(_scroll % 2);
    scene.add(_road, pos: V3(0, 0, 25 + roadOff));
    scene.add(_side, pos: V3(-_roadHalf - 4, -.02, 25 + roadOff));
    scene.add(_side, pos: V3(_roadHalf + 4, -.02, 25 + roadOff));

    for (final p in _props) {
      final x = p.side * (_roadHalf + 1.6 + p.jit * .3);
      switch (p.kind) {
        case 0:
          scene.add(_car, pos: V3(x, 0, p.z), rotY: p.jit, scale: .8);
        case 1:
          scene.add(_barrier, pos: V3(p.side * (_roadHalf + .6), 0, p.z), rotY: .2 * p.side);
        default:
          scene.add(_deadTree, pos: V3(x + p.side * 1.2, 0, p.z), rotY: p.jit);
      }
    }

    // gates
    for (final g in _gates) {
      if (!g.active) continue;
      for (var s = 0; s < 2; s++) {
        final gs = g.sides[s];
        final cx = s == 0 ? -2.0 : 2.0;
        final good = gs.value >= 0;
        final dim = g.passed && g.chosen != s;
        final col = good ? const Color(0xFF3FA8FF) : const Color(0xFFFF3B5C);
        scene.add(_post, pos: V3(cx - 1.85, 1.2, g.z));
        scene.add(_post, pos: V3(cx + 1.85, 1.2, g.z));
        scene.add(_panel, pos: V3(cx, 1.3, g.z), scale3: const V3(3.5, 1.9, 1),
            tint: col, flash: gs.flash * .5, alpha: dim ? .2 : .72);
        final gateSide = gs;
        scene.addSprite(V3(cx, 1.45, g.z - .1), (c, pos, sc) {
          if (dim) return;
          _gateLabel(c, pos, sc, gateSide);
        });
      }
    }

    // barrels
    for (final br in _barrels) {
      if (br.dead) continue;
      scene.add(_barrel, pos: V3(br.x, 0, br.z), flash: br.flash);
    }

    // zombies
    for (final z in _zombies) {
      final s = z.boss ? 2.4 : 1.0;
      final fall = z.dead ? math.min(1.4, z.deadT * 4) : 0.0;
      final sink = z.dead ? z.deadT * 1.2 : 0.0;
      scene.add(z.boss ? _bossMesh : _zombie,
          pos: V3(z.x, -sink, z.z),
          rotY: math.pi,
          rotX: -fall,
          rotZ: z.dead ? 0 : math.sin(z.anim) * .12,
          scale: s,
          flash: z.flash * .8);
    }

    // squad
    for (var i = 0; i < _soldiers; i++) {
      final f = _formation(i);
      final bob = math.sin(_t * 12 + i) * .05;
      scene.add(_soldier, pos: V3(_squadX + f.x, bob.abs(), f.z), scale: .72, flash: _hurt * .6, tint: _hurt > .3 ? Pal.red : null);
    }

    // bullets
    for (final b in _bullets) {
      scene.addSprite(V3(b.x, 1.05, b.z), (c, pos, sc) {
        final len = math.max(3.0, sc * .6);
        c.drawLine(pos, pos + Offset(0, len), D.stroke(const Color(0xAAFFE27A), math.max(1.5, sc * .07)));
        c.drawCircle(pos, math.max(1.5, sc * .05), D.fill(Pal.white));
      });
    }

    scene.render(c);

    // muzzle flashes
    if (_muzzle > .3 && !host.finished) {
      for (var i = 0; i < math.min(_soldiers, 6); i++) {
        final f = _formation(i);
        final p = scene.cam.project(V3(_squadX + f.x + .22, 1.05, f.z + .9));
        if (p != null) D.star(c, p, 5 + _muzzle * 5, const Color(0xCCFFE27A), rotation: _t * 20);
      }
    }

    // boss hp bar
    final boss = _boss;
    if (boss != null && !boss.dead) {
      final bp = scene.cam.project(V3(boss.x, 5.4, boss.z));
      if (bp != null) {
        D.bar(c, Rect.fromCenter(center: bp, width: 90, height: 10), boss.hp / boss.maxHp, Pal.red, border: Pal.ink);
      }
      D.rrect(c, const Rect.fromLTWH(40, 98, 280, 30), 12, const Color(0xCC1B1530));
      D.text(c, host.tr('boss', 'BOSS'), const Offset(72, 113), size: 16, color: Pal.red, stroke: Pal.ink);
      D.bar(c, const Rect.fromLTWH(102, 106, 206, 14), boss.hp / boss.maxHp, const Color(0xFFB03A8A), border: Pal.ink);
    }

    // HUD
    D.rrect(c, const Rect.fromLTWH(10, 42, 340, 50), 16, const Color(0xCC1B1530), border: const Color(0xFF6A5A8A), borderWidth: 2);
    // soldier icon
    D.circle(c, const Offset(40, 67), 13, const Color(0xFF3D7BFF), border: Pal.ink, borderWidth: 2.5);
    c.drawArc(Rect.fromCircle(center: const Offset(40, 64), radius: 13), math.pi, math.pi, true,
        D.fill(const Color(0xFF2E5A2E)));
    D.text(c, 'x$_soldiers', const Offset(62, 67), size: 26, color: Pal.white, stroke: Pal.ink, strokeWidth: 6,
        anchor: Alignment.centerLeft);
    // fire rate icon (bullets)
    for (var i = 0; i < 3; i++) {
      D.rrect(c, Rect.fromLTWH(196 + i * 8.0, 56, 6, 20), 3, Pal.yellow, border: Pal.ink, borderWidth: 1.5);
    }
    final rw = D.text(c, (_rate * _soldiers).toStringAsFixed(0), const Offset(228, 67), size: 26, color: Pal.yellow,
        stroke: Pal.ink, strokeWidth: 6, anchor: Alignment.centerLeft);
    D.text(c, '/s', Offset(230 + rw.width, 72), size: 14, color: const Color(0xFFCFC6E6), anchor: Alignment.centerLeft);

    // red vignette on hurt
    if (_hurt > .05) {
      c.drawRect(
          const Rect.fromLTWH(0, 0, 360, 640),
          Paint()
            ..shader = ui.Gradient.radial(const Offset(180, 380), 360,
                [const Color(0x00FF0000), Color.fromRGBO(255, 0, 40, .55 * _hurt)], [.5, 1]));
    }

    // tutorial
    if (!_moved && _t < 4 && !host.finished) {
      final x = 180 + math.sin(_t * 3) * 70;
      D.hand(c, Offset(x, 560), _t * 0);
      D.arrow(c, const Offset(92, 590), const Offset(-1, 0), 44, Pal.white, width: 9);
      D.arrow(c, const Offset(268, 590), const Offset(1, 0), 44, Pal.white, width: 9);
    }
  }

  void _gateLabel(Canvas c, Offset pos, double sc, _GateSide gs) {
    final k = (sc / 30).clamp(.35, 1.8);
    final v = gs.value.round();
    final txt = gs.soldiers ? (v >= 0 ? '+$v' : '$v') : (v >= 0 ? '+$v%' : '$v%');
    c.save();
    c.translate(pos.dx, pos.dy);
    c.scale(k * (1 + gs.flash * .15));
    if (gs.soldiers) {
      D.circle(c, const Offset(-38, 0), 11, const Color(0xFF3D7BFF), border: Pal.ink, borderWidth: 2.5);
      c.drawArc(Rect.fromCircle(center: const Offset(-38, -3), radius: 11), math.pi, math.pi, true,
          D.fill(const Color(0xFF2E5A2E)));
    } else {
      for (var i = 0; i < 3; i++) {
        D.rrect(c, Rect.fromLTWH(-50 + i * 7.0, -9, 5, 18), 2.5, Pal.yellow, border: Pal.ink, borderWidth: 1.5);
      }
    }
    D.text(c, txt, const Offset(12, 0), size: 30, color: Pal.white, stroke: Pal.ink, strokeWidth: 7);
    c.restore();
  }
}

class _Zombie {
  _Zombie(this.x, this.z, {required this.hp, this.boss = false}) : maxHp = hp;
  double x, z;
  int hp;
  final int maxHp;
  final bool boss;
  double anim = 0;
  double flash = 0;
  bool dead = false;
  double deadT = 0;
}

class _Bullet {
  _Bullet(this.x, this.z);
  final double x;
  double z;
}

class _GateSide {
  _GateSide(this.soldiers, this.value);
  final bool soldiers;
  double value;
  double flash = 0;
}

class _GatePair {
  _GatePair(this.z, this.sides);
  double z;
  final List<_GateSide> sides;
  double spawnAt = .3;
  bool active = false;
  bool passed = false;
  int chosen = -1;
}

class _Barrel {
  _Barrel(this.x, this.z);
  final double x;
  double z;
  int hp = 3;
  bool dead = false;
  double flash = 0;
}

class _Prop {
  _Prop(this.side, this.z, this.kind, this.jit);
  final int side;
  double z;
  final int kind;
  final double jit;
}
