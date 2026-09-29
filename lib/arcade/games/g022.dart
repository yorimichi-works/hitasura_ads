import 'dart:math' as math;

import '../engine/engine.dart';

/// No.022 Tiny King's Tax — pixel Reigns-style swipe ruler.
///
/// Petitioners bring requests (food, gold, war, festival, church, taxes).
/// Swipe right to accept, left to refuse. Four realm meters (people, gold,
/// army, church) react; if any runs empty or overflows, the king is
/// overthrown. Survive 8 decisions.
class G022 extends MiniGame {
  static const _goal = 8;
  static const _cardC = Offset(180, 440);

  static const _k = Color(0xFF1A1C2C);
  static const _purple = Color(0xFF5D275D);
  static const _red = Color(0xFFB13E53);
  static const _orange = Color(0xFFEF7D57);
  static const _yellow = Color(0xFFFFCD75);
  static const _lime = Color(0xFFA7F070);
  static const _green = Color(0xFF38B764);
  static const _blue = Color(0xFF3B5DC9);
  static const _sky = Color(0xFF41A6F6);
  static const _white = Color(0xFFF4F4F4);
  static const _silver = Color(0xFF94B0C2);
  static const _slate = Color(0xFF566C86);
  static const _dark = Color(0xFF333C57);
  static const _brown = Color(0xFF8B5A3C);
  static const _tan = Color(0xFFC2885A);
  static const _skin = Color(0xFFF2C29B);
  static const _paper = Color(0xFFF1DDB0);

  double _t = 0;
  final List<double> _meters = [5, 5, 5, 5]; // people, gold, army, church
  final List<double> _shown = [5, 5, 5, 5];
  final List<double> _meterFlash = [0, 0, 0, 0];
  int _decisions = 0;
  _Petition? _card;
  double _dx = 0; // card drag offset
  double _dragStartX = 0;
  bool _dragging = false;
  double _fly = 0; // fly-off progress
  int _flyDir = 0;
  double _enter = 0; // new card rise 0..1
  bool _swiped = false;
  int _overthrown = -1;
  double _endT = 0;
  int _lastType = -1;
  double _kingJoy = 0;

  static Map<String, Color> _pal(Map<String, Color> extra) => {
        'K': _k, 'S': _skin, 'W': _white, 'Y': _yellow, 'R': _red, 'O': _orange, 'b': _brown, 'G': _green,
        'L': _lime, 'V': _silver, 'M': _slate, 'D': _dark, 'P': _purple, 'B': _blue, 'T': _tan,
        ...extra,
      };

  static final _king = Sprite([
    '..Y..YY..Y..',
    '..YY.YY.YY..',
    '..YYYYYYYY..',
    '..YRYYYYRY..',
    '..SSSSSSSS..',
    '..SKSSSSKS..',
    '..SSSSSSSS..',
    '..WWSRRSWW..',
    '.RWWWWWWWWR.',
    'RRRWWWWWWRRR',
    'RRRRWWWWRRRR',
    'RRRRRYYRRRRR',
    'WRRRRRRRRRRW',
    'WRRRRRRRRRRW',
    'WWWWWWWWWWWW',
    '.KK......KK.',
  ], _pal({}));

  static const _humanRows = [
    '...HHHH...',
    '..HHHHHH..',
    '..HSSSSH..',
    '..SKSSKS..',
    '..SSSSSS..',
    '...SRRS...',
    '..CCCCCC..',
    '.CCCCCCCC.',
    'SCCCCCCCCS',
    'SCCBBBBCCS',
    '.CCCCCCCC.',
    '..CC..CC..',
    '..LL..LL..',
    '.KKK..KKK.',
  ];

  static Sprite _human(Color hat, Color coat, Color belt, Color legs) =>
      Sprite(_humanRows, _pal({'H': hat, 'C': coat, 'B': belt, 'L': legs}));

  static final _people = <Sprite>[
    _human(_brown, _tan, _brown, _brown), // peasant
    _human(_purple, _purple, _yellow, _dark), // merchant
    _human(_silver, _red, _k, _slate), // general
    _human(_yellow, _red, _yellow, _green), // jester
    _human(_white, _white, _yellow, _white), // bishop
    _human(_k, _dark, _yellow, _k), // tax collector
  ];

  // icons 8x8
  static final _iconPeople = Sprite([
    '..KKKK..', '.KSSSSK.', '.KSKKSK.', '..KKKK..', '.KBBBBK.', 'KBBBBBBK', 'KBBBBBBK', 'KKKKKKKK'
  ], _pal({}));
  static final _iconGold = Sprite([
    '..KKKK..', '.KYYYYK.', 'KYYWYYOK', 'KYYWYYOK', 'KYYWYYOK', 'KYYYYYOK', '.KOOOOK.', '..KKKK..'
  ], _pal({}));
  static final _iconArmy = Sprite([
    '......KK', '.....KWK', '....KWK.', 'KK.KWK..', '.KKWK...', '..KYK...', '.KYKKK..', 'KYK.....'
  ], _pal({}));
  static final _iconChurch = Sprite([
    '...KK...', '..KYYK..', '...KK...', '.KKKKKK.', 'KWWWWWWK', 'KWWKKWWK', 'KWWKKWWK', 'KKKKKKKK'
  ], _pal({}));
  static final _iconFood = Sprite([
    '........', '..KKKK..', '.KOOOOK.', 'KOYOYOOK', 'KOOOOOOK', 'KbbbbbbK', '.KKKKKK.', '........'
  ], _pal({}));
  static final _iconParty = Sprite([
    '...KKKKK', '...KRRRK', '...K...K', '...K...K', '.KKK.KKK', 'KRRKKRRK', 'KRRKKRRK', '.KK..KK.'
  ], _pal({}));
  static final _iconTax = Sprite([
    '...KK...', '..KYYK..', '.KYYYYK.', '..KYYK..', '.KKKKKK.', 'KbbYYbbK', 'KbbbbbbK', '.KKKKKK.'
  ], _pal({}));
  static final _crown = Sprite(['Y.Y.Y', 'YYYYY', 'YRYRY', 'YYYYY'], _pal({}));
  static final _mob = Sprite([
    'V.......V.......V..',
    'V.......V.......V..',
    'b..KK...b..KK...b..',
    'b.KSSK..b.KSSK..b..',
    'bKSKKSK.bKSKKSK.b..',
    'bKTTTTK.bKTTTTK.bK.',
    'KTTTTTTKKTTTTTTKKTK',
  ], _pal({}));

  static List<Sprite> get _meterIcons => [_iconPeople, _iconGold, _iconArmy, _iconChurch];
  static const _meterCols = [_sky, _yellow, _red, _white];

  // petition types: icon, accept deltas, reject deltas
  static final _types = <(Sprite, List<int>, List<int>)>[
    (_iconFood, [2, -2, 0, 0], [-2, 0, 0, 0]), // peasant: food
    (_iconGold, [-1, 2, 0, 0], [0, -1, 0, 1]), // merchant: trade deal
    (_iconArmy, [-1, -1, 3, 0], [0, 0, -2, 0]), // general: war
    (_iconParty, [2, -2, 0, -1], [-1, 0, 0, 1]), // jester: festival
    (_iconChurch, [0, -1, 0, 2], [0, 0, 0, -2]), // bishop: church
    (_iconTax, [-2, 3, 0, 0], [1, -2, 0, 0]), // tax collector
  ];

  @override
  void init() => _nextCard();

  bool _safe(List<int> d) {
    for (var i = 0; i < 4; i++) {
      final v = _meters[i] + d[i];
      if (v <= 0 || v >= 10) return false;
    }
    return true;
  }

  void _nextCard() {
    // prefer petitions where at least one answer is safe, and where the
    // realm's most extreme meter is involved (keeps it tense)
    final order = List<int>.generate(_types.length, (i) => i)..shuffle(rng);
    int? chosen;
    for (final i in order) {
      if (i == _lastType) continue;
      final (_, acc, rej) = _types[i];
      if (_safe(acc) || _safe(rej)) {
        chosen = i;
        break;
      }
    }
    chosen ??= order.first;
    _lastType = chosen;
    final (icon, acc, rej) = _types[chosen];
    // small variance
    List<int> jitter(List<int> d) => [for (final v in d) v == 0 ? 0 : v + (chance(.3) ? v.sign : 0)];
    _card = _Petition(chosen, icon, jitter(acc), jitter(rej));
    _dx = 0;
    _fly = 0;
    _flyDir = 0;
    _enter = 0;
  }

  // ------------------------------------------------------------ update ---

  @override
  void update(double dt) {
    _t += dt;
    if (_card != null && _flyDir == 0 && !host.finished && _enter >= 1 && chance(.05)) { double sc(List<int> d) { var m = 99.0; for (var i = 0; i < 4; i++) { final v = _meters[i] + d[i]; m = math.min(m, math.min(v, 10 - v)); } return m; } _decide(sc(_card!.acc) >= sc(_card!.rej)); } // BOT
    _enter = math.min(1, _enter + dt * 4);
    _kingJoy = M.approach(_kingJoy, 0, 3, dt);
    for (var i = 0; i < 4; i++) {
      _shown[i] = M.approach(_shown[i], _meters[i], 7, dt);
      _meterFlash[i] = M.approach(_meterFlash[i], 0, 4, dt);
    }
    if (!_dragging && _flyDir == 0) _dx = M.approach(_dx, 0, 14, dt);
    if (_flyDir != 0) {
      _fly += dt * 3.2;
      _dx += _flyDir * 1400 * dt;
      if (_fly >= 1 && !host.finished && _overthrown < 0) {
        if (_decisions >= _goal) {
          _winGame();
        } else {
          _nextCard();
        }
      }
    }
    if (host.finished) _endT += dt;
  }

  void _decide(bool accept) {
    final card = _card;
    if (card == null || _flyDir != 0 || host.finished) return;
    _swiped = true;
    _flyDir = accept ? 1 : -1;
    _fly = 0;
    final d = accept ? card.acc : card.rej;
    host.sfx(Sfx.swipe);
    host.sfx(accept ? Sfx.stamp : Sfx.pSelect, volume: .7);
    _decisions++;
    for (var i = 0; i < 4; i++) {
      if (d[i] == 0) continue;
      _meters[i] = (_meters[i] + d[i]).clamp(0, 10).toDouble();
      _meterFlash[i] = 1;
      final at = Offset(_meterX(i), 88);
      host.fx.pop(d[i] > 0 ? '+${d[i]}' : '${d[i]}', at + const Offset(0, 40), color: d[i] > 0 ? _lime : _red, size: 20);
      host.fx.burst(at, _meterCols[i], count: 6, speed: 120, size: 5, shape: PartShape.square, gravity: 200);
    }
    host.sfx(Sfx.pCoin, volume: .5, rate: 1 + _decisions * .06);
    if (accept) _kingJoy = 1;
    // overthrown?
    for (var i = 0; i < 4; i++) {
      if (_meters[i] <= 0 || _meters[i] >= 10) {
        _overthrown = i;
        host.sfx(Sfx.pDie);
        host.sfx(Sfx.crash, volume: .6);
        host.shake(10, .5);
        host.flash(_red, .2);
        host.lose();
        return;
      }
    }
    host.addScore(10 * _decisions, Offset(180, 560));
    if (_decisions == _goal) host.sfx(Sfx.pPowerup);
  }

  void _winGame() {
    var balanced = 0;
    for (final m in _meters) {
      if (m >= 3 && m <= 7) balanced++;
    }
    host.sfx(Sfx.fanfare);
    host.fx.confetti();
    host.fx.coins(const Offset(180, 220), count: 18);
    host.win(stars: balanced == 4 ? 3 : (balanced >= 2 ? 2 : 1));
  }

  double _meterX(int i) => 54 + i * 84.0;

  // ------------------------------------------------------------- input ---

  @override
  void onDown(Offset p) {
    if (host.finished || _flyDir != 0) return;
    return; // BOT
    _dragging = true;
    _dragStartX = p.dx - _dx;
  }

  @override
  void onMove(Offset p) {
    if (!_dragging) return;
    _dx = (p.dx - _dragStartX).clamp(-170.0, 170.0);
  }

  @override
  void onUp(Offset p) {
    if (!_dragging) return;
    _dragging = false;
    if (_dx.abs() > 60) {
      _decide(_dx > 0);
    } else {
      host.sfx(Sfx.tap, volume: .3);
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    return; // BOT
    if (key == 'left') _decide(false);
    if (key == 'right') _decide(true);
  }

  @override
  void onTimeUp() {
    if (_decisions >= _goal - 2 && _overthrown < 0) {
      host.sfx(Sfx.jingleWin);
      host.win(stars: 1);
    } else {
      host.lose();
    }
  }

  // ------------------------------------------------------------ render ---

  @override
  void render(Canvas c) {
    final pp = Paint()..isAntiAlias = false;
    // stone wall
    pp.color = const Color(0xFF3A3450);
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 640), pp);
    pp.color = const Color(0xFF2E2A42);
    for (var row = 0; row < 20; row++) {
      final y = 36.0 + row * 18;
      c.drawRect(Rect.fromLTWH(0, y, 360, 3), pp);
      for (var x = (row.isEven ? 0.0 : 24.0); x < 360; x += 48) {
        c.drawRect(Rect.fromLTWH(x, y, 3, 18), pp);
      }
    }
    pp.color = const Color(0xFF474062);
    for (var i = 0; i < 30; i++) {
      c.drawRect(Rect.fromLTWH((i * 97 % 350).toDouble(), 40 + (i * 53 % 300).toDouble(), 6, 3), pp);
    }
    // floor
    for (var row = 0; row < 7; row++) {
      for (var col = 0; col < 12; col++) {
        pp.color = (row + col).isEven ? const Color(0xFF6B5A7A) : const Color(0xFF584A68);
        c.drawRect(Rect.fromLTWH(col * 30.0, 400 + row * 36.0, 30, 36), pp);
      }
    }
    // carpet
    pp.color = const Color(0xFF7A1F35);
    c.drawRect(const Rect.fromLTWH(126, 250, 108, 400), pp);
    pp.color = _red;
    c.drawRect(const Rect.fromLTWH(132, 250, 96, 400), pp);
    pp.color = _yellow;
    c.drawRect(const Rect.fromLTWH(138, 250, 3, 400), pp);
    c.drawRect(const Rect.fromLTWH(219, 250, 3, 400), pp);

    // banners
    for (final x in [30.0, 294.0]) {
      pp.color = _red;
      c.drawRect(Rect.fromLTWH(x, 130, 36, 90), pp);
      pp.color = _yellow;
      c.drawRect(Rect.fromLTWH(x, 130, 36, 6), pp);
      _crown.draw(c, Offset(x + 8, 160), scale: 4);
      pp.color = _red;
      c.drawRect(Rect.fromLTWH(x, 220, 12, 9), pp);
      c.drawRect(Rect.fromLTWH(x + 24, 220, 12, 9), pp);
    }
    // torches
    for (final x in [96.0, 264.0]) {
      pp.color = _dark;
      c.drawRect(Rect.fromLTWH(x - 4, 190, 8, 24), pp);
      final f = (_t * 8).floor() % 2;
      pp.color = _orange;
      c.drawRect(Rect.fromLTWH(x - 6, 172 + f * 2.0, 12, 18), pp);
      pp.color = _yellow;
      c.drawRect(Rect.fromLTWH(x - 3, 178 + f * 2.0, 6, 10), pp);
      c.drawCircle(Offset(x, 180), 34, Paint()..color = const Color(0x22FFB040));
    }

    // throne + king
    pp.color = _purple;
    c.drawRect(const Rect.fromLTWH(138, 142, 84, 112), pp);
    pp.color = _yellow;
    c.drawRect(const Rect.fromLTWH(138, 142, 84, 6), pp);
    c.drawRect(const Rect.fromLTWH(138, 142, 6, 112), pp);
    c.drawRect(const Rect.fromLTWH(216, 142, 6, 112), pp);
    for (var i = 0; i < 3; i++) {
      c.drawRect(Rect.fromLTWH(144 + i * 30.0, 130, 12, 12), pp);
    }
    pp.color = _red;
    c.drawRect(const Rect.fromLTWH(150, 150, 60, 60), pp);
    final bounce = _kingJoy > .1 ? -((_t * 14) % math.pi).abs() * 3 * _kingJoy : 0.0;
    if (_overthrown >= 0) {
      // king tumbles off the throne, crown flies
      final k = math.min(1.0, _endT * 1.6);
      c.save();
      c.translate(180 + k * 60, 200 + k * 40);
      c.rotate(k * 1.6);
      _king.drawCentered(c, Offset.zero, scale: 4);
      c.restore();
      _crown.drawCentered(c, Offset(180 - _endT * 80, 150 - _endT * 90 + _endT * _endT * 120), scale: 4);
    } else {
      _king.drawCentered(c, Offset(180, 204 + bounce), scale: 4);
      if (host.finished) {
        // victory sparkle crowns
        for (var i = 0; i < 5; i++) {
          final a = _t * 2 + i * 1.26;
          _crown.drawCentered(c, Offset(180 + math.cos(a) * 60, 200 + math.sin(a) * 30), scale: 3);
        }
      }
    }

    // petition card
    _drawCard(c);

    // HUD meters
    pp.color = const Color(0xEE1A1C2C);
    c.drawRect(const Rect.fromLTWH(0, 38, 360, 90), pp);
    pp.color = _yellow;
    c.drawRect(const Rect.fromLTWH(0, 125, 360, 3), pp);
    final card = _card;
    final preview = card != null && _flyDir == 0 && _dx.abs() > 18 ? (_dx > 0 ? card.acc : card.rej) : null;
    for (var i = 0; i < 4; i++) {
      final x = _meterX(i);
      final icon = _meterIcons[i];
      const s = 5.0;
      final r = Rect.fromCenter(center: Offset(x, 76), width: icon.w * s, height: icon.h * s);
      final danger = _meters[i] <= 2 || _meters[i] >= 8;
      final wob = danger ? math.sin(_t * 20) * 1.5 : 0.0;
      icon.draw(c, r.topLeft + Offset(wob, 0), scale: s, tint: _dark);
      final fill = (_shown[i] / 10).clamp(0.0, 1.0);
      c.save();
      c.clipRect(Rect.fromLTRB(r.left - 4, r.bottom - r.height * fill, r.right + 4, r.bottom));
      icon.draw(c, r.topLeft + Offset(wob, 0), scale: s, tint: _meterFlash[i] > .5 ? _white : null);
      c.restore();
      // 10 segment bar
      for (var k = 0; k < 10; k++) {
        final on = k < _meters[i].round();
        pp.color = on ? (danger ? (k < 2 || k >= 8 ? _red : _meterCols[i]) : _meterCols[i]) : _dark;
        c.drawRect(Rect.fromLTWH(x - 29 + k * 6.0, 108, 5, 8), pp);
      }
      // preview arrow
      if (preview != null && preview[i] != 0) {
        final up = preview[i] > 0;
        final risky = _meters[i] + preview[i] <= 0 || _meters[i] + preview[i] >= 10;
        pp.color = risky ? (M.wave(_t, 5) > .5 ? _red : _white) : (up ? _lime : _orange);
        final n = preview[i].abs().clamp(1, 3);
        for (var k = 0; k < n; k++) {
          final ax = x + 24 + 0.0;
          final ay = 60 + k * 10.0;
          _pixArrow(c, Offset(ax, ay), up, pp);
        }
      }
    }

    // progress crowns
    for (var i = 0; i < _goal; i++) {
      final done = i < _decisions;
      _crown.draw(c, Offset(66 + i * 30.0, 604), scale: 4, tint: done ? null : _dark);
    }
    PixelFont.draw(c, '$_decisions/$_goal', const Offset(180, 588), 2, _white, align: 0, shadow: _k);

    // overthrown mob
    if (_overthrown >= 0) {
      final k = math.min(1.0, _endT * 2.5);
      final y = 640 - k * 110;
      for (var i = 0; i < 3; i++) {
        _mob.draw(c, Offset(-20 + i * 120.0 + math.sin(_t * 12 + i) * 4, y + (i.isOdd ? 8 : 0)), scale: 5);
      }
      D.text(c, host.tr('overthrown', 'OVERTHROWN!'), const Offset(180, 400), size: 30, color: _red, stroke: _k,
          strokeWidth: 7);
    }

    // tutorial
    if (!_swiped && _t < 5 && !host.finished) {
      final k = (_t * .9) % 1;
      final x = 180 + math.sin(k * math.pi * 2) * 70;
      D.hand(c, Offset(x, 520), 0);
    }

    Retro.scanlines(c, alpha: .1);
    Retro.vignette(c, strength: .4);
  }

  void _pixArrow(Canvas c, Offset o, bool up, Paint pp) {
    if (up) {
      c.drawRect(Rect.fromLTWH(o.dx - 1.5, o.dy, 3, 3), pp);
      c.drawRect(Rect.fromLTWH(o.dx - 4.5, o.dy + 3, 9, 3), pp);
    } else {
      c.drawRect(Rect.fromLTWH(o.dx - 4.5, o.dy, 9, 3), pp);
      c.drawRect(Rect.fromLTWH(o.dx - 1.5, o.dy + 3, 3, 3), pp);
    }
  }

  void _drawCard(Canvas c) {
    final card = _card;
    if (card == null) return;
    final rise = (1 - M.easeOutBack(_enter)) * 260;
    final rot = _dx * .0022;
    final center = _cardC + Offset(_dx, rise + _dx.abs() * .08);
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(rot);
    final pp = Paint()..isAntiAlias = false;
    const w = 232.0, h = 262.0;
    // shadow + pixel border
    pp.color = const Color(0x66000000);
    c.drawRect(const Rect.fromLTWH(-w / 2 + 8, -h / 2 + 10, w, h), pp);
    pp.color = _k;
    c.drawRect(const Rect.fromLTWH(-w / 2 - 4, -h / 2, w + 8, h), pp);
    c.drawRect(const Rect.fromLTWH(-w / 2, -h / 2 - 4, w, h + 8), pp);
    pp.color = _paper;
    c.drawRect(const Rect.fromLTWH(-w / 2, -h / 2, w, h), pp);
    pp.color = const Color(0xFFD9BE88);
    c.drawRect(const Rect.fromLTWH(-w / 2, h / 2 - 12, w, 12), pp);
    c.drawRect(const Rect.fromLTWH(-w / 2 + 8, -h / 2 + 8, 6, 6), pp);
    c.drawRect(const Rect.fromLTWH(w / 2 - 14, -h / 2 + 8, 6, 6), pp);

    // speech bubble with icon
    const bub = Rect.fromLTWH(-46, -h / 2 + 18, 92, 72);
    pp.color = _k;
    c.drawRect(bub.inflate(4), pp);
    pp.color = _white;
    c.drawRect(bub, pp);
    pp.color = _k;
    c.drawRect(Rect.fromLTWH(-6, bub.bottom + 4, 12, 6), pp);
    c.drawRect(Rect.fromLTWH(-3, bub.bottom + 10, 6, 6), pp);
    pp.color = _white;
    c.drawRect(Rect.fromLTWH(-3, bub.bottom, 6, 8), pp);
    final bob = ((_t * 3).floor() % 2) * 3.0;
    card.icon.drawCentered(c, Offset(0, bub.center.dy - bob), scale: 6);

    // petitioner
    final who = _people[card.type];
    who.drawCentered(c, Offset(0, 52 + ((_t * 2.5).floor() % 2) * 2.0), scale: 7);
    // extra props per type
    switch (card.type) {
      case 2: // general: sword
        pp.color = _silver;
        c.drawRect(const Rect.fromLTWH(40, 10, 6, 44), pp);
        pp.color = _yellow;
        c.drawRect(const Rect.fromLTWH(32, 50, 22, 6), pp);
      case 3: // jester bells
        pp.color = _yellow;
        c.drawRect(const Rect.fromLTWH(-34, -12, 8, 8), pp);
        c.drawRect(const Rect.fromLTWH(26, -12, 8, 8), pp);
      case 4: // bishop staff
        pp.color = _yellow;
        c.drawRect(const Rect.fromLTWH(-50, -10, 5, 90), pp);
        c.drawRect(const Rect.fromLTWH(-56, -16, 17, 6), pp);
      case 1: // merchant money bag
        pp.color = _brown;
        c.drawRect(const Rect.fromLTWH(36, 60, 22, 20), pp);
        pp.color = _yellow;
        c.drawRect(const Rect.fromLTWH(43, 66, 8, 8), pp);
      default:
        break;
    }

    // yes / no stamps
    final tilt = (_dx.abs() / 80).clamp(0.0, 1.0);
    if (tilt > .05) {
      final yes = _dx > 0;
      final col = yes ? _green : _red;
      c.save();
      c.translate(yes ? -60 : 60, -h / 2 + 118);
      c.rotate(yes ? -.25 : .25);
      final label = yes ? host.tr('yes', 'YES') : host.tr('no', 'NO');
      final p2 = Paint()
        ..color = col.withValues(alpha: tilt)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      c.drawRect(const Rect.fromLTWH(-48, -22, 96, 44), p2);
      D.text(c, label, Offset.zero, size: 26, color: col.withValues(alpha: tilt), weight: FontWeight.w900);
      c.restore();
    }
    c.restore();

    // side hints
    if (_flyDir == 0 && !host.finished) {
      final a = .35 + .25 * M.wave(_t, 1.5);
      D.text(c, host.tr('no', 'NO'), const Offset(26, 440), size: 16, color: _red.withValues(alpha: a + .2), stroke: _k);
      D.text(c, host.tr('yes', 'YES'), const Offset(334, 440), size: 16, color: _lime.withValues(alpha: a + .2), stroke: _k);
      final pp2 = Paint()..color = Color.fromRGBO(255, 255, 255, a);
      for (var i = 0; i < 3; i++) {
        c.drawRect(Rect.fromLTWH(18.0 + i * 5, 462 - i * 3.0, 3, 6 + i * 6.0), pp2);
        c.drawRect(Rect.fromLTWH(339.0 - i * 5, 462 - i * 3.0, 3, 6 + i * 6.0), pp2);
      }
    }
  }
}

class _Petition {
  _Petition(this.type, this.icon, this.acc, this.rej);
  final int type;
  final Sprite icon;
  final List<int> acc;
  final List<int> rej;
}
