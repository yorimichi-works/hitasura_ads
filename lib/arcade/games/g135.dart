import '../engine/engine.dart';

/// No.135 CAPTCHA Hell — prove you're not a robot. Three escalating image
/// challenges; the last one asks you to find the robot... in the mirror.
class G135 extends MiniGame {
  static const _gx = 30.0, _gy = 176.0, _ts = 98.0, _gap = 4.0;
  static const _verifyR = Rect.fromLTWH(222, 490, 112, 42);
  static const _checkR = Rect.fromLTWH(40, 262, 44, 44);
  static const _blue = Color(0xFF4A90E2);

  int _stage = 0; // 0 checkbox, 1..3 rounds, 4 passed
  double _stageT = 0;
  bool _checking = false;
  final List<_Tile> _tiles = [];
  int _mistakes = 0;
  double _robot = 62; // robot probability %
  double _robotShown = 62;
  double _t = 0;
  double _shakeCard = 0;
  double _replaceChance = .5;
  double _verifyPress = 0;
  String _banner = '';
  double _bannerT = 9;

  static const _kLight = 0, _kBus = 1, _kMirror = 8;

  @override
  void init() {}

  // ------------------------------------------------------------ rounds ---

  void _startRound(int r) {
    _stage = r;
    _stageT = 0;
    _tiles.clear();
    final kinds = List<int>.filled(9, 0);
    if (r == 1) {
      final n = 3 + randInt(2);
      final pos = List<int>.generate(9, (i) => i)..shuffle(rng);
      for (var i = 0; i < 9; i++) {
        kinds[pos[i]] = i < n ? _kLight : 2 + randInt(6);
      }
    } else if (r == 2) {
      final pos = List<int>.generate(9, (i) => i)..shuffle(rng);
      for (var i = 0; i < 9; i++) {
        kinds[pos[i]] = i < 3 ? _kBus : 2 + randInt(6);
      }
      _replaceChance = .35;
    } else {
      final m = randInt(9);
      for (var i = 0; i < 9; i++) {
        kinds[i] = i == m ? _kMirror : 1 + randInt(7);
      }
    }
    for (var i = 0; i < 9; i++) {
      _tiles.add(_Tile(kinds[i], rng.nextDouble())..appear = -i * .04);
    }
    host.sfx(Sfx.open, volume: .6);
  }

  int get _targetKind => _stage == 1 ? _kLight : (_stage == 2 ? _kBus : _kMirror);

  // ------------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    if (host.finished) return;
    if (_stage == 0) {
      if (!_checking && _checkR.inflate(40).contains(p)) {
        _checking = true;
        _stageT = 0;
        host.sfx(Sfx.click);
      }
      return;
    }
    if (_stage > 3 || _stageT < .15) return;
    if (_verifyR.inflate(6).contains(p)) {
      _verify();
      return;
    }
    for (var i = 0; i < 9; i++) {
      if (!_tileRect(i).inflate(_gap / 2).contains(p)) continue;
      final tl = _tiles[i];
      if (tl.leaving > 0 || tl.appear < .6) return;
      if (_stage == 2) {
        if (tl.kind == _kBus) {
          tl.leaving = .001;
          tl.selected = true;
          host.sfx(Sfx.select, rate: 1.2);
          host.fx.sparkle(_tileRect(i).center, count: 5, radius: 30, color: _blue);
        } else {
          tl.shake = 1;
          _oops(_tileRect(i).center);
        }
        return;
      }
      tl.selected = !tl.selected;
      tl.bump = 1;
      host.sfx(tl.selected ? Sfx.select : Sfx.back, volume: .7, rate: tl.selected ? 1.1 : .9);
      if (tl.selected && tl.kind == _kMirror) {
        host.sfx(Sfx.glitch, volume: .6);
        host.fx.pop('?!', _tileRect(i).center + const Offset(0, -40), color: Pal.red, size: 30);
      }
      return;
    }
  }

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action') {
      if (_stage == 0) {
        onDown(_checkR.center);
      } else {
        _verify();
      }
    }
  }

  void _oops(Offset at) {
    _mistakes++;
    _robot = min(99, _robot + 12);
    host.sfx(Sfx.buzzer, volume: .7);
    host.shake(5);
    host.fx.pop(host.tr('oops', 'OOPS'), at, color: Pal.red, size: 24);
  }

  void _verify() {
    if (_stage < 1 || _stage > 3) return;
    _verifyPress = 1;
    host.sfx(Sfx.tap);
    var ok = true;
    for (final tl in _tiles) {
      if (_stage == 2) {
        if (tl.kind == _kBus && tl.leaving == 0) ok = false;
        if (tl.leaving > 0) ok = false; // still animating
      } else if (tl.selected != (tl.kind == _targetKind)) {
        ok = false;
      }
    }
    if (ok) {
      _robot = max(1, _robot - (_stage == 3 ? 60 : 18));
      host.sfx(Sfx.correct, rate: 1 + _stage * .1);
      host.fx.burst(_verifyR.center, Pal.green, count: 16, shape: PartShape.star, speed: 220);
      if (_stage == 3) {
        _stage = 4;
        _stageT = 0;
        _banner = host.tr('human_probably', 'Human. Probably.');
        _bannerT = 0;
        host.sfx(Sfx.fanfare);
        host.fx.confetti(count: 60);
        host.win(stars: _mistakes == 0 ? 3 : (_mistakes <= 2 ? 2 : 1));
      } else {
        _startRound(_stage + 1);
      }
    } else {
      _shakeCard = 1;
      _mistakes++;
      _robot = min(99, _robot + 15);
      _banner = host.tr('try_again', 'Try again');
      _bannerT = 0;
      host.sfx(Sfx.wrong);
      host.shake(7);
      host.flash(const Color(0x44FF3B5C), .15);
      if (_stage == 1) _startRound(1);
    }
  }

  @override
  void onTimeUp() {
    _robot = 100;
    _banner = host.tr('robot_detected', 'Robot detected!');
    _bannerT = 0;
    host.sfx(Sfx.glitch);
    host.lose();
  }

  // ------------------------------------------------------------ update ---

  @override
  void update(double dt) {
    _t += dt;
    _stageT += dt;
    _bannerT += dt;
    _shakeCard = M.approach(_shakeCard, 0, 6, dt);
    _verifyPress = M.approach(_verifyPress, 0, 10, dt);
    _robotShown = M.approach(_robotShown, _robot, 5, dt);
    if (_stage == 0 && _checking && _stageT > .45) {
      host.sfx(Sfx.notify, volume: .6);
      _startRound(1);
    }
    for (var i = 0; i < _tiles.length; i++) {
      final tl = _tiles[i];
      tl.appear = min(1, tl.appear + dt * 5);
      tl.bump = M.approach(tl.bump, 0, 9, dt);
      tl.shake = M.approach(tl.shake, 0, 6, dt);
      if (tl.leaving > 0) {
        tl.leaving += dt * 3.6;
        if (tl.leaving >= 1) {
          // reCAPTCHA-style: slowly fade in a brand-new picture
          final bus = chance(_replaceChance);
          _replaceChance = max(0, _replaceChance - .35);
          _tiles[i] = _Tile(bus ? _kBus : 2 + randInt(6), rng.nextDouble())..appear = -.2;
        }
      }
    }
  }

  // ------------------------------------------------------------ render ---

  Rect _tileRect(int i) => Rect.fromLTWH(_gx + (i % 3) * (_ts + _gap), _gy + (i ~/ 3) * (_ts + _gap), _ts, _ts);

  @override
  void render(Canvas c) {
    // a fake web page behind the widget
    D.gradientBg(c, const [Color(0xFFEFF2F7), Color(0xFFDDE3EC)]);
    c.drawRect(const Rect.fromLTWH(0, 36, 360, 30), D.fill(const Color(0xFFCBD3DF)));
    for (var i = 0; i < 3; i++) {
      D.circle(c, Offset(16 + i * 16.0, 51), 5, [Pal.red, Pal.yellow, Pal.green][i]);
    }
    D.rrect(c, const Rect.fromLTWH(70, 43, 270, 16), 8, Pal.white);
    for (var i = 0; i < 18; i++) {
      final w = 120.0 + (i * 53) % 180;
      D.rrect(c, Rect.fromLTWH(20, 90 + i * 30.0, w, 10), 5, const Color(0x22303050));
    }
    c.drawRect(const Rect.fromLTWH(0, 66, 360, 574), D.fill(const Color(0x66101020)));

    final sx = sin(_t * 60) * 10 * _shakeCard;
    c.save();
    c.translate(sx, 0);
    if (_stage == 0) {
      _checkboxCard(c);
    } else {
      _challengeCard(c);
    }
    c.restore();

    // robot-o-meter
    D.rrect(c, const Rect.fromLTWH(20, 566, 320, 50), 14, const Color(0xEE1B1530));
    _robotHead(c, const Offset(46, 591), 15, happy: _robot < 30);
    D.bar(c, const Rect.fromLTWH(72, 584, 190, 14), _robotShown / 100,
        Color.lerp(Pal.green, Pal.red, _robotShown / 100)!, back: const Color(0x33FFFFFF));
    D.text(c, '${_robotShown.round()}%', const Offset(300, 591), size: 20, color: Pal.white);

    if (_bannerT < 1.4 && _banner.isNotEmpty) {
      final k = _bannerT;
      final s = k < .25 ? M.easeOutBack(k / .25) : 1.0;
      final good = _stage == 4;
      D.title(c, _banner, const Offset(180, 330), size: good ? 36 : 34, scale: s,
          color: good ? Pal.lime : Pal.red, rotate: good ? -.06 : .05);
    }
    if (_stage == 0 && !_checking && host.time < 3) D.hand(c, _checkR.center, _t);
  }

  void _checkboxCard(Canvas c) {
    const card = Rect.fromLTWH(24, 244, 312, 80);
    D.rrect(c, card.shift(const Offset(0, 4)), 6, const Color(0x44000000));
    D.rrect(c, card, 6, const Color(0xFFF9F9F9), border: const Color(0xFFD3D3D3), borderWidth: 1.5);
    if (_checking) {
      final a = _t * 8;
      c.drawArc(_checkR.deflate(6), a, 4.2, false, D.stroke(_blue, 4));
    } else {
      D.rrect(c, _checkR, 4, Pal.white, border: const Color(0xFFC1C1C1), borderWidth: 2.5);
    }
    D.text(c, host.tr('not_robot', "I'm not a robot"), const Offset(98, 284),
        size: 17, color: const Color(0xFF222222), weight: FontWeight.w600, anchor: Alignment.centerLeft, maxWidth: 170);
    // logo
    final lo = const Offset(304, 276);
    c.drawArc(Rect.fromCircle(center: lo, radius: 13), _t * 2, 4.5, false, D.stroke(_blue, 5));
    c.drawArc(Rect.fromCircle(center: lo, radius: 13), _t * 2 + 4.6, 1.2, false, D.stroke(const Color(0xFFABABAB), 5));
    D.rrect(c, const Rect.fromLTWH(286, 296, 36, 6), 3, const Color(0xFFBBBBBB));
  }

  void _challengeCard(Canvas c) {
    const card = Rect.fromLTWH(20, 76, 320, 474);
    D.rrect(c, card.shift(const Offset(0, 5)), 6, const Color(0x55000000));
    D.rrect(c, card, 6, Pal.white, border: const Color(0xFFD3D3D3), borderWidth: 1.5);
    // header
    const hr = Rect.fromLTWH(30, 86, 300, 82);
    c.drawRect(hr, D.fill(_blue));
    D.text(c, host.tr('select_all', 'Select all'), const Offset(44, 106),
        size: 15, color: Pal.white, weight: FontWeight.w600, anchor: Alignment.centerLeft, maxWidth: 190);
    final word = switch (_stage) {
      1 => host.tr('traffic_lights', 'traffic lights'),
      2 => host.tr('buses', 'buses'),
      _ => host.tr('robots', 'robots'),
    };
    D.text(c, word, const Offset(44, 136), size: 28, color: Pal.white, anchor: Alignment.centerLeft, maxWidth: 200);
    if (_stage == 2) {
      D.text(c, host.tr('until_none', 'until none left'), const Offset(44, 160),
          size: 11, color: const Color(0xDDFFFFFF), weight: FontWeight.w600, anchor: Alignment.centerLeft, maxWidth: 200);
    }
    // example icon
    const ic = Rect.fromLTWH(252, 94, 68, 66);
    D.rrect(c, ic, 4, Pal.white);
    c.save();
    c.clipRect(ic);
    _drawThing(c, _stage >= 3 ? 9 : _targetKind, ic.center + const Offset(0, 2), .62, .5);
    c.restore();
    // tiles
    for (var i = 0; i < _tiles.length; i++) {
      final tl = _tiles[i];
      final r = _tileRect(i);
      c.drawRect(r, D.fill(const Color(0xFFE8E8E8)));
      final a = tl.appear.clamp(0.0, 1.0) * (1 - tl.leaving.clamp(0.0, 1.0));
      if (a <= 0) continue;
      final sel = tl.selected ? .82 : 1.0;
      final s = sel * (1 - tl.bump * .06);
      c.save();
      c.translate(r.center.dx + sin(tl.shake * 30) * 6 * tl.shake, r.center.dy);
      c.scale(s);
      final rr = Rect.fromCenter(center: Offset.zero, width: _ts, height: _ts);
      if (a < 1) c.saveLayer(rr, Paint()..color = Color.fromRGBO(0, 0, 0, a));
      c.clipRect(rr);
      _tileBg(c, rr, tl);
      _drawThing(c, tl.kind, Offset(0, 6 + (tl.v - .5) * 10), .95 + tl.v * .15, tl.v);
      if (a < 1) c.restore();
      c.restore();
      if (tl.selected && tl.leaving == 0) {
        D.circle(c, r.topLeft + const Offset(14, 14), 12, _blue, border: Pal.white, borderWidth: 2.5);
        D.line(c, r.topLeft + const Offset(8, 14), r.topLeft + const Offset(12, 19), Pal.white, 3);
        D.line(c, r.topLeft + const Offset(12, 19), r.topLeft + const Offset(20, 9), Pal.white, 3);
      }
    }
    // footer
    c.drawRect(const Rect.fromLTWH(20, 482, 320, 1.5), D.fill(const Color(0xFFDDDDDD)));
    // reload / audio / info icons
    const ig = Color(0xFF777777);
    c.drawArc(Rect.fromCircle(center: const Offset(46, 511), radius: 10), .6, 5, false, D.stroke(ig, 3));
    c.drawPath(
        Path()
          ..moveTo(78, 506)
          ..lineTo(84, 506)
          ..lineTo(90, 500)
          ..lineTo(90, 522)
          ..lineTo(84, 516)
          ..lineTo(78, 516)
          ..close(),
        D.fill(ig));
    D.circle(c, const Offset(118, 511), 10, Pal.white, border: ig, borderWidth: 2.5);
    D.text(c, 'i', const Offset(118, 511), size: 13, color: ig);
    final vr = _verifyR.shift(Offset(0, _verifyPress * 2));
    D.rrect(c, vr, 4, _blue);
    D.text(c, host.tr('verify', 'VERIFY'), vr.center, size: 17, color: Pal.white, maxWidth: 104);
    // stage pips
    for (var i = 0; i < 3; i++) {
      D.circle(c, Offset(160 + i * 18.0, 511), 5, i < _stage - 1 || _stage == 4 ? Pal.green : const Color(0xFFCCCCCC));
    }
  }

  void _tileBg(Canvas c, Rect r, _Tile tl) {
    final hue = 195 + tl.v * 30;
    c.drawRect(Rect.fromLTRB(r.left, r.top, r.right, r.top + r.height * .6),
        D.fill(D.hsv(hue, .35 + (tl.kind == _kMirror ? 0 : .1), .95)));
    c.drawRect(Rect.fromLTRB(r.left, r.top + r.height * .6, r.right, r.bottom), D.fill(D.hsv(30, .08, .55 + tl.v * .15)));
    // "photo grain"
    final g = D.fill(const Color(0x10000000));
    for (var k = 0; k < 6; k++) {
      c.drawRect(Rect.fromLTWH(r.left + (k * 37 + tl.v * 50) % r.width, r.top + (k * 23 + tl.v * 90) % r.height, 3, 3), g);
    }
  }

  /// Draws a tile subject. 0 light,1 bus,2 bike,3 cat,4 hydrant,5 crosswalk,
  /// 6 tree,7 car,8 mirror(with you, a robot),9 robot icon.
  void _drawThing(Canvas c, int kind, Offset o, double s, double v) {
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s);
    switch (kind) {
      case 0:
        c.drawRect(const Rect.fromLTWH(-4, 10, 8, 50), D.fill(const Color(0xFF3A3A3A)));
        D.rrect(c, const Rect.fromLTWH(-16, -44, 32, 62), 8, const Color(0xFF2B2B2B), border: Pal.ink, borderWidth: 2);
        final lit = (v * 3).floor() % 3;
        for (var i = 0; i < 3; i++) {
          final col = [Pal.red, Pal.yellow, Pal.green][i];
          D.circle(c, Offset(0, -32 + i * 19.0), 7, i == lit ? col : Color.lerp(col, Pal.ink, .7)!);
        }
      case 1:
        D.rrect(c, const Rect.fromLTWH(-44, -24, 88, 44), 8, v > .5 ? const Color(0xFFFFC21A) : const Color(0xFFE8363C),
            border: Pal.ink, borderWidth: 2.5);
        for (var i = 0; i < 4; i++) {
          D.rrect(c, Rect.fromLTWH(-38 + i * 20.0, -18, 15, 14), 2, const Color(0xFFBFE6FF));
        }
        c.drawRect(const Rect.fromLTWH(-44, 2, 88, 4), D.fill(Pal.white));
        for (final x in [-26.0, 26.0]) {
          D.circle(c, Offset(x, 22), 9, Pal.ink);
          D.circle(c, Offset(x, 22), 4, Pal.gray);
        }
      case 2:
        final wp = D.stroke(Pal.ink, 3);
        c.drawCircle(const Offset(-22, 14), 15, wp);
        c.drawCircle(const Offset(22, 14), 15, wp);
        final fr = D.stroke(v > .5 ? Pal.blue : Pal.red, 4);
        c.drawLine(const Offset(-22, 14), const Offset(-4, -10), fr);
        c.drawLine(const Offset(-4, -10), const Offset(18, -10), fr);
        c.drawLine(const Offset(18, -10), const Offset(22, 14), fr);
        c.drawLine(const Offset(-22, 14), const Offset(4, 14), fr);
        c.drawLine(const Offset(4, 14), const Offset(18, -10), fr);
        c.drawLine(const Offset(-8, -16), const Offset(2, -16), D.stroke(Pal.ink, 4));
        c.drawLine(const Offset(16, -18), const Offset(24, -22), D.stroke(Pal.ink, 3));
      case 3:
        final col = v > .5 ? const Color(0xFFFFA64D) : const Color(0xFF6E6A80);
        c.drawOval(const Rect.fromLTWH(-20, -2, 40, 30), D.fill(col));
        for (final sx in [-1.0, 1.0]) {
          c.drawPath(
              Path()
                ..moveTo(sx * 16, -18)
                ..lineTo(sx * 14, -36)
                ..lineTo(sx * 3, -24)
                ..close(),
              D.fill(col));
        }
        D.circle(c, const Offset(0, -14), 17, col, border: Pal.ink, borderWidth: 2);
        D.face(c, const Offset(0, -13), 14, Face.smug);
      case 4:
        D.rrect(c, const Rect.fromLTWH(-14, -20, 28, 44), 6, const Color(0xFFD9302F), border: Pal.ink, borderWidth: 2.5);
        c.drawArc(const Rect.fromLTWH(-15, -34, 30, 28), pi, pi, true, D.fill(const Color(0xFFD9302F)));
        D.rrect(c, const Rect.fromLTWH(-22, -6, 44, 10), 4, const Color(0xFFB02020), border: Pal.ink, borderWidth: 2);
        D.rrect(c, const Rect.fromLTWH(-18, 22, 36, 6), 2, const Color(0xFF8A1818));
      case 5:
        for (var i = 0; i < 5; i++) {
          c.drawPath(
              Path()
                ..moveTo(-50 + i * 22.0, 44)
                ..lineTo(-38 + i * 22.0, 44)
                ..lineTo(-30 + i * 18.0, 0)
                ..lineTo(-38 + i * 18.0, 0)
                ..close(),
              D.fill(Pal.white));
        }
      case 6:
        D.tree(c, const Offset(0, 44), 90, leaf: v > .5 ? const Color(0xFF2FA84F) : const Color(0xFF6BBF4E));
      case 7:
        final col = [Pal.sky, Pal.lime, Pal.pink, Pal.purple][(v * 4).floor() % 4];
        D.rrect(c, const Rect.fromLTWH(-22, -24, 40, 18), 8, col, border: Pal.ink, borderWidth: 2);
        D.rrect(c, const Rect.fromLTWH(-38, -10, 76, 22), 8, col, border: Pal.ink, borderWidth: 2.5);
        for (final x in [-22.0, 22.0]) {
          D.circle(c, Offset(x, 14), 8, Pal.ink);
        }
      case 8:
        // a mirror... and in it, you
        c.drawOval(const Rect.fromLTWH(-32, -44, 64, 88), D.fill(const Color(0xFFC9A227)));
        c.drawOval(const Rect.fromLTWH(-26, -38, 52, 76), D.fill(const Color(0xFFCFF0FF)));
        c.save();
        c.clipPath(Path()..addOval(const Rect.fromLTWH(-26, -38, 52, 76)));
        _robotHead(c, const Offset(0, -2), 18, happy: false, wave: true);
        c.drawLine(const Offset(-20, -30), const Offset(8, -40), D.stroke(const Color(0x88FFFFFF), 5));
        c.restore();
        c.drawOval(const Rect.fromLTWH(-32, -44, 64, 88), D.stroke(Pal.ink, 2.5));
        c.drawRect(const Rect.fromLTWH(-3, 44, 6, 10), D.fill(const Color(0xFF8A6A10)));
      case 9:
        _robotHead(c, Offset.zero, 26, happy: true);
    }
    c.restore();
  }

  void _robotHead(Canvas c, Offset o, double r, {bool happy = true, bool wave = false}) {
    c.drawLine(o + Offset(0, -r), o + Offset(0, -r * 1.5), D.stroke(Pal.ink, r * .12));
    D.circle(c, o + Offset(0, -r * 1.55), r * .18, Pal.red);
    D.rrect(c, Rect.fromCenter(center: o, width: r * 2, height: r * 1.7), r * .35, const Color(0xFFB8C2D0),
        border: Pal.ink, borderWidth: r * .1);
    final blink = (sin(_t * 3) > .95) ? .2 : 1.0;
    for (final sx in [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: o + Offset(sx * r * .45, -r * .12), width: r * .45, height: r * .45 * blink),
          D.fill(happy ? Pal.teal : Pal.red));
    }
    D.rrect(c, Rect.fromCenter(center: o + Offset(0, r * .45), width: r * .9, height: r * .25), r * .1, Pal.ink);
    if (!happy) {
      // nervous sweat
      c.drawOval(Rect.fromCenter(center: o + Offset(r * 1.05, -r * .5 + (_t * 20) % 6), width: r * .25, height: r * .4),
          D.fill(Pal.sky));
    }
    if (wave) {
      final a = sin(_t * 8) * .4;
      c.drawLine(o + Offset(r * .9, r * .9), o + Offset(r * 1.4 + a * 6, r * .1), D.stroke(const Color(0xFF8C96A6), r * .22));
    }
  }
}

class _Tile {
  _Tile(this.kind, this.v);
  final int kind;
  final double v;
  bool selected = false;
  double appear = 0;
  double leaving = 0;
  double bump = 0;
  double shake = 0;
}
