// App Store preview (iPhone App Preview) renderer — one language per run.
//
//   python tool/pv/make_pv.py ja            # preferred: renders + mixes audio
//   flutter test tool/pv/pv_render_test.dart --dart-define=PV_LANG=ja \
//       --dart-define=FFMPEG=<ffmpeg.exe> [--dart-define=STILLS=0.5,4.1]
//
// Every frame is real app rendering: the games run headless with scripted
// players (see pv_bots.dart, clip picks from build/pv/scout.json) and the
// shell screens are the real widgets. Output (886x1920, 30 fps):
//   build/pv/<lang>/frames.rgba raw RGBA frames (make_pv.py encodes + deletes)
//   build/pv/<lang>/sfx.json   sound effects to mix (PV time, name, volume, rate)
// With STILLS only PNGs build/pv/<lang>/still_<sec>.png are written.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/app.dart';
import 'package:hitasura_ads/arcade/engine/draw.dart';
import 'package:hitasura_ads/arcade/engine/fx.dart';
import 'package:hitasura_ads/arcade/engine/game.dart';
import 'package:hitasura_ads/arcade/engine/game_view.dart';
import 'package:hitasura_ads/arcade/registry.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/l10n/l10n.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';
import 'package:hitasura_ads/state/app_controller.dart';
import 'package:hitasura_ads/ui/ad_player.dart';
import 'package:hitasura_ads/ui/collection.dart';
import 'package:hitasura_ads/ui/kit.dart';
import 'package:hitasura_ads/ui/rush.dart';
import 'package:hitasura_ads/ui/thumbs.dart';

import 'pv_bots.dart';

const _lang = String.fromEnvironment('PV_LANG', defaultValue: 'ja');
const _stillsArg = String.fromEnvironment('STILLS');
const _storeDevice = String.fromEnvironment('STORE_DEVICE'); // iphone_6_9 | ipad_13 → store shots instead

// Output geometry. All drawing uses a 360-wide virtual space (like the games).
const _pxW = 886, _pxH = 1920;
const _k = _pxW / 360.0;
const _vH = _pxH / _k; // ≈ 780.2
const _gameTop = _vH - 640; // game area = bottom 360x640
const _fps = 30;
const _beat = .4; // BGM "rush" is 150 BPM
const _total = 74 * _beat; // 29.6 s

// ------------------------------------------------------------------ clips ---

class Seg {
  const Seg(this.a, this.b, {this.fromEnd = false});
  final double a, b; // session seconds; relative to the finish when fromEnd
  final bool fromEnd;
}

class ClipSpec {
  const ClipSpec(this.no, this.kind, this.seed, this.segs);
  final int no, kind, seed;
  final List<Seg> segs;
}

class _Frame {
  _Frame(this.t, this.pic, this.touch, this.hold, this.pressAge, this.sfx);
  final double t;
  final ui.Picture pic;
  final Offset touch;
  final bool hold;
  final double pressAge;
  final List<SfxEvent> sfx;
}

class _Clip {
  _Clip(this.spec, this.frames);
  final ClipSpec spec;
  final List<_Frame> frames;
  int shown = -1;
  _Frame at(double tau) => frames[(tau * _fps).floor().clamp(0, frames.length - 1)];
}

/// Clip picks (game no, bot kind, seed) come from the scout: all of these WIN.
const _hookClip = ClipSpec(1, 0, 2, [Seg(.15, 1.35), Seg(-1.6, .4, fromEnd: true)]);
const _montage = [
  ClipSpec(18, 0, 0, [Seg(-.8, .4, fromEnd: true)]), // crowd runner x105
  ClipSpec(16, 1, 2, [Seg(-.8, .4, fromEnd: true)]), // frost survival
  ClipSpec(8, 0, 3, [Seg(-.8, .4, fromEnd: true)]), // fruit merge drop
  ClipSpec(82, 0, 0, [Seg(-.8, .4, fromEnd: true)]), // invaders
  ClipSpec(104, 5, 1, [Seg(-.8, .4, fromEnd: true)]), // penguin 3D
  ClipSpec(116, 2, 2, [Seg(-.8, .4, fromEnd: true)]), // claw machine
  ClipSpec(137, 0, 0, [Seg(-.8, .4, fromEnd: true)]), // soccer
  ClipSpec(96, 3, 2, [Seg(-.8, .4, fromEnd: true)]), // bowling 3D
];
const _rushDur = [1.2, 1.2, .8, .8, .8, .4, .4, .4, .4];
const _rushPick = [(63, 0, 3), (73, 0, 1), (66, 0, 2), (76, 0, 2), (69, 0, 3), (79, 0, 3), (62, 1, 2), (70, 0, 0), (65, 3, 4)];
const _gridNos = [109, 106, 125, 86, 129, 100, 54, 31, 92];

Color _accent(int no) {
  final g = allGames.firstWhere((g) => g.no == no);
  final c = K.category(g.cat);
  return c == Colors.white ? K.yellow : Color.lerp(c, Colors.white, .15)!;
}

_Clip _simulate(ClipSpec spec) {
  final g = allGames.firstWhere((g) => g.no == spec.no);
  final text = L10n.game(g.no);
  final audio = RecordingAudio();
  final s = GameSession(
    game: g.create(),
    duration: g.duration,
    verb: text.verb,
    hook: text.hook,
    seed: 1000 + spec.seed,
    audio: audio,
    accent: _accent(g.no),
  );
  final bot = Bot(spec.kind, spec.seed * 7 + g.no);
  final ends = spec.segs.where((s) => s.fromEnd);
  final back = ends.isEmpty ? 0.0 : ends.map((s) => -s.a).reduce(math.max);
  final after = ends.isEmpty ? 0.0 : ends.map((s) => s.b).reduce(math.max);
  final abs = spec.segs.where((s) => !s.fromEnd).toList();
  final absEnd = abs.isEmpty ? 0.0 : abs.map((s) => s.b).reduce(math.max);
  bool inAbs(double t) => abs.any((s) => t >= s.a - .02 && t < s.b + .02);

  const dt = 1 / 30;
  var t = 0.0;
  double? endAt;
  var ev = 0;
  final kept = <_Frame>[];
  while (t < g.duration + 6) {
    if (s.acceptsInput) bot.step(s, t, dt);
    audio.now = t;
    s.tick(dt);
    t += dt;
    if (endAt == null && s.finished) endAt = t;
    final rec = ui.PictureRecorder();
    s.render(Canvas(rec));
    final sfx = audio.events.sublist(ev);
    ev = audio.events.length;
    kept.add(_Frame(t, rec.endRecording(), bot.pos, bot.holding && s.acceptsInput, t - bot.lastPress, sfx));
    // Drop frames no segment can use any more.
    final keepFrom = ends.isEmpty ? double.infinity : (endAt ?? t) - back - .05;
    kept.removeWhere((f) {
      final drop = f.t < keepFrom && !inAbs(f.t);
      if (drop) f.pic.dispose();
      return drop;
    });
    final endsDone = ends.isEmpty || (endAt != null && t >= endAt + after + .05);
    if (endsDone && t >= absEnd + .05) break;
    if (ends.isEmpty && s.phase == SessionPhase.done) break;
  }
  final e = endAt ?? t;
  final frames = <_Frame>[
    for (final seg in spec.segs)
      ...kept.where((f) {
        final lo = seg.fromEnd ? e + seg.a : seg.a, hi = seg.fromEnd ? e + seg.b : seg.b;
        return f.t >= lo && f.t < hi;
      }),
  ];
  // ignore: avoid_print
  print('clip No.${spec.no}: ${s.won ? 'WIN(${s.stars})' : 'LOSE'} end=${e.toStringAsFixed(2)} frames=${frames.length}');
  return _Clip(spec, frames);
}

// ------------------------------------------------------------------- text ---

TextStyle _style(double size, Color color, {Paint? fg}) => TextStyle(
      fontSize: size,
      color: fg == null ? color : null,
      foreground: fg,
      fontWeight: FontWeight.w900,
      fontFamily: D.fontFamily,
      fontFamilyFallback: D.fontFallback,
      height: 1.1,
    );

double _measure(String s, double size) {
  final tp = TextPainter(text: TextSpan(text: s, style: _style(size, Pal.white)), textDirection: D.textDirection)
    ..layout();
  final w = tp.width;
  tp.dispose();
  return w;
}

/// Chunky outlined caption, shrunk to fit [maxW], popping in with [pop] 0..1.
void _caption(Canvas c, String s, Offset at, double size,
    {Color color = Pal.white, double maxW = 336, double pop = 1, bool title = false, double rotate = 0}) {
  if (pop <= 0 || s.isEmpty) return;
  final w = _measure(s, size) + size * .5;
  final fit = math.min(1.0, maxW / w);
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(rotate);
  c.scale(fit * M.easeOutBack(pop.clamp(0, 1)));
  if (title) {
    D.title(c, s, Offset.zero, size: size, color: color);
  } else {
    D.text(c, s, Offset.zero, size: size, color: color, stroke: Pal.ink, strokeWidth: size * .28);
  }
  c.restore();
}

double _popAt(double t, double t0, [double len = .22]) => ((t - t0) / len).clamp(0.0, 1.0);

// ------------------------------------------------------------------- draw ---

void _band(Canvas c, double t, {Color a = const Color(0xFF2A1563), Color b = const Color(0xFF15102A), Color edge = Pal.yellow}) {
  const r = Rect.fromLTWH(0, 0, 360, _gameTop);
  D.gradientBg(c, [a, b], rect: r);
  c.save();
  c.clipRect(r);
  final p = Paint()..color = const Color(0x12FFFFFF);
  final off = (t * 60) % 48;
  for (var x = -200.0; x < 420; x += 48) {
    final path = Path()
      ..moveTo(x + off, 0)
      ..lineTo(x + off + 22, 0)
      ..lineTo(x + off + 22 - 80, _gameTop)
      ..lineTo(x + off - 80, _gameTop)
      ..close();
    c.drawPath(path, p);
  }
  c.restore();
  c.drawRect(const Rect.fromLTWH(0, _gameTop - 5, 360, 5), Paint()..color = edge);
}

void _game(Canvas c, _Frame f, Rect dst, {double punch = 0, bool touch = true}) {
  c.save();
  c.clipRect(dst);
  c.translate(dst.left, dst.top);
  final s = dst.width / 360;
  c.scale(s);
  if (punch > 0) {
    c.translate(180, 320);
    c.scale(1 + punch);
    c.translate(-180, -320);
  }
  c.drawPicture(f.pic);
  if (touch) {
    if (f.pressAge >= 0 && f.pressAge < .3) {
      final k = f.pressAge / .3;
      c.drawCircle(f.touch, 12 + 34 * k,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * (1 - k) + 1
            ..color = Color.fromRGBO(255, 255, 255, .9 * (1 - k)));
    }
    if (f.hold || f.pressAge < .08) {
      c.drawCircle(f.touch, 15, Paint()..color = const Color(0x77FFFFFF));
      c.drawCircle(f.touch, 15,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xDDFFFFFF));
    }
  }
  c.restore();
}

void _flash(Canvas c, double since, {double len = .12, Color color = Pal.white}) {
  if (since < 0 || since >= len) return;
  c.drawRect(const Rect.fromLTWH(0, 0, 360, _vH), Paint()..color = color.withValues(alpha: .75 * (1 - since / len)));
}

void _pill(Canvas c, String s, Offset at, Color bg, {double size = 15, Color fg = Pal.ink, double pop = 1}) {
  if (pop <= 0) return;
  final w = _measure(s, size) + 26;
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(M.easeOutBack(pop));
  D.rrect(c, Rect.fromCenter(center: Offset.zero, width: w, height: size + 14), (size + 14) / 2, bg,
      border: Pal.ink, borderWidth: 2.5);
  D.text(c, s, Offset.zero, size: size, color: fg);
  c.restore();
}

// --------------------------------------------------------------------- UI ---

class _NoAds extends RewardedAdService {
  @override
  RewardedAdStatus get status => RewardedAdStatus.ready;
  @override
  bool get isSupported => true;
  @override
  bool get usesTestAds => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<RewardedAdResult> show({String placementName = 'reward'}) async => RewardedAdResult.unavailable;
}

final _uiKey = GlobalKey();

Future<void> _loadFonts() async {
  Future<void> fam(String name, List<String> files) async {
    final l = FontLoader(name);
    for (final f in files) {
      final file = File(f);
      if (!file.existsSync()) {
        // ignore: avoid_print
        print('font missing: $f');
        continue;
      }
      final b = file.readAsBytesSync();
      l.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await l.load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? 'D:/user/develop/flutter';
  const w = 'C:/Windows/Fonts/';
  await fam('KosugiMaru', ['assets/fonts/KosugiMaru-Regular.ttf']);
  await fam('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
  await fam('Noto Sans JP', ['${w}NotoSansJP-VF.ttf']);
  await fam('Noto Sans KR', ['${w}malgunbd.ttf', '${w}malgun.ttf']);
  await fam('Noto Sans SC', ['${w}msyhbd.ttc', '${w}msyh.ttc']);
  await fam('Noto Sans TC', ['${w}msjhbd.ttc', '${w}msjh.ttc']);
  await fam('Noto Sans Devanagari', ['${w}NirmalaB.ttf', '${w}Nirmala.ttf']);
  await fam('Noto Sans Bengali', ['${w}NirmalaB.ttf', '${w}Nirmala.ttf']);
  await fam('Noto Sans Arabic', ['${w}NotoSansArabic-Bold.ttf', '${w}NotoSansArabic-Regular.ttf']);
  await fam('Noto Sans Thai', ['${w}LeelaUIb.ttf', '${w}LeelawUI.ttf']);
  await fam('Noto Sans', ['${w}NotoSans-Bold.ttf', '${w}NotoSans-Regular.ttf']);
}

// ------------------------------------------------------------------- main ---

void main() {
  if (_storeDevice.isNotEmpty) {
    _storeMain();
    return;
  }
  testWidgets('render PV $_lang', (tester) async {
    final script = (jsonDecode(File('tool/pv/pv_script.json').readAsStringSync()) as Map)[_lang] as Map;
    String cap(String key) => script[key] as String;
    final stills = _stillsArg.isEmpty ? <double>[] : _stillsArg.split(',').map(double.parse).toList();
    final outDir = 'build/pv/$_lang';
    Directory(outDir).createSync(recursive: true);

    await tester.runAsync(_loadFonts);
    L10n.code = _lang;
    applyLanguage();

    // ---- game clips (simulated up front; pictures are cheap)
    final hook = _simulate(_hookClip);
    final montage = [for (final s in _montage) _simulate(s)];
    final rush = [
      for (var i = 0; i < _rushPick.length; i++)
        _simulate(ClipSpec(_rushPick[i].$1, _rushPick[i].$2, _rushPick[i].$3,
            [Seg(-_rushDur[i] * .62, _rushDur[i] * .38, fromEnd: true)])),
    ];
    final grid = [for (final no in _gridNos) _simulate(ClipSpec(no, 0, 1, const [Seg(2.4, 6.6)]))];

    // ---- shell UI (real widgets)
    tester.view.physicalSize = const Size(_pxW + 0.0, _pxH + 0.0);
    tester.view.devicePixelRatio = _k;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final rnd = math.Random(5);
    final controller = await AppController.create(
      store: MemoryAppStore(AppSnapshot(
        user: UserProfile(id: 'u', nickname: _lang == 'ja' ? 'ドパガキ' : 'PLAYER', age: 0, createdAt: now),
        discoveredIds: {for (final g in allGames) g.id},
        searchEnergy: 5,
        searchEnergyRecoveryAnchor: now,
        arcade: ArcadeState(
          language: _lang,
          coins: 15100,
          xp: 98000,
          stars: {for (final g in allGames) g.id: 1 + rnd.nextInt(3) + (rnd.nextInt(3) == 0 ? 0 : 0)},
        ),
      )),
    );
    await tester.pumpWidget(RepaintBoundary(
        key: _uiKey, child: HitasuraAdsApp(controller: controller, rewardedAdService: _NoAds())));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => CollectionScreen(controller: controller)));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    ScrollPosition gridPos() => tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((s) => s.position.axis == Axis.vertical)
        .position;
    // Warm the thumbnail cache across the whole grid.
    Future<void> settleThumbs() async {
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 40));
      }
    }

    await settleThumbs();
    final maxScroll = gridPos().maxScrollExtent;
    for (var y = 0.0; y < maxScroll; y += 600) {
      gridPos().jumpTo(y);
      await tester.pump();
      await settleThumbs();
    }
    gridPos().jumpTo(0);
    await tester.pump();
    await settleThumbs();
    final missing = [for (final g in allGames) if (ThumbCache.instance.get(g.no) == null) g.no];
    // ignore: avoid_print
    print('thumbs missing: ${missing.length}');

    Future<ui.Image> grabUi(double ratio) async {
      final b = _uiKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() => b.toImage(pixelRatio: ratio)))!;
    }

    // ---- raw frame sink (encoded by make_pv.py; a pipe stalls under the test binding)
    RandomAccessFile? raw;
    if (stills.isEmpty) raw = File('$outDir/frames.rgba').openSync(mode: FileMode.write);

    // ---- timeline
    final sfxOut = <Map<String, Object>>[];
    void emit(double t, String name, [double vol = 1, double rate = 1]) =>
        sfxOut.add({'t': double.parse(t.toStringAsFixed(3)), 'name': name, 'vol': vol, 'rate': rate});
    void play(_Clip clip, double tau, double pvT, double vol) {
      final i = (tau * _fps).floor().clamp(0, clip.frames.length - 1);
      for (var j = clip.shown + 1; j <= i; j++) {
        for (final e in clip.frames[j].sfx) {
          emit(pvT, e.name, e.volume * vol, e.rate);
        }
      }
      if (i > clip.shown) clip.shown = i;
    }

    final fx = Fx(math.Random(3));
    final total = (_total * _fps).round();
    final stillFrames = {for (final s in stills) (s * _fps).round(): s};
    final gameRect = const Rect.fromLTWH(0, _gameTop, 360, 640);
    // Logo = the brand part of the store title ("ひたすら広告　151の…" → "ひたすら広告").
    final title = L10n.ui('app_title').split(RegExp('[　:]')).first.trim();
    final cued = <int>{};
    bool cue(int id) => cued.add(id);

    var uiScene = 0; // 0 collection, 1 home
    for (var f = 0; f < total; f++) {
      final t = f / _fps;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.scale(_k);
      c.drawRect(const Rect.fromLTWH(0, 0, 360, _vH), Paint()..color = Pal.night);
      ui.Image? uiImg;

      if (t < 8 * _beat) {
        // ── 0: hook — the pin-pull ad, for real
        final cut = hook.spec.segs[0].b - hook.spec.segs[0].a;
        play(hook, t, t, .8);
        if (t < 1 / _fps) {
          emit(t, 'whoosh', .6);
        }
        if (t >= cut && cue(1)) emit(t, 'swipe', .6);
        _game(c, hook.at(t), gameRect, punch: t >= cut ? .06 * (1 - _popAt(t, cut, .2)) : 0);
        _band(c, t);
        _caption(c, cap('hook1'), const Offset(180, 42), 24, pop: _popAt(t, 0));
        _caption(c, cap('hook2'), const Offset(180, 96), 40, title: true, color: Pal.yellow,
            pop: _popAt(t, _beat), rotate: -.03 + .015 * math.sin(t * 9));
        _flash(c, t - cut);
      } else if (t < 32 * _beat) {
        // ── 1: montage — 8 ads, every one cleared
        final local = t - 8 * _beat;
        final i = (local / (3 * _beat)).floor().clamp(0, montage.length - 1);
        final tau = local - i * 3 * _beat;
        final clip = montage[i];
        if (cue(100 + i)) emit(t, 'whoosh', .5, 1 + i * .04);
        play(clip, tau, t, .7);
        _game(c, clip.at(tau), gameRect, punch: .07 * (1 - _popAt(tau, 0, .25)));
        _band(c, t, a: Color.lerp(const Color(0xFF2A1563), _accent(clip.spec.no), .35)!);
        final gt = L10n.game(clip.spec.no);
        _pill(c, 'No.${clip.spec.no.toString().padLeft(3, '0')}', const Offset(180, 36), _accent(clip.spec.no),
            pop: _popAt(tau, 0, .18));
        _caption(c, gt.title, const Offset(180, 94), 38, title: true, color: Pal.white,
            pop: _popAt(tau, .04), rotate: (i.isEven ? -1 : 1) * .025);
        _flash(c, tau, len: .1);
      } else if (t < 48 * _beat) {
        // ── 2: AD RUSH — micro ads back to back, faster and faster
        final local = t - 32 * _beat;
        var i = 0, start = 0.0;
        while (i < _rushDur.length - 1 && local >= start + _rushDur[i]) {
          start += _rushDur[i];
          i++;
        }
        final tau = local - start;
        final clip = rush[i];
        if (cue(200 + i)) {
          emit(t, 'combo', .7, 1 + i * .09);
          if (i == 2 || i == 5) emit(t, 'levelup', .6);
        }
        play(clip, tau, t, .6);
        _game(c, clip.at(tau), gameRect, punch: .09 * (1 - _popAt(tau, 0, .2)));
        // speed vignette grows with the stage
        final heat = i / (_rushDur.length - 1);
        c.drawRect(
            gameRect,
            Paint()
              ..shader = ui.Gradient.radial(gameRect.center, 380,
                  [const Color(0x00FF3B5C), Color.fromRGBO(255, 59, 92, .45 * heat * (.7 + .3 * M.wave(t, 5)))], [.6, 1]));
        _pill(c, '${L10n.ui('rush_stage')} ${i + 1}', const Offset(180, _gameTop + 42), Pal.yellow,
            size: 16, pop: _popAt(tau, 0, .15));
        if (i >= 2) {
          final since = local - (i >= 5 ? _rushDur.take(5).fold(0.0, (a, b) => a + b) : 2.4);
          if (since < .8) {
            _caption(c, L10n.ui('speed_up'), const Offset(180, _gameTop + 300), 50, title: true,
                color: Pal.red, pop: _popAt(since, 0, .18), rotate: -.12);
          }
        }
        _band(c, t, a: const Color(0xFF63152E), edge: Pal.red);
        _caption(c, L10n.ui('rush'), const Offset(180, 42), 26, color: Pal.yellow, pop: _popAt(local, 0));
        _caption(c, cap('rush2'), const Offset(180, 96), 40, title: true, color: Pal.white,
            pop: _popAt(local, _beat), rotate: .03 * math.sin(t * 14));
        _flash(c, tau, len: .08);
      } else if (t < 58 * _beat) {
        // ── 3: nine at once → "151"
        final local = t - 48 * _beat;
        final zoom = local > 9 * _beat ? M.easeInOut(((local - 9 * _beat) / _beat).clamp(0, 1)) : 0.0;
        c.save();
        c.translate(180, _gameTop + 320);
        c.scale(1 + zoom * 1.4);
        c.translate(-180, -(_gameTop + 320));
        for (var i = 0; i < grid.length; i++) {
          final pop = _popAt(local, i * .07, .2);
          if (pop <= 0) continue;
          if (cue(300 + i)) emit(t, 'pop', .45, 1 + i * .06);
          final cell = Rect.fromLTWH((i % 3) * 120.0, _gameTop + (i ~/ 3) * (640 / 3), 120, 640 / 3);
          c.save();
          c.translate(cell.center.dx, cell.center.dy);
          c.scale(M.easeOutBack(pop));
          c.translate(-cell.center.dx, -cell.center.dy);
          play(grid[i], local, t, i == 4 ? .35 : 0);
          _game(c, grid[i].at(local), cell.deflate(1.5), touch: false);
          c.drawRect(cell.deflate(1.5),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = Pal.ink);
          c.restore();
        }
        c.restore();
        const stampAt = 4 * _beat;
        if (local >= stampAt) {
          if (cue(400)) {
            emit(t, 'stamp', 1);
            emit(t, 'cheer', .7);
          }
          final s = local - stampAt;
          c.drawRect(gameRect, Paint()..color = Color.fromRGBO(14, 11, 31, (s * 2).clamp(0, .45)));
          D.rays(c, Offset(180, _gameTop + 320), 520, const Color(0x33FFE066), count: 16, t: s * 1.4);
          _caption(c, '151', Offset(180, _gameTop + 320), 150, title: true, color: Pal.yellow,
              pop: _popAt(s, 0, .25), rotate: -.08 + .02 * math.sin(s * 8));
        }
        _band(c, t, a: const Color(0xFF14506B), edge: Pal.teal);
        _caption(c, cap('grid1'), const Offset(180, 42), 24, pop: _popAt(local, 0));
        _caption(c, cap('grid2'), const Offset(180, 96), 42, title: true, color: Pal.yellow,
            pop: _popAt(local, stampAt), rotate: -.03);
        _flash(c, local, len: .1);
        if (zoom > 0) {
          c.drawRect(const Rect.fromLTWH(0, 0, 360, _vH), Paint()..color = Color.fromRGBO(255, 255, 255, zoom * .9));
        }
      } else if (t < 64 * _beat) {
        // ── 4: the real collection screen, all 151 found
        final local = t - 58 * _beat;
        if (cue(500)) emit(t, 'swipe', .7);
        final p = M.easeInOut((local / (6 * _beat)).clamp(0, 1));
        gridPos().jumpTo(maxScroll * p);
        await tester.pump(const Duration(microseconds: 33333));
        uiImg = await grabUi(_k);
        c.save();
        c.scale(1 / _k);
        c.drawImage(uiImg, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
        c.restore();
        // ribbon caption
        c.save();
        c.translate(180, 610);
        c.rotate(-.06);
        final rb = Rect.fromCenter(center: Offset.zero, width: 460, height: 112);
        c.drawRect(rb.shift(const Offset(0, 6)), Paint()..color = const Color(0x88000000));
        c.drawRect(rb, Paint()..color = Pal.ink);
        c.drawRect(Rect.fromLTWH(rb.left, rb.top, rb.width, 5), Paint()..color = Pal.pink);
        c.drawRect(Rect.fromLTWH(rb.left, rb.bottom - 5, rb.width, 5), Paint()..color = Pal.pink);
        c.restore();
        _caption(c, cap('coll1'), const Offset(180, 588), 22, pop: _popAt(local, 0), rotate: -.06);
        _caption(c, cap('coll2'), const Offset(182, 632), 38, title: true, color: Pal.yellow,
            pop: _popAt(local, _beat), rotate: -.06);
        _flash(c, local, len: .15);
      } else {
        // ── 5: end card
        final local = t - 64 * _beat;
        if (uiScene == 0) {
          uiScene = 1;
          nav.pop();
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
        }
        if (cue(600)) {
          emit(t, 'fanfare', .8);
          emit(t, 'stamp', .9);
          fx.confetti(count: 90);
        }
        await tester.pump(const Duration(microseconds: 33333));
        const shrink = .62;
        uiImg = await grabUi(_k * shrink);
        D.gradientBg(c, const [Color(0xFF3A0F6B), Color(0xFF15102A), Color(0xFF3B0A3F)],
            rect: const Rect.fromLTWH(0, 0, 360, _vH));
        D.rays(c, const Offset(180, 170), 700, const Color(0x1AFFFFFF), count: 18, t: local * .5);
        // the phone screen
        final rise = 1 - M.easeOut(_popAt(local, .1, .5));
        final ph = Rect.fromLTWH(180 - 360 * shrink / 2, 300 + rise * 300, 360 * shrink, _vH * shrink);
        final rr = RRect.fromRectAndRadius(ph, const Radius.circular(20));
        c.drawRRect(rr.shift(const Offset(0, 8)), Paint()..color = const Color(0x66000000));
        c.save();
        c.clipRRect(rr);
        c.translate(ph.left, ph.top);
        c.scale(ph.width / uiImg.width);
        c.drawImage(uiImg, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
        c.restore();
        c.drawRRect(rr,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = Pal.white);
        _caption(c, title, const Offset(180, 128), 54, title: true, color: Pal.yellow,
            pop: _popAt(local, 0, .3), rotate: -.04 + .015 * math.sin(local * 4), maxW: 340);
        _pill(c, L10n.ui('app_sub'), const Offset(180, 200), Pal.pink, size: 17, fg: Pal.white,
            pop: _popAt(local, _beat, .2));
        _caption(c, L10n.ui('tagline'), const Offset(180, 248), 17, pop: _popAt(local, 2 * _beat), maxW: 340);
        fx.update(1 / _fps);
        fx.render(c);
        _flash(c, local, len: .2);
      }

      final pic = rec.endRecording();
      final write = stills.isEmpty || stillFrames.containsKey(f);
      if (write) {
        await tester.runAsync(() async {
          final img = await pic.toImage(_pxW, _pxH);
          if (stills.isEmpty) {
            final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
            raw!.writeFromSync(data!.buffer.asUint8List());
          } else {
            final data = await img.toByteData(format: ui.ImageByteFormat.png);
            File('$outDir/still_${stillFrames[f]!.toStringAsFixed(1)}.png').writeAsBytesSync(data!.buffer.asUint8List());
          }
          img.dispose();
        });
      }
      pic.dispose();
      uiImg?.dispose();
      if (f % 60 == 0) {
        // ignore: avoid_print
        print('frame $f/$total');
      }
    }

    raw?.closeSync();
    File('$outDir/sfx.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(sfxOut));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }, timeout: const Timeout(Duration(minutes: 40)));
}

// ------------------------------------------------------------ store shots ---
//   flutter test tool/pv/pv_render_test.dart --dart-define=PV_LANG=ja --dart-define=STORE_DEVICE=iphone_6_9
//   → build/store/<lang>/<device>/<scene>.png at the device's native pixel size.
// Every shot is the real app widget tree at that device size. In gameplay shots
// the live GameView viewport is painted with a bot-played frame of the same game
// (rendered by the game's own code) so the moment shown is a real win.

void _storeMain() {
  testWidgets('store shots $_lang $_storeDevice', (tester) async {
    final ipad = _storeDevice == 'ipad_13';
    final ratio = ipad ? 2.0 : 3.0;
    final phys = ipad ? const Size(2064, 2752) : const Size(1320, 2868);
    tester.view.physicalSize = phys;
    tester.view.devicePixelRatio = ratio;
    tester.view.padding = ipad
        ? const FakeViewPadding(top: 48, bottom: 40)
        : const FakeViewPadding(top: 186, bottom: 102);
    addTearDown(tester.view.reset);
    final outDir = 'build/store/$_lang/$_storeDevice';
    final copy = (jsonDecode(File('tool/pv/store_copy.json').readAsStringSync()) as Map)[_lang] as Map;
    Directory(outDir).createSync(recursive: true);

    await tester.runAsync(_loadFonts);
    L10n.code = _lang;
    applyLanguage();

    _Frame endFrame(_Clip c) => c.frames[math.max(0, c.frames.length - 4)];
    _Frame at(_Clip c, double t) => c.frames.lastWhere((f) => f.t <= t, orElse: () => c.frames.first);
    final hook = _simulate(_hookClip);
    final runner = _simulate(_montage[0]);
    final penguin = _simulate(_montage[4]);
    final rushClip = _simulate(ClipSpec(_rushPick[0].$1, _rushPick[0].$2, _rushPick[0].$3,
        [Seg(-_rushDur[0] * .62, _rushDur[0] * .38, fromEnd: true)]));

    final now = DateTime.now();
    final rnd = math.Random(5);
    final controller = await AppController.create(
      store: MemoryAppStore(AppSnapshot(
        user: UserProfile(id: 'u', nickname: _lang == 'ja' ? 'ドパガキ' : 'PLAYER', age: 0, createdAt: now),
        discoveredIds: {for (final g in allGames) g.id},
        soundEffectsEnabled: false,
        notificationsEnabled: false,
        searchEnergy: 5,
        searchEnergyRecoveryAnchor: now,
        arcade: ArcadeState(
          language: _lang,
          coins: 15100,
          xp: 98000,
          stars: {for (final g in allGames) g.id: 1 + rnd.nextInt(3)},
        ),
      )),
    );
    await tester.pumpWidget(RepaintBoundary(
        key: _uiKey, child: HitasuraAdsApp(controller: controller, rewardedAdService: _NoAds())));
    Future<void> settle([int steps = 10]) async {
      for (var i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shot(String scene, {_Frame? frame, bool touch = false}) async {
      final err = tester.takeException();
      if (err != null) throw StateError('$scene layout: $err');
      Rect? view;
      if (frame != null) {
        final r = tester.getRect(find.byType(GameView).last);
        final k = math.min(r.width / 360, r.height / 640);
        view = Rect.fromCenter(center: r.center * ratio, width: 360 * k * ratio, height: 640 * k * ratio);
      }
      await tester.runAsync(() async {
        final b = _uiKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: ratio);
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawImage(img, Offset.zero, Paint());
        if (frame != null) _game(c, frame, view!, touch: touch);
        final out = await rec.endRecording().toImage(phys.width.round(), phys.height.round());
        final data = await out.toByteData(format: ui.ImageByteFormat.png);
        File('$outDir/raw_$scene.png').writeAsBytesSync(data!.buffer.asUint8List());
        final lines = (copy[scene] as List).cast<String>();
        final card = await _storeCard(out, lines, _storeAccent[scene]!, phys, ipad);
        final cardData = await card.toByteData(format: ui.ImageByteFormat.png);
        File('$outDir/$scene.png').writeAsBytesSync(cardData!.buffer.asUint8List());
        card.dispose();
        img.dispose();
        out.dispose();
      });
    }

    await settle(12);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await settle(6);
    await shot('06_home');
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);

    Future<void> play(int no, String scene, _Frame f, {bool touch = false}) async {
      nav.push(MaterialPageRoute<void>(
          builder: (_) => AdPlayerScreen(
              controller: controller, first: allGames.firstWhere((g) => g.no == no), roulette: false, replayMode: true)));
      await settle(20);
      await shot(scene, frame: f, touch: touch);
      nav.pop();
      await settle(8);
    }

    await play(1, '01_play', at(hook, .62), touch: true);
    await play(18, '02_runner', endFrame(runner));
    await play(104, '04_3d', endFrame(penguin));

    nav.push(MaterialPageRoute<void>(builder: (_) => RushScreen(controller: controller)));
    await settle(10);
    await tester.tap(find.byType(ChunkyButton).last);
    await settle(30);
    await shot('03_rush', frame: endFrame(rushClip));
    nav.pop();
    await settle(8);

    nav.push(MaterialPageRoute<void>(builder: (_) => CollectionScreen(controller: controller)));
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await shot('05_collection');
    nav.pop();
    await settle(8);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    controller.dispose();
  }, timeout: const Timeout(Duration(minutes: 10)), variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

const _storeAccent = {
  '01_play': Color(0xFFFFD332),
  '02_runner': Color(0xFF5EE0F2),
  '03_rush': Color(0xFFFF5FA8),
  '04_3d': Color(0xFFFFD332),
  '05_collection': Color(0xFF60EBDA),
  '06_home': Color(0xFFFF5FA8),
};

const _rtl = {'ar', 'ur', 'fa'};

/// App Store card: headline above a device frame showing [screen].
Future<ui.Image> _storeCard(ui.Image screen, List<String> lines, Color accent, Size size, bool ipad) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final w = size.width, h = size.height;
  final full = Offset.zero & size;
  c.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), const [Color(0xFF1A1030), Color(0xFF0D0820)]));
  c.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.radial(Offset(w * .8, h * .18), w * .9,
            [accent.withValues(alpha: .28), accent.withValues(alpha: 0)]));
  final stripe = Paint()
    ..color = const Color(0x0DFFFFFF)
    ..strokeWidth = w * .006;
  for (var x = -w; x < w * 1.6; x += w * .14) {
    c.drawLine(Offset(x, 0), Offset(x + w * .55, h), stripe);
  }

  // headline: two centred lines, shrunk to fit one line each
  final margin = w * .07;
  final dir = _rtl.contains(_lang) ? TextDirection.rtl : TextDirection.ltr;
  double drawLine(String text, double top, double size, Color color) {
    TextPainter tp(double s, Paint? fg) => TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontFamily: 'Noto Sans',
              fontFamilyFallback: D.fontFallback,
              fontSize: s,
              fontWeight: FontWeight.w900,
              height: 1.15,
              foreground: fg,
              color: fg == null ? color : null,
            ),
          ),
          textDirection: dir,
          textAlign: TextAlign.center,
          maxLines: 1,
        )..layout();
    var s = size;
    while (s > size * .45 && tp(s, null).width > w - margin * 2) {
      s -= size * .03;
    }
    final stroke = tp(
        s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .16
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF0A071A));
    final fill = tp(s, null);
    final at = Offset((w - fill.width) / 2, top);
    stroke.paint(c, at + Offset(0, s * .05));
    fill.paint(c, at);
    return top + fill.height;
  }

  final s1 = ipad ? w * .068 : w * .092;
  var y = h * (ipad ? .055 : .062);
  y = drawLine(lines[0], y, s1, Colors.white);
  y = drawLine(lines[1], y + s1 * .1, s1 * 1.18, accent);
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(w / 2, y + s1 * .45), width: w * .16, height: s1 * .1), Radius.circular(s1)),
      Paint()..color = accent);

  // device
  final top = y + s1 * 1.05;
  final bottom = h - h * .035;
  final devH = bottom - top;
  final devW = devH * w / h;
  final dev = Rect.fromLTWH((w - devW) / 2, top, devW, devH);
  final bezel = devW * (ipad ? .028 : .03);
  final r = devW * (ipad ? .055 : .13);
  c.drawRRect(RRect.fromRectAndRadius(dev.shift(Offset(0, devW * .03)), Radius.circular(r)),
      Paint()
        ..color = const Color(0xB0000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, devW * .04));
  c.drawRRect(RRect.fromRectAndRadius(dev, Radius.circular(r)), Paint()..color = const Color(0xFF09071A));
  c.drawRRect(
      RRect.fromRectAndRadius(dev.deflate(devW * .004), Radius.circular(r)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = devW * .006
        ..color = const Color(0xFFC7B4FF));
  final scr = dev.deflate(bezel);
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(scr, Radius.circular(r - bezel)));
  c.drawImageRect(screen, Offset.zero & Size(screen.width.toDouble(), screen.height.toDouble()), scr,
      Paint()..filterQuality = FilterQuality.high);
  c.restore();
  if (!ipad) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(w / 2, scr.top + scr.width * .045), width: scr.width * .27, height: scr.width * .075),
            Radius.circular(scr.width)),
        Paint()..color = Colors.black);
  }
  return rec.endRecording().toImage(w.round(), h.round());
}
