import '../engine/engine.dart';

/// No.085 Slime Quest — first-person 16-bit JRPG boss battle.
///
/// Pick a command for each of the 3 heroes. ATTACK and MAGIC show a timing
/// meter: tap in the gold zone for a CRITICAL. The Slime King telegraphs a
/// charged MEGA SLAM — DEFEND guards the whole party. ITEM heals / revives.
bool _ascii(String s) {
  for (final u in s.codeUnits) {
    if (u > 126) return false;
  }
  return true;
}

void _px(Canvas c, String s, Offset pos, double scale, Color col, {int align = -1, Color? shadow}) {
  if (_ascii(s)) {
    PixelFont.draw(c, s.toUpperCase(), pos, scale, col, align: align, shadow: shadow);
  } else {
    D.text(c, s, Offset(pos.dx, pos.dy + 3.5 * scale), size: 8 * scale, color: col, stroke: shadow,
        strokeWidth: shadow == null ? 0 : scale * 1.4,
        anchor: align < 0 ? Alignment.centerLeft : (align == 0 ? Alignment.center : Alignment.centerRight));
  }
}

const _k = Color(0xFF000000);
const _white = Color(0xFFF8F8F8);
const _gold = Color(0xFFF8D830);
const _red = Color(0xFFF83828);

// ------------------------------------------------------------------ art ---

List<String> _slimeRows() {
  const w = 32, h = 30;
  const crown = [
    'Y.....Y.....Y',
    'YY...YYY...YY',
    'YYY.YYRYY.YYY',
    'YYYYYYYYYYYYY',
    'YGYYYRYYYGYYY',
    'OOOOOOOOOOOOO',
  ];
  final rows = <String>[];
  for (var y = 0; y < h; y++) {
    final sb = StringBuffer();
    for (var x = 0; x < w; x++) {
      var ch = '.';
      // body
      final by = y - 4;
      double hw;
      if (by < 0) {
        hw = -1;
      } else if (by < 9) {
        hw = 2 + by * 1.55;
      } else if (by < 23) {
        hw = 15.5;
      } else {
        hw = 15.5 - (by - 22) * 1.5;
      }
      final dx = (x + .5 - 16).abs();
      if (dx < hw) {
        final edge = dx > hw - 1 || by == 0 || y == h - 1;
        if (edge) {
          ch = 'K';
        } else if (x > 16 + hw - 4 || y > h - 4) {
          ch = 'D';
        } else {
          ch = 'B';
        }
        final hx = x - 9.0, hy = y - 13.0;
        if (hx * hx / 4 + hy * hy / 9 < 1.2) ch = 'W';
        if (x == 7 && y == 18) ch = 'W';
      }
      // eyes
      if ((x == 11 || x == 12 || x == 20 || x == 21) && y >= 15 && y <= 18) ch = 'K';
      if ((x == 11 || x == 20) && y == 15) ch = 'W';
      // brows (angry)
      if (y == 13 && (x == 10 || x == 22)) ch = 'K';
      if (y == 14 && (x == 11 || x == 12 || x == 20 || x == 21)) ch = 'K';
      // mouth
      if (y == 21 && x >= 11 && x <= 21) ch = 'K';
      if (y == 22 && x >= 12 && x <= 20) ch = x == 12 || x == 20 ? 'K' : 'R';
      if (y == 23 && x >= 13 && x <= 19) ch = 'K';
      if (y == 22 && (x == 14 || x == 18)) ch = 'W';
      // crown
      final cx = x - 10;
      if (y < crown.length && cx >= 0 && cx < 13 && crown[y][cx] != '.') ch = crown[y][cx];
      sb.write(ch);
    }
    rows.add(sb.toString());
  }
  return rows;
}

final _slimeRowsList = _slimeRows();
final _slime = Sprite(_slimeRowsList, {
  'K': const Color(0xFF081848),
  'B': const Color(0xFF3C8CF8),
  'D': const Color(0xFF2050C0),
  'W': const Color(0xFFD8F0FC),
  'R': const Color(0xFFE83858),
  'Y': _gold,
  'O': const Color(0xFFB87800),
  'G': const Color(0xFF38D868),
});
final _slimeAngry = Sprite(_slimeRowsList, {
  'K': const Color(0xFF400818),
  'B': const Color(0xFFF85C5C),
  'D': const Color(0xFFB82C3C),
  'W': const Color(0xFFFCD8D8),
  'R': const Color(0xFFFCF020),
  'Y': _gold,
  'O': const Color(0xFFB87800),
  'G': const Color(0xFF38D868),
});

final _heroPal = <String, Color>{
  'R': const Color(0xFFE84830),
  'W': _white,
  'S': const Color(0xFFFCC8A0),
  'K': _k,
  'M': const Color(0xFFB85048),
  'B': const Color(0xFF3060D8),
  'Y': _gold,
  'G': const Color(0xFFB8C8D8),
  'N': const Color(0xFF603818),
  'P': const Color(0xFF8038C8),
  'O': const Color(0xFF906030),
  'g': const Color(0xFF30A848),
};
final _heroes = [
  Sprite([
    '....RRRR.RR.....',
    '...RRRRRRRRR....',
    '..RRRRRRRRRRR...',
    '..RRWWWWWWWRR...',
    '..RSSSSSSSSSR...',
    '..SSKSSSSKSSS...',
    '..SSKSSSSKSSS...',
    '...SSSSSSSSS....',
    '....SSMMSSS.....',
    '...BBBSSSBBB....',
    '..BBBBBBBBBBB.GG',
    '.SBBBBYBBBBBBGG.',
    '.SSBBBBBBBBSGG..',
    '...BBBBBBBB.S...',
    '...NN....NN.....',
    '..NNN....NNN....',
  ], _heroPal),
  Sprite([
    '........PP......',
    '.......PPPP.....',
    '......PPPPP.....',
    '.....PPPYPPP....',
    '....PPPPPPPPP...',
    '..PPPPPPPPPPPPP.',
    '....SSSSSSSS....',
    '....SKSSSSKS....',
    '....SKSSSSKS....',
    '....SSSWWSSS...Y',
    '...PPWWWWWWPP.O.',
    '..PPPPWWWWPPPPO.',
    '.SPPPPPPPPPPPSO.',
    '...PPPPPPPPPP.O.',
    '...PPPPPPPPPP.O.',
    '....NN....NN..O.',
  ], _heroPal),
  Sprite([
    '.....gggggg.....',
    '....gggggggg....',
    '...gggSSSSggg...',
    '...ggSSSSSSgg...',
    '...gSKSSSSKSg...',
    '...gSKSSSSKSg...',
    '...gSSSMMSSSg...',
    '....gSSSSSSg....',
    '...WWggggggWW..Y',
    '..WWWWWYWWWWW.YY',
    '..SWWWYYYWWWWS.Y',
    '..SWWWWYWWWWWS.O',
    '...WWWWWWWWWW..O',
    '...WWWWWWWWWW..O',
    '....NN...NN....O',
    '...NNN...NNN...O',
  ], _heroPal),
];

final _iconPal = <String, Color>{
  'W': _white,
  'G': const Color(0xFFB8A078),
  'B': const Color(0xFF6C4020),
  'R': const Color(0xFFE82810),
  'O': const Color(0xFFF88800),
  'Y': const Color(0xFFF8E040),
  'L': const Color(0xFF3868D8),
  'K': _k,
  'N': const Color(0xFF905830),
  'g': const Color(0xFF38D060),
  'l': const Color(0xFFA8F8B8),
  'b': const Color(0xFF203880),
};
final _icons = [
  Sprite([
    '..........WW',
    '.........WWW',
    '........WWW.',
    '.......WWW..',
    '......WWW...',
    '.....WWW....',
    '..G.WWW.....',
    '..GGWW......',
    '...GG.......',
    '..BBGG......',
    '.BB..G......',
    'BB..........',
  ], _iconPal),
  Sprite([
    '.....R......',
    '....RR...R..',
    '...RRR..RR..',
    '..RRORR.RRR.',
    '..ROOORRRRR.',
    '.RROOYORROR.',
    '.ROOYYYOOOR.',
    '.ROYYYYYOOR.',
    '.ROYYWYYYOR.',
    '..ROYWWYOR..',
    '...ROOOOR...',
    '....RRRR....',
  ], _iconPal),
  Sprite([
    '.bbbbbbbbbb.',
    'bWWWWWWWWWWb',
    'bWLLLYYLLLWb',
    'bWLLLYYLLLWb',
    'bWYYYYYYYYWb',
    'bWYYYYYYYYWb',
    'bWLLLYYLLLWb',
    '.bWLLYYLLWb.',
    '.bWLLYYLLWb.',
    '..bWLYYLWb..',
    '...bWWWWb...',
    '....bbbb....',
  ], _iconPal),
  Sprite([
    '....KKKK....',
    '....NNNN....',
    '.....WW.....',
    '....KWWK....',
    '...KWWWWK...',
    '..KggggggK..',
    '.KglggggggK.',
    '.KglggggggK.',
    '.KggggggggK.',
    '.KggggggggK.',
    '..KggggggK..',
    '...KKKKKK...',
  ], _iconPal),
];

// ---------------------------------------------------------------- model ---

class _Hero {
  _Hero(this.maxHp, this.maxMp) : hp = maxHp, mp = maxMp;
  final int maxHp, maxMp;
  int hp, mp;
  double shake = 0, flash = 0, heal = 0;
  bool get ko => hp <= 0;
}

class _Pop {
  _Pop(this.s, this.x, this.y, this.col, {this.big = false});
  final String s;
  final double x;
  double y;
  final Color col;
  final bool big;
  double t = 0;
}

enum _St { choose, meter, act, enemy, over }

class G085 extends MiniGame {
  static const _bossMax = 1500;
  final _party = [_Hero(150, 12), _Hero(110, 30), _Hero(125, 24)];
  final _pops = <_Pop>[];
  int _bossHp = _bossMax;
  double _bossShown = _bossMax.toDouble();
  _St _st = _St.choose;
  int _active = 0;
  int _cmd = 0;
  double _stT = 0;
  double _meterPos = 0;
  double _mult = 1;
  bool _applied = false;
  bool _guard = false;
  bool _charging = false;
  bool _mega = false;
  int _enemyTurns = 0;
  int _potions = 3;
  String _msg = '';
  double _t = 0;
  double _bossFlash = 0;
  double _bossShake = 0;
  double _slash = -1;
  double _fireFx = -1;
  bool _won = false;
  double _endT = 0;
  int _pressed = -1;
  double _pressT = 0;
  bool _critLast = false;

  List<String> get _names =>
      [host.tr('hero', 'HERO'), host.tr('mage', 'MAGE'), host.tr('cleric', 'CLERIC')];

  @override
  void init() {
    _msg = '${host.tr('boss', 'BOSS')}!';
  }

  double get _sp => host.speed;

  // ------------------------------------------------------------ logic ---

  bool _canUse(int cmd) {
    final h = _party[_active];
    if (cmd == 1) return h.mp >= _mpCost(_active);
    if (cmd == 3) return _potions > 0;
    return true;
  }

  int _mpCost(int i) => const [6, 8, 8][i];

  void _choose(int cmd) {
    if (_st != _St.choose || host.finished) return;
    _pressed = cmd;
    _pressT = .15;
    if (!_canUse(cmd)) {
      host.sfx(Sfx.pHit, rate: .6, volume: .6);
      _msg = cmd == 1 ? 'MP 0' : '0';
      return;
    }
    host.sfx(Sfx.pSelect);
    _cmd = cmd;
    _stT = 0;
    _applied = false;
    final isHealer = _active == 2 && cmd == 1;
    if (cmd == 0 || (cmd == 1 && !isHealer)) {
      _st = _St.meter;
      _meterPos = 0;
      _msg = '${host.tr('tap', 'TAP')}!';
    } else {
      _st = _St.act;
      _mult = 1;
    }
  }

  void _meterTap() {
    final p = _meterPos;
    if (p > .7 && p < .84) {
      _mult = 2.5;
      _critLast = true;
      host.sfx(Sfx.pPowerup, rate: 1.3);
    } else if (p > .54 && p < .92) {
      _mult = 1.3;
      _critLast = false;
      host.sfx(Sfx.pSelect, rate: 1.2);
    } else {
      _mult = .7;
      _critLast = false;
      host.sfx(Sfx.pSelect, rate: .8);
    }
    _st = _St.act;
    _stT = 0;
  }

  void _dealBoss(int dmg, {bool crit = false}) {
    _bossHp = max(0, _bossHp - dmg);
    _bossFlash = 1;
    _bossShake = crit ? 1.4 : .8;
    host.addScore(dmg);
    _pops.add(_Pop('$dmg', 180 + rand(-30, 30), 190, crit ? _gold : _white, big: crit));
    host.shake(crit ? 9 : 4);
    host.hitStop(crit ? .1 : .04);
    if (crit) {
      host.flash(_white, .12);
      _pops.add(_Pop(host.tr('critical', 'CRITICAL'), 180, 110, _gold, big: true));
      host.punch(.05);
    }
  }

  void _applyAction() {
    final h = _party[_active];
    final name = _names[_active];
    switch (_cmd) {
      case 0:
        final base = const [120, 48, 62][_active];
        final dmg = (base * _mult * rand(.9, 1.1)).round();
        _msg = '$name ${host.tr('attack', 'ATTACK')}';
        _slash = 0;
        host.sfx(Sfx.slash);
        host.sfx(Sfx.pHit, rate: _critLast ? 1.4 : 1);
        _dealBoss(dmg, crit: _mult > 2);
      case 1:
        h.mp -= _mpCost(_active);
        if (_active == 2) {
          _msg = '$name ${host.tr('heal', 'HEAL')}';
          host.sfx(Sfx.magic);
          host.sfx(Sfx.pPowerup, rate: 1.2);
          for (var i = 0; i < 3; i++) {
            final p = _party[i];
            if (p.ko) continue;
            final amt = min(70, p.maxHp - p.hp);
            p.hp += amt;
            p.heal = 1;
            _pops.add(_Pop('+$amt', _winRect(i).center.dx, _winRect(i).top + 10, const Color(0xFF58F878)));
          }
        } else {
          final base = const [110, 200, 0][_active];
          final dmg = (base * (_mult > 2 ? 1.8 : (_mult > 1 ? 1.2 : .85)) * rand(.92, 1.08)).round();
          _msg = '$name ${host.tr('fire', 'FIRE')}';
          _fireFx = 0;
          host.sfx(Sfx.fire);
          host.sfx(Sfx.pExplode, rate: .8);
          host.fx.burst(const Offset(180, 200), const Color(0xFFF88800),
              count: 30, speed: 260, size: 9, shape: PartShape.square, gravity: -200,
              colors: const [Color(0xFFF8E040), Color(0xFFF88800), Color(0xFFE82810)]);
          host.flash(const Color(0xFFF88800), .1);
          _dealBoss(dmg, crit: _mult > 2);
        }
      case 2:
        _guard = true;
        _msg = '$name ${host.tr('defend', 'DEFEND')}';
        host.sfx(Sfx.clang);
        h.flash = 1;
        host.fx.ring(_winRect(_active).center, const Color(0xFF3868D8), size: 60);
      case 3:
        _potions--;
        _msg = '$name ${host.tr('item', 'ITEM')}';
        host.sfx(Sfx.pPowerup);
        host.sfx(Sfx.sparkle);
        for (var i = 0; i < 3; i++) {
          final p = _party[i];
          final amt = p.ko ? 50 : min(60, p.maxHp - p.hp);
          p.hp += amt;
          p.heal = 1;
          _pops.add(_Pop('+$amt', _winRect(i).center.dx, _winRect(i).top + 10, const Color(0xFF58F878)));
          host.fx.sparkle(_winRect(i).center, color: const Color(0xFF58F878));
        }
    }
    if (_bossHp <= 0) {
      _victory();
    }
  }

  void _victory() {
    _won = true;
    _st = _St.over;
    _endT = 0;
    _msg = host.tr('win', 'WIN');
    host.sfx(Sfx.pExplode);
    host.sfx(Sfx.fanfare, volume: .9);
    host.shake(10, .5);
    host.flash(_white, .25);
    host.fx.burst(const Offset(180, 200), const Color(0xFF3C8CF8), count: 60, speed: 380, size: 10,
        shape: PartShape.square, gravity: 500, colors: const [Color(0xFF3C8CF8), Color(0xFFD8F0FC), _gold]);
    final left = host.timeLeft;
    host.win(stars: left > 6 ? 3 : (left > 2.5 ? 2 : 1));
  }

  void _nextHero() {
    var n = _active + 1;
    while (n < 3 && _party[n].ko) {
      n++;
    }
    if (n >= 3) {
      _st = _St.enemy;
      _stT = 0;
      _applied = false;
      _mega = _charging;
      _charging = false;
      _msg = _mega ? host.tr('mega_slam', 'MEGA SLAM') : '${host.tr('boss', 'BOSS')} ${host.tr('attack', 'ATTACK')}';
      if (_mega) host.sfx(Sfx.horror, volume: .6);
    } else {
      _active = n;
      _st = _St.choose;
      _msg = '${_names[_active]}?';
    }
  }

  void _enemyAct() {
    _enemyTurns++;
    if (_mega) {
      for (var i = 0; i < 3; i++) {
        _hurt(i, (rand(62, 82) * (_guard ? .35 : 1)).round());
      }
      host.shake(16, .5);
      host.flash(_red, .2);
      host.sfx(Sfx.explode);
      host.hitStop(.12);
      if (_guard) {
        _pops.add(_Pop(host.tr('guard', 'GUARD'), 180, 330, const Color(0xFF58A8F8), big: true));
        host.sfx(Sfx.clang);
      }
      return;
    }
    final charge = _enemyTurns == 2 || (_enemyTurns > 2 && chance(.45));
    if (charge) {
      _charging = true;
      _msg = '${host.tr('charge', 'CHARGE')}!!';
      host.sfx(Sfx.pPowerup, rate: .5);
      host.shake(3, .6);
      return;
    }
    if (chance(.5)) {
      for (var i = 0; i < 3; i++) {
        _hurt(i, (rand(22, 36) * (_guard ? .4 : 1)).round());
      }
      host.shake(8);
      host.sfx(Sfx.thud);
    } else {
      final alive = [for (var i = 0; i < 3; i++) if (!_party[i].ko) i];
      if (alive.isNotEmpty) _hurt(pick(alive), (rand(44, 62) * (_guard ? .4 : 1)).round());
      host.shake(6);
      host.sfx(Sfx.chomp);
    }
    host.flash(_red, .1);
  }

  void _hurt(int i, int dmg) {
    final h = _party[i];
    if (h.ko) return;
    h.hp = max(0, h.hp - dmg);
    h.shake = 1;
    h.flash = 1;
    final r = _winRect(i);
    _pops.add(_Pop('$dmg', r.center.dx, r.top + 12, _red));
    host.sfx(Sfx.pHit, rate: .8);
  }

  @override
  void update(double dt) {
    _t += dt;
    _stT += dt;
    _bossFlash = max(0, _bossFlash - dt * 5);
    _bossShake = max(0, _bossShake - dt * 3);
    _pressT = max(0, _pressT - dt);
    _bossShown = M.approach(_bossShown, _bossHp.toDouble(), 6, dt);
    if (_slash >= 0) {
      _slash += dt * 4;
      if (_slash > 1) _slash = -1;
    }
    if (_fireFx >= 0) {
      _fireFx += dt * 2.5;
      if (_fireFx > 1) _fireFx = -1;
    }
    for (final h in _party) {
      h.shake = max(0, h.shake - dt * 3);
      h.flash = max(0, h.flash - dt * 3);
      h.heal = max(0, h.heal - dt * 2);
    }
    for (var i = _pops.length - 1; i >= 0; i--) {
      final p = _pops[i];
      p.t += dt;
      p.y -= (p.t < .15 ? 200 : 20) * dt;
      if (p.t > 1.0) _pops.removeAt(i);
    }
    switch (_st) {
      case _St.choose:
        break;
      case _St.meter:
        _meterPos = _stT * 1.45 * _sp;
        if (_meterPos >= 1) {
          _meterPos = 1;
          _mult = .7;
          _critLast = false;
          _st = _St.act;
          _stT = 0;
        }
      case _St.act:
        if (!_applied && _stT > .12) {
          _applied = true;
          _applyAction();
        }
        if (_st == _St.act && _stT > .6 / _sp) _nextHero();
      case _St.enemy:
        if (!_applied && _stT > .45 / _sp) {
          _applied = true;
          _enemyAct();
        }
        if (_stT > 1.0 / _sp) {
          _guard = false;
          if (_party.every((h) => h.ko)) {
            _st = _St.over;
            _msg = host.tr('lose', 'LOSE');
            host.sfx(Sfx.pDie);
            host.lose();
          } else {
            _active = -1;
            _nextHero();
          }
        }
      case _St.over:
        _endT += dt;
    }
  }

  // ------------------------------------------------------------ input ---

  static const _cmdArea = Rect.fromLTWH(10, 462, 340, 170);
  Rect _cmdRect(int i) => Rect.fromLTWH(_cmdArea.left + 10 + (i % 2) * 164, _cmdArea.top + 12 + (i ~/ 2) * 78, 156, 70);
  Rect _winRect(int i) => Rect.fromLTWH(10 + i * 115.0, 360, 110, 96);

  @override
  void onDown(Offset p) {
    if (_st == _St.meter) {
      _meterTap();
      return;
    }
    if (_st == _St.choose) {
      for (var i = 0; i < 4; i++) {
        if (_cmdRect(i).inflate(4).contains(p)) {
          _choose(i);
          return;
        }
      }
    }
  }

  @override
  void onKey(String key, bool down) {
    if (!down) return;
    if (_st == _St.meter && key == 'action') {
      _meterTap();
      return;
    }
    if (_st != _St.choose) return;
    switch (key) {
      case 'up':
        _choose(0);
      case 'right':
        _choose(1);
      case 'left':
        _choose(2);
      case 'down':
        _choose(3);
      case 'action':
        _choose(0);
    }
  }

  // ----------------------------------------------------------- render ---

  void _window(Canvas c, Rect r, {bool hi = false}) {
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2838B8), Color(0xFF0C1060)],
      ).createShader(r);
    // stepped corners
    c.drawRect(Rect.fromLTRB(r.left + 6, r.top, r.right - 6, r.bottom), fill);
    c.drawRect(Rect.fromLTRB(r.left + 3, r.top + 3, r.right - 3, r.bottom - 3), fill);
    c.drawRect(Rect.fromLTRB(r.left, r.top + 6, r.right, r.bottom - 6), fill);
    final border = Paint()..color = hi ? _gold : _white;
    final shade = Paint()..color = const Color(0xFF8890B0);
    // outer white frame (3px) with stepped corners
    c.drawRect(Rect.fromLTWH(r.left + 6, r.top + 3, r.width - 12, 3), border);
    c.drawRect(Rect.fromLTWH(r.left + 6, r.bottom - 6, r.width - 12, 3), border);
    c.drawRect(Rect.fromLTWH(r.left + 3, r.top + 6, 3, r.height - 12), border);
    c.drawRect(Rect.fromLTWH(r.right - 6, r.top + 6, 3, r.height - 12), border);
    // inner shade line
    c.drawRect(Rect.fromLTWH(r.left + 6, r.top + 6, r.width - 12, 1.5), shade);
    c.drawRect(Rect.fromLTWH(r.left + 6, r.top + 6, 1.5, r.height - 12), shade);
    // corner dots
    for (final o in [
      Offset(r.left + 6, r.top + 6),
      Offset(r.right - 9, r.top + 6),
      Offset(r.left + 6, r.bottom - 9),
      Offset(r.right - 9, r.bottom - 9)
    ]) {
      c.drawRect(Rect.fromLTWH(o.dx, o.dy, 3, 3), border);
    }
  }

  @override
  void render(Canvas c) {
    _renderBackdrop(c);
    _renderBoss(c);

    // message window
    const mr = Rect.fromLTWH(10, 302, 340, 54);
    _window(c, mr);
    if (_st == _St.meter) {
      _renderMeter(c, mr);
    } else {
      final blink = _st == _St.choose && (_t * 3).floor().isEven;
      _px(c, _msg, const Offset(26, 322), 2, _white);
      if (blink) {
        final tri = Path()
          ..moveTo(326, 324)
          ..lineTo(338, 324)
          ..lineTo(332, 331)
          ..close();
        c.drawPath(tri, Paint()..color = _white);
      }
    }

    // party windows
    for (var i = 0; i < 3; i++) {
      final h = _party[i];
      final r0 = _winRect(i);
      final sh = sin(_t * 60) * 5 * h.shake;
      final active = (_st == _St.choose || _st == _St.meter || (_st == _St.act)) && _active == i;
      final r = r0.shift(Offset(sh, active ? -6 : 0));
      _window(c, r, hi: active);
      final portrait = _heroes[i];
      final ko = h.ko;
      portrait.draw(c, Offset(r.left + 10, r.top + 12 + (active ? sin(_t * 8) * 2 : 0)),
          scale: 2, tint: ko ? const Color(0xFF606880) : (h.flash > .5 ? _red : (h.heal > .5 ? const Color(0xFF58F878) : null)));
      _px(c, _names[i], Offset(r.left + 48, r.top + 14), 1.5, active ? _gold : _white);
      if (ko) {
        _px(c, 'KO', Offset(r.left + 48, r.top + 30), 2, _red);
      }
      // HP
      _px(c, 'HP', Offset(r.left + 12, r.top + 50), 1.5, const Color(0xFFB0B8E0));
      final hpCol = h.hp < h.maxHp * .3 ? _red : (h.hp < h.maxHp * .6 ? _gold : _white);
      _px(c, '${h.hp}', Offset(r.right - 12, r.top + 48), 2, hpCol, align: 1);
      final bar = Rect.fromLTWH(r.left + 12, r.top + 64, r.width - 24, 4);
      c.drawRect(bar, Paint()..color = const Color(0xFF000020));
      c.drawRect(Rect.fromLTWH(bar.left, bar.top, bar.width * h.hp / h.maxHp, 4), Paint()..color = const Color(0xFF58F878));
      _px(c, 'MP', Offset(r.left + 12, r.top + 76), 1.5, const Color(0xFFB0B8E0));
      _px(c, '${h.mp}', Offset(r.right - 12, r.top + 74), 2, const Color(0xFF88C8F8), align: 1);
    }

    // command window
    _window(c, _cmdArea);
    final labels = [
      host.tr('attack', 'ATTACK'),
      _active == 2 ? host.tr('heal', 'HEAL') : host.tr('magic', 'MAGIC'),
      host.tr('defend', 'DEFEND'),
      host.tr('item', 'ITEM'),
    ];
    for (var i = 0; i < 4; i++) {
      final r = _cmdRect(i);
      final enabled = _st == _St.choose && _active >= 0 && _active < 3 && _canUse(i);
      final pressed = _pressed == i && _pressT > 0;
      final rr = r.shift(Offset(0, pressed ? 3 : 0));
      c.drawRect(rr, Paint()..color = enabled ? const Color(0x33FFFFFF) : const Color(0x11FFFFFF));
      final icon = i == 1 && _active == 2 ? _icons[3] : _icons[i];
      icon.draw(c, Offset(rr.left + 10, rr.top + 17), scale: 3, opacity: enabled ? 1 : .35);
      _px(c, labels[i], Offset(rr.left + 56, rr.top + 20), 2, enabled ? _white : const Color(0xFF6870A0));
      final sub = switch (i) {
        1 => 'MP${_active >= 0 && _active < 3 ? _mpCost(_active) : 0}',
        3 => 'x$_potions',
        _ => '',
      };
      if (sub.isNotEmpty) _px(c, sub, Offset(rr.left + 56, rr.top + 42), 1.5, const Color(0xFF88C8F8));
      // cursor
      if (enabled && i == 0 && host.time < 3) {
        final bob = sin(_t * 10) * 3;
        final tri = Path()
          ..moveTo(rr.left - 4 + bob, rr.top + 26)
          ..lineTo(rr.left + 6 + bob, rr.top + 33)
          ..lineTo(rr.left - 4 + bob, rr.top + 40)
          ..close();
        c.drawPath(tri, Paint()..color = _white);
      }
    }
    if (host.time < 2.2 && _st == _St.choose) D.hand(c, _cmdRect(0).center + const Offset(10, 10), _t);

    for (final p in _pops) {
      final s = p.big ? 4.0 : 3.0;
      final bounce = p.t < .2 ? (1 + (.2 - p.t) * 2) : 1.0;
      c.save();
      c.translate(p.x, p.y);
      c.scale(bounce);
      _px(c, p.s, Offset.zero, s, p.col, align: 0, shadow: _k);
      c.restore();
    }

    if (_won && _endT > .3) {
      final s = min(1.0, (_endT - .3) * 4);
      c.save();
      c.translate(180, 150);
      c.scale(M.easeOutBack(s));
      _px(c, host.tr('level_up', 'LEVEL UP!'), Offset.zero, 4, _gold, align: 0, shadow: _k);
      _px(c, 'EXP +${host.score}', const Offset(0, 40), 2, _white, align: 0, shadow: _k);
      c.restore();
    }
    Retro.scanlines(c, alpha: .1);
  }

  void _renderMeter(Canvas c, Rect mr) {
    final bar = Rect.fromLTWH(mr.left + 20, mr.top + 18, mr.width - 40, 18);
    c.drawRect(bar, Paint()..color = const Color(0xFF000020));
    c.drawRect(Rect.fromLTWH(bar.left + bar.width * .54, bar.top, bar.width * .38, bar.height), Paint()..color = const Color(0xFF3868D8));
    c.drawRect(Rect.fromLTWH(bar.left + bar.width * .7, bar.top, bar.width * .14, bar.height),
        Paint()..color = (_t * 10).floor().isEven ? _gold : const Color(0xFFF8A020));
    c.drawRect(Rect.fromLTWH(bar.left, bar.top, bar.width, 2), Paint()..color = _white);
    c.drawRect(Rect.fromLTWH(bar.left, bar.bottom - 2, bar.width, 2), Paint()..color = _white);
    final x = bar.left + bar.width * _meterPos;
    c.drawRect(Rect.fromLTWH(x - 3, bar.top - 6, 6, bar.height + 12), Paint()..color = _white);
    c.drawRect(Rect.fromLTWH(x - 1.5, bar.top - 4, 3, bar.height + 8), Paint()..color = _red);
    _px(c, host.tr('tap', 'TAP'), Offset(bar.left + bar.width * .77, bar.top - 14), 1.5, _gold, align: 0, shadow: _k);
  }

  void _renderBackdrop(Canvas c) {
    // dusk sky bands with dithering
    const bands = [Color(0xFF281848), Color(0xFF482868), Color(0xFF784088), Color(0xFFB85C88), Color(0xFFE8906C)];
    const top = 36.0, bottom = 250.0;
    const bh = (bottom - top) / 5;
    for (var i = 0; i < 5; i++) {
      c.drawRect(Rect.fromLTWH(0, top + i * bh, 360, bh + 1), Paint()..color = bands[i]);
      if (i > 0) {
        final p = Paint()..color = bands[i - 1];
        for (var x = 0; x < 120; x++) {
          if (x.isEven) c.drawRect(Rect.fromLTWH(x * 3.0, top + i * bh, 3, 3), p);
        }
      }
    }
    // stars
    final sp = Paint()..color = const Color(0xCCFFFFFF);
    for (var i = 0; i < 18; i++) {
      final x = (i * 67 % 360).toDouble(), y = 44.0 + (i * 29 % 70);
      if ((_t * 2 + i).floor() % 5 != 0) c.drawRect(Rect.fromLTWH(x, y, 3, 3), sp);
    }
    // moon
    c.drawCircle(const Offset(300, 84), 21, Paint()..color = const Color(0xFFF8E8B8));
    c.drawCircle(const Offset(292, 78), 6, Paint()..color = const Color(0xFFE0C890));
    // distant castle silhouette
    final sil = Paint()..color = const Color(0xFF301838);
    c.drawRect(const Rect.fromLTWH(30, 190, 90, 60), sil);
    c.drawRect(const Rect.fromLTWH(48, 160, 24, 40), sil);
    c.drawRect(const Rect.fromLTWH(84, 170, 18, 30), sil);
    for (var i = 0; i < 5; i++) {
      c.drawRect(Rect.fromLTWH(30 + i * 18.0, 184, 9, 6), sil);
    }
    c.drawRect(const Rect.fromLTWH(56, 176, 6, 6), Paint()..color = const Color(0xFFF8C848));
    // hills
    final hill = Paint()..color = const Color(0xFF203050);
    for (var x = 0.0; x < 360; x += 6) {
      final h = 20 + 14 * sin(x / 40) + 8 * sin(x / 13);
      c.drawRect(Rect.fromLTWH(x, 250 - h, 6, h), hill);
    }
    // ground (checker floor with perspective rows)
    const gTop = 248.0;
    for (var r = 0; r < 6; r++) {
      final y = gTop + r * 9.0;
      final col = r.isEven ? const Color(0xFF305830) : const Color(0xFF284828);
      c.drawRect(Rect.fromLTWH(0, y, 360, 9), Paint()..color = col);
    }
    // grass tufts
    final tuft = Paint()..color = const Color(0xFF58A848);
    for (var i = 0; i < 16; i++) {
      final x = (i * 53 % 360).toDouble(), y = gTop + 6 + (i * 17 % 44);
      c.drawRect(Rect.fromLTWH(x, y, 3, 6), tuft);
      c.drawRect(Rect.fromLTWH(x + 3, y + 3, 3, 3), tuft);
    }
  }

  void _renderBoss(Canvas c) {
    final dead = _won;
    if (dead && _endT > 1.2) return;
    final charging = _charging || (_st == _St.enemy && _mega && _stT < .45);
    final breathe = sin(_t * 3.2);
    double sx = 1 + breathe * .03, sy = 1 - breathe * .04;
    var ox = 0.0, oy = 0.0;
    if (_st == _St.enemy && !dead) {
      // hop attack
      final k = (_stT * _sp / .45).clamp(0.0, 1.0);
      oy = -sin(k * pi) * 40;
      if (k > .9) {
        sx = 1.15;
        sy = .85;
      }
    }
    ox += sin(_t * 70) * 6 * _bossShake;
    if (charging) ox += sin(_t * 50) * 2;
    if (dead) {
      sy *= 1 - _endT / 1.2;
      sx *= 1 + _endT * .6;
    }
    const scale = 5.0;
    const base = Offset(180, 292);
    // shadow
    c.drawOval(Rect.fromCenter(center: base + const Offset(0, -4), width: 150 * sx, height: 18), Paint()..color = const Color(0x55000000));
    c.save();
    c.translate(base.dx + ox, base.dy + oy);
    c.scale(sx, sy);
    final s = charging ? _slimeAngry : _slime;
    s.draw(c, Offset(-_slime.w * scale / 2, -_slime.h * scale), scale: scale, tint: _bossFlash > .5 ? _white : null);
    c.restore();
    if (charging) {
      final a = M.wave(_t, 4);
      c.drawCircle(base + Offset(ox, -75 + oy), 90 + a * 10,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = Color.fromRGBO(248, 56, 40, .3 + .4 * a));
      _px(c, '!!', base + Offset(70 + ox, -150), 3, _red, shadow: _k);
    }
    if (_slash >= 0) {
      final k = _slash;
      final p = Paint()..color = Color.fromRGBO(255, 255, 255, 1 - k);
      for (var i = 0; i < 3; i++) {
        final off = (i - 1) * 16.0;
        final a = Offset(110 + off + k * 30, 140 - off * .5);
        final b = Offset(250 + off - k * 10, 260 - off * .5);
        final n = 14;
        for (var j = 0; j <= n; j++) {
          if (j / n > k * 1.4) break;
          final pt = Offset.lerp(a, b, j / n)!;
          c.drawRect(Rect.fromCenter(center: pt, width: 9, height: 9), p);
        }
      }
    }
    if (_fireFx >= 0) {
      final k = _fireFx;
      for (var i = 0; i < 9; i++) {
        final ang = i / 9 * pi * 2 + k * 3;
        final r = 20 + k * 90;
        final pt = Offset(180 + cos(ang) * r, 200 + sin(ang) * r * .6);
        c.drawRect(Rect.fromCenter(center: pt, width: 15, height: 15),
            Paint()..color = (i.isEven ? const Color(0xFFF8E040) : const Color(0xFFF88800)).withValues(alpha: 1 - k));
      }
    }
    // boss HP bar
    const hb = Rect.fromLTWH(60, 48, 240, 12);
    c.drawRect(hb.inflate(3), Paint()..color = _k);
    c.drawRect(hb, Paint()..color = const Color(0xFF401020));
    c.drawRect(Rect.fromLTWH(hb.left, hb.top, hb.width * _bossShown / _bossMax, hb.height), Paint()..color = const Color(0xFFF8A020));
    c.drawRect(Rect.fromLTWH(hb.left, hb.top, hb.width * _bossHp / _bossMax, hb.height), Paint()..color = _red);
    c.drawRect(Rect.fromLTWH(hb.left, hb.top, hb.width * _bossHp / _bossMax, 3), Paint()..color = const Color(0xFFF89080));
    _px(c, host.tr('boss', 'BOSS'), const Offset(60, 66), 1.5, _white, shadow: _k);
    _px(c, '$_bossHp/$_bossMax', const Offset(300, 66), 1.5, _white, align: 1, shadow: _k);
  }
}
