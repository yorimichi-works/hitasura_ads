import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../arcade/engine/audio.dart';
import '../arcade/engine/sfx.dart';
import '../arcade/spec.dart';

/// Visual language of the shell: "late-night ad TV" — deep indigo night,
/// candy neon accents, sticker cards with thick ink outlines and hard
/// offset shadows, chunky pressable buttons.
abstract final class K {
  static const ink = Color(0xFF140E2A);
  static const night = Color(0xFF1B1140);
  static const night2 = Color(0xFF2A1462);
  static const paper = Color(0xFFFFF6E6);
  static const yellow = Color(0xFFFFD23F);
  static const pink = Color(0xFFFF4FA3);
  static const cyan = Color(0xFF2EE6F0);
  static const lime = Color(0xFFA6F03A);
  static const orange = Color(0xFFFF8A1F);
  static const red = Color(0xFFFF3B5C);
  static const purple = Color(0xFF8C4DFF);
  static const blue = Color(0xFF3D6BFF);

  static const font = 'KosugiMaru';

  static Color rarity(Rarity r) => switch (r) {
        Rarity.common => const Color(0xFF9FB4C8),
        Rarity.uncommon => const Color(0xFF3CD2A0),
        Rarity.rare => const Color(0xFF3FA2FF),
        Rarity.superRare => const Color(0xFFFFB020),
        Rarity.secret => const Color(0xFFFF4FA3),
      };

  static Color category(GameCat c) => switch (c) {
        GameCat.hyper => const Color(0xFFFF8A1F),
        GameCat.strategy => const Color(0xFF6F8CFF),
        GameCat.tycoon => const Color(0xFFFFC53D),
        GameCat.party => const Color(0xFFFF4FA3),
        GameCat.micro => const Color(0xFFFF3B5C),
        GameCat.retro => const Color(0xFF34D399),
        GameCat.threeD => const Color(0xFF2EE6F0),
        GameCat.gacha => const Color(0xFFB85CFF),
        GameCat.rpg => const Color(0xFFFF7A59),
        GameCat.puzzle => const Color(0xFF7BD35A),
        GameCat.sports => const Color(0xFF3FA2FF),
        GameCat.asmr => const Color(0xFFFF9ECF),
        GameCat.meta => const Color(0xFFFFE14D),
        GameCat.secret => const Color(0xFFFFFFFF),
      };

  static TextStyle t(double size, {Color color = Colors.white, FontWeight weight = FontWeight.w800, double? height}) =>
      TextStyle(fontFamily: font, fontSize: size, color: color, fontWeight: weight, height: height ?? 1.2);

  static void tap([String sound = Sfx.tap]) => ArcadeAudio.instance.sfx(sound, volume: .7);
}

/// Text with a thick outline (the "game title" look).
class InkText extends StatelessWidget {
  const InkText(this.text,
      {super.key,
      this.size = 24,
      this.color = Colors.white,
      this.stroke = K.ink,
      this.strokeWidth,
      this.align = TextAlign.center,
      this.maxLines,
      this.shadow = true});

  final String text;
  final double size;
  final Color color;
  final Color stroke;
  final double? strokeWidth;
  final TextAlign align;
  final int? maxLines;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final sw = strokeWidth ?? size * .2;
    TextStyle base(Paint? fg, Color? c) => TextStyle(
          fontFamily: K.font,
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: 1.15,
          color: fg == null ? c : null,
          foreground: fg,
        );
    Widget txt(TextStyle s) => Text(text, textAlign: align, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis, style: s);
    return Stack(children: [
      if (shadow)
        Transform.translate(
          offset: Offset(0, size * .1),
          child: txt(base(
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = sw * 1.2
                ..strokeJoin = StrokeJoin.round
                ..color = stroke,
              null)),
        ),
      txt(base(
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw
            ..strokeJoin = StrokeJoin.round
            ..color = stroke,
          null)),
      txt(base(null, color)),
    ]);
  }
}

/// Sticker card: ink border + hard offset shadow.
class Sticker extends StatelessWidget {
  const Sticker({
    super.key,
    required this.child,
    this.color = K.paper,
    this.radius = 20,
    this.padding = const EdgeInsets.all(14),
    this.shadow = 5,
    this.border = 3,
    this.gradient,
  });

  final Widget child;
  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double shadow;
  final double border;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: K.ink, width: border),
        boxShadow: [BoxShadow(color: K.ink, offset: Offset(0, shadow), blurRadius: 0)],
      ),
      child: child,
    );
  }
}

/// Big pressable 3D button with a sound and a squish.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.onTap,
    required this.child,
    this.color = K.yellow,
    this.height = 64,
    this.radius = 20,
    this.depth = 7,
    this.sound = Sfx.select,
    this.expand = true,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Color color;
  final double height;
  final double radius;
  final double depth;
  final String sound;
  final bool expand;
  final bool enabled;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    final color = enabled ? widget.color : const Color(0xFF6B6485);
    final dark = Color.lerp(color, K.ink, .5)!;
    final press = _down ? widget.depth - 2 : 0.0;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              K.tap(widget.sound);
              widget.onTap!();
            }
          : null,
      child: SizedBox(
        height: widget.height + widget.depth,
        width: widget.expand ? double.infinity : null,
        child: Stack(children: [
          Positioned.fill(
            top: widget.depth,
            child: Container(
              decoration: BoxDecoration(
                color: dark,
                borderRadius: BorderRadius.circular(widget.radius),
                border: Border.all(color: K.ink, width: 3),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 60),
            left: 0,
            right: 0,
            top: press,
            height: widget.height,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(color, Colors.white, .25)!, color],
                ),
                borderRadius: BorderRadius.circular(widget.radius),
                border: Border.all(color: K.ink, width: 3),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Stack(alignment: Alignment.center, children: [
                Positioned(
                  top: 4,
                  left: 6,
                  right: 6,
                  height: widget.height * .28,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .28),
                      borderRadius: BorderRadius.circular(widget.radius * .6),
                    ),
                  ),
                ),
                widget.child,
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Small pill label.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = K.yellow, this.textColor = K.ink, this.size = 12, this.icon});
  final String text;
  final Color color;
  final Color textColor;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: size * .7, vertical: size * .25),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: K.ink, width: 2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: size * 1.2, color: textColor), SizedBox(width: size * .3)],
          Text(text, style: K.t(size, color: textColor, weight: FontWeight.w900)),
        ]),
      );
}

/// Animated night-TV background: gradient, perspective grid, drifting
/// shapes and occasional sparkles. Pure paint; very cheap.
class NightBackground extends StatefulWidget {
  const NightBackground({super.key, this.child, this.hue = 0});
  final Widget? child;
  final double hue;

  @override
  State<NightBackground> createState() => _NightBackgroundState();
}

class _NightBackgroundState extends State<NightBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      RepaintBoundary(
        child: CustomPaint(painter: _BgPainter(_c, widget.hue)),
      ),
      if (widget.child != null) widget.child!,
    ]);
  }
}

class _BgPainter extends CustomPainter {
  _BgPainter(this.anim, this.hue) : super(repaint: anim);
  final Animation<double> anim;
  final double hue;

  @override
  void paint(Canvas c, Size s) {
    final t = anim.value * 60;
    final r = Offset.zero & s;
    Color h(double base, double sat, double v) => HSVColor.fromAHSV(1, (base + hue) % 360, sat, v).toColor();
    c.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [h(258, .75, .16), h(270, .7, .3), h(310, .65, .42)],
            stops: const [0, .6, 1],
          ).createShader(r));
    // glowing sun/moon
    final sun = Offset(s.width * .5, s.height * .62);
    c.drawCircle(
        sun,
        s.width * .55,
        Paint()
          ..shader = RadialGradient(colors: [h(330, .7, 1).withValues(alpha: .35), h(330, .7, 1).withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: sun, radius: s.width * .55)));
    // perspective grid floor
    final horizon = s.height * .62;
    final gp = Paint()
      ..color = h(190, .8, 1).withValues(alpha: .18)
      ..strokeWidth = 1.2;
    for (var i = -12; i <= 12; i++) {
      c.drawLine(Offset(s.width / 2 + i * 14, horizon), Offset(s.width / 2 + i * s.width * .22, s.height), gp);
    }
    for (var k = 0; k < 14; k++) {
      final z = ((k + (t * .6) % 1) / 14);
      final y = horizon + (s.height - horizon) * z * z;
      c.drawLine(Offset(0, y), Offset(s.width, y), gp..color = h(190, .8, 1).withValues(alpha: .05 + .2 * z));
    }
    // stars
    final sp = Paint()..color = Colors.white;
    for (var i = 0; i < 40; i++) {
      final x = (i * 97.3 % 1) * s.width + (i * 37 % s.width);
      final y = (i * 53.7) % (horizon * .95);
      final tw = .3 + .7 * (.5 + .5 * math.sin(t * 2 + i));
      sp.color = Colors.white.withValues(alpha: .15 + .45 * tw);
      c.drawCircle(Offset(x % s.width, y), 1 + (i % 3) * .5, sp);
    }
    // drifting shapes
    final shapes = [K.pink, K.cyan, K.yellow, K.lime, K.purple];
    for (var i = 0; i < 9; i++) {
      final col = shapes[i % shapes.length];
      final x = ((i * 0.137 + t * (0.004 + i * .0007)) % 1.2 - .1) * s.width;
      final y = s.height * (.08 + (i * .173) % .8) + math.sin(t * .7 + i) * 16;
      final rot = t * (.2 + i * .05);
      final p = Paint()
        ..color = col.withValues(alpha: .16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      c.save();
      c.translate(x, y);
      c.rotate(rot);
      final sz = 10.0 + (i % 4) * 6;
      switch (i % 4) {
        case 0:
          c.drawCircle(Offset.zero, sz, p);
        case 1:
          c.drawRect(Rect.fromCenter(center: Offset.zero, width: sz * 1.6, height: sz * 1.6), p);
        case 2:
          c.drawPath(
              Path()
                ..moveTo(0, -sz)
                ..lineTo(sz, sz * .8)
                ..lineTo(-sz, sz * .8)
                ..close(),
              p);
        default:
          c.drawLine(Offset(-sz, 0), Offset(sz, 0), p);
          c.drawLine(Offset(0, -sz), Offset(0, sz), p);
      }
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BgPainter old) => old.hue != hue;
}

/// Continuous gentle bob + scale pulse for call-to-action widgets.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, this.amount = .04, this.period = 1.1});
  final Widget child;
  final double amount;
  final double period;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: (widget.period * 1000).round()))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final s = 1 + widget.amount * math.sin(_c.value * math.pi * 2);
          return Transform.scale(scale: s, child: child);
        },
        child: widget.child,
      );
}

/// Rarity stars row.
class RarityBadge extends StatelessWidget {
  const RarityBadge(this.rarity, {super.key, this.label, this.size = 11});
  final Rarity rarity;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final col = K.rarity(rarity);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * .7, vertical: size * .2),
      decoration: BoxDecoration(
        gradient: rarity == Rarity.superRare || rarity == Rarity.secret
            ? const LinearGradient(colors: [Color(0xFFFF5F6D), Color(0xFFFFC371), Color(0xFF47E5BC), Color(0xFF7F7FD5)])
            : null,
        color: col,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: K.ink, width: 2),
      ),
      child: Text(label ?? '', style: K.t(size, color: K.ink, weight: FontWeight.w900)),
    );
  }
}
