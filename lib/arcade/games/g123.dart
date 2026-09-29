import '../engine/engine.dart';

/// No.123 Pocket Pet — Tamagotchi parody. A glossy vector egg-device with a
/// dot-matrix LCD. Keep FOOD / FUN / CLEAN up with the three buttons (poop
/// happens!). The pet evolves twice: good care → cute form, neglect → ugly.
/// Cute final form = win.
class G123 extends MiniGame {
  double _t = 0;
  double _food = .55, _fun = .5, _clean = .8;
  final List<double> _poops = []; // x positions on the LCD (0..1)
  double _poopT = 3.2;
  int _stage = 0; // 0 egg, 1 baby, 2 teen, 3 adult
  bool _cuteTeen = true, _cuteAdult = true;
  double _good = 0, _care = 0;
  double _evoT = -1; // evolution flashing
  int _evoFrom = 0, _evoTo = 0;
  double _actT = 0;
  int _act = -1; // 0 feed 1 play 2 clean
  double _petX = .5, _petDir = 1, _hop = 0;
  double _sad = 0;
  final List<double> _press = [0, 0, 0];
  bool _resolved = false;
  double _overfed = 0;
  double _devShake = 0;

  static const _lcd = Rect.fromLTWH(92, 226, 176, 150);
  static const _btn = [Offset(118, 478), Offset(180, 500), Offset(242, 478)];
  static const _lcdBg = Color(0xFFA9C47A);
  static const _ink = Color(0xFF26361C);
  static const _mid = Color(0xFF6E8A54);

  static final Map<String, Color> _pal = {'X': _ink, 'o': _mid, 'w': const Color(0xFFD4E6A8)};
  static final _egg = Sprite(const [
    '......XXXX......',
    '....XXwwwwXX....',
    '...XwwwwwwwwX...',
    '..XwwoowwwwwwX..',
    '..XwwoowwwwwwX..',
    '.XwwwwwwwwoowwX.',
    '.XwwwwwwwwoowwX.',
    '.XwwoowwwwwwwwX.',
    '.XwwoowwwwwwwwX.',
    '.XwwwwwwwoowwwX.',
    '..XwwwwwwoowwX..',
    '...XwwwwwwwwX...',
    '....XXXXXXXX....',
  ], _pal);
  static final _baby = Sprite(const [
    '................',
    '.....XXXXXX.....',
    '...XXwwwwwwXX...',
    '..XwwwwwwwwwwX..',
    '.XwwXXwwwwXXwwX.',
    '.XwwXXwwwwXXwwX.',
    '.XwowwwwwwwwowX.',
    '.XwwwwwXXwwwwwX.',
    '..XwwwwwwwwwwX..',
    '..XXwwwwwwwwXX..',
    '....XXXXXXXX....',
  ], _pal);
  static final _teenCute = Sprite(const [
    '..XX........XX..',
    '..XwX......XwX..',
    '..XwwXXXXXXwwX..',
    '.XwwwwwwwwwwwwX.',
    '.XwwXXwwwwXXwwX.',
    '.XwwXXwwwwXXwwX.',
    '.XowwwwXXwwwwoX.',
    '.XwwwwwwwwwwwwX.',
    '..XwwXXXXXXwwX..',
    '..XwwwwwwwwwwX..',
    '..XwXXwwwwXXwX..',
    '..XX..XXXX..XX..',
  ], _pal);
  static final _teenUgly = Sprite(const [
    '.......XXX......',
    '...XXXXoooXX....',
    '..XoooooooooXX..',
    '.XoXXXoooooooX..',
    '.XoXwXooooXXoX..',
    '.XoXXXooooXXooX.',
    'XooooooooooooooX',
    'XoooXXXXXXXXoooX',
    'XoooXwoXooooXooX',
    '.XooXXXXXXXXoooX',
    '.XooooooooooooX.',
    '..XXXX.XX.XXXX..',
  ], _pal);
  static final _adultCute = Sprite(const [
    '.X....XXXX....X.',
    '.XX.XXwwwwXX.XX.',
    '.XwXwwwwwwwwXwX.',
    '..XwwwwwwwwwwX..',
    '.XwwXXXwwXXXwwX.',
    '.XwXXwXwwXwXXwX.',
    '.XwXXXXwwXXXXwX.',
    'XXowwwwwwwwwwoXX',
    'XwXwwwwXXwwwwXwX',
    'XwwXwwwwwwwwXwwX',
    '.XwwXXXXXXXXwwX.',
    '..XwwwwwwwwwwX..',
    '..XwwwXXXXwwwX..',
    '...XXX....XXX...',
  ], _pal);
  static final _adultUgly = Sprite(const [
    '..X..XXXXXX..X..',
    '...XXooooooXX...',
    '..XooooooooooX..',
    '.XooooXXXXooooX.',
    '.XoooXwwwwXoooX.',
    'XooooXwXXwXooooX',
    'XooooXwwwwXooooX',
    'XoooooXXXXoooooX',
    'XoXooooooooooXoX',
    'XoXXXXXXXXXXXXoX',
    'XooXwXooXwXoXooX',
    '.XoXXXXXXXXXXoX.',
    '.XooooooooooooX.',
    '..XXXX....XXXX..',
  ], _pal);
  static final _poop = Sprite(const [
    '...X...',
    '..XoX..',
    '.XoooX.',
    '.XXXXX.',
    'XoooooX',
    'XXXXXXX',
  ], _pal);
  static final _meat = Sprite(const [
    '..XXXX.',
    '.XooooX',
    'XoooooX',
    'XoooooX',
    '.XoooX.',
    '..XwX..',
    '...Xw..',
    '....XX.',
  ], _pal);
  static final _ball = Sprite(const [
    '..XXX..',
    '.XwoXX.',
    'XwoooXX',
    'XoooXwX',
    'XXXXwwX',
    '.XXwwX.',
    '..XXX..',
  ], _pal);
  static final _heart = Sprite(const [
    '.XX.XX.',
    'XXXXXXX',
    'XXXXXXX',
    '.XXXXX.',
    '..XXX..',
    '...X...',
  ], _pal);

  Sprite get _petSprite => switch (_stage) {
        0 => _egg,
        1 => _baby,
        2 => _cuteTeen ? _teenCute : _teenUgly,
        _ => _cuteAdult ? _adultCute : _adultUgly,
      };

  Sprite _spriteFor(int stage, bool cute) => switch (stage) {
        0 => _egg,
        1 => _baby,
        2 => cute ? _teenCute : _teenUgly,
        _ => cute ? _adultCute : _adultUgly,
      };

  double get _mood => min(_food, min(_fun, _clean));

  // ---------------------------------------------------------------- update
  @override
  void update(double dt) {
    _t += dt;
    _devShake = max(0, _devShake - dt * 3);
    for (var i = 0; i < 3; i++) {
      _press[i] = max(0, _press[i] - dt * 5);
    }
    _overfed = max(0, _overfed - dt);
    if (_act >= 0) {
      _actT += dt;
      if (_actT > .7) _act = -1;
    }
    if (_evoT >= 0) {
      _evoT += dt;
      if (_evoT > 1.6) {
        _evoT = -1;
        host.sfx(Sfx.ssr);
        host.flash(Pal.white, .25);
        host.fx.burst(_lcd.center, Pal.white, count: 24, speed: 300, shape: PartShape.star);
        if (_stage == 3) _resolve();
      }
      return;
    }
    if (host.finished) return;

    // hatch / evolutions on a fixed schedule
    final tm = host.time;
    if (_stage == 0 && tm > 1.3) {
      _stage = 1;
      host.sfx(Sfx.crack);
      host.sfx(Sfx.pPowerup);
      host.fx.pop(host.tr('hatch', 'HATCH!'), const Offset(180, 200), size: 28);
    } else if (_stage == 1 && tm > 7) {
      _evolve(2, _ratio > .55);
    } else if (_stage == 2 && tm > 13.5) {
      _evolve(3, _ratio > .6);
    }
    if (_stage == 0) return;

    // needs drain
    _food = max(0, _food - dt * .085 * host.speed);
    _fun = max(0, _fun - dt * .075 * host.speed);
    _clean = max(0, _clean - dt * (.03 + _poops.length * .07) * host.speed);
    _poopT -= dt;
    if (_poopT <= 0 && _poops.length < 3) {
      _poopT = rand(3, 4.5);
      _poops.add(rand(.62, .9));
      host.sfx(Sfx.pHit, rate: .6);
      host.fx.pop('!', _lcdPoint(.8, .7) + const Offset(0, -30), color: Pal.brown, size: 24);
    }
    _care += dt;
    if (_mood > .3 && _overfed <= 0) _good += dt;
    _sad = M.approach(_sad, _mood < .3 ? 1 : 0, 4, dt);
    // wander
    if (_act < 0) {
      _petX += _petDir * dt * .16;
      if (_petX > .6 || _petX < .28) _petDir = -_petDir;
      _hop += dt * (_mood > .3 ? 6 : 2.5);
    }
  }

  double get _ratio => _care <= 0 ? 1 : _good / _care;

  void _evolve(int to, bool cute) {
    _evoFrom = _stage;
    _evoTo = to;
    _stage = to;
    if (to == 2) {
      _cuteTeen = cute;
    } else {
      _cuteAdult = cute;
    }
    _evoT = 0;
    _devShake = 1;
    host.sfx(Sfx.drumroll);
    host.sfx(Sfx.rarityUp, volume: .7);
    host.fx.pop('?!', const Offset(180, 200), color: Pal.yellow, size: 40);
  }

  void _resolve() {
    if (_resolved) return;
    _resolved = true;
    if (_cuteAdult) {
      host.sfx(Sfx.fanfare);
      host.fx.confetti();
      for (var i = 0; i < 8; i++) {
        host.fx.add(Particle(
            pos: _lcd.center + Offset(rand(-60, 60), 0),
            vel: Offset(rand(-80, 80), rand(-260, -120)),
            life: 1.4,
            color: Pal.pink,
            size: rand(8, 14),
            shape: PartShape.heart,
            gravity: 60));
      }
      host.fx.pop(host.tr('cute', 'CUTE!'), const Offset(180, 190), color: Pal.pink, size: 38, life: 1.5);
      final r = _ratio;
      host.win(stars: r > .8 ? 3 : (r > .7 ? 2 : 1));
    } else {
      host.sfx(Sfx.aww);
      host.fx.pop(host.tr('ugly', 'UGLY...'), const Offset(180, 190), color: Pal.gray, size: 36, life: 1.5);
      host.lose();
    }
  }

  @override
  void onTimeUp() {
    if (!_resolved) {
      _resolved = true;
      _cuteAdult ? host.win(stars: 1) : host.lose();
    }
  }

  void _do(int a) {
    if (host.finished || _evoT >= 0) return;
    _press[a] = 1;
    host.sfx(Sfx.pSelect, volume: .6);
    if (_stage == 0 || _act >= 0) return;
    _act = a;
    _actT = 0;
    final at = _lcdPoint(_petX, .5);
    switch (a) {
      case 0:
        if (_food > .88) {
          _overfed = 2;
          _fun = max(0, _fun - .15);
          _poopT = min(_poopT, .8);
          host.sfx(Sfx.oops);
          host.fx.pop(host.tr('full', 'FULL!'), at + const Offset(0, -50), color: Pal.orange, size: 22);
        } else {
          _food = min(1, _food + .42);
          host.sfx(Sfx.chomp);
          host.fx.pop('+${host.tr('food', 'FOOD')}', at + const Offset(0, -50), color: Pal.orange, size: 18, life: .6);
        }
      case 1:
        _fun = min(1, _fun + .42);
        _food = max(0, _food - .04);
        host.sfx(Sfx.pJump);
        host.fx.pop('+${host.tr('fun', 'FUN')}', at + const Offset(0, -50), color: Pal.pink, size: 18, life: .6);
      case 2:
        final had = _poops.length;
        _poops.clear();
        _clean = 1;
        host.sfx(Sfx.splash);
        host.sfx(Sfx.sparkle, volume: .6);
        host.fx.sparkle(_lcd.center, count: 10, radius: 70, color: Pal.white);
        if (had > 0) host.fx.pop('+${host.tr('clean', 'CLEAN')}', at + const Offset(0, -50), color: Pal.sky, size: 18, life: .6);
    }
    if (_mood > .5) host.fx.add(Particle(pos: at + const Offset(0, -30), vel: const Offset(0, -60), life: .8, color: Pal.pink, size: 10, shape: PartShape.heart));
  }

  @override
  void onDown(Offset p) {
    for (var i = 0; i < 3; i++) {
      if ((p - _btn[i]).distance < 34) {
        _do(i);
        return;
      }
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (key == 'left') _do(0);
    if (key == 'up' || key == 'action') _do(1);
    if (key == 'right') _do(2);
  }

  // ---------------------------------------------------------------- render
  Offset _lcdPoint(double x, double y) => Offset(_lcd.left + _lcd.width * x, _lcd.top + _lcd.height * y);

  @override
  void render(Canvas c) {
    // pastel polka-dot background
    D.gradientBg(c, const [Color(0xFFFFD6EC), Color(0xFFC9E4FF)]);
    final dot = D.fill(const Color(0x33FFFFFF));
    for (var y = 0; y < 14; y++) {
      for (var x = 0; x < 8; x++) {
        c.drawCircle(Offset(x * 50.0 + (y.isEven ? 0 : 25), y * 50.0 + (_t * 10) % 50), 8, dot);
      }
    }
    for (var i = 0; i < 5; i++) {
      final tt = (_t * .15 + i * .2) % 1.0;
      D.heart(c, Offset(30 + i * 75.0, 640 - tt * 700), 16, const Color(0x55FF5FC8));
    }
    final sh = sin(_t * 60) * 5 * _devShake;
    c.save();
    c.translate(sh, 0);
    _renderDevice(c);
    _renderLcd(c);
    c.restore();
    if (host.time < 2.6 && !host.finished) {
      D.hand(c, _btn[0] + const Offset(0, 10), _t);
    }
    // needs legend under the device
    if (_stage > 0 && !host.finished) {
      final low = _mood < .3;
      if (low && (_t * 3).floor().isEven) {
        final idx = _food <= _fun && _food <= _clean ? 0 : (_fun <= _clean ? 1 : 2);
        D.arrow(c, _btn[idx] + const Offset(0, 58), const Offset(0, -1), 30, Pal.red, width: 9);
      }
    }
  }

  void _renderDevice(Canvas c) {
    const o = Offset(180, 350);
    final body = Path()
      ..moveTo(o.dx, o.dy - 230)
      ..cubicTo(o.dx + 150, o.dy - 230, o.dx + 160, o.dy + 20, o.dx + 150, o.dy + 100)
      ..cubicTo(o.dx + 135, o.dy + 220, o.dx + 60, o.dy + 240, o.dx, o.dy + 240)
      ..cubicTo(o.dx - 60, o.dy + 240, o.dx - 135, o.dy + 220, o.dx - 150, o.dy + 100)
      ..cubicTo(o.dx - 160, o.dy + 20, o.dx - 150, o.dy - 230, o.dx, o.dy - 230)
      ..close();
    // chain loop
    c.drawCircle(Offset(o.dx, o.dy - 246), 18, D.stroke(const Color(0xFFD0D6E2), 6));
    c.drawPath(body.shift(const Offset(0, 8)), D.fill(const Color(0x33000000)));
    c.drawPath(
        body,
        Paint()
          ..shader = const RadialGradient(center: Alignment(-.3, -.5), radius: 1, colors: [Color(0xFFFFB3DA), Color(0xFFFF6FB5), Color(0xFFD9408E)])
              .createShader(Rect.fromCenter(center: o, width: 320, height: 480)));
    c.drawPath(body, D.stroke(Pal.ink, 5));
    // gloss
    c.drawOval(Rect.fromCenter(center: o + const Offset(-70, -150), width: 70, height: 36), D.fill(const Color(0x55FFFFFF)));
    // stars stickers
    D.star(c, o + const Offset(96, -150), 14, Pal.yellow, border: Pal.ink);
    D.star(c, o + const Offset(-110, 60), 10, Pal.sky, border: Pal.ink);
    D.heart(c, o + const Offset(108, 70), 18, Pal.white, border: Pal.ink);
    // bezel
    final bez = RRect.fromRectAndRadius(_lcd.inflate(16), const Radius.circular(26));
    c.drawRRect(bez, D.fill(const Color(0xFF3A2A4A)));
    c.drawRRect(bez, D.stroke(Pal.ink, 4));
    // buttons + printed icons
    for (var i = 0; i < 3; i++) {
      final b = _btn[i];
      final pr = _press[i];
      c.drawCircle(b + const Offset(0, 5), 25, D.fill(const Color(0xFF8A2A5A)));
      c.drawCircle(b + Offset(0, pr * 4), 25, D.fill(const [Color(0xFFFFE070), Color(0xFF7FE0FF), Color(0xFFB5F28A)][i]));
      c.drawCircle(b + Offset(0, pr * 4), 25, D.stroke(Pal.ink, 3));
      c.drawOval(Rect.fromCenter(center: b + Offset(-7, -9 + pr * 4), width: 18, height: 9), D.fill(const Color(0x88FFFFFF)));
      final ic = b + Offset(0, pr * 4);
      switch (i) {
        case 0: // drumstick
          c.drawOval(Rect.fromCenter(center: ic + const Offset(-3, -3), width: 20, height: 16), D.fill(const Color(0xFFB0652A)));
          D.line(c, ic + const Offset(4, 4), ic + const Offset(10, 10), Pal.white, 4);
        case 1: // ball
          c.drawCircle(ic, 9, D.fill(Pal.red));
          c.drawArc(Rect.fromCircle(center: ic, radius: 9), 0, pi, true, D.fill(Pal.white));
          c.drawCircle(ic, 9, D.stroke(Pal.ink, 2));
        default: // bubbles
          c.drawCircle(ic + const Offset(-4, 2), 6, D.stroke(const Color(0xFF3D6BFF), 2.5));
          c.drawCircle(ic + const Offset(5, -4), 4, D.stroke(const Color(0xFF3D6BFF), 2.5));
      }
    }
  }

  void _renderLcd(Canvas c) {
    final r = _lcd;
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), D.fill(_lcdBg));
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)));
    // dot matrix grid
    final grid = D.fill(const Color(0x14000000));
    for (var y = r.top; y < r.bottom; y += 4) {
      c.drawRect(Rect.fromLTWH(r.left, y, r.width, 1), grid);
    }
    for (var x = r.left; x < r.right; x += 4) {
      c.drawRect(Rect.fromLTWH(x, r.top, 1, r.height), grid);
    }
    // needs row
    final needs = [_food, _fun, _clean];
    final icons = [_meat, _ball, _heart];
    for (var i = 0; i < 3; i++) {
      final x = r.left + 8 + i * 57.0;
      icons[i].draw(c, Offset(x, r.top + 6), scale: 2);
      for (var s = 0; s < 4; s++) {
        final on = needs[i] > s / 4 + .01;
        final blink = needs[i] < .25 && (_t * 4).floor().isEven;
        c.drawRect(Rect.fromLTWH(x + 17 + s * 8.0, r.top + 9, 6, 8), D.fill(on && !blink ? _ink : const Color(0x22000000)));
      }
    }
    c.drawRect(Rect.fromLTWH(r.left, r.top + 26, r.width, 2), D.fill(_ink));
    // pet
    final ground = r.top + r.height - 18;
    Sprite spr = _petSprite;
    var visible = true;
    if (_evoT >= 0) {
      final flip = (_evoT * (6 + _evoT * 10)).floor().isEven;
      spr = flip ? _spriteFor(_evoFrom, true) : _spriteFor(_evoTo, _evoTo == 2 ? _cuteTeen : _cuteAdult);
      if (_evoFrom == _evoTo) visible = true;
    }
    final hop = _act == 1 ? (sin(_actT * 14).abs() * 14) : (sin(_hop).abs() * (_stage == 0 ? 0 : 4));
    final eggWob = _stage == 0 ? sin(_t * 20) * (host.time > .6 ? 2 : 0) : 0.0;
    final px = _lcd.left + _lcd.width * _petX + eggWob;
    final scale = _stage >= 3 ? 5.0 : 4.0;
    if (visible) {
      spr.draw(c, Offset(px - spr.w * scale / 2, ground - spr.h * scale - hop), scale: scale, flipX: _petDir < 0 && _stage > 0);
    }
    // action props
    if (_act == 0 && _overfed <= 0) {
      final bite = (_actT * 5).floor().clamp(0, 3);
      _meat.draw(c, Offset(px + 34, ground - 30), scale: 3);
      if (bite > 0) c.drawRect(Rect.fromLTWH(px + 34, ground - 30, bite * 5.0, 12), D.fill(_lcdBg));
    } else if (_act == 1) {
      _ball.draw(c, Offset(px + 30 + sin(_actT * 9) * 10, ground - 22 - (sin(_actT * 12).abs() * 40)), scale: 3);
    } else if (_act == 2) {
      final wx = r.left + r.width * M.clamp01(_actT / .6);
      c.drawRect(Rect.fromLTWH(wx - 3, r.top + 30, 6, r.height - 30), D.fill(_ink));
      for (var k = 0; k < 4; k++) {
        c.drawRect(Rect.fromLTWH(wx - 12 - k * 10, r.top + 40 + k * 22, 4, 4), D.fill(_mid));
      }
    }
    // poops with stink lines
    for (final x in _poops) {
      final p = Offset(r.left + r.width * x, ground - 18);
      _poop.draw(c, p, scale: 3);
      for (var k = 0; k < 2; k++) {
        final yy = p.dy - 8 - ((_t * 20 + k * 6) % 12);
        c.drawRect(Rect.fromLTWH(p.dx + 4 + k * 8, yy, 3, 5), D.fill(_mid));
      }
    }
    // mood bubble
    if (_stage > 0 && _evoT < 0) {
      if (_sad > .5 && (_t * 2).floor().isEven) {
        PixelFont.draw(c, _mood == _food ? '!' : (_mood == _fun ? '?' : '#'), Offset(px + 22, ground - 70), 3, _ink);
      } else if (_mood > .6) {
        _heart.draw(c, Offset(px + 22, ground - 72 - sin(_t * 4) * 3), scale: 2);
      }
    }
    if (_evoT >= 0) PixelFont.draw(c, '?!', Offset(r.center.dx, r.top + 36), 4, _ink, align: 0);
    // screen glare
    c.drawPath(
        Path()
          ..moveTo(r.left, r.top)
          ..lineTo(r.left + 60, r.top)
          ..lineTo(r.left, r.top + 60)
          ..close(),
        D.fill(const Color(0x22FFFFFF)));
    c.restore();
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), D.stroke(Pal.ink, 3));
  }
}
