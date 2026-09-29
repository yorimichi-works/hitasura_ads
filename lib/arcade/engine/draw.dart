import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Shared palette. Saturated, candy-like colors that read well on phones.
abstract final class Pal {
  static const red = Color(0xFFFF3B5C);
  static const orange = Color(0xFFFF8A1F);
  static const yellow = Color(0xFFFFD23F);
  static const lime = Color(0xFF9BE22D);
  static const green = Color(0xFF2ECC71);
  static const teal = Color(0xFF14C9C9);
  static const sky = Color(0xFF3FB8FF);
  static const blue = Color(0xFF3D6BFF);
  static const purple = Color(0xFF8C4DFF);
  static const pink = Color(0xFFFF5FC8);
  static const brown = Color(0xFF9A5B34);
  static const white = Color(0xFFFFFFFF);
  static const cream = Color(0xFFFFF4DC);
  static const ink = Color(0xFF1B1530);
  static const night = Color(0xFF0E0B1F);
  static const gray = Color(0xFF8E8AA3);
  static const gold = Color(0xFFFFC53D);
  static const skin = Color(0xFFFFD1A6);
  static const skinDark = Color(0xFFB9784F);

  static const candy = <Color>[red, orange, yellow, lime, teal, sky, purple, pink];
}

/// Facial expressions for [D.face] and [D.blob].
enum Face { happy, neutral, sad, angry, shocked, dead, love, sleepy, smug, cry }

/// Canvas drawing helpers shared by every mini-game.
///
/// All helpers draw in the 360x640 virtual game space; nothing here allocates
/// per frame except small Paint objects, and text layouts are cached.
abstract final class D {
  static final Paint _p = Paint()..isAntiAlias = true;

  static Paint fill(Color c) => Paint()..color = c;
  static Paint stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // ---------------------------------------------------------------- text ---

  /// Text direction used for localized strings (set by the app from L10n).
  static TextDirection textDirection = TextDirection.ltr;

  /// Primary font family and fallbacks for all game text.
  static String fontFamily = 'KosugiMaru';
  static const fontFallback = <String>[
    'Noto Sans JP',
    'Noto Sans KR',
    'Noto Sans SC',
    'Noto Sans TC',
    'Noto Sans Devanagari',
    'Noto Sans Bengali',
    'Noto Sans Arabic',
    'Noto Sans Thai',
    'Noto Sans',
  ];

  static final _textCache = <_TextKey, _TextEntry>{};

  /// Draws [text] anchored at [pos].
  ///
  /// [anchor] is the point inside the text box placed at [pos]:
  /// `Alignment.center` (default) centers it; `Alignment.topLeft` puts the
  /// top-left corner at [pos]. [stroke] adds a thick outline behind the fill
  /// (the chunky "mobile game" look). Returns the drawn size.
  static Size text(
    Canvas c,
    String text,
    Offset pos, {
    double size = 20,
    Color color = Pal.white,
    FontWeight weight = FontWeight.w900,
    Color? stroke,
    double strokeWidth = 0,
    Alignment anchor = Alignment.center,
    double? maxWidth,
    TextAlign align = TextAlign.center,
    Color? shadow,
    double letterSpacing = 0,
    bool italic = false,
    String? family,
  }) {
    if (text.isEmpty) return Size.zero;
    final sw = stroke == null ? 0.0 : (strokeWidth > 0 ? strokeWidth : size * .22);
    final key = _TextKey(text, size, color.toARGB32(), weight.value, stroke?.toARGB32() ?? 0,
        sw, maxWidth ?? -1, align.index, letterSpacing, italic, family ?? fontFamily,
        textDirection.index);
    var entry = _textCache.remove(key);
    if (entry == null) {
      TextPainter make(Paint? foreground, Color? col) {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: size,
              color: foreground == null ? col : null,
              foreground: foreground,
              fontWeight: weight,
              fontFamily: family ?? fontFamily,
              fontFamilyFallback: fontFallback,
              letterSpacing: letterSpacing,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              height: 1.1,
            ),
          ),
          textAlign: align,
          textDirection: textDirection,
        );
        tp.layout(maxWidth: maxWidth ?? double.infinity);
        return tp;
      }

      entry = _TextEntry(
        make(null, color),
        stroke == null
            ? null
            : make(
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = sw
                  ..strokeJoin = StrokeJoin.round
                  ..color = stroke,
                null),
      );
      if (_textCache.length > 600) _textCache.remove(_textCache.keys.first);
    }
    _textCache[key] = entry;
    final tp = entry.fill;
    final o = Offset(
      pos.dx - tp.width * (anchor.x + 1) / 2,
      pos.dy - tp.height * (anchor.y + 1) / 2,
    );
    if (shadow != null) {
      D.text(c, text, pos + Offset(0, size * .12),
          size: size, color: shadow, weight: weight, stroke: stroke == null ? null : shadow, strokeWidth: sw,
          anchor: anchor, maxWidth: maxWidth, align: align, letterSpacing: letterSpacing, italic: italic,
          family: family);
    }
    entry.stroke?.paint(c, o);
    tp.paint(c, o);
    return tp.size;
  }

  /// Big bouncy "cartoon" title text with outline and drop shadow.
  static void title(Canvas c, String s, Offset pos,
      {double size = 44, Color color = Pal.yellow, Color stroke = Pal.ink, double rotate = 0, double scale = 1}) {
    c.save();
    c.translate(pos.dx, pos.dy);
    if (rotate != 0) c.rotate(rotate);
    if (scale != 1) c.scale(scale);
    text(c, s, const Offset(0, 5), size: size, color: stroke, stroke: stroke, strokeWidth: size * .3);
    text(c, s, Offset.zero, size: size, color: color, stroke: stroke, strokeWidth: size * .26);
    c.restore();
  }

  // ---------------------------------------------------------- primitives ---

  static void rrect(Canvas c, Rect r, double radius, Color color,
      {Color? border, double borderWidth = 3, Gradient? gradient}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    _p
      ..style = PaintingStyle.fill
      ..color = color
      ..shader = gradient?.createShader(r);
    c.drawRRect(rr, _p);
    _p.shader = null;
    if (border != null) {
      c.drawRRect(rr, stroke(border, borderWidth));
    }
  }

  static void circle(Canvas c, Offset o, double r, Color color, {Color? border, double borderWidth = 3}) {
    _p
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = color;
    c.drawCircle(o, r, _p);
    if (border != null) c.drawCircle(o, r, stroke(border, borderWidth));
  }

  static void line(Canvas c, Offset a, Offset b, Color color, double width) {
    c.drawLine(a, b, stroke(color, width));
  }

  /// Soft elliptical ground shadow.
  static void shadow(Canvas c, Offset center, double w, double h, [double alpha = .25]) {
    c.drawOval(Rect.fromCenter(center: center, width: w, height: h),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
  }

  /// Full-screen vertical gradient.
  static void gradientBg(Canvas c, List<Color> colors, {Rect rect = const Rect.fromLTWH(0, 0, 360, 640)}) {
    c.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, colors,
              colors.length == 2 ? null : List.generate(colors.length, (i) => i / (colors.length - 1))));
  }

  /// Radial "sunburst" rays, rotating with [t]. Classic reward background.
  static void rays(Canvas c, Offset center, double radius, Color color,
      {int count = 12, double t = 0, double width = .5}) {
    final p = Paint()..color = color;
    final step = math.pi * 2 / count;
    for (var i = 0; i < count; i++) {
      final a = i * step + t;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + math.cos(a - step * width / 2) * radius, center.dy + math.sin(a - step * width / 2) * radius)
        ..lineTo(center.dx + math.cos(a + step * width / 2) * radius, center.dy + math.sin(a + step * width / 2) * radius)
        ..close();
      c.drawPath(path, p);
    }
  }

  static Path starPath(Offset c, double outer, double inner, {int points = 5, double rotation = -math.pi / 2}) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = rotation + i * math.pi / points;
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  static void star(Canvas c, Offset o, double r, Color color, {Color? border, double rotation = -math.pi / 2}) {
    final path = starPath(o, r, r * .48, rotation: rotation);
    c.drawPath(path, fill(color));
    if (border != null) c.drawPath(path, stroke(border, r * .14));
  }

  static void heart(Canvas c, Offset o, double size, Color color, {Color? border}) {
    final s = size / 2;
    final path = Path()
      ..moveTo(o.dx, o.dy + s * .9)
      ..cubicTo(o.dx - s * 1.6, o.dy - s * .2, o.dx - s * .7, o.dy - s * 1.3, o.dx, o.dy - s * .45)
      ..cubicTo(o.dx + s * .7, o.dy - s * 1.3, o.dx + s * 1.6, o.dy - s * .2, o.dx, o.dy + s * .9)
      ..close();
    c.drawPath(path, fill(color));
    if (border != null) c.drawPath(path, stroke(border, size * .08));
  }

  /// Shiny gold coin. [spin] 0..1 squashes horizontally to fake rotation.
  static void coin(Canvas c, Offset o, double r, {double spin = 0}) {
    final sx = math.cos(spin * math.pi * 2).abs().clamp(.15, 1.0);
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(sx, 1);
    c.drawCircle(Offset.zero, r, fill(const Color(0xFFB8860B)));
    c.drawCircle(const Offset(0, -1), r * .9, fill(Pal.gold));
    c.drawCircle(const Offset(0, -1), r * .62, stroke(const Color(0xFFE0A019), r * .14));
    c.drawRect(Rect.fromCenter(center: Offset(-r * .1, -r * .05), width: r * .22, height: r * .8), fill(const Color(0xFFFFF1A8)));
    c.drawCircle(Offset(-r * .45, -r * .45), r * .16, fill(const Color(0xCCFFFFFF)));
    c.restore();
  }

  /// Faceted gem.
  static void gem(Canvas c, Offset o, double r, Color color) {
    final top = Path()
      ..moveTo(o.dx - r, o.dy - r * .2)
      ..lineTo(o.dx - r * .55, o.dy - r * .75)
      ..lineTo(o.dx + r * .55, o.dy - r * .75)
      ..lineTo(o.dx + r, o.dy - r * .2)
      ..close();
    final bottom = Path()
      ..moveTo(o.dx - r, o.dy - r * .2)
      ..lineTo(o.dx + r, o.dy - r * .2)
      ..lineTo(o.dx, o.dy + r)
      ..close();
    c.drawPath(bottom, fill(color));
    c.drawPath(top, fill(Color.lerp(color, Pal.white, .45)!));
    c.drawPath(
        Path()
          ..moveTo(o.dx - r * .35, o.dy - r * .2)
          ..lineTo(o.dx, o.dy + r)
          ..lineTo(o.dx + r * .1, o.dy - r * .2)
          ..close(),
        fill(Color.lerp(color, Pal.white, .25)!));
    c.drawPath(top..addPath(bottom, Offset.zero), stroke(Color.lerp(color, Pal.ink, .5)!, r * .1));
  }

  /// A rounded, glossy "mobile game" button. Returns its rect for hit tests.
  static Rect button(Canvas c, Rect r, String label,
      {Color color = Pal.green, Color textColor = Pal.white, bool pressed = false, double fontSize = 20}) {
    final depth = pressed ? 2.0 : 6.0;
    final dark = Color.lerp(color, Pal.ink, .45)!;
    rrect(c, r.shift(const Offset(0, 6)), r.height * .32, dark);
    final face = r.shift(Offset(0, 6 - depth));
    rrect(c, face, r.height * .32, color, border: Pal.ink, borderWidth: 3);
    rrect(c, Rect.fromLTWH(face.left + 6, face.top + 4, face.width - 12, face.height * .36), face.height * .2,
        const Color(0x55FFFFFF));
    text(c, label, face.center, size: fontSize, color: textColor, stroke: Pal.ink, strokeWidth: fontSize * .22,
        maxWidth: face.width - 8);
    return r;
  }

  /// Progress bar with rounded ends. [t] in 0..1.
  static void bar(Canvas c, Rect r, double t, Color color, {Color back = const Color(0x66000000), Color? border}) {
    rrect(c, r, r.height / 2, back);
    final w = (r.width * t.clamp(0.0, 1.0));
    if (w > 0) {
      rrect(c, Rect.fromLTWH(r.left, r.top, math.max(w, r.height), r.height), r.height / 2, color);
      rrect(c, Rect.fromLTWH(r.left + 3, r.top + 2, math.max(w - 6, 1), r.height * .35), r.height / 4,
          const Color(0x44FFFFFF));
    }
    if (border != null) rrect(c, r, r.height / 2, const Color(0x00000000), border: border, borderWidth: 2.5);
  }

  // ----------------------------------------------------------- characters ---

  /// Draws eyes + mouth for a face centered at [o] with radius [r].
  /// [look] shifts pupils (-1..1 in each axis).
  static void face(Canvas c, Offset o, double r, Face f, {Offset look = Offset.zero, Color ink = Pal.ink, bool blush = true}) {
    final ex = r * .36, ey = -r * .12, er = r * .2;
    final inkP = fill(ink);
    final lineP = stroke(ink, r * .09);
    void eye(double sx) {
      final e = o + Offset(sx * ex, ey);
      switch (f) {
        case Face.dead:
          c.drawLine(e + Offset(-er, -er), e + Offset(er, er), lineP);
          c.drawLine(e + Offset(er, -er), e + Offset(-er, er), lineP);
        case Face.sleepy:
          c.drawArc(Rect.fromCenter(center: e, width: er * 2, height: er * 1.4), 0, math.pi, false, lineP);
        case Face.happy || Face.smug:
          c.drawArc(Rect.fromCenter(center: e + Offset(0, er * .3), width: er * 2, height: er * 2), math.pi, math.pi,
              false, lineP);
        case Face.love:
          heart(c, e, er * 2.2, Pal.red);
        default:
          c.drawOval(Rect.fromCenter(center: e, width: er * 1.7, height: er * 2.1), fill(Pal.white));
          final pr = f == Face.shocked ? er * .45 : er * .7;
          c.drawCircle(e + Offset(look.dx * er * .4, look.dy * er * .4), pr, inkP);
          c.drawCircle(e + Offset(look.dx * er * .4 - pr * .3, look.dy * er * .4 - pr * .35), pr * .35, fill(Pal.white));
      }
      if (f == Face.angry) {
        c.drawLine(e + Offset(-er * 1.1 * sx, -er * 1.5), e + Offset(er * 1.0 * sx, -er * .9), lineP);
      }
      if (f == Face.cry) {
        c.drawOval(Rect.fromCenter(center: e + Offset(sx * er * .2, er * 1.8), width: er * .8, height: er * 1.6),
            fill(const Color(0xCC6ECBFF)));
      }
    }

    eye(-1);
    eye(1);
    if (blush && f != Face.dead) {
      final bp = fill(const Color(0x55FF5F7A));
      c.drawOval(Rect.fromCenter(center: o + Offset(-r * .62, r * .18), width: r * .34, height: r * .18), bp);
      c.drawOval(Rect.fromCenter(center: o + Offset(r * .62, r * .18), width: r * .34, height: r * .18), bp);
    }
    final m = o + Offset(0, r * .32);
    switch (f) {
      case Face.happy || Face.love:
        final path = Path()
          ..moveTo(m.dx - r * .28, m.dy - r * .05)
          ..quadraticBezierTo(m.dx, m.dy + r * .42, m.dx + r * .28, m.dy - r * .05)
          ..close();
        c.drawPath(path, fill(const Color(0xFF8B1E3F)));
        c.drawPath(path, lineP);
      case Face.sad || Face.cry:
        c.drawArc(Rect.fromCenter(center: m + Offset(0, r * .15), width: r * .45, height: r * .3), math.pi, math.pi,
            false, lineP);
      case Face.shocked:
        c.drawOval(Rect.fromCenter(center: m + Offset(0, r * .05), width: r * .26, height: r * .34), inkP);
      case Face.angry:
        c.drawLine(m + Offset(-r * .2, r * .08), m + Offset(r * .2, r * .02), lineP);
      case Face.dead:
        c.drawLine(m + Offset(-r * .2, 0), m + Offset(r * .2, 0), lineP);
      case Face.smug:
        c.drawArc(Rect.fromCenter(center: m + Offset(r * .08, -r * .05), width: r * .4, height: r * .25), 0, math.pi,
            false, lineP);
      case Face.sleepy:
        c.drawOval(Rect.fromCenter(center: m + Offset(0, r * .05), width: r * .16, height: r * .12), inkP);
      case Face.neutral:
        c.drawLine(m + Offset(-r * .15, 0), m + Offset(r * .15, 0), lineP);
    }
  }

  /// Round mascot blob (slime / chick / generic character). [squash] > 1
  /// flattens vertically for bounces.
  static void blob(Canvas c, Offset o, double r, Color color,
      {Face face = Face.happy, Offset look = Offset.zero, double squash = 1, bool outline = true}) {
    c.save();
    c.translate(o.dx, o.dy + r * (squash - 1) * .5);
    c.scale(1 / math.sqrt(squash), squash == 1 ? 1 : 1 / squash);
    final body = Path()
      ..addRRect(RRect.fromRectAndCorners(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.9),
          topLeft: Radius.circular(r), topRight: Radius.circular(r), bottomLeft: Radius.circular(r * .8), bottomRight: Radius.circular(r * .8)));
    c.drawPath(body, fill(color));
    c.drawOval(Rect.fromCenter(center: Offset(-r * .35, -r * .5), width: r * .5, height: r * .3), fill(const Color(0x66FFFFFF)));
    if (outline) c.drawPath(body, stroke(Pal.ink, math.max(2, r * .09)));
    D.face(c, Offset(0, r * .05), r * .95, face, look: look);
    c.restore();
  }

  /// Simple articulated stick/bean person. [run] animates limbs (phase in radians).
  static void person(Canvas c, Offset feet, double height, Color shirt,
      {Color skin = Pal.skin, Color pants = const Color(0xFF34406B), double run = 0, bool running = false,
      Face face = Face.happy, Color? hair, bool flip = false, double armsUp = 0}) {
    final h = height;
    c.save();
    c.translate(feet.dx, feet.dy);
    if (flip) c.scale(-1, 1);
    final sw = running ? math.sin(run) * .7 : 0.0;
    final hip = Offset(0, -h * .38);
    final sh = Offset(0, -h * .66);
    // legs
    for (final s in [1.0, -1.0]) {
      final a = sw * s;
      c.drawLine(hip, hip + Offset(math.sin(a) * h * .38, math.cos(a) * h * .38), stroke(pants, h * .12));
    }
    // arms
    for (final s in [1.0, -1.0]) {
      final a = -sw * s + (armsUp * math.pi * .8) * s;
      c.drawLine(sh, sh + Offset(math.sin(a) * h * .3 * s.sign, math.cos(a) * h * .3 * (armsUp > .5 ? -1 : 1)),
          stroke(skin, h * .09));
    }
    // body
    rrect(c, Rect.fromCenter(center: Offset(0, -h * .52), width: h * .34, height: h * .36), h * .1, shirt,
        border: Pal.ink, borderWidth: h * .04);
    // head
    final head = Offset(0, -h * .82);
    c.drawCircle(head, h * .18, fill(skin));
    if (hair != null) {
      c.drawArc(Rect.fromCircle(center: head, radius: h * .19), math.pi, math.pi, true, fill(hair));
    }
    c.drawCircle(head, h * .18, stroke(Pal.ink, h * .035));
    D.face(c, head + Offset(0, h * .02), h * .15, face, blush: true);
    c.restore();
  }

  /// Fluffy cartoon cloud.
  static void cloud(Canvas c, Offset o, double s, {Color color = Pal.white}) {
    final p = fill(color);
    c.drawCircle(o + Offset(-s * .5, 0), s * .35, p);
    c.drawCircle(o + Offset(0, -s * .15), s * .45, p);
    c.drawCircle(o + Offset(s * .5, 0), s * .35, p);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o + Offset(0, s * .12), width: s * 1.6, height: s * .45),
        Radius.circular(s * .22)), p);
  }

  /// Stylized tree (round canopy).
  static void tree(Canvas c, Offset base, double h, {Color leaf = Pal.green}) {
    c.drawRect(Rect.fromCenter(center: base + Offset(0, -h * .2), width: h * .14, height: h * .4), fill(Pal.brown));
    c.drawCircle(base + Offset(0, -h * .62), h * .34, fill(leaf));
    c.drawCircle(base + Offset(-h * .18, -h * .5), h * .22, fill(Color.lerp(leaf, Pal.ink, .12)!));
    c.drawCircle(base + Offset(h * .1, -h * .75), h * .14, fill(Color.lerp(leaf, Pal.white, .25)!));
  }

  /// Flickering flame. [t] is time in seconds.
  static void flame(Canvas c, Offset base, double h, double t) {
    for (var i = 0; i < 3; i++) {
      final k = 1 - i * .3;
      final wob = math.sin(t * 18 + i * 2) * h * .06;
      final path = Path()
        ..moveTo(base.dx - h * .3 * k, base.dy)
        ..quadraticBezierTo(base.dx - h * .38 * k, base.dy - h * .5 * k, base.dx + wob, base.dy - h * k)
        ..quadraticBezierTo(base.dx + h * .38 * k, base.dy - h * .5 * k, base.dx + h * .3 * k, base.dy)
        ..close();
      c.drawPath(path, fill([Pal.red, Pal.orange, Pal.yellow][i]));
    }
  }

  /// A speech/icon bubble with a tail pointing down to [tail].
  static void bubble(Canvas c, Rect r, {Color color = Pal.white, Offset? tail}) {
    if (tail != null) {
      final path = Path()
        ..moveTo(r.center.dx - 8, r.bottom - 2)
        ..lineTo(tail.dx, tail.dy)
        ..lineTo(r.center.dx + 8, r.bottom - 2)
        ..close();
      c.drawPath(path, fill(color));
      c.drawPath(path, stroke(Pal.ink, 2.5));
    }
    rrect(c, r, 12, color, border: Pal.ink, borderWidth: 2.5);
    if (tail != null) {
      c.drawRect(Rect.fromCenter(center: Offset(r.center.dx, r.bottom - 2), width: 14, height: 5), fill(color));
    }
  }

  /// Arrow pointing along [dir] (unit-ish vector) centered at [o].
  static void arrow(Canvas c, Offset o, Offset dir, double len, Color color, {double width = 10}) {
    final d = dir / math.max(dir.distance, 1e-6);
    final n = Offset(-d.dy, d.dx);
    final tip = o + d * len / 2;
    final tail = o - d * len / 2;
    final head = tip - d * width * 1.6;
    final path = Path()
      ..moveTo(tail.dx + n.dx * width / 2, tail.dy + n.dy * width / 2)
      ..lineTo(head.dx + n.dx * width / 2, head.dy + n.dy * width / 2)
      ..lineTo(head.dx + n.dx * width * 1.3, head.dy + n.dy * width * 1.3)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(head.dx - n.dx * width * 1.3, head.dy - n.dy * width * 1.3)
      ..lineTo(head.dx - n.dx * width / 2, head.dy - n.dy * width / 2)
      ..lineTo(tail.dx - n.dx * width / 2, tail.dy - n.dy * width / 2)
      ..close();
    c.drawPath(path, fill(color));
    c.drawPath(path, stroke(Pal.ink, 2.5));
  }

  /// A pointing hand/finger hint ("tap here"), bobbing with [t].
  static void hand(Canvas c, Offset tip, double t, {double size = 44}) {
    final bob = math.sin(t * 8) * 6;
    c.save();
    c.translate(tip.dx + 6, tip.dy + 10 + bob);
    c.rotate(-.35);
    final s = size / 44;
    c.scale(s);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, 0, 12, 30), const Radius.circular(6)))
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, 20, 30, 26), const Radius.circular(10)));
    c.drawPath(path, fill(Pal.white));
    c.drawPath(path, stroke(Pal.ink, 3));
    c.restore();
  }

  static Color hsv(double h, double s, double v, [double a = 1]) =>
      HSVColor.fromAHSV(a, h % 360, s.clamp(0, 1), v.clamp(0, 1)).toColor();

  static Color withAlpha(Color c, double a) => c.withValues(alpha: a.clamp(0.0, 1.0));
}

class _TextKey {
  _TextKey(this.s, this.size, this.color, this.weight, this.stroke, this.sw, this.maxW, this.align, this.ls,
      this.italic, this.family, this.dir);
  final String s;
  final double size;
  final int color;
  final int weight;
  final int stroke;
  final double sw;
  final double maxW;
  final int align;
  final double ls;
  final bool italic;
  final String family;
  final int dir;

  @override
  bool operator ==(Object o) =>
      o is _TextKey &&
      o.s == s &&
      o.size == size &&
      o.color == color &&
      o.weight == weight &&
      o.stroke == stroke &&
      o.sw == sw &&
      o.maxW == maxW &&
      o.align == align &&
      o.ls == ls &&
      o.italic == italic &&
      o.family == family &&
      o.dir == dir;

  @override
  int get hashCode => Object.hash(s, size, color, weight, stroke, sw, maxW, align, ls, italic, family, dir);
}

class _TextEntry {
  _TextEntry(this.fill, this.stroke);
  final TextPainter fill;
  final TextPainter? stroke;
}
