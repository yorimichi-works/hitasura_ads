import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../arcade/engine/audio.dart';
import '../arcade/engine/draw.dart';
import '../arcade/engine/fx.dart';
import '../arcade/engine/sfx.dart';
import '../arcade/spec.dart';
import '../l10n/l10n.dart';
import 'kit.dart';
import 'thumbs.dart';

/// Gacha-style "NEW AD DISCOVERED!" capsule reveal. Resolves when dismissed.
Future<void> showDiscoveryReveal(BuildContext context, GameSpec spec, {String? headline}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, _, _) => _Reveal(spec: spec, headline: headline),
  );
}

class _Reveal extends StatefulWidget {
  const _Reveal({required this.spec, this.headline});
  final GameSpec spec;
  final String? headline;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  Duration _last = Duration.zero;
  bool _opened = false;
  double _openT = 0;
  int _shakes = 0;
  final _fx = Fx(math.Random());

  bool get _fancy => widget.spec.rarity == Rarity.superRare || widget.spec.rarity == Rarity.secret;
  int get _shakeCount => switch (widget.spec.rarity) {
        Rarity.common => 2,
        Rarity.uncommon => 3,
        Rarity.rare => 3,
        _ => 4,
      };

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((now) {
      final dt = _last == Duration.zero ? 1 / 60 : (now - _last).inMicroseconds / 1e6;
      _last = now;
      _t += dt;
      _fx.update(dt);
      if (!_opened) {
        final shakeIdx = ((_t - .5) / .42).floor();
        if (shakeIdx >= 0 && shakeIdx > _shakes - 1 && _shakes < _shakeCount) {
          _shakes++;
          ArcadeAudio.instance.sfx(Sfx.shake, rate: 1 + _shakes * .08);
          if (_shakes == _shakeCount && _fancy) ArcadeAudio.instance.sfx(Sfx.rarityUp);
        }
        if (_t > .5 + _shakeCount * .42 + .2) _open();
      } else {
        _openT += dt;
      }
      setState(() {});
    })
      ..start();
    ArcadeAudio.instance.sfx(Sfx.whoosh);
  }

  void _open() {
    if (_opened) return;
    _opened = true;
    _openT = 0;
    ArcadeAudio.instance.sfx(_fancy ? Sfx.ssr : Sfx.magic);
    ArcadeAudio.instance.sfx(Sfx.explodeSmall, volume: .6);
    _fx.confetti(at: const Offset(180, 300), count: _fancy ? 140 : 70);
    _fx.burst(const Offset(180, 300), Pal.yellow, count: 30, speed: 420, shape: PartShape.star, life: 1.1, gravity: 200);
    if (_fancy) _fx.coins(const Offset(180, 330), count: 30, speed: 520);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tap() {
    if (!_opened) {
      _open();
    } else if (_openT > .6) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final rc = K.rarity(spec.rarity);
    final text = L10n.game(spec.no);
    final cardT = Curves.elasticOut.transform((_openT / .9).clamp(0, 1));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(builder: (context, box) {
          final scale = math.min(box.maxWidth / 360, box.maxHeight / 640);
          return Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RevealPainter(this, rc, scale, Size(box.maxWidth, box.maxHeight)),
              ),
            ),
            if (_opened)
              Center(
                child: Transform.scale(
                  scale: .3 + .7 * cardT,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    InkText(widget.headline ?? L10n.ui('new_ad'), size: 28, color: K.yellow),
                    const SizedBox(height: 14),
                    Container(
                      width: 210,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: _fancy
                            ? SweepGradient(
                                colors: const [Color(0xFFFF5F6D), Color(0xFFFFC371), Color(0xFF47E5BC), Color(0xFF7F7FD5), Color(0xFFFF5F6D)],
                                transform: GradientRotation(_openT * 2))
                            : null,
                        color: rc,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: K.ink, width: 4),
                        boxShadow: [
                          const BoxShadow(color: K.ink, offset: Offset(0, 6)),
                          BoxShadow(color: rc.withValues(alpha: .6), blurRadius: 40, spreadRadius: 6),
                        ],
                      ),
                      child: Column(children: [
                        Row(children: [
                          Pill(spec.label, color: Colors.white, size: 11),
                          const Spacer(),
                          RarityBadge(spec.rarity, label: L10n.ui('rarity_${spec.rarity.name}'), size: 10),
                        ]),
                        const SizedBox(height: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14), border: Border.all(color: K.ink, width: 3)),
                          child: SizedBox(width: 150, child: GameThumb(spec: spec, unlocked: true, radius: 11)),
                        ),
                        const SizedBox(height: 8),
                        InkText(text.title, size: 20, maxLines: 2),
                        const SizedBox(height: 4),
                        Pill(L10n.ui('cat_${spec.cat.name}'), color: K.category(spec.cat), size: 10),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: _openT > .6 ? (.5 + .5 * math.sin(_openT * 5)).clamp(0, 1) : 0,
                      child: Text(L10n.ui('tap_continue'), style: K.t(14, color: Colors.white)),
                    ),
                  ]),
                ),
              ),
          ]);
        }),
      ),
    );
  }
}

class _RevealPainter extends CustomPainter {
  _RevealPainter(this.s, this.rc, this.scale, this.size);
  final _RevealState s;
  final Color rc;
  final double scale;
  final Size size;

  @override
  void paint(Canvas c, Size sz) {
    c.save();
    c.translate((sz.width - 360 * scale) / 2, (sz.height - 640 * scale) / 2);
    c.scale(scale);
    const center = Offset(180, 300);
    final t = s._t;
    if (!s._opened) {
      // background glow grows with each shake
      final g = s._shakes / s._shakeCount;
      c.drawCircle(center, 90 + g * 120,
          Paint()..color = rc.withValues(alpha: .12 + g * .25));
      final drop = Curves.bounceOut.transform((t / .5).clamp(0, 1));
      final y = -120 + (center.dy + 120) * drop;
      final phase = ((t - .5) % .42) / .42;
      final shaking = t > .5 && s._shakes <= s._shakeCount;
      final ang = shaking ? math.sin(phase * math.pi * 4) * .35 * (1 - phase) : 0.0;
      c.save();
      c.translate(180, y);
      c.rotate(ang);
      _capsule(c, 0, 70);
      c.restore();
      if (s._shakes == s._shakeCount && s._fancy) {
        D.rays(c, center, 400, const Color(0x33FFFFFF), count: 18, t: t * 3);
      }
    } else {
      final o = s._openT;
      final colors = s._fancy
          ? [const Color(0x66FF5F6D), const Color(0x66FFC371), const Color(0x6647E5BC), const Color(0x667F7FD5)]
          : [rc.withValues(alpha: .35)];
      for (var i = 0; i < colors.length; i++) {
        D.rays(c, center, 700, colors[i], count: 12, t: o * .6 + i * .2, width: .35);
      }
      // flash
      if (o < .25) c.drawRect(const Rect.fromLTWH(-400, -400, 1200, 1500), Paint()..color = Colors.white.withValues(alpha: 1 - o / .25));
      // capsule halves flying apart
      final k = (o * 1.6).clamp(0.0, 1.0);
      c.save();
      c.translate(180 - k * 140, 300 - k * 200);
      c.rotate(-k * 2);
      _half(c, true);
      c.restore();
      c.save();
      c.translate(180 + k * 140, 300 + k * 160);
      c.rotate(k * 2);
      _half(c, false);
      c.restore();
    }
    s._fx.render(c);
    c.restore();
  }

  void _capsule(Canvas c, double y, double r) {
    _half(c, true, r: r);
    _half(c, false, r: r);
    c.drawCircle(Offset(-r * .35, -r * .45), r * .18, Paint()..color = Colors.white.withValues(alpha: .7));
  }

  void _half(Canvas c, bool top, {double r = 70}) {
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    final p = Paint()..color = top ? (s._fancy ? K.pink : rc) : Colors.white;
    c.drawArc(rect, top ? math.pi : 0, math.pi, true, p);
    c.drawArc(rect, top ? math.pi : 0, math.pi, true, Paint()
      ..color = K.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6);
    c.drawRect(Rect.fromLTWH(-r, top ? -6 : 0, r * 2, 6), Paint()..color = K.ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
