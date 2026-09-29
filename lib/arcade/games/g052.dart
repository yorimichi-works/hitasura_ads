import 'dart:ui' show MaskFilter, BlurStyle;

import '../engine/engine.dart';

enum _M { show, input, clear, fail }

/// No.052 Memory Lights — neon Simon: watch, repeat, outlast the party.
class G052 extends MiniGame {
  static const _neon = [Color(0xFF22F0FF), Color(0xFFFF3DDB), Color(0xFFFFE53D), Color(0xFF6BFF5A)];
  static const _rates = [.75, .94, 1.12, 1.5];
  static const _lens = [3, 4, 5];
  static const _gridC = Offset(180, 382);
  static const _pad = 128.0, _gap = 14.0;

  final _seq = <int>[];
  final _glow = List<double>.filled(4, 0);
  final _cpuOut = List<bool>.filled(4, false);
  final _cpuOutT = List<double>.filled(4, 0);
  final _cpuOrder = <int>[];
  _M _mode = _M.show;
  double _mT = 0;
  double _t = 0;
  int _round = 0;
  int _showIdx = -1;
  int _inputIdx = 0;
  int _wrongPad = -1;
  double _step = .44;
  int _lastPad = -1;

  static final _blur = MaskFilter.blur(BlurStyle.normal, 14);
  static final _blurSmall = MaskFilter.blur(BlurStyle.normal, 5);

  @override
  void init() {
    for (var i = 0; i < 5; i++) {
      var n = randInt(4);
      if (i > 1 && n == _seq[i - 1] && n == _seq[i - 2]) n = (n + 1) % 4;
      _seq.add(n);
    }
    _cpuOrder.addAll([1, 2, 3]..shuffle(rng));
    _step = .44 / sqrt(host.speed);
    _mT = -.35; // short breath before the first note
  }

  Rect _padRect(int i) {
    final col = i % 2, row = i ~/ 2;
    final x = _gridC.dx + (col == 0 ? -(_pad + _gap / 2) : _gap / 2);
    final y = _gridC.dy + (row == 0 ? -(_pad + _gap / 2) : _gap / 2);
    return Rect.fromLTWH(x, y, _pad, _pad);
  }

  void _light(int i, {double vol = .8}) {
    _glow[i] = 1;
    host.sfx(Sfx.ding, volume: vol, rate: _rates[i]);
  }

  @override
  void onDown(Offset p) {
    if (_mode != _M.input) return;
    for (var i = 0; i < 4; i++) {
      if (_padRect(i).inflate(4).contains(p)) {
        _press(i);
        return;
      }
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down || _mode != _M.input) return;
    const map = {'up': 0, 'right': 1, 'left': 2, 'down': 3};
    final i = map[key];
    if (i != null) _press(i);
  }

  void _press(int i) {
    final len = _lens[_round];
    if (_seq[_inputIdx] == i) {
      _light(i);
      _lastPad = i;
      host.fx.ring(_padRect(i).center, _neon[i], size: 80);
      host.fx.sparkle(_padRect(i).center, count: 6, radius: 40, color: _neon[i]);
      _inputIdx++;
      if (_inputIdx >= len) {
        _mode = _M.clear;
        _mT = 0;
        host.sfx(Sfx.correct);
        host.sfx(Sfx.combo, rate: 1 + _round * .2, volume: .6);
        host.fx.pop(host.tr('clear', 'CLEAR!'), const Offset(180, 382), color: Pal.white, size: 40);
        host.punch(.03);
        // one rival cracks each round
        final out = _cpuOrder[_round];
        _cpuOut[out] = true;
        _cpuOutT[out] = 0;
        if (_round == 2) {
          host.sfx(Sfx.fanfare, volume: .8);
          host.fx.confetti(count: 90);
          host.flash(const Color(0x66FFFFFF), .2);
          final t = host.time;
          host.win(stars: t < 12.5 ? 3 : (t < 14.5 ? 2 : 1));
        }
      }
    } else {
      _mode = _M.fail;
      _mT = 0;
      _wrongPad = i;
      host.sfx(Sfx.buzzer);
      host.sfx(Sfx.glitch, volume: .6);
      host.shake(10, .35);
      host.flash(Pal.red, .2);
      host.lose();
    }
  }

  @override
  void update(double dt) {
    _t += dt;
    _mT += dt;
    for (var i = 0; i < 4; i++) {
      _glow[i] = M.approach(_glow[i], 0, 5, dt);
      _cpuOutT[i] += dt;
    }
    switch (_mode) {
      case _M.show:
        final len = _lens[_round];
        final idx = _mT < 0 ? -1 : (_mT / _step).floor();
        if (idx != _showIdx && idx >= 0 && idx < len) {
          _showIdx = idx;
          _light(_seq[idx]);
        }
        if (_mT >= len * _step + .1) {
          _mode = _M.input;
          _mT = 0;
          _inputIdx = 0;
          host.sfx(Sfx.notify, volume: .5);
        }
      case _M.input:
        break;
      case _M.clear:
        if (_mT > .8 && _round < 2) {
          _round++;
          _mode = _M.show;
          _mT = -.1;
          _showIdx = -1;
          host.sfx(Sfx.whoosh, volume: .4);
        }
      case _M.fail:
        break;
    }
  }

  @override
  void render(Canvas c) {
    // synthwave backdrop
    D.gradientBg(c, const [Color(0xFF07021A), Color(0xFF1B0640), Color(0xFF3A0A5E)]);
    // horizon sun
    c.save();
    c.clipRect(const Rect.fromLTWH(0, 0, 360, 250));
    c.drawCircle(const Offset(180, 250), 90, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE53D), Color(0xFFFF3DDB)])
        .createShader(Rect.fromCircle(center: const Offset(180, 250), radius: 90)));
    for (var i = 0; i < 6; i++) {
      c.drawRect(Rect.fromLTWH(0, 190 + i * 11.0, 360, 2.0 + i), D.fill(const Color(0xFF1B0640)));
    }
    c.restore();
    // stars
    for (var i = 0; i < 30; i++) {
      final x = (i * 97 % 360).toDouble();
      final y = 44 + (i * 53 % 150).toDouble();
      final tw = .3 + .7 * M.wave(_t, .5 + (i % 5) * .2);
      c.drawCircle(Offset(x, y), 1.4, D.fill(Color.fromRGBO(255, 255, 255, tw)));
    }
    // neon grid floor
    c.drawRect(const Rect.fromLTWH(0, 250, 360, 390), D.fill(const Color(0xFF12032C)));
    final gp = D.stroke(const Color(0x88FF3DDB), 1.5);
    for (var i = 0; i < 12; i++) {
      final k = ((i + (_t * 1.2) % 1) / 12);
      final y = 250 + pow(k, 2.2) * 390;
      c.drawLine(Offset(0, y), Offset(360, y), gp);
    }
    for (var i = -8; i <= 8; i++) {
      c.drawLine(Offset(180 + i * 8.0, 250), Offset(180 + i * 70.0, 640), gp);
    }
    c.drawLine(const Offset(0, 250), const Offset(360, 250), D.stroke(const Color(0xFFFF3DDB), 2.5));

    _renderRivals(c);
    // console base
    final base = RRect.fromRectAndRadius(Rect.fromCenter(center: _gridC, width: _pad * 2 + _gap + 30, height: _pad * 2 + _gap + 30),
        const Radius.circular(36));
    c.drawRRect(base.shift(const Offset(0, 8)), D.fill(const Color(0xFF05010F)));
    c.drawRRect(base, D.fill(const Color(0xFF15082E)));
    c.drawRRect(base, Paint()
      ..color = const Color(0xFF8C4DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = _blurSmall);
    c.drawRRect(base, D.stroke(const Color(0xFFB98CFF), 2));
    for (var i = 0; i < 4; i++) {
      _renderPad(c, i);
    }
    // center hub shows progress
    D.circle(c, _gridC, 30, const Color(0xFF15082E), border: const Color(0xFFB98CFF), borderWidth: 3);
    final len = _lens[_round];
    final done = _mode == _M.input ? _inputIdx : (_mode == _M.clear ? len : 0);
    for (var k = 0; k < len; k++) {
      final a = -pi / 2 + k / len * pi * 2;
      final on = k < done;
      c.drawCircle(_gridC + Offset(cos(a), sin(a)) * 18, 4.5, D.fill(on ? Pal.white : const Color(0x55FFFFFF)));
    }
    D.text(c, '$len', _gridC, size: 16, color: Pal.white);

    // round pips
    for (var r = 0; r < 3; r++) {
      final x = 132 + r * 48.0;
      final state = r < _round || (r == _round && _mode == _M.clear) ? 2 : (r == _round ? 1 : 0);
      final col = state == 2 ? const Color(0xFF6BFF5A) : (state == 1 ? const Color(0xFF22F0FF) : const Color(0x44FFFFFF));
      c.drawCircle(Offset(x, 568), 13, Paint()
        ..color = col
        ..maskFilter = state > 0 ? _blurSmall : null);
      D.circle(c, Offset(x, 568), 11, const Color(0xFF15082E), border: col, borderWidth: 3);
      D.text(c, '${_lens[r]}', Offset(x, 568), size: 12, color: col);
    }
    // status line
    String status;
    Color sc;
    switch (_mode) {
      case _M.show:
        status = host.tr('watch', 'WATCH');
        sc = const Color(0xFF22F0FF);
      case _M.input:
        status = host.tr('repeat', 'REPEAT!');
        sc = const Color(0xFFFFE53D);
      case _M.clear:
        status = host.tr('nice', 'NICE!');
        sc = const Color(0xFF6BFF5A);
      case _M.fail:
        status = host.tr('miss', 'MISS');
        sc = const Color(0xFFFF3D5C);
    }
    final pulse = 1 + sin(_t * 8) * .04;
    c.save();
    c.translate(180, 608);
    c.scale(pulse);
    D.text(c, status, Offset.zero, size: 26, color: sc, stroke: const Color(0xFF15082E));
    c.restore();
    if (_mode == _M.input && _inputIdx == 0 && _round == 0 && _mT < 2.5) {
      D.hand(c, _padRect(_seq[0]).center, _t);
    }
  }

  void _renderPad(Canvas c, int i) {
    final r = _padRect(i);
    final g = _glow[i];
    final wrong = _mode == _M.fail && i == _wrongPad;
    final col = wrong ? const Color(0xFFFF3D5C) : _neon[i];
    final press = g * 4;
    final rr = RRect.fromRectAndRadius(r.shift(Offset(0, press)), const Radius.circular(26));
    // dim body
    c.drawRRect(rr, D.fill(Color.lerp(const Color(0xFF15082E), col, .18 + g * .7 + (wrong ? .5 : 0))!));
    // glow
    if (g > .02 || wrong) {
      final a = wrong ? .6 + .4 * sin(_t * 30) : g;
      c.drawRRect(rr.inflate(6), Paint()
        ..color = col.withValues(alpha: a * .9)
        ..maskFilter = _blur);
      c.drawRRect(rr, D.fill(col.withValues(alpha: a * .85)));
      c.drawRRect(rr.deflate(18), D.fill(Color.fromRGBO(255, 255, 255, a * .5)));
    }
    // neon border
    c.drawRRect(rr, Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = _blurSmall);
    c.drawRRect(rr, D.stroke(Color.lerp(col, Pal.white, .4)!, 2.5));
    // symbol
    final ctr = rr.center;
    final sym = D.stroke(Color.lerp(col, Pal.white, .3 + g * .7)!, 5);
    switch (i) {
      case 0:
        c.drawPath(Path()
          ..moveTo(ctr.dx, ctr.dy - 22)
          ..lineTo(ctr.dx + 22, ctr.dy + 16)
          ..lineTo(ctr.dx - 22, ctr.dy + 16)
          ..close(), sym);
      case 1:
        c.drawCircle(ctr, 21, sym);
      case 2:
        c.drawRect(Rect.fromCenter(center: ctr, width: 38, height: 38), sym);
      default:
        c.drawPath(D.starPath(ctr, 25, 11), sym);
    }
    if (wrong) {
      D.line(c, ctr + const Offset(-30, -30), ctr + const Offset(30, 30), Pal.white, 8);
      D.line(c, ctr + const Offset(30, -30), ctr + const Offset(-30, 30), Pal.white, 8);
    }
  }

  void _renderRivals(Canvas c) {
    // you + 3 rivals on neon podiums
    for (var k = 0; k < 4; k++) {
      final x = 54 + k * 84.0;
      const y = 214.0;
      final out = k > 0 && _cpuOut[k];
      final ot = _cpuOutT[k];
      final col = _Cast.col[k];
      // podium
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y + 10), width: 62, height: 16), const Radius.circular(6)),
          Paint()
            ..color = col.withValues(alpha: out ? .2 : .8)
            ..maskFilter = _blurSmall);
      D.rrect(c, Rect.fromCenter(center: Offset(x, y + 10), width: 58, height: 14), 6, const Color(0xFF15082E),
          border: out ? const Color(0x55FFFFFF) : col, borderWidth: 2);
      Face face;
      if (out) {
        face = Face.dead;
      } else if (k == 0 && _mode == _M.fail) {
        face = Face.cry;
      } else if (_mode == _M.clear) {
        face = k == 0 ? Face.happy : Face.shocked;
      } else if (_mode == _M.show) {
        face = Face.neutral;
      } else {
        face = k == 0 ? Face.angry : _Cast.mood[k];
      }
      final look = _lastPad >= 0 && _mode != _M.show
          ? Offset(_lastPad % 2 == 0 ? -1 : 1, 1)
          : Offset(sin(_t * 2 + k) * .5, 1);
      final fall = out ? M.clamp01(ot / .4) : 0.0;
      final bob = _mode == _M.clear && !out ? -sin(_mT * 14).abs() * 8 : 0.0;
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, out ? .55 : 1));
      _Cast.draw(c, k, Offset(x, y + 3 + bob + fall * 6), 20, face: face, look: look, tilt: fall * .5, squash: 1 - fall * .15);
      c.restore();
      if (out) {
        final s = M.easeOutBack(M.clamp01(ot / .3));
        c.save();
        c.translate(x, y - 22);
        c.scale(s);
        c.rotate(-.2);
        D.rrect(c, const Rect.fromLTWH(-24, -11, 48, 22), 6, const Color(0xFFFF3D5C), border: Pal.white, borderWidth: 2);
        D.text(c, host.tr('out', 'OUT'), Offset.zero, size: 13, color: Pal.white);
        c.restore();
      }
      final label = k == 0 ? host.tr('you', 'YOU') : '${host.tr('cpu', 'CPU')}$k';
      D.text(c, label, Offset(x, y + 30), size: 11, color: k == 0 ? Pal.yellow : const Color(0xCCFFFFFF));
    }
  }
}

/// Party cast shared by No.046–053: you (blue hero) vs Red, Green, Yellow.
abstract final class _Cast {
  static const col = [Color(0xFF3D8BFF), Color(0xFFFF4B5C), Color(0xFF37D67A), Color(0xFFFFCF33)];
  static const dark = [Color(0xFF1F4FB8), Color(0xFFB8243A), Color(0xFF1C8F4E), Color(0xFFC79A10)];
  static const mood = [Face.happy, Face.angry, Face.smug, Face.happy];

  /// Draws party member [i] standing with feet at [feet]. [run] animates feet.
  static void draw(Canvas c, int i, Offset feet, double r,
      {Face? face, double squash = 1, double tilt = 0, double? run, Offset look = Offset.zero, bool soot = false}) {
    c.save();
    c.translate(feet.dx, feet.dy);
    if (tilt != 0) c.rotate(tilt);
    if (squash != 1) c.scale(1 / sqrt(squash), squash);
    final body = soot ? const Color(0xFF3A3340) : col[i];
    final dk = soot ? const Color(0xFF221D28) : dark[i];
    // feet
    final ph = run ?? 0;
    for (final s in [-1.0, 1.0]) {
      final sw = run == null ? 0.0 : sin(ph * pi + (s > 0 ? 0 : pi));
      final lift = run == null ? 0.0 : max(0.0, sw) * r * .35;
      c.drawOval(Rect.fromCenter(center: Offset(s * r * .42 + sw * r * .38, -r * .08 - lift), width: r * .62, height: r * .36),
          D.fill(dk));
    }
    // accessories behind the body
    if (i == 1) {
      for (final s in [-1.0, 1.0]) {
        final p = Path()
          ..moveTo(s * r * .72, -r * 1.45)
          ..lineTo(s * r * .78, -r * 2.2)
          ..lineTo(s * r * .3, -r * 1.7)
          ..close();
        c.drawPath(p, D.fill(soot ? dk : const Color(0xFFFFF4DC)));
        c.drawPath(p, D.stroke(Pal.ink, max(1.5, r * .08)));
      }
    }
    D.blob(c, Offset(0, -r * .95), r, body, face: face ?? mood[i], look: look);
    final sw = max(1.5, r * .08);
    switch (i) {
      case 0: // hero cowlick + headband
        final p = Path()
          ..moveTo(-r * .2, -r * 1.82)
          ..quadraticBezierTo(-r * .15, -r * 2.5, r * .45, -r * 2.35)
          ..quadraticBezierTo(r * .05, -r * 2.2, r * .2, -r * 1.84)
          ..close();
        c.drawPath(p, D.fill(body));
        c.drawPath(p, D.stroke(Pal.ink, sw));
        c.drawRect(Rect.fromLTWH(-r * .92, -r * 1.52, r * 1.84, r * .2), D.fill(soot ? dk : Pal.white));
        final tail = Path()
          ..moveTo(r * .85, -r * 1.45)
          ..lineTo(r * 1.35, -r * 1.7 + sin(ph * 2) * r * .1)
          ..lineTo(r * 1.3, -r * 1.3)
          ..close();
        c.drawPath(tail, D.fill(soot ? dk : Pal.white));
        c.drawPath(tail, D.stroke(Pal.ink, sw * .7));
      case 2: // sprout
        c.drawLine(Offset(0, -r * 1.85), Offset(0, -r * 2.3), D.stroke(Pal.ink, sw));
        for (final s in [-1.0, 1.0]) {
          c.save();
          c.translate(s * r * .22, -r * 2.3);
          c.rotate(s * .6);
          final leaf = Rect.fromCenter(center: Offset.zero, width: r * .5, height: r * .26);
          c.drawOval(leaf, D.fill(soot ? dk : const Color(0xFF9BE22D)));
          c.drawOval(leaf, D.stroke(Pal.ink, sw * .8));
          c.restore();
        }
      case 3: // bow
        final o = Offset(r * .45, -r * 1.72);
        for (final s in [-1.0, 1.0]) {
          final p = Path()
            ..moveTo(o.dx, o.dy)
            ..lineTo(o.dx + s * r * .42, o.dy - r * .24)
            ..lineTo(o.dx + s * r * .42, o.dy + r * .24)
            ..close();
          c.drawPath(p, D.fill(soot ? dk : Pal.pink));
          c.drawPath(p, D.stroke(Pal.ink, sw * .8));
        }
        c.drawCircle(o, r * .12, D.fill(soot ? dk : Pal.pink));
        c.drawCircle(o, r * .12, D.stroke(Pal.ink, sw * .8));
    }
    c.restore();
  }
}
