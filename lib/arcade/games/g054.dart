import '../engine/engine.dart';

/// No.054 Mini Star Party — a compact Mario-Party-style board round.
///
/// 4 players (YOU + 3 CPU blobs) take 3 turns each on a 16-space loop.
/// Hit the dice block (the numbers cycle 1→6 — time your tap: the landing
/// space is previewed), blue +3 coins, red -3, "?" events. Pass the star
/// with 10 coins to buy it. Most stars (then coins) wins.
class G054 extends MiniGame {
  // ------------------------------------------------------------ layout ---
  static const _n = 16;
  static const _rounds = 3;
  static const _starCost = 10;
  // 0 blue, 1 red, 2 event
  static const _types = [0, 0, 1, 2, 0, 0, 1, 2, 0, 0, 2, 0, 1, 0, 2, 0];
  static final List<Offset> _spaces = _buildSpaces();
  static const _stage = Offset(180, 262);

  static List<Offset> _buildSpaces() {
    const x0 = 52.0, y0 = 138.0, s = 64.0;
    final out = <Offset>[];
    for (var i = 0; i < 5; i++) {
      out.add(Offset(x0 + i * s, y0));
    }
    for (var j = 1; j < 5; j++) {
      out.add(Offset(x0 + 4 * s, y0 + j * s));
    }
    for (var i = 3; i >= 0; i--) {
      out.add(Offset(x0 + i * s, y0 + 4 * s));
    }
    for (var j = 3; j >= 1; j--) {
      out.add(Offset(x0, y0 + j * s));
    }
    return out;
  }

  static const _cardY = 432.0;
  static Offset _cardCenter(int i) => Offset(48 + i * 88.0, _cardY + 40);

  // ------------------------------------------------------------- state ---
  final _pl = List.generate(4, (i) => _P(i));
  int _star = 6;
  double _starWarp = 0; // sparkle anim when relocated
  int _round = 0;
  int _turn = 0; // index in turn order (0 = you)
  _Ph _ph = _Ph.intro;
  double _pt = 0; // phase time
  double _t = 0;
  double _tempo = 1;

  // dice
  int _diceNum = 1;
  double _diceClock = 0;
  int _rolled = 0;
  int _stepsLeft = 0;
  double _blockHit = 0; // 0..1 flash after hit
  double _heroJump = 0; // 0..1 jump anim
  double _cpuHitAt = .5;
  bool _tapped = false;

  // move
  int _from = 0;
  double _hopT = 0;
  double _hopDur = .13;

  // event banner
  String _banner = '';
  Color _bannerCol = Pal.yellow;
  int _bannerIcon = 0; // 0 none 1 coin bag 2 hand 3 boss 4 star
  double _bannerT = 0;

  double _roundBanner = 0;
  bool _resultsShown = false;
  double _resT = 0;
  List<int> _rank = const [0, 1, 2, 3];

  // flying star (bought)
  Offset? _flyFrom;
  int _flyTo = 0;
  double _flyT = 0;

  _P get _cur => _pl[_turn];

  @override
  void init() {
    for (final p in _pl) {
      p.coins = 7;
      p.shown = 7;
    }
    _round = 0;
    _turn = 0;
    _roundBanner = 1;
    _ph = _Ph.intro;
    host.showScore = false;
  }

  // ------------------------------------------------------------ update ---
  @override
  void update(double dt) {
    _t += dt;
    _pt += dt * (_turn == 0 ? 1 : _tempo);
    final pdt = dt * (_turn == 0 ? 1 : _tempo);
    _blockHit = M.approach(_blockHit, 0, 5, dt);
    _roundBanner = max(0, _roundBanner - dt * .9);
    _bannerT = max(0, _bannerT - dt);
    _starWarp = max(0, _starWarp - dt);
    for (final p in _pl) {
      p.shown = M.approach(p.shown, p.coins.toDouble(), 10, dt);
      p.react = max(0, p.react - dt);
      p.squash = M.approach(p.squash, 1, 12, dt);
      p.cardBump = M.approach(p.cardBump, 0, 8, dt);
    }
    if (_flyFrom != null) {
      _flyT += dt * 1.8;
      if (_flyT >= 1) {
        _flyFrom = null;
        _pl[_flyTo].cardBump = 1;
        host.sfx(Sfx.star, rate: 1.2);
        host.fx.sparkle(_cardCenter(_flyTo), count: 12, radius: 36, color: Pal.yellow);
      }
    }
    if (_heroJump > 0) _heroJump = max(0, _heroJump - dt * 3.2);

    if (host.finished) {
      _resT += dt;
      return;
    }

    switch (_ph) {
      case _Ph.intro:
        if (_pt > .55) _startTurn();
      case _Ph.dice:
        _diceClock += pdt;
        final rate = (_turn == 0 ? 5.2 : 9.0) * sqrt(host.speed);
        final step = (_diceClock * rate).floor();
        final nn = step % 6 + 1;
        if (nn != _diceNum) {
          _diceNum = nn;
          if (_turn == 0) host.sfx(Sfx.tick, volume: .35, rate: 1 + nn * .06);
        }
        if (_turn != 0 && _pt > _cpuHitAt) _hit(_diceNum);
        if (_turn == 0 && _pt > 3.2) _hit(_diceNum); // auto hit if idle
      case _Ph.hit:
        if (_pt > .42) {
          _ph = _Ph.move;
          _pt = 0;
          _startHop();
        }
      case _Ph.move:
        _hopT += pdt / _hopDur;
        if (_hopT >= 1) _landHop();
      case _Ph.buy:
        if (_pt > .75) {
          if (_stepsLeft > 0) {
            _ph = _Ph.move;
            _pt = 0;
            _startHop();
          } else {
            _arrive();
          }
        }
      case _Ph.effect:
        if (_pt > .55) _nextTurn();
      case _Ph.results:
        _resT += dt;
        if (_resT > 1.5 && !_resultsShown) _finish();
    }
  }

  void _computeTempo() {
    // keep the whole round inside the timer: speed CPU turns up if needed
    var cpuLeft = 0;
    var youLeft = 0;
    for (var r = _round; r < _rounds; r++) {
      for (var i = 0; i < 4; i++) {
        if (r == _round && i < _turn) continue;
        if (i == 0) {
          youLeft++;
        } else {
          cpuLeft++;
        }
      }
    }
    final avail = host.timeLeft - 2.6 - youLeft * 1.9;
    final need = cpuLeft * 1.55;
    _tempo = avail <= .5 ? 3 : (need / avail).clamp(1.0, 3.0);
  }

  void _startTurn() {
    _computeTempo();
    _ph = _Ph.dice;
    _pt = 0;
    _diceClock = randInt(6) / 6;
    _tapped = false;
    _cpuHitAt = rand(.35, .6);
    host.sfx(Sfx.pop, rate: 1.2);
    _cur.squash = 1.3;
  }

  void _hit(int num) {
    if (_ph != _Ph.dice) return;
    _rolled = num;
    _stepsLeft = num;
    _ph = _Ph.hit;
    _pt = 0;
    _heroJump = 1;
    _blockHit = 1;
    host.sfx(Sfx.hit, rate: 1.1);
    host.sfx(Sfx.dice, volume: .8);
    host.shake(5);
    host.punch(.03);
    const blockPos = Offset(180, 214);
    host.fx.burst(blockPos, Pal.yellow,
        count: 18, speed: 260, size: 7, shape: PartShape.square, colors: const [Pal.yellow, Pal.orange, Pal.white, Pal.sky]);
    host.fx.ring(blockPos, Pal.white, size: 70);
    if (_turn == 0) {
      final good = _previewValue(num) > 0;
      if (good) host.fx.pop(host.tr('nice', 'NICE!'), const Offset(180, 160), color: Pal.lime, size: 26);
    }
  }

  int _previewValue(int num) {
    final p = _pl[0];
    var coins = p.coins;
    var v = 0;
    for (var s = 1; s <= num; s++) {
      if ((p.pos + s) % _n == _star && coins >= _starCost) {
        v += 100;
        coins -= _starCost;
      }
    }
    final t = _types[(p.pos + num) % _n];
    return v + (t == 0 ? 3 : (t == 1 ? -3 : 1));
  }

  void _startHop() {
    _from = _cur.pos;
    _hopT = 0;
    _hopDur = .13;
    host.sfx(Sfx.jump, volume: .45, rate: 1.1 + (_rolled - _stepsLeft) * .07);
  }

  void _landHop() {
    final p = _cur;
    p.pos = (p.pos + 1) % _n;
    _stepsLeft--;
    p.squash = 1.35;
    host.sfx(Sfx.step, volume: .5, rate: 1 + (_rolled - _stepsLeft) * .08);
    if (p.pos == _star) {
      if (p.coins >= _starCost) {
        _buyStar(p);
        return;
      } else {
        host.sfx(Sfx.wrong, volume: .5);
        host.fx.pop('$_starCost', _spaces[p.pos] + const Offset(0, -30), color: Pal.red, size: 18);
        p.react = .8;
        p.reactFace = Face.cry;
      }
    }
    if (_stepsLeft > 0) {
      _startHop();
    } else {
      _arrive();
    }
  }

  void _buyStar(_P p) {
    p.coins -= _starCost;
    p.stars++;
    _ph = _Ph.buy;
    _pt = 0;
    final at = _spaces[_star];
    host.sfx(Sfx.fanfare, volume: .8);
    host.sfx(Sfx.star);
    host.flash(const Color(0x88FFF1A8));
    host.shake(6);
    host.fx.burst(at, Pal.yellow, count: 26, speed: 300, size: 9, shape: PartShape.star, gravity: 200);
    host.fx.ring(at, Pal.yellow, size: 90);
    host.fx.pop(host.tr('star', 'STAR!'), at + const Offset(0, -46), color: Pal.yellow, size: 30, life: 1);
    host.fx.pop('-$_starCost', _cardCenter(p.id) + const Offset(18, 10), color: Pal.red, size: 18);
    _flyFrom = at;
    _flyTo = p.id;
    _flyT = 0;
    _banner = host.tr('star', 'STAR!');
    _bannerCol = Pal.yellow;
    _bannerIcon = 4;
    _bannerT = .75;
    for (final o in _pl) {
      if (o == p) {
        o.react = 1.4;
        o.reactFace = Face.love;
      } else {
        o.react = 1.4;
        o.reactFace = o.id == 0 ? Face.shocked : (o.id == 1 ? Face.angry : Face.cry);
      }
    }
    // the star runs away to a new space, well ahead of the buyer
    final occupied = {for (final o in _pl) o.pos};
    var ns = _star;
    for (var tries = 0; tries < 30; tries++) {
      ns = (p.pos + 4 + randInt(9)) % _n;
      if (ns != _star && ns != 0 && !occupied.contains(ns)) break;
    }
    _star = ns;
    _starWarp = 1;
  }

  void _arrive() {
    final p = _cur;
    _ph = _Ph.effect;
    _pt = 0;
    final at = _spaces[p.pos];
    final type = _types[p.pos];
    if (type == 0) {
      p.coins += 3;
      host.sfx(Sfx.coins, rate: 1.1);
      host.fx.coins(at, count: 6, speed: 220);
      host.fx.pop('+3', at + const Offset(0, -24), color: Pal.yellow, size: 22);
      p.react = .6;
      p.reactFace = Face.happy;
      p.cardBump = .6;
    } else if (type == 1) {
      final lost = min(3, p.coins);
      p.coins -= lost;
      host.sfx(Sfx.oops, volume: .8);
      host.fx.burst(at, Pal.red, count: 10, speed: 160, size: 6);
      host.fx.pop('-$lost', at + const Offset(0, -24), color: Pal.red, size: 22);
      p.react = .8;
      p.reactFace = Face.cry;
      p.cardBump = .6;
      if (p.id == 0) host.shake(4);
    } else {
      _event(p);
    }
  }

  void _event(_P p) {
    final at = _spaces[p.pos];
    host.sfx(Sfx.magic);
    host.fx.sparkle(at, count: 12, radius: 26, color: Pal.lime);
    // YOU are the main character: fate is a little kinder to you
    final e = p.id == 0 ? randInt(2) : randInt(3);
    _bannerT = .9;
    if (e == 0) {
      p.coins += 5;
      _banner = host.tr('lucky', 'LUCKY!');
      _bannerCol = Pal.lime;
      _bannerIcon = 1;
      host.sfx(Sfx.cash);
      host.fx.coins(at, count: 10, speed: 280);
      host.fx.pop('+5', at + const Offset(0, -24), color: Pal.yellow, size: 24);
      p.react = .8;
      p.reactFace = Face.love;
      p.cardBump = 1;
    } else if (e == 1) {
      var rich = -1;
      for (final o in _pl) {
        if (o != p && (rich < 0 || o.coins > _pl[rich].coins)) rich = o.id;
      }
      final v = _pl[rich];
      final a = min(3, v.coins);
      v.coins -= a;
      p.coins += a;
      _banner = host.tr('steal', 'STEAL!');
      _bannerCol = Pal.purple;
      _bannerIcon = 2;
      host.sfx(Sfx.swipe);
      host.sfx(Sfx.coin, rate: 1.3);
      host.fx.coins(_cardCenter(v.id), count: 6, speed: 200);
      host.fx.pop('-$a', _cardCenter(v.id) + const Offset(0, -30), color: Pal.red, size: 20);
      host.fx.pop('+$a', _cardCenter(p.id) + const Offset(0, -30), color: Pal.yellow, size: 20);
      v.react = 1;
      v.reactFace = Face.angry;
      v.cardBump = 1;
      p.react = 1;
      p.reactFace = Face.smug;
      p.cardBump = 1;
    } else {
      final lost = min(5, p.coins);
      p.coins -= lost;
      _banner = host.tr('boss', 'BOSS!');
      _bannerCol = Pal.red;
      _bannerIcon = 3;
      host.sfx(Sfx.horror, volume: .7);
      host.sfx(Sfx.explodeSmall, volume: .6);
      host.shake(7);
      host.fx.smoke(at, count: 8, color: const Color(0xCC4A2A5A));
      host.fx.pop('-$lost', at + const Offset(0, -24), color: Pal.red, size: 24);
      p.react = 1;
      p.reactFace = Face.dead;
      p.cardBump = 1;
      for (final o in _pl) {
        if (o != p) {
          o.react = .9;
          o.reactFace = Face.happy;
        }
      }
    }
  }

  void _nextTurn() {
    _turn++;
    if (_turn >= 4) {
      _turn = 0;
      _round++;
      if (_round >= _rounds) {
        _goResults();
        return;
      }
      _roundBanner = 1;
      host.sfx(Sfx.whistle, volume: .6);
    }
    _startTurn();
  }

  List<int> _ranking() {
    final ids = [0, 1, 2, 3];
    ids.sort((a, b) {
      final pa = _pl[a], pb = _pl[b];
      if (pa.stars != pb.stars) return pb.stars - pa.stars;
      if (pa.coins != pb.coins) return pb.coins - pa.coins;
      return a - b; // ties go to YOU (host's favorite)
    });
    return ids;
  }

  void _goResults() {
    _ph = _Ph.results;
    _pt = 0;
    _resT = 0;
    _rank = _ranking();
    host.sfx(Sfx.drumroll);
  }

  void _finish() {
    _resultsShown = true;
    _rank = _ranking();
    final won = _rank.first == 0;
    for (final p in _pl) {
      final place = _rank.indexOf(p.id);
      p.react = 9;
      p.reactFace = place == 0 ? Face.love : (place == 3 ? Face.cry : (p.id == 0 ? Face.sad : Face.shocked));
    }
    if (won) {
      host.sfx(Sfx.fanfare);
      host.sfx(Sfx.cheer, volume: .7);
      host.fx.confetti(count: 90);
      host.fx.coins(const Offset(180, 330), count: 20, speed: 420);
      final second = _pl[_rank[1]];
      final me = _pl[0];
      host.win(stars: me.stars > second.stars ? 3 : (me.coins > second.coins ? 2 : 1));
    } else {
      host.sfx(Sfx.aww);
      host.lose();
    }
  }

  @override
  void onTimeUp() {
    if (host.finished) return;
    if (_ph != _Ph.results) _goResults();
    _resT = 1.5;
    _finish();
  }

  // ------------------------------------------------------------- input ---
  @override
  void onDown(Offset p) {
    if (_ph == _Ph.dice && _turn == 0 && !_tapped) {
      _tapped = true;
      _hit(_diceNum);
    }
  }

  @override
  void onKey(String key, bool down) {
    if (down && key == 'action') onDown(Offset.zero);
  }

  // ------------------------------------------------------------ render ---
  @override
  void render(Canvas c) {
    _drawBackground(c);
    _drawBoard(c);
    _drawPreview(c);
    _drawStarSpace(c);
    _drawPieces(c);
    _drawStage(c);
    _drawCards(c);
    _drawHud(c);
    _drawFlyingStar(c);
    if (_ph == _Ph.results || (host.finished && _resultsShown)) _drawResults(c);
  }

  void _drawBackground(Canvas c) {
    D.gradientBg(c, const [Color(0xFF7FDBFF), Color(0xFF3AA6F0), Color(0xFF2167C9)]);
    // sea waves
    final wave = D.stroke(const Color(0x44FFFFFF), 3);
    for (var row = 0; row < 12; row++) {
      final y = 50.0 + row * 52;
      final off = (row.isEven ? 1 : -1) * (_t * 14) % 60;
      for (var x = -60.0 + off; x < 400; x += 60) {
        c.drawArc(Rect.fromCenter(center: Offset(x, y), width: 26, height: 10), pi, pi, false, wave);
      }
    }
    // island
    final island = RRect.fromRectAndRadius(const Rect.fromLTWH(14, 100, 332, 318), const Radius.circular(46));
    c.drawRRect(island.shift(const Offset(0, 8)), D.fill(const Color(0x33000000)));
    c.drawRRect(island, D.fill(const Color(0xFFFFE3A3)));
    final grass = RRect.fromRectAndRadius(const Rect.fromLTWH(24, 108, 312, 300), const Radius.circular(40));
    c.drawRRect(grass, D.fill(const Color(0xFF6FD66B)));
    c.save();
    c.clipRRect(grass);
    final stripe = D.fill(const Color(0x1A1B5E20));
    for (var i = -10; i < 20; i++) {
      c.drawPath(
          Path()
            ..moveTo(i * 40.0, 100)
            ..lineTo(i * 40.0 + 20, 100)
            ..lineTo(i * 40.0 + 340, 420)
            ..lineTo(i * 40.0 + 320, 420)
            ..close(),
          stripe);
    }
    c.restore();
    c.drawRRect(grass, D.stroke(const Color(0xFF3FA84A), 3));
    // interior plaza for the dice stage
    final plaza = RRect.fromRectAndRadius(const Rect.fromLTWH(92, 176, 176, 180), const Radius.circular(30));
    c.drawRRect(plaza, D.fill(const Color(0xFFB5F09B)));
    c.drawRRect(plaza, D.stroke(const Color(0x553FA84A), 3));
    // flowers + mini trees at plaza corners
    for (final p in const [Offset(104, 190), Offset(256, 190), Offset(104, 344), Offset(256, 344)]) {
      D.tree(c, p + const Offset(0, 8), 26, leaf: const Color(0xFF34B85A));
    }
    for (var i = 0; i < 8; i++) {
      final p = Offset(130 + (i * 37) % 100, 350 - (i * 23) % 12);
      c.drawCircle(p, 3, D.fill(Pal.candy[i % Pal.candy.length]));
    }
    // loop path
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromPoints(_spaces[0], _spaces[8]), const Radius.circular(8)));
    c.drawPath(path, D.stroke(const Color(0xFFC89B5A), 20));
    c.drawPath(path, D.stroke(const Color(0xFFFFF1C9), 14));
  }

  void _drawBoard(Canvas c) {
    for (var i = 0; i < _n; i++) {
      final o = _spaces[i];
      final t = _types[i];
      final col = t == 0 ? Pal.blue : (t == 1 ? Pal.red : Pal.green);
      D.shadow(c, o + const Offset(0, 5), 44, 16, .25);
      c.drawCircle(o + const Offset(0, 3), 20, D.fill(Color.lerp(col, Pal.ink, .45)!));
      c.drawCircle(o, 20, D.fill(col));
      c.drawCircle(o + const Offset(-5, -6), 7, D.fill(const Color(0x55FFFFFF)));
      c.drawCircle(o, 20, D.stroke(Pal.white, 3));
      if (t == 0) {
        c.drawCircle(o, 6, D.fill(const Color(0xAAFFFFFF)));
      } else if (t == 1) {
        D.line(c, o + const Offset(-6, 0), o + const Offset(6, 0), const Color(0xCCFFFFFF), 4);
      } else {
        D.text(c, '?', o, size: 22, color: Pal.white, stroke: const Color(0xFF1C7A3F), strokeWidth: 4);
      }
      if (i == 0) {
        // start flag
        D.line(c, o + const Offset(-14, -10), o + const Offset(-14, -36), Pal.ink, 3);
        c.drawPath(
            Path()
              ..moveTo(o.dx - 14, o.dy - 36)
              ..lineTo(o.dx + 4 + sin(_t * 6) * 2, o.dy - 30)
              ..lineTo(o.dx - 14, o.dy - 24)
              ..close(),
            D.fill(Pal.orange));
      }
    }
  }

  void _drawPreview(Canvas c) {
    if (_ph != _Ph.dice || _turn != 0) return;
    final p = _pl[0];
    final dest = (p.pos + _diceNum) % _n;
    // trail dots
    for (var s = 1; s < _diceNum; s++) {
      final o = _spaces[(p.pos + s) % _n];
      c.drawCircle(o, 5, D.fill(const Color(0xCCFFFFFF)));
    }
    final pulse = M.wave(_t, 3);
    final o = _spaces[dest];
    c.drawCircle(o, 25 + pulse * 5, D.stroke(Pal.white, 4));
    c.drawCircle(o, 25 + pulse * 5, D.stroke(const Color(0x66FFFFFF), 10));
    final v = _previewValue(_diceNum);
    final icon = v >= 100 ? 'STAR' : '';
    final col = v >= 100 ? Pal.yellow : (v > 0 ? Pal.lime : Pal.red);
    final label = v >= 100 ? host.tr('star', 'STAR!') : (_types[dest] == 2 ? '?' : (v > 0 ? '+3' : '-3'));
    D.text(c, label, o + Offset(0, -34 - pulse * 4), size: icon.isEmpty ? 18 : 16, color: col, stroke: Pal.ink);
  }

  void _drawStarSpace(Canvas c) {
    final o = _spaces[_star];
    final bob = sin(_t * 4) * 3;
    D.rays(c, o, 42, const Color(0x55FFF3A0), count: 10, t: _t * 1.2);
    c.drawCircle(o, 22, D.stroke(Pal.yellow, 4));
    final so = o + Offset(0, -30 + bob);
    D.star(c, so + const Offset(0, 3), 17, const Color(0xFFB8860B));
    D.star(c, so, 17, Pal.yellow, border: Pal.ink, rotation: -pi / 2 + sin(_t * 3) * .15);
    D.face(c, so + const Offset(0, 2), 9, Face.happy, blush: false);
    // price tag
    final tag = Rect.fromCenter(center: o + const Offset(22, -14), width: 28, height: 16);
    D.rrect(c, tag, 8, Pal.white, border: Pal.ink, borderWidth: 2);
    D.text(c, '$_starCost', tag.center, size: 11, color: Pal.ink);
    if (_starWarp > 0) {
      c.drawCircle(o, 30 + (1 - _starWarp) * 40,
          D.stroke(Color.fromRGBO(255, 230, 120, _starWarp), 6 * _starWarp));
    }
  }

  Offset _pieceOffset(int who) {
    final p = _pl[who];
    var count = 0, slot = 0;
    for (final o in _pl) {
      final moving = o == _cur && (_ph == _Ph.move) && !host.finished;
      if (moving) continue;
      if (o.pos == p.pos) {
        if (o.id < who) slot++;
        count++;
      }
    }
    if (count <= 1) return Offset.zero;
    const offs = [Offset(-9, -7), Offset(9, -7), Offset(-9, 7), Offset(9, 7)];
    return offs[slot % 4];
  }

  void _drawPieces(Canvas c) {
    final order = [3, 2, 1, 0]..remove(_turn)..add(_turn);
    for (final i in order) {
      final p = _pl[i];
      Offset pos;
      var lift = 0.0;
      if (i == _turn && _ph == _Ph.move) {
        final a = _spaces[_from], b = _spaces[(_from + 1) % _n];
        final k = M.easeInOut(_hopT.clamp(0, 1));
        pos = Offset.lerp(a, b, k)!;
        lift = sin(_hopT.clamp(0, 1) * pi) * 22;
      } else {
        pos = _spaces[p.pos] + _pieceOffset(i);
      }
      D.shadow(c, pos + const Offset(0, 10), 24 - lift * .3, 8, .3);
      final face = p.react > 0 ? p.reactFace : _Cast.face[i];
      _Cast.draw(c, i, pos + Offset(0, -6 - lift), 12, face: face, squash: p.squash);
      if (i == _turn && !host.finished && _ph != _Ph.results) {
        final ay = pos.dy - 38 - lift + sin(_t * 8) * 3;
        c.drawPath(
            Path()
              ..moveTo(pos.dx - 7, ay)
              ..lineTo(pos.dx + 7, ay)
              ..lineTo(pos.dx, ay + 8)
              ..close(),
            D.fill(_Cast.col[i]));
      }
    }
  }

  void _drawStage(Canvas c) {
    if (_ph == _Ph.results) return;
    final who = _turn;
    final p = _pl[who];
    // spotlight
    c.drawOval(Rect.fromCenter(center: _stage + const Offset(0, 74), width: 120, height: 26),
        D.fill(Color.lerp(_Cast.col[who], Pal.white, .5)!.withValues(alpha: .6)));
    // hero jump
    final jumpK = _heroJump > 0 ? sin((1 - _heroJump) * pi) : 0.0;
    final heroPos = _stage + Offset(0, 48 - jumpK * 34);
    D.shadow(c, _stage + const Offset(0, 76), 60 - jumpK * 20, 14, .25);
    final face = _ph == _Ph.dice
        ? (who == 0 ? Face.happy : _Cast.face[who])
        : (p.react > 0 ? p.reactFace : Face.happy);
    _Cast.draw(c, who, heroPos, 28, face: face, squash: _heroJump > .5 ? .85 : p.squash, look: const Offset(0, -1));

    // dice block
    if (_ph == _Ph.dice || (_ph == _Ph.hit && _pt < .12)) {
      final bob = sin(_t * 5) * 4;
      final wob = sin(_t * 9) * .06;
      _drawBlock(c, Offset(180, 204 + bob), 58, '$_diceNum', wob, _turn == 0);
    } else if (_ph == _Ph.hit || _ph == _Ph.move || _ph == _Ph.buy) {
      // big rolled number bubble counting down
      final n = _ph == _Ph.hit ? _rolled : _stepsLeft;
      final k = _ph == _Ph.hit ? M.easeOutBack((_pt / .3).clamp(0, 1)) : 1.0;
      if (n > 0) {
        c.save();
        c.translate(180, 206);
        c.scale(k);
        c.drawCircle(Offset.zero, 30, D.fill(Pal.white));
        c.drawCircle(Offset.zero, 30, D.stroke(_Cast.col[who], 5));
        D.text(c, '$n', const Offset(0, 1), size: 38, color: Pal.ink);
        c.restore();
      }
    }

    // event banner
    if (_bannerT > 0 && _bannerIcon != 0) {
      final k = M.easeOutBack(((0.9 - _bannerT) / .2).clamp(0, 1));
      c.save();
      c.translate(180, 206);
      c.scale(k.clamp(0.01, 2));
      D.rrect(c, const Rect.fromLTWH(-72, -40, 144, 80), 18, Pal.white, border: Pal.ink, borderWidth: 3);
      D.rrect(c, const Rect.fromLTWH(-66, -34, 132, 68), 14, _bannerCol.withValues(alpha: .25));
      final ic = const Offset(-38, 0);
      switch (_bannerIcon) {
        case 1:
          c.drawOval(Rect.fromCenter(center: ic + const Offset(0, 6), width: 40, height: 34), D.fill(const Color(0xFFC08A4A)));
          c.drawOval(Rect.fromCenter(center: ic + const Offset(0, 6), width: 40, height: 34), D.stroke(Pal.ink, 2.5));
          D.coin(c, ic + const Offset(0, 6), 9, spin: _t);
        case 2:
          D.rrect(c, Rect.fromCenter(center: ic, width: 30, height: 30), 12, Pal.purple, border: Pal.ink);
          for (var f = 0; f < 3; f++) {
            D.rrect(c, Rect.fromLTWH(ic.dx - 13 + f * 9, ic.dy - 24, 8, 16), 4, Pal.purple, border: Pal.ink, borderWidth: 2);
          }
        case 3:
          c.drawCircle(ic, 20, D.fill(const Color(0xFF4A2A5A)));
          for (final s in [-1.0, 1.0]) {
            c.drawPath(
                Path()
                  ..moveTo(ic.dx + s * 14, ic.dy - 12)
                  ..lineTo(ic.dx + s * 22, ic.dy - 30)
                  ..lineTo(ic.dx + s * 5, ic.dy - 18)
                  ..close(),
                D.fill(Pal.cream));
          }
          D.face(c, ic, 16, Face.angry, ink: Pal.white, blush: false);
        case 4:
          D.star(c, ic, 22, Pal.yellow, border: Pal.ink);
      }
      D.text(c, _banner, const Offset(20, 0), size: 20, color: _bannerCol, stroke: Pal.ink, maxWidth: 90);
      c.restore();
    }
  }

  void _drawBlock(Canvas c, Offset o, double s, String label, double rot, bool mine) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(rot);
    final h = s / 2;
    // top face (fake 3D)
    final top = Path()
      ..moveTo(-h, -h)
      ..lineTo(-h + 10, -h - 10)
      ..lineTo(h + 10, -h - 10)
      ..lineTo(h, -h)
      ..close();
    final side = Path()
      ..moveTo(h, -h)
      ..lineTo(h + 10, -h - 10)
      ..lineTo(h + 10, h - 10)
      ..lineTo(h, h)
      ..close();
    final hue = (_t * 160) % 360;
    c.drawPath(top, D.fill(D.hsv(hue, .35, 1)));
    c.drawPath(side, D.fill(D.hsv(hue, .6, .7)));
    c.drawPath(top, D.stroke(Pal.ink, 3));
    c.drawPath(side, D.stroke(Pal.ink, 3));
    D.rrect(c, Rect.fromCenter(center: Offset.zero, width: s, height: s), 10, D.hsv(hue, .55, .95),
        border: Pal.ink, borderWidth: 3.5);
    D.rrect(c, Rect.fromCenter(center: Offset.zero, width: s - 12, height: s - 12), 7, Pal.white);
    // rivets
    for (final d in const [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)]) {
      c.drawCircle(d * (h - 5), 2.5, D.fill(Pal.ink));
    }
    D.text(c, label, const Offset(0, 1), size: 36, color: mine ? Pal.blue : Pal.ink);
    c.restore();
  }

  void _drawCards(Canvas c) {
    for (var i = 0; i < 4; i++) {
      final p = _pl[i];
      final active = i == _turn && _ph != _Ph.results && !host.finished;
      final cc = _cardCenter(i);
      final lift = (active ? -6.0 : 0.0) - p.cardBump * 6;
      final r = Rect.fromCenter(center: cc + Offset(0, lift), width: 80, height: 78);
      final col = _Cast.col[i];
      D.rrect(c, r.shift(const Offset(0, 4)), 14, Color.lerp(col, Pal.ink, .6)!);
      D.rrect(c, r, 14, Color.lerp(col, Pal.white, .55)!,
          border: active ? Pal.white : Pal.ink, borderWidth: active ? 4 : 3,
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(col, Pal.white, .6)!, Color.lerp(col, Pal.white, .2)!]));
      if (active) {
        c.drawRRect(RRect.fromRectAndRadius(r.inflate(4), const Radius.circular(18)),
            D.stroke(Pal.yellow.withValues(alpha: .5 + .5 * M.wave(_t, 3)), 3));
      }
      final face = p.react > 0 ? p.reactFace : _Cast.face[i];
      _Cast.draw(c, i, Offset(r.left + 20, r.top + 24), 13, face: face);
      D.text(c, i == 0 ? host.tr('you', 'YOU') : host.tr('cpu', 'CPU'), Offset(r.left + 56, r.top + 16),
          size: 12, color: Pal.white, stroke: Pal.ink, strokeWidth: 3, maxWidth: 44);
      // stars
      D.star(c, Offset(r.left + 16, r.top + 50), 9, Pal.yellow, border: Pal.ink);
      D.text(c, '${p.stars}', Offset(r.left + 34, r.top + 50), size: 16, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
      // coins
      D.coin(c, Offset(r.left + 50, r.top + 50), 7);
      D.text(c, '${p.shown.round()}', Offset(r.left + 68, r.top + 50), size: 14, color: Pal.white, stroke: Pal.ink,
          strokeWidth: 4);
      // live place badge
      final place = _ranking().indexOf(i) + 1;
      final bc = place == 1 ? Pal.gold : (place == 2 ? const Color(0xFFCFD8E6) : (place == 3 ? const Color(0xFFD9955B) : Pal.gray));
      c.drawCircle(Offset(r.right - 6, r.top + 4), 10, D.fill(bc));
      c.drawCircle(Offset(r.right - 6, r.top + 4), 10, D.stroke(Pal.ink, 2));
      D.text(c, '$place', Offset(r.right - 6, r.top + 5), size: 12, color: Pal.ink);
    }
  }

  void _drawHud(Canvas c) {
    // round pill
    final rr = Rect.fromCenter(center: const Offset(180, 66), width: 150, height: 34);
    D.rrect(c, rr.shift(const Offset(0, 3)), 17, const Color(0x55000000));
    D.rrect(c, rr, 17, Pal.ink, border: Pal.white, borderWidth: 3);
    final rn = min(_round + 1, _rounds);
    D.text(c, '${host.tr('round', 'ROUND')} $rn/$_rounds', rr.center, size: 17, color: Pal.yellow, maxWidth: 140);

    if (_roundBanner > 0 && _ph != _Ph.results) {
      final k = _roundBanner;
      final x = 180 + (k > .8 ? (k - .8) / .2 * 400 : (k < .2 ? -(.2 - k) / .2 * 400 : 0.0));
      D.rrect(c, Rect.fromCenter(center: Offset(x, 262), width: 300, height: 64), 20, const Color(0xDD1B1530),
          border: Pal.yellow, borderWidth: 4);
      final label = _round == _rounds - 1 ? '${host.tr('round', 'ROUND')} $rn  ${host.tr('final', 'FINAL')}' : '${host.tr('round', 'ROUND')} $rn';
      D.title(c, label, Offset(x, 262), size: 30, color: _round == _rounds - 1 ? Pal.red : Pal.yellow);
    }

    // bottom prompt
    if (_ph == _Ph.dice && _turn == 0) {
      final k = 1 + .06 * sin(_t * 10);
      D.title(c, host.tr('tap', 'TAP!'), const Offset(180, 560), size: 36 * k, color: Pal.white);
      D.hand(c, const Offset(250, 548), _t, size: 40);
      D.text(c, '1 2 3 4 5 6', const Offset(180, 604), size: 14, color: const Color(0xCCFFFFFF), letterSpacing: 2);
    } else if (_ph != _Ph.results && !host.finished && _ph != _Ph.intro) {
      final col = _Cast.col[_turn];
      final lab = _turn == 0 ? host.tr('you', 'YOU') : '${host.tr('cpu', 'CPU')} $_turn';
      D.rrect(c, Rect.fromCenter(center: const Offset(180, 568), width: 170, height: 46), 23, col,
          border: Pal.ink, borderWidth: 3);
      _Cast.draw(c, _turn, const Offset(118, 566), 14, face: _Cast.face[_turn]);
      D.text(c, lab, const Offset(194, 569), size: 22, color: Pal.white, stroke: Pal.ink, maxWidth: 100);
    }
  }

  void _drawFlyingStar(Canvas c) {
    final f = _flyFrom;
    if (f == null) return;
    final to = _cardCenter(_flyTo) + const Offset(-24, 10);
    final k = M.easeInOut(_flyT.clamp(0, 1));
    final p = Offset.lerp(f, to, k)! + Offset(0, -sin(k * pi) * 120);
    D.rays(c, p, 50, const Color(0x66FFF3A0), count: 8, t: _t * 4);
    D.star(c, p, 22 - k * 8, Pal.yellow, border: Pal.ink, rotation: _t * 8);
  }

  void _drawResults(Canvas c) {
    final k = M.clamp01(_resT / .4);
    c.drawRect(GameHost.bounds, D.fill(Color.fromRGBO(20, 12, 40, .78 * k)));
    if (k < .05) return;
    final rank = _rank;
    const xs = [180.0, 100.0, 260.0, 324.0];
    const hs = [120.0, 84.0, 60.0, 30.0];
    const base = 520.0;
    final reveal = _resultsShown || _resT > 1.2;
    if (reveal) {
      D.rays(c, Offset(xs[0], base - hs[0] - 40), 400, const Color(0x33FFE680), count: 16, t: _t * .6);
    }
    for (var place = 3; place >= 0; place--) {
      final id = rank[place];
      final x = xs[place];
      final h = hs[place];
      final appear = M.clamp01((_resT - .2 - (3 - place) * .25) / .3);
      if (appear <= 0) continue;
      final hh = h * M.easeOutBack(appear);
      final w = place == 3 ? 48.0 : 72.0;
      final col = place == 0 ? Pal.gold : (place == 1 ? const Color(0xFFCFD8E6) : (place == 2 ? const Color(0xFFD9955B) : Pal.gray));
      D.rrect(c, Rect.fromLTWH(x - w / 2, base - hh, w, hh), 8, col, border: Pal.ink, borderWidth: 3);
      D.text(c, '${place + 1}', Offset(x, base - hh + 22), size: 26, color: Pal.white, stroke: Pal.ink);
      final p = _pl[id];
      final hop = place == 0 && reveal ? (sin(_t * 10).abs() * 12) : 0.0;
      final face = reveal ? (place == 0 ? Face.love : (place == 3 ? Face.cry : Face.shocked)) : Face.neutral;
      _Cast.draw(c, id, Offset(x, base - hh - 22 - hop), place == 0 ? 26 : 20, face: face);
      if (place == 0 && reveal) {
        // crown
        final cy = base - hh - 22 - hop - 36;
        c.drawPath(
            Path()
              ..moveTo(x - 16, cy + 10)
              ..lineTo(x - 18, cy - 8)
              ..lineTo(x - 8, cy + 2)
              ..lineTo(x, cy - 12)
              ..lineTo(x + 8, cy + 2)
              ..lineTo(x + 18, cy - 8)
              ..lineTo(x + 16, cy + 10)
              ..close(),
            D.fill(Pal.gold));
      }
      // stats
      D.star(c, Offset(x - 12, base + 18), 8, Pal.yellow, border: Pal.ink);
      D.text(c, '${p.stars}', Offset(x + 6, base + 18), size: 15, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
      D.coin(c, Offset(x - 12, base + 38), 6);
      D.text(c, '${p.coins}', Offset(x + 8, base + 38), size: 13, color: Pal.white, stroke: Pal.ink, strokeWidth: 4);
    }
  }
}

enum _Ph { intro, dice, hit, move, buy, effect, results }

class _P {
  _P(this.id);
  final int id;
  int pos = 0;
  int coins = 0;
  double shown = 0;
  int stars = 0;
  double react = 0;
  Face reactFace = Face.happy;
  double squash = 1;
  double cardBump = 0;
}

/// The party cast: YOU (blue hero) and 3 CPU rivals.
abstract final class _Cast {
  static const col = [Color(0xFF3D6BFF), Color(0xFFFF3B5C), Color(0xFF2ECC71), Color(0xFFFFC21F)];
  static const face = [Face.happy, Face.angry, Face.smug, Face.sleepy];

  static void draw(Canvas c, int who, Offset o, double r,
      {Face? face, double squash = 1, Offset look = Offset.zero}) {
    final sq = squash;
    final topY = o.dy + r * (sq - 1) * .5 - r * .95 / sq;
    // accessories behind
    if (who == 0) {
      // antenna with star
      D.line(c, Offset(o.dx, topY + 2), Offset(o.dx + r * .15, topY - r * .45), Pal.ink, max(1.5, r * .1));
      D.star(c, Offset(o.dx + r * .15, topY - r * .55), r * .32, Pal.yellow, border: Pal.ink);
    } else if (who == 1) {
      final tuft = Path();
      for (var k = -1; k <= 1; k++) {
        final bx = o.dx + k * r * .38;
        tuft
          ..moveTo(bx - r * .22, topY + r * .2)
          ..lineTo(bx + k * r * .12, topY - r * .42)
          ..lineTo(bx + r * .22, topY + r * .2)
          ..close();
      }
      c.drawPath(tuft, D.fill(const Color(0xFFB8173A)));
      c.drawPath(tuft, D.stroke(Pal.ink, max(1.2, r * .07)));
    }
    D.blob(c, o, r, col[who], face: face ?? _Cast.face[who], look: look, squash: sq);
    final fy = o.dy + r * (sq - 1) * .5;
    if (who == 2) {
      // round glasses
      final g = D.stroke(Pal.ink, max(1.2, r * .08));
      final sx = 1 / sqrt(sq);
      for (final s in [-1.0, 1.0]) {
        c.drawCircle(Offset(o.dx + s * r * .34 * sx, fy - r * .06 / sq), r * .26, g);
      }
      D.line(c, Offset(o.dx - r * .1 * sx, fy - r * .08 / sq), Offset(o.dx + r * .1 * sx, fy - r * .08 / sq), Pal.ink,
          max(1.2, r * .07));
    } else if (who == 3) {
      // bow
      final b = Offset(o.dx + r * .55, topY + r * .28);
      final bow = Path()
        ..moveTo(b.dx, b.dy)
        ..lineTo(b.dx - r * .42, b.dy - r * .25)
        ..lineTo(b.dx - r * .42, b.dy + r * .25)
        ..close()
        ..moveTo(b.dx, b.dy)
        ..lineTo(b.dx + r * .42, b.dy - r * .25)
        ..lineTo(b.dx + r * .42, b.dy + r * .25)
        ..close();
      c.drawPath(bow, D.fill(Pal.pink));
      c.drawPath(bow, D.stroke(Pal.ink, max(1.2, r * .07)));
      c.drawCircle(b, r * .12, D.fill(Pal.pink));
    }
  }
}
