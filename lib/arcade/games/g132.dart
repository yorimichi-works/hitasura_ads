import '../engine/engine.dart';

/// No.132 Only 1% Can Solve — viral picture-math puzzles, 3 questions with
/// twists (the clock shows another hour, the infamous 6÷2(1+2)). 2/3 wins.
class G132 extends MiniGame {
  final List<_Q> _qs = [];
  int _qi = 0;
  int _right = 0, _wrong = 0;
  int _picked = -1;
  double _fb = -1; // feedback timer (>=0 while showing)
  double _slide = 1; // card slide-in 1 -> 0
  double _t = 0;
  double _iq = 100, _iqShown = 100;
  double _iqBump = 0;
  Face _brainFace = Face.smug;
  bool _done = false;

  static const _btnRects = [
    Rect.fromLTWH(22, 438, 152, 66),
    Rect.fromLTWH(186, 438, 152, 66),
    Rect.fromLTWH(22, 520, 152, 66),
    Rect.fromLTWH(186, 520, 152, 66),
  ];

  @override
  void init() {
    // Q1: fruit algebra
    final a = 2 + randInt(4); // apple
    var b = 1 + randInt(8); // banana
    if (b == a) b = a + 2;
    final mul = chance(.4);
    _qs.add(_Q(
      [
        [_T.icon('apple'), _T.op('+'), _T.icon('apple'), _T.op('='), _T.num('${a * 2}')],
        [_T.icon('apple'), _T.op('+'), _T.icon('banana'), _T.op('='), _T.num('${a + b}')],
        [_T.icon('banana'), _T.op(mul ? '×' : '+'), mul ? _T.icon('apple') : _T.icon('banana'), _T.op('='), _T.num('?')],
      ],
      mul ? a * b : b * 2,
      mul ? a + b : a * 2,
    ));
    // Q2: the clock twist (the question clock shows another hour)
    final h = pick<int>(const [2, 3, 4]);
    final h2 = h + pick<int>(const [3, 5, 6]);
    final ap = 2 + randInt(6);
    _qs.add(_Q(
      [
        [_T.clock(h), _T.op('+'), _T.clock(h), _T.op('='), _T.num('${h * 2}')],
        [_T.clock(h), _T.op('+'), _T.icon('apple'), _T.op('='), _T.num('${h + ap}')],
        [_T.clock(h2), _T.op('+'), _T.icon('apple'), _T.op('='), _T.num('?')],
      ],
      h2 + ap,
      h + ap,
    ));
    // Q3: the internet's favourite fight
    final m = pick(const [
      [6, 2, 1, 2],
      [8, 2, 2, 2],
      [12, 2, 1, 2],
      [12, 3, 1, 1],
      [9, 3, 1, 2],
    ]);
    final ans = m[0] ~/ m[1] * (m[2] + m[3]);
    final trap = m[0] ~/ (m[1] * (m[2] + m[3]));
    _qs.add(_Q(
      [
        [_T.big('${m[0]}÷${m[1]}(${m[2]}+${m[3]})')],
        [_T.big('= ?')],
      ],
      ans,
      trap,
    ));
    for (final q in _qs) {
      q.makeOptions(rng);
    }
  }

  // ----------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    if (_fb >= 0 || _done || _slide > .3) return;
    for (var i = 0; i < 4; i++) {
      if (_btnRects[i].inflate(4).contains(p)) {
        _answer(i);
        return;
      }
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    const map = {'left': 0, 'up': 1, 'down': 2, 'right': 3};
    final i = map[key];
    if (i != null) onDown(_btnRects[i].center);
  }

  void _answer(int i) {
    final q = _qs[_qi];
    _picked = i;
    _fb = 0;
    final ok = q.options[i] == q.answer;
    q.correct = ok;
    final at = _btnRects[i].center;
    if (ok) {
      _right++;
      _iq += 40;
      host.sfx(Sfx.correct, rate: 1 + _right * .1);
      host.sfx(Sfx.ding, volume: .6);
      host.fx.burst(at, Pal.lime, count: 18, shape: PartShape.star, speed: 260);
      host.fx.pop('IQ +40', at + const Offset(0, -40), color: Pal.lime, size: 28);
      host.addScore(100);
      _brainFace = Face.love;
      host.punch(.03);
    } else {
      _wrong++;
      _iq -= 25;
      host.sfx(Sfx.wrong);
      host.shake(8);
      host.flash(const Color(0x66FF3B5C), .15);
      host.fx.pop('IQ -25', at + const Offset(0, -40), color: Pal.red, size: 28);
      _brainFace = Face.dead;
    }
    _iqBump = 1;
  }

  void _next() {
    _fb = -1;
    _picked = -1;
    if (_wrong >= 2) {
      _done = true;
      host.sfx(Sfx.aww, volume: .7);
      host.lose();
      return;
    }
    if (_qi == _qs.length - 1) {
      _done = true;
      _brainFace = Face.love;
      host.sfx(Sfx.fanfare);
      host.fx.confetti(count: 60);
      host.win(stars: _right == 3 ? 3 : 2);
      return;
    }
    _qi++;
    _slide = 1;
    _brainFace = Face.smug;
    host.sfx(Sfx.whoosh, volume: .6);
  }

  @override
  void onTimeUp() {
    _done = true;
    if (_right >= 2) {
      host.win(stars: 1);
    } else {
      _brainFace = Face.cry;
      host.lose();
    }
  }

  // ---------------------------------------------------------- update ---

  @override
  void update(double dt) {
    _t += dt;
    _slide = M.approach(_slide, 0, 11, dt);
    if (_slide < .01) _slide = 0;
    if (_fb >= 0) {
      _fb += dt;
      if (_fb > .95 && !_done) _next();
    }
    _iqShown = M.approach(_iqShown, _iq, 7, dt);
    _iqBump = M.approach(_iqBump, 0, 5, dt);
  }

  // ---------------------------------------------------------- render ---

  @override
  void render(Canvas c) {
    D.gradientBg(c, const [Color(0xFFFFF3B0), Color(0xFFFFC56B), Color(0xFFFF8A5C)]);
    D.rays(c, const Offset(180, 260), 520, const Color(0x22FFFFFF), count: 16, t: _t * .2);
    // header: "1%" badge, brain, IQ counter
    c.save();
    c.translate(70, 72);
    c.rotate(-.1 + sin(_t * 4) * .03);
    D.rrect(c, const Rect.fromLTWH(-54, -24, 108, 48), 12, Pal.red, border: Pal.ink, borderWidth: 3.5);
    D.text(c, '1%', const Offset(0, 1), size: 34, color: Pal.yellow, stroke: Pal.ink, strokeWidth: 6);
    c.restore();
    _brain(c, Offset(180, 72 + sin(_t * 3) * 3), 28);
    D.rrect(c, const Rect.fromLTWH(234, 50, 112, 44), 14, Pal.ink);
    D.text(c, 'IQ ${_iqShown.round()}', const Offset(290, 72),
        size: 22 * (1 + _iqBump * .25), color: _iq >= 100 ? Pal.lime : Pal.red);
    // progress dots
    for (var i = 0; i < 3; i++) {
      final q = _qs[i];
      final p = Offset(150 + i * 30.0, 114);
      final col = q.correct == null ? (i == _qi ? Pal.white : const Color(0x66FFFFFF)) : (q.correct! ? Pal.green : Pal.red);
      D.circle(c, p, 9, col, border: Pal.ink, borderWidth: 2.5);
    }

    // question card
    final cx = _slide * 380;
    c.save();
    c.translate(cx, 0);
    const card = Rect.fromLTWH(16, 132, 328, 288);
    D.rrect(c, card.shift(const Offset(0, 7)), 20, const Color(0x55000000));
    D.rrect(c, card, 20, Pal.white, border: Pal.ink, borderWidth: 4);
    final grid = D.fill(const Color(0x1A3D6BFF));
    for (var x = card.left + 16; x < card.right - 4; x += 16) {
      c.drawRect(Rect.fromLTWH(x, card.top + 6, 1, card.height - 12), grid);
    }
    for (var y = card.top + 16; y < card.bottom - 4; y += 16) {
      c.drawRect(Rect.fromLTWH(card.left + 6, y, card.width - 12, 1), grid);
    }
    final q = _qs[_qi];
    final rows = q.rows;
    final gap = rows.length == 3 ? 82.0 : 90.0;
    final y0 = card.center.dy - gap * (rows.length - 1) / 2;
    for (var r = 0; r < rows.length; r++) {
      _row(c, rows[r], Offset(180, y0 + r * gap), _fb >= 0 && r == rows.length - 1 ? q.answer : null);
    }
    // stamp
    if (_fb >= 0) {
      final k = M.easeOutBack((_fb / .25).clamp(0.0, 1.0));
      c.save();
      c.translate(292, 396);
      c.rotate(-.25);
      c.scale(k * 1.0 + .001);
      if (q.correct == true) {
        D.circle(c, Offset.zero, 34, const Color(0xDD2ECC71), border: Pal.ink, borderWidth: 4);
        D.line(c, const Offset(-14, 0), const Offset(-3, 12), Pal.white, 8);
        D.line(c, const Offset(-3, 12), const Offset(17, -12), Pal.white, 8);
      } else {
        D.circle(c, Offset.zero, 34, const Color(0xDDFF3B5C), border: Pal.ink, borderWidth: 4);
        D.line(c, const Offset(-13, -13), const Offset(13, 13), Pal.white, 8);
        D.line(c, const Offset(13, -13), const Offset(-13, 13), Pal.white, 8);
      }
      c.restore();
    }
    c.restore();

    // answers
    for (var i = 0; i < 4; i++) {
      final r = _btnRects[i];
      var col = [Pal.sky, Pal.pink, Pal.purple, Pal.orange][i];
      var pressed = false;
      if (_fb >= 0) {
        if (q.options[i] == q.answer) {
          col = Pal.green;
        } else if (i == _picked) {
          col = Pal.red;
          pressed = true;
        } else {
          col = Color.lerp(col, Pal.gray, .7)!;
        }
      }
      final pop = (_fb >= 0 && q.options[i] == q.answer) ? 1 + .06 * sin(_fb * 20) * (1 - _fb).clamp(0.0, 1.0) : 1.0;
      final rr = Rect.fromCenter(center: r.center + Offset(_slide * 380 * (i.isEven ? .6 : .9), 0), width: r.width * pop, height: r.height * pop);
      D.button(c, rr, '${q.options[i]}', color: col, fontSize: 32, pressed: pressed);
    }
    if (host.time < 2 && _qi == 0 && _fb < 0) {
      D.hand(c, _btnRects[0].center + const Offset(10, 10), _t);
    }
    // win flourish
    if (_done && host.finished && _right >= 2) {
      D.rrect(c, Rect.fromCenter(center: const Offset(180, 404), width: 200, height: 44), 14, Pal.gold, border: Pal.ink, borderWidth: 3);
      D.text(c, '${host.tr('top', 'TOP')} 1%', const Offset(180, 405), size: 26, color: Pal.ink, maxWidth: 190);
    }
  }

  void _row(Canvas c, List<_T> row, Offset center, int? reveal) {
    var w = 0.0;
    for (final t in row) {
      w += t.width;
    }
    var x = center.dx - w / 2;
    for (final t in row) {
      final p = Offset(x + t.width / 2, center.dy);
      switch (t.kind) {
        case 'apple':
          _apple(c, p, 22);
        case 'banana':
          _banana(c, p, 24);
        case 'clock':
          _clock(c, p, 23, t.value);
        case 'op':
          D.text(c, t.text, p, size: 30, color: Pal.ink);
        case 'num':
          if (reveal != null && t.text == '?') {
            D.text(c, '$reveal', p, size: 36, color: Pal.green, stroke: Pal.ink, strokeWidth: 5);
            break;
          }
          final q = t.text == '?';
          D.text(c, t.text, p,
              size: 34 * (q ? 1 + .08 * sin(_t * 8) : 1), color: q ? Pal.red : Pal.blue, stroke: q ? Pal.ink : null, strokeWidth: 5);
        case 'big':
          final txt = reveal != null ? t.text.replaceAll('?', '$reveal') : t.text;
          D.text(c, txt, p, size: 44, color: reveal != null && txt != t.text ? Pal.green : Pal.ink, letterSpacing: 1);
      }
      x += t.width;
    }
  }

  void _apple(Canvas c, Offset o, double r) {
    final p = Path()
      ..moveTo(o.dx, o.dy - r * .6)
      ..cubicTo(o.dx + r * .55, o.dy - r * 1.05, o.dx + r * 1.2, o.dy - r * .6, o.dx + r * 1.02, o.dy + r * .15)
      ..cubicTo(o.dx + r * .9, o.dy + r * .85, o.dx + r * .4, o.dy + r * 1.08, o.dx, o.dy + r * .88)
      ..cubicTo(o.dx - r * .4, o.dy + r * 1.08, o.dx - r * .9, o.dy + r * .85, o.dx - r * 1.02, o.dy + r * .15)
      ..cubicTo(o.dx - r * 1.2, o.dy - r * .6, o.dx - r * .55, o.dy - r * 1.05, o.dx, o.dy - r * .6)
      ..close();
    c.drawPath(p, D.fill(const Color(0xFFE8283F)));
    c.drawOval(Rect.fromCenter(center: o + Offset(r * .25, r * .35), width: r * 1.1, height: r * .9),
        D.fill(const Color(0x33000000)));
    c.drawPath(p, D.stroke(const Color(0xFF7A0E1E), 2.5));
    c.drawOval(Rect.fromCenter(center: o + Offset(-r * .5, -r * .2), width: r * .3, height: r * .55), D.fill(const Color(0x99FFFFFF)));
    c.drawLine(o + Offset(0, -r * .55), o + Offset(r * .12, -r * 1.05), D.stroke(Pal.brown, 3.5));
    final leaf = Path()
      ..moveTo(o.dx + r * .1, o.dy - r * .85)
      ..quadraticBezierTo(o.dx + r * .5, o.dy - r * 1.3, o.dx + r * .8, o.dy - r * .95)
      ..quadraticBezierTo(o.dx + r * .45, o.dy - r * .7, o.dx + r * .1, o.dy - r * .85)
      ..close();
    c.drawPath(leaf, D.fill(Pal.green));
    c.drawPath(leaf, D.stroke(const Color(0xFF1E7A40), 1.5));
  }

  void _banana(Canvas c, Offset o, double r) {
    final p = Path()
      ..moveTo(o.dx - r, o.dy - r * .5)
      ..quadraticBezierTo(o.dx - r * .2, o.dy + r * 1.1, o.dx + r, o.dy - r * .3)
      ..quadraticBezierTo(o.dx + r * .1, o.dy + r * .45, o.dx - r, o.dy - r * .5)
      ..close();
    c.drawPath(p, D.fill(const Color(0xFFFFD84A)));
    c.drawPath(p, D.stroke(const Color(0xFF9A7A10), 2.5));
    c.drawCircle(Offset(o.dx - r, o.dy - r * .5), 3, D.fill(const Color(0xFF5A4010)));
    c.drawCircle(Offset(o.dx + r, o.dy - r * .3), 2.5, D.fill(const Color(0xFF5A4010)));
  }

  void _clock(Canvas c, Offset o, double r, int hour) {
    D.circle(c, o, r, Pal.white, border: Pal.ink, borderWidth: 3);
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      c.drawCircle(o + Offset(sin(a), -cos(a)) * r * .8, i % 3 == 0 ? 2 : 1.2, D.fill(Pal.ink));
    }
    final ha = hour * pi / 6;
    c.drawLine(o, o + Offset(sin(ha), -cos(ha)) * r * .5, D.stroke(Pal.red, 4));
    c.drawLine(o, o + Offset(0, -r * .75), D.stroke(Pal.ink, 2.5));
    c.drawCircle(o, 2.5, D.fill(Pal.ink));
  }

  void _brain(Canvas c, Offset o, double r) {
    final col = const Color(0xFFFF9EC4);
    for (final q in const [Offset(-.5, -.2), Offset(.5, -.2), Offset(0, -.5), Offset(-.4, .3), Offset(.4, .3)]) {
      c.drawCircle(o + q * r, r * .6, D.fill(col));
    }
    final outline = Path();
    for (final q in const [Offset(-.5, -.2), Offset(.5, -.2), Offset(0, -.5), Offset(-.4, .3), Offset(.4, .3)]) {
      outline.addOval(Rect.fromCircle(center: o + q * r, radius: r * .6));
    }
    c.drawPath(outline, D.stroke(const Color(0xFFB0426E), 2));
    c.drawLine(o + Offset(0, -r * .9), o + Offset(0, r * .6), D.stroke(const Color(0xFFB0426E), 2));
    D.face(c, o + Offset(0, r * .1), r * .7, _brainFace);
    if (_brainFace == Face.smug) {
      // tiny glasses
      c.drawCircle(o + Offset(-r * .25, 0), r * .2, D.stroke(Pal.ink, 2));
      c.drawCircle(o + Offset(r * .25, 0), r * .2, D.stroke(Pal.ink, 2));
    }
  }
}

class _T {
  _T(this.kind, this.text, this.value, this.width);
  factory _T.icon(String k) => _T(k, '', 0, 56);
  factory _T.clock(int h) => _T('clock', '', h, 56);
  factory _T.op(String s) => _T('op', s, 0, 34);
  factory _T.num(String s) => _T('num', s, 0, 56);
  factory _T.big(String s) => _T('big', s, 0, 10);
  final String kind;
  final String text;
  final int value;
  final double width;
}

class _Q {
  _Q(this.rows, this.answer, this.trap);
  final List<List<_T>> rows;
  final int answer;
  final int trap;
  final List<int> options = [];
  bool? correct;

  void makeOptions(Random r) {
    final set = <int>{answer};
    if (trap != answer && trap > 0) set.add(trap);
    final cands = [answer + 1, answer - 1, answer + 2, answer * 2, answer - 2, answer + 3, answer + 4];
    cands.shuffle(r);
    for (final v in cands) {
      if (set.length >= 4) break;
      if (v > 0) set.add(v);
    }
    options
      ..addAll(set)
      ..shuffle(r);
  }
}
