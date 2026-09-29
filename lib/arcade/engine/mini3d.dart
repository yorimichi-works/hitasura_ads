import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Tiny flat-shaded 3D renderer for low-poly mini-games.
///
/// Coordinate system: +x right, +y up, +z forward (away from a camera with
/// yaw 0). Build [Mesh]es once, then every frame:
/// ```dart
/// scene.clear();
/// scene.cam.pos = V3(0, 6, -10);
/// scene.cam.lookAt(V3.zero);
/// scene.add(cube, pos: V3(0, 1, 0), rotY: t);
/// scene.render(canvas);
/// ```
/// Faces are depth-sorted (painter's algorithm) and drawn in one batched
/// `drawVertices` call per run, so ~3000 triangles per frame are fine.
class V3 {
  const V3(this.x, this.y, this.z);
  final double x, y, z;

  static const zero = V3(0, 0, 0);
  static const up = V3(0, 1, 0);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);
  V3 operator /(double s) => V3(x / s, y / s, z / s);
  V3 operator -() => V3(-x, -y, -z);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(x * x + y * y + z * z);
  V3 get normalized {
    final l = length;
    return l < 1e-9 ? this : this / l;
  }

  V3 lerp(V3 o, double t) => V3(x + (o.x - x) * t, y + (o.y - y) * t, z + (o.z - z) * t);
  V3 withY(double ny) => V3(x, ny, z);

  @override
  String toString() => 'V3(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

class Face3 {
  Face3(this.idx, this.color);
  final List<int> idx; // 3 or 4 vertex indices (convex polygon)
  Color color;
  late V3 normal;
}

class Mesh {
  Mesh(this.verts, this.faces, {bool fixWinding = false, this.doubleSided = false}) {
    _computeNormals(fixWinding);
  }

  final List<V3> verts;
  final List<Face3> faces;
  bool doubleSided;

  void _computeNormals(bool fix) {
    var centroid = V3.zero;
    for (final v in verts) {
      centroid += v;
    }
    centroid = verts.isEmpty ? V3.zero : centroid / verts.length.toDouble();
    for (final f in faces) {
      final a = verts[f.idx[0]], b = verts[f.idx[1]], c = verts[f.idx[2]];
      var n = (b - a).cross(c - a).normalized;
      if (fix) {
        var fc = V3.zero;
        for (final i in f.idx) {
          fc += verts[i];
        }
        fc = fc / f.idx.length.toDouble();
        if (n.dot(fc - centroid) < 0) {
          f.idx.setAll(0, f.idx.reversed.toList());
          n = -n;
        }
      }
      f.normal = n;
    }
  }

  /// Returns a copy with every face recolored.
  Mesh recolor(Color c) => Mesh(verts, [for (final f in faces) Face3(List.of(f.idx), c)], doubleSided: doubleSided);

  /// Merge several meshes (each placed at an offset, optional per-part scale).
  static Mesh merge(List<(Mesh, V3)> parts) {
    final v = <V3>[];
    final f = <Face3>[];
    for (final (m, off) in parts) {
      final base = v.length;
      v.addAll(m.verts.map((p) => p + off));
      for (final face in m.faces) {
        f.add(Face3([for (final i in face.idx) i + base], face.color)..normal = face.normal);
      }
    }
    final mesh = Mesh._raw(v, f);
    return mesh;
  }

  Mesh._raw(this.verts, this.faces) : doubleSided = false;

  /// Axis-aligned box centered at origin. [colors] optional per side:
  /// [top, bottom, front(-z), back(+z), left(-x), right(+x)].
  static Mesh box(double w, double h, double d, Color color, {List<Color>? colors}) {
    final x = w / 2, y = h / 2, z = d / 2;
    final v = [
      V3(-x, -y, -z), V3(x, -y, -z), V3(x, y, -z), V3(-x, y, -z), // front
      V3(-x, -y, z), V3(x, -y, z), V3(x, y, z), V3(-x, y, z), // back
    ];
    Color c(int i) => colors == null ? color : colors[i];
    return Mesh(v, [
      Face3([3, 2, 6, 7], c(0)), // top
      Face3([0, 4, 5, 1], c(1)), // bottom
      Face3([0, 1, 2, 3], c(2)), // front
      Face3([5, 4, 7, 6], c(3)), // back
      Face3([4, 0, 3, 7], c(4)), // left
      Face3([1, 5, 6, 2], c(5)), // right
    ], fixWinding: true);
  }

  /// Low-poly UV sphere.
  static Mesh sphere(double r, Color color, {int lat = 6, int lon = 10, Color? stripe}) {
    final v = <V3>[];
    for (var i = 0; i <= lat; i++) {
      final th = math.pi * i / lat;
      for (var j = 0; j < lon; j++) {
        final ph = math.pi * 2 * j / lon;
        v.add(V3(r * math.sin(th) * math.cos(ph), r * math.cos(th), r * math.sin(th) * math.sin(ph)));
      }
    }
    final f = <Face3>[];
    for (var i = 0; i < lat; i++) {
      for (var j = 0; j < lon; j++) {
        final a = i * lon + j, b = i * lon + (j + 1) % lon;
        final c = (i + 1) * lon + (j + 1) % lon, d = (i + 1) * lon + j;
        final col = stripe != null && i == lat ~/ 2 ? stripe : color;
        if (i == 0) {
          f.add(Face3([a, c, d], col));
        } else if (i == lat - 1) {
          f.add(Face3([a, b, d], col));
        } else {
          f.add(Face3([a, b, c, d], col));
        }
      }
    }
    return Mesh(v, f, fixWinding: true);
  }

  /// Cylinder along y, centered at origin.
  static Mesh cylinder(double r, double h, Color color, {int seg = 12, Color? cap, double? topRadius}) {
    final tr = topRadius ?? r;
    final v = <V3>[];
    for (var j = 0; j < seg; j++) {
      final a = math.pi * 2 * j / seg;
      v.add(V3(math.cos(a) * r, -h / 2, math.sin(a) * r));
      v.add(V3(math.cos(a) * tr, h / 2, math.sin(a) * tr));
    }
    final f = <Face3>[];
    for (var j = 0; j < seg; j++) {
      final n = (j + 1) % seg;
      f.add(Face3([j * 2, n * 2, n * 2 + 1, j * 2 + 1], color));
    }
    final capC = cap ?? color;
    // caps as fans around a center vertex
    final bottomC = v.length;
    v.add(V3(0, -h / 2, 0));
    final topC = v.length;
    v.add(V3(0, h / 2, 0));
    for (var j = 0; j < seg; j++) {
      final n = (j + 1) % seg;
      f.add(Face3([bottomC, n * 2, j * 2], capC));
      if (tr > 0.0001) f.add(Face3([topC, j * 2 + 1, n * 2 + 1], capC));
    }
    return Mesh(v, f, fixWinding: true);
  }

  /// Cone (point up) centered at origin.
  static Mesh cone(double r, double h, Color color, {int seg = 10}) {
    final v = <V3>[V3(0, h / 2, 0), V3(0, -h / 2, 0)];
    for (var j = 0; j < seg; j++) {
      final a = math.pi * 2 * j / seg;
      v.add(V3(math.cos(a) * r, -h / 2, math.sin(a) * r));
    }
    final f = <Face3>[];
    for (var j = 0; j < seg; j++) {
      final a = 2 + j, b = 2 + (j + 1) % seg;
      f.add(Face3([0, a, b], color));
      f.add(Face3([1, b, a], color));
    }
    return Mesh(v, f, fixWinding: true);
  }

  /// Square-based pyramid.
  static Mesh pyramid(double w, double h, Color color) => cone(w * .7071, h, color, seg: 4);

  /// Flat horizontal quad (double sided) centered at origin.
  static Mesh plane(double w, double d, Color color) => Mesh([
        V3(-w / 2, 0, -d / 2),
        V3(w / 2, 0, -d / 2),
        V3(w / 2, 0, d / 2),
        V3(-w / 2, 0, d / 2),
      ], [
        Face3([0, 3, 2, 1], color)
      ], doubleSided: true);

  /// Subdivided ground grid; [colorAt] picks each cell's color.
  /// Subdivision keeps large floors from being culled at the near plane.
  static Mesh grid(double w, double d, int nx, int nz, Color Function(int i, int j) colorAt) {
    final v = <V3>[];
    for (var j = 0; j <= nz; j++) {
      for (var i = 0; i <= nx; i++) {
        v.add(V3(-w / 2 + w * i / nx, 0, -d / 2 + d * j / nz));
      }
    }
    final f = <Face3>[];
    for (var j = 0; j < nz; j++) {
      for (var i = 0; i < nx; i++) {
        final a = j * (nx + 1) + i;
        f.add(Face3([a, a + nx + 1, a + nx + 2, a + 1], colorAt(i, j)));
      }
    }
    return Mesh(v, f, doubleSided: true);
  }

  /// Torus (ring) lying in the XY plane (hole facing the camera).
  static Mesh torus(double r, double tube, Color color, {int seg = 16, int side = 6}) {
    final v = <V3>[];
    for (var i = 0; i < seg; i++) {
      final a = math.pi * 2 * i / seg;
      for (var j = 0; j < side; j++) {
        final b = math.pi * 2 * j / side;
        final rr = r + math.cos(b) * tube;
        v.add(V3(math.cos(a) * rr, math.sin(a) * rr, math.sin(b) * tube));
      }
    }
    final f = <Face3>[];
    for (var i = 0; i < seg; i++) {
      for (var j = 0; j < side; j++) {
        final a = i * side + j;
        final b = ((i + 1) % seg) * side + j;
        final c = ((i + 1) % seg) * side + (j + 1) % side;
        final d = i * side + (j + 1) % side;
        f.add(Face3([a, b, c, d], color));
      }
    }
    // Winding: compute normals facing away from the tube center.
    final m = Mesh(v, f);
    for (var i = 0; i < seg; i++) {
      final a = math.pi * 2 * i / seg;
      final center = V3(math.cos(a) * r, math.sin(a) * r, 0);
      for (var j = 0; j < side; j++) {
        final face = m.faces[i * side + j];
        var fc = V3.zero;
        for (final k in face.idx) {
          fc += v[k];
        }
        fc = fc / 4;
        if (face.normal.dot(fc - center) < 0) {
          face.idx.setAll(0, face.idx.reversed.toList());
          face.normal = -face.normal;
        }
      }
    }
    return m;
  }
}

class Camera3 {
  V3 pos = const V3(0, 5, -10);
  double yaw = 0; // radians, 0 looks toward +z
  double pitch = 0; // radians, positive looks down
  double focal = 420; // pixels; larger = narrower FOV
  Offset center = const Offset(180, 320);
  double near = .15;

  void lookAt(V3 target) {
    final d = target - pos;
    yaw = math.atan2(d.x, d.z);
    pitch = math.atan2(-d.y, math.sqrt(d.x * d.x + d.z * d.z));
  }

  V3 get forward => V3(math.sin(yaw) * math.cos(pitch), -math.sin(pitch), math.cos(yaw) * math.cos(pitch));

  /// World → view space (x right, y up, z depth).
  V3 toView(V3 p) {
    final dx = p.x - pos.x, dy = p.y - pos.y, dz = p.z - pos.z;
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final x1 = dx * cy - dz * sy;
    final z1 = dx * sy + dz * cy;
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final y2 = dy * cp + z1 * sp;
    final z2 = -dy * sp + z1 * cp;
    return V3(x1, y2, z2);
  }

  /// Projects a world point to the screen. Returns null when behind camera.
  Offset? project(V3 p) {
    final v = toView(p);
    if (v.z < near) return null;
    return Offset(center.dx + v.x * focal / v.z, center.dy - v.y * focal / v.z);
  }

  /// Pixel scale at a world point (screen px per world unit), 0 if behind.
  double scaleAt(V3 p) {
    final v = toView(p);
    return v.z < near ? 0 : focal / v.z;
  }

  /// Casts a ray through screen point [s] and intersects the plane y=[planeY].
  V3? screenToGround(Offset s, [double planeY = 0]) {
    final vx = (s.dx - center.dx) / focal;
    final vy = -(s.dy - center.dy) / focal;
    // view dir (vx, vy, 1) → world: inverse pitch then inverse yaw
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final y1 = vy * cp - 1 * sp;
    final z1 = vy * sp + 1 * cp;
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final wx = vx * cy + z1 * sy;
    final wz = -vx * sy + z1 * cy;
    final dir = V3(wx, y1, wz);
    if (dir.y.abs() < 1e-6) return null;
    final t = (planeY - pos.y) / dir.y;
    if (t < 0) return null;
    return pos + dir * t;
  }
}

class _Poly {
  _Poly(this.depth, this.pts, this.color);
  final double depth;
  final List<double> pts; // x0,y0,x1,y1,...
  final Color color;
}

class _SpriteItem {
  _SpriteItem(this.depth, this.screen, this.scale, this.draw);
  final double depth;
  final Offset screen;
  final double scale;
  final void Function(Canvas c, Offset screen, double scale) draw;
}

class Scene3 {
  final Camera3 cam = Camera3();

  /// Direction pointing TOWARD the light.
  V3 light = const V3(-.4, 1, -.55).normalized;
  double ambient = .45;
  double diffuse = .65;
  Color? fogColor;
  double fogNear = 20;
  double fogFar = 60;

  final List<Object> _items = [];
  final List<double> _depths = [];

  void clear() {
    _items.clear();
    _depths.clear();
  }

  /// Adds a mesh instance. Rotation order: roll(z) → pitch(x) → yaw(y).
  /// [tint] multiplies face colors (e.g. flash white on hit via [flash] 0..1).
  void add(Mesh m,
      {V3 pos = V3.zero, double rotX = 0, double rotY = 0, double rotZ = 0, double scale = 1, V3? scale3,
      Color? tint, double flash = 0, double alpha = 1}) {
    final sx = scale3?.x ?? scale, sy = scale3?.y ?? scale, sz = scale3?.z ?? scale;
    final cx = math.cos(rotX), snx = math.sin(rotX);
    final cy = math.cos(rotY), sny = math.sin(rotY);
    final cz = math.cos(rotZ), snz = math.sin(rotZ);
    V3 rot(V3 p) {
      // z
      var x = p.x * cz - p.y * snz;
      var y = p.x * snz + p.y * cz;
      var z = p.z;
      // x
      final y2 = y * cx - z * snx;
      final z2 = y * snx + z * cx;
      y = y2;
      z = z2;
      // y
      final x3 = x * cy + z * sny;
      final z3 = -x * sny + z * cy;
      x = x3;
      z = z3;
      return V3(x, y, z);
    }

    final world = List<V3>.generate(m.verts.length, (i) {
      final v = m.verts[i];
      return rot(V3(v.x * sx, v.y * sy, v.z * sz)) + pos;
    }, growable: false);
    final view = List<V3>.generate(world.length, (i) => cam.toView(world[i]), growable: false);
    final camPos = cam.pos;
    for (final f in m.faces) {
      var n = rot(f.normal);
      // face center
      var cxw = 0.0, cyw = 0.0, czw = 0.0, depth = 0.0;
      var behind = false;
      for (final i in f.idx) {
        final w = world[i];
        cxw += w.x;
        cyw += w.y;
        czw += w.z;
        final vz = view[i].z;
        if (vz < cam.near) behind = true;
        depth += vz;
      }
      if (behind) continue;
      final inv = 1 / f.idx.length;
      final fc = V3(cxw * inv, cyw * inv, czw * inv);
      final toCam = camPos - fc;
      if (n.dot(toCam) <= 0) {
        if (!m.doubleSided) continue;
        n = -n;
      }
      depth *= inv;
      final lambert = math.max(0.0, n.dot(light));
      var k = ambient + diffuse * lambert;
      var base = f.color;
      if (tint != null) {
        base = Color.from(
            alpha: base.a, red: base.r * tint.r, green: base.g * tint.g, blue: base.b * tint.b);
      }
      var r = (base.r * k).clamp(0.0, 1.0);
      var g = (base.g * k).clamp(0.0, 1.0);
      var b = (base.b * k).clamp(0.0, 1.0);
      if (flash > 0) {
        r += (1 - r) * flash;
        g += (1 - g) * flash;
        b += (1 - b) * flash;
      }
      final fog = fogColor;
      if (fog != null) {
        final ft = ((depth - fogNear) / (fogFar - fogNear)).clamp(0.0, 1.0);
        r += (fog.r - r) * ft;
        g += (fog.g - g) * ft;
        b += (fog.b - b) * ft;
      }
      final pts = <double>[];
      for (final i in f.idx) {
        final v = view[i];
        pts
          ..add(cam.center.dx + v.x * cam.focal / v.z)
          ..add(cam.center.dy - v.y * cam.focal / v.z);
      }
      _items.add(_Poly(depth, pts, Color.from(alpha: base.a * alpha, red: r, green: g, blue: b)));
      _depths.add(depth);
    }
  }

  /// Adds a 2D sprite anchored at a 3D point, depth-sorted with the meshes.
  /// [draw] receives the projected screen point and pixels-per-world-unit.
  void addSprite(V3 p, void Function(Canvas c, Offset screen, double scale) draw) {
    final v = cam.toView(p);
    if (v.z < cam.near) return;
    final s = Offset(cam.center.dx + v.x * cam.focal / v.z, cam.center.dy - v.y * cam.focal / v.z);
    _items.add(_SpriteItem(v.z, s, cam.focal / v.z, draw));
    _depths.add(v.z);
  }

  int get itemCount => _items.length;

  void render(Canvas c) {
    final order = List<int>.generate(_items.length, (i) => i)..sort((a, b) => _depths[b].compareTo(_depths[a]));
    final pos = <double>[];
    final cols = <int>[];
    final paint = Paint();
    void flush() {
      if (pos.isEmpty) return;
      final v = Vertices.raw(VertexMode.triangles, Float32List.fromList(pos), colors: Int32List.fromList(cols));
      c.drawVertices(v, BlendMode.dst, paint);
      v.dispose();
      pos.clear();
      cols.clear();
    }

    for (final i in order) {
      final item = _items[i];
      if (item is _Poly) {
        final p = item.pts;
        final col = item.color.toARGB32();
        final n = p.length ~/ 2;
        for (var k = 1; k < n - 1; k++) {
          pos
            ..add(p[0])
            ..add(p[1])
            ..add(p[k * 2])
            ..add(p[k * 2 + 1])
            ..add(p[k * 2 + 2])
            ..add(p[k * 2 + 3]);
          cols
            ..add(col)
            ..add(col)
            ..add(col);
        }
      } else if (item is _SpriteItem) {
        flush();
        item.draw(c, item.screen, item.scale);
      }
    }
    flush();
  }
}

/// Handy prebuilt low-poly models.
abstract final class Models {
  /// Little person (body box + head box), feet at y=0, ~1.6 units tall.
  static Mesh person(Color shirt, {Color skin = const Color(0xFFFFD1A6), Color pants = const Color(0xFF34406B)}) =>
      Mesh.merge([
        (Mesh.box(.22, .7, .22, pants), const V3(-.14, .35, 0)),
        (Mesh.box(.22, .7, .22, pants), const V3(.14, .35, 0)),
        (Mesh.box(.6, .6, .34, shirt), const V3(0, 1.0, 0)),
        (Mesh.box(.42, .42, .42, skin), const V3(0, 1.55, 0)),
      ]);

  /// Low-poly car, ~2 x 1 x 4 units, wheels touching y=0, facing +z.
  static Mesh car(Color body, {Color glass = const Color(0xFF9AD8FF)}) => Mesh.merge([
        (Mesh.box(1.8, .6, 3.8, body), const V3(0, .6, 0)),
        (Mesh.box(1.5, .55, 1.9, glass), const V3(0, 1.17, -.2)),
        (Mesh.box(.35, .5, .5, const Color(0xFF222222)), const V3(-.85, .25, 1.2)),
        (Mesh.box(.35, .5, .5, const Color(0xFF222222)), const V3(.85, .25, 1.2)),
        (Mesh.box(.35, .5, .5, const Color(0xFF222222)), const V3(-.85, .25, -1.2)),
        (Mesh.box(.35, .5, .5, const Color(0xFF222222)), const V3(.85, .25, -1.2)),
      ]);

  /// Pine tree (trunk + two cones), base at y=0.
  static Mesh pine({Color leaf = const Color(0xFF2E9E57)}) => Mesh.merge([
        (Mesh.cylinder(.18, .8, const Color(0xFF8A5A3C), seg: 6), const V3(0, .4, 0)),
        (Mesh.cone(1.0, 1.6, leaf, seg: 7), const V3(0, 1.5, 0)),
        (Mesh.cone(.75, 1.2, leaf, seg: 7), const V3(0, 2.3, 0)),
      ]);

  /// Round tree, base at y=0.
  static Mesh roundTree({Color leaf = const Color(0xFF53C26B)}) => Mesh.merge([
        (Mesh.cylinder(.16, 1.0, const Color(0xFF8A5A3C), seg: 6), const V3(0, .5, 0)),
        (Mesh.sphere(.8, leaf, lat: 4, lon: 7), const V3(0, 1.5, 0)),
      ]);

  /// Simple house: box + pyramid roof, base at y=0.
  static Mesh house(Color wall, Color roof, {double w = 2, double h = 1.6, double d = 2}) => Mesh.merge([
        (Mesh.box(w, h, d, wall), V3(0, h / 2, 0)),
        (Mesh.cone(w * .8, h * .7, roof, seg: 4), V3(0, h + h * .35, 0)),
      ]);
}
