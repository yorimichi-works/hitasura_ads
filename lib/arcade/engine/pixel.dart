import 'dart:ui';

/// Pixel-art sprite defined by rows of characters and a palette.
///
/// ```dart
/// static final hero = Sprite([
///   '..RRR...',
///   '.RRRRRR.',
///   '.SSKSK..',
/// ], {'R': Color(0xFFE03030), 'S': Color(0xFFFFC090), 'K': Color(0xFF000000)});
/// hero.draw(canvas, Offset(100, 200), scale: 4);
/// ```
/// `.` and ` ` are transparent. Paths are built once and cached, so drawing
/// is cheap even for hundreds of sprites per frame.
class Sprite {
  Sprite(List<String> rows, Map<String, Color> palette)
      : w = rows.fold(0, (m, r) => r.length > m ? r.length : m),
        h = rows.length {
    final byColor = <Color, Path>{};
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      var x = 0;
      while (x < row.length) {
        final ch = row[x];
        final col = palette[ch];
        if (col == null) {
          x++;
          continue;
        }
        var run = 1;
        while (x + run < row.length && row[x + run] == ch) {
          run++;
        }
        (byColor[col] ??= Path()).addRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), run.toDouble(), 1));
        x += run;
      }
    }
    _layers = byColor.entries.map((e) => (e.key, e.value)).toList(growable: false);
    _silhouette = Path();
    for (final l in _layers) {
      _silhouette.addPath(l.$2, Offset.zero);
    }
  }

  final int w;
  final int h;
  late final List<(Color, Path)> _layers;
  late final Path _silhouette;

  static final Paint _paint = Paint()..isAntiAlias = false;

  /// Draws with top-left at [pos]. [tint] replaces every color (hit flash).
  void draw(Canvas c, Offset pos, {double scale = 3, bool flipX = false, bool flipY = false, Color? tint, double opacity = 1}) {
    c.save();
    c.translate(pos.dx, pos.dy);
    c.scale(scale);
    if (flipX || flipY) {
      c.translate(flipX ? w.toDouble() : 0, flipY ? h.toDouble() : 0);
      c.scale(flipX ? -1 : 1, flipY ? -1 : 1);
    }
    if (tint != null) {
      _paint.color = tint.withValues(alpha: tint.a * opacity);
      c.drawPath(_silhouette, _paint);
    } else {
      for (final (col, path) in _layers) {
        _paint.color = opacity >= 1 ? col : col.withValues(alpha: col.a * opacity);
        c.drawPath(path, _paint);
      }
    }
    c.restore();
  }

  /// Draws centered on [center].
  void drawCentered(Canvas c, Offset center, {double scale = 3, bool flipX = false, Color? tint, double opacity = 1}) =>
      draw(c, center - Offset(w * scale / 2, h * scale / 2), scale: scale, flipX: flipX, tint: tint, opacity: opacity);
}

/// Classic 5x7 bitmap font for retro HUDs (A-Z, 0-9 and a few symbols).
/// Lowercase is drawn as uppercase. Unknown characters render as blanks.
abstract final class PixelFont {
  static const _glyphs = <String, List<String>>{
    'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
    'B': ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
    'C': ['01110', '10001', '10000', '10000', '10000', '10001', '01110'],
    'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
    'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
    'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
    'G': ['01110', '10001', '10000', '10111', '10001', '10001', '01111'],
    'H': ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
    'I': ['01110', '00100', '00100', '00100', '00100', '00100', '01110'],
    'J': ['00111', '00010', '00010', '00010', '00010', '10010', '01100'],
    'K': ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
    'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
    'M': ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
    'N': ['10001', '10001', '11001', '10101', '10011', '10001', '10001'],
    'O': ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
    'P': ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
    'Q': ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
    'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
    'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
    'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
    'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
    'V': ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
    'W': ['10001', '10001', '10001', '10101', '10101', '10101', '01010'],
    'X': ['10001', '10001', '01010', '00100', '01010', '10001', '10001'],
    'Y': ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
    'Z': ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
    '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
    '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
    '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
    '3': ['11111', '00010', '00100', '00010', '00001', '10001', '01110'],
    '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
    '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
    '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
    '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
    '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
    '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
    '!': ['00100', '00100', '00100', '00100', '00100', '00000', '00100'],
    '?': ['01110', '10001', '00001', '00010', '00100', '00000', '00100'],
    '.': ['00000', '00000', '00000', '00000', '00000', '01100', '01100'],
    ',': ['00000', '00000', '00000', '00000', '01100', '00100', '01000'],
    ':': ['00000', '01100', '01100', '00000', '01100', '01100', '00000'],
    '-': ['00000', '00000', '00000', '11111', '00000', '00000', '00000'],
    '+': ['00000', '00100', '00100', '11111', '00100', '00100', '00000'],
    'x': ['00000', '10001', '01010', '00100', '01010', '10001', '00000'],
    '/': ['00001', '00010', '00010', '00100', '01000', '01000', '10000'],
    '%': ['11001', '11010', '00010', '00100', '01000', '01011', '10011'],
    '\$': ['00100', '01111', '10100', '01110', '00101', '11110', '00100'],
    '*': ['00000', '10101', '01110', '11111', '01110', '10101', '00000'],
    '<': ['00010', '00100', '01000', '10000', '01000', '00100', '00010'],
    '>': ['01000', '00100', '00010', '00001', '00010', '00100', '01000'],
    '=': ['00000', '00000', '11111', '00000', '11111', '00000', '00000'],
    '#': ['01010', '01010', '11111', '01010', '11111', '01010', '01010'],
    '\'': ['00100', '00100', '01000', '00000', '00000', '00000', '00000'],
    '(': ['00010', '00100', '01000', '01000', '01000', '00100', '00010'],
    ')': ['01000', '00100', '00010', '00010', '00010', '00100', '01000'],
  };

  static final Map<String, Path> _paths = {
    for (final e in _glyphs.entries) e.key: _build(e.value),
  };

  static Path _build(List<String> rows) {
    final p = Path();
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        if (rows[y][x] == '1') p.addRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1));
      }
    }
    return p;
  }

  /// Width in virtual pixels of [s] at [scale].
  static double width(String s, double scale) => s.isEmpty ? 0 : (s.length * 6 - 1) * scale;

  /// Draws [s]. [align]: -1 left, 0 center, 1 right (relative to [pos].dx).
  /// [shadow] draws a 1-pixel drop shadow.
  static void draw(Canvas c, String s, Offset pos, double scale, Color color, {int align = -1, Color? shadow}) {
    final w = width(s, scale);
    final x0 = align < 0 ? pos.dx : (align == 0 ? pos.dx - w / 2 : pos.dx - w);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    final sp = shadow == null
        ? null
        : (Paint()
          ..color = shadow
          ..isAntiAlias = false);
    for (var i = 0; i < s.length; i++) {
      var ch = s[i];
      if (ch != 'x') ch = ch.toUpperCase();
      final path = _paths[ch];
      if (path == null) continue;
      c.save();
      c.translate(x0 + i * 6 * scale, pos.dy);
      c.scale(scale);
      if (sp != null) c.drawPath(path.shift(const Offset(1, 1)), sp);
      c.drawPath(path, paint);
      c.restore();
    }
  }
}

/// Retro screen helpers.
abstract final class Retro {
  /// CRT-style scanlines over [rect].
  static void scanlines(Canvas c, {Rect rect = const Rect.fromLTWH(0, 0, 360, 640), double alpha = .14, double gap = 3}) {
    final p = Paint()..color = Color.fromRGBO(0, 0, 0, alpha);
    for (var y = rect.top; y < rect.bottom; y += gap) {
      c.drawRect(Rect.fromLTWH(rect.left, y, rect.width, 1), p);
    }
  }

  /// Soft dark vignette corners.
  static void vignette(Canvas c, {double strength = .45}) {
    const r = Rect.fromLTWH(0, 0, 360, 640);
    c.drawRect(
        r,
        Paint()
          ..shader = Gradient.radial(
              r.center, 420, [const Color(0x00000000), Color.fromRGBO(0, 0, 0, strength)], [.55, 1]));
  }

  /// Draws a tile-map style checker/brick background of [cell] px.
  static void tiles(Canvas c, Rect r, double cell, Color a, Color b) {
    final pa = Paint()..color = a;
    final pb = Paint()..color = b;
    var row = 0;
    for (var y = r.top; y < r.bottom; y += cell, row++) {
      var col = 0;
      for (var x = r.left; x < r.right; x += cell, col++) {
        c.drawRect(Rect.fromLTWH(x, y, cell, cell), (row + col).isEven ? pa : pb);
      }
    }
  }
}
