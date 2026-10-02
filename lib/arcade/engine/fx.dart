import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'draw.dart';

enum PartShape { circle, square, star, spark, coin, confetti, heart, smoke, ring }

class Particle {
  Particle({
    required this.pos,
    required this.vel,
    required this.life,
    required this.color,
    this.size = 6,
    this.shape = PartShape.circle,
    this.gravity = 0,
    this.drag = 0,
    this.spin = 0,
    this.grow = 0,
  }) : maxLife = life;

  Offset pos;
  Offset vel;
  double life;
  final double maxLife;
  Color color;
  double size;
  PartShape shape;
  double gravity;
  double drag;
  double spin;
  double angle = 0;
  double grow;

  double get t => 1 - (life / maxLife).clamp(0.0, 1.0);
}

class FloatText {
  FloatText(this.text, this.pos, this.color, this.size, this.life, this.rise, {this.direction}) : maxLife = life;
  final String text;
  Offset pos;
  final Color color;
  final double size;
  double life;
  final double maxLife;
  final double rise;
  final TextDirection? direction;
}

/// Particle + floating text system. The host updates and renders it on top
/// of the game automatically; games only spawn effects.
class Fx {
  Fx(this._rng);

  final math.Random _rng;
  final List<Particle> parts = [];
  final List<FloatText> texts = [];

  double _r(double a, double b) => a + _rng.nextDouble() * (b - a);

  void add(Particle p) {
    if (parts.length < 1400) parts.add(p);
  }

  /// Radial burst of particles.
  void burst(Offset at, Color color,
      {int count = 16, double speed = 220, double size = 6, PartShape shape = PartShape.circle, double life = .6,
      double gravity = 300, List<Color>? colors}) {
    for (var i = 0; i < count; i++) {
      final a = _r(0, math.pi * 2);
      final s = _r(speed * .35, speed);
      add(Particle(
        pos: at,
        vel: Offset(math.cos(a) * s, math.sin(a) * s),
        life: _r(life * .6, life),
        color: colors == null ? color : colors[_rng.nextInt(colors.length)],
        size: _r(size * .6, size * 1.3),
        shape: shape,
        gravity: gravity,
        drag: 1.5,
        spin: _r(-10, 10),
      ));
    }
  }

  /// Confetti shower from the top of the screen (or from [at]).
  void confetti({Offset? at, int count = 70}) {
    for (var i = 0; i < count; i++) {
      final o = at ?? Offset(_r(0, 360), _r(-40, -5));
      add(Particle(
        pos: o,
        vel: at == null ? Offset(_r(-60, 60), _r(40, 220)) : Offset(_r(-260, 260), _r(-520, -150)),
        life: _r(1.4, 2.4),
        color: Pal.candy[_rng.nextInt(Pal.candy.length)],
        size: _r(5, 10),
        shape: PartShape.confetti,
        gravity: 260,
        drag: .8,
        spin: _r(-14, 14),
      ));
    }
  }

  /// Coins fountain (use for rewards).
  void coins(Offset at, {int count = 14, double speed = 360}) {
    for (var i = 0; i < count; i++) {
      final a = _r(-math.pi * .85, -math.pi * .15);
      final s = _r(speed * .5, speed);
      add(Particle(
        pos: at,
        vel: Offset(math.cos(a) * s, math.sin(a) * s),
        life: _r(.8, 1.3),
        color: Pal.gold,
        size: _r(7, 10),
        shape: PartShape.coin,
        gravity: 900,
        drag: .3,
        spin: _r(2, 6),
      ));
    }
  }

  /// Expanding ring shockwave.
  void ring(Offset at, Color color, {double size = 60, double life = .4}) {
    add(Particle(pos: at, vel: Offset.zero, life: life, color: color, size: 6, shape: PartShape.ring, grow: size / life));
  }

  /// Rising smoke puffs.
  void smoke(Offset at, {int count = 6, Color color = const Color(0xCCDDDDDD), double size = 14}) {
    for (var i = 0; i < count; i++) {
      add(Particle(
        pos: at + Offset(_r(-8, 8), _r(-4, 4)),
        vel: Offset(_r(-30, 30), _r(-70, -20)),
        life: _r(.5, 1.0),
        color: color,
        size: _r(size * .6, size),
        shape: PartShape.smoke,
        drag: 1,
        grow: size * 1.5,
      ));
    }
  }

  /// Twinkling sparkles around a point.
  void sparkle(Offset at, {int count = 8, double radius = 30, Color color = Pal.white}) {
    for (var i = 0; i < count; i++) {
      add(Particle(
        pos: at + Offset(_r(-radius, radius), _r(-radius, radius)),
        vel: Offset(0, _r(-30, -5)),
        life: _r(.35, .8),
        color: color,
        size: _r(5, 11),
        shape: PartShape.spark,
      ));
    }
  }

  /// Floating score / word popup ("+10", "PERFECT!").
  void pop(String text, Offset at, {Color color = Pal.yellow, double size = 26, double life = .8, double rise = 60, TextDirection? direction}) {
    if (texts.length < 40) texts.add(FloatText(text, at, color, size, life, rise, direction: direction));
  }

  void clear() {
    parts.clear();
    texts.clear();
  }

  void update(double dt) {
    for (var i = parts.length - 1; i >= 0; i--) {
      final p = parts[i];
      p.life -= dt;
      if (p.life <= 0) {
        parts.removeAt(i);
        continue;
      }
      p.vel = Offset(p.vel.dx, p.vel.dy + p.gravity * dt) * (1 - (p.drag * dt).clamp(0, .9));
      p.pos += p.vel * dt;
      p.angle += p.spin * dt;
      p.size += p.grow * dt;
    }
    for (var i = texts.length - 1; i >= 0; i--) {
      final t = texts[i];
      t.life -= dt;
      if (t.life <= 0) {
        texts.removeAt(i);
        continue;
      }
      t.pos = t.pos.translate(0, -t.rise * dt / t.maxLife);
    }
  }

  void render(Canvas c) {
    final paint = Paint();
    for (final p in parts) {
      final fade = p.shape == PartShape.confetti || p.shape == PartShape.coin
          ? (p.life / .3).clamp(0.0, 1.0)
          : (p.life / p.maxLife).clamp(0.0, 1.0);
      paint
        ..color = p.color.withValues(alpha: p.color.a * fade)
        ..style = PaintingStyle.fill
        ..strokeWidth = 0;
      switch (p.shape) {
        case PartShape.circle:
          c.drawCircle(p.pos, p.size / 2, paint);
        case PartShape.square:
          c.save();
          c.translate(p.pos.dx, p.pos.dy);
          c.rotate(p.angle);
          c.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size), paint);
          c.restore();
        case PartShape.confetti:
          c.save();
          c.translate(p.pos.dx, p.pos.dy);
          c.rotate(p.angle);
          c.scale(math.cos(p.angle * 1.7), 1);
          c.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * .55), paint);
          c.restore();
        case PartShape.star:
          c.drawPath(D.starPath(p.pos, p.size, p.size * .45, rotation: p.angle), paint);
        case PartShape.spark:
          final s = p.size * math.sin(p.t * math.pi);
          c.drawPath(D.starPath(p.pos, s, s * .22, points: 4, rotation: 0), paint);
        case PartShape.coin:
          D.coin(c, p.pos, p.size, spin: p.angle / 6);
        case PartShape.heart:
          D.heart(c, p.pos, p.size * 2, paint.color);
        case PartShape.smoke:
          c.drawCircle(p.pos, p.size / 2, paint);
        case PartShape.ring:
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 * fade + 1;
          c.drawCircle(p.pos, p.size, paint);
      }
    }
    for (final t in texts) {
      final age = 1 - t.life / t.maxLife;
      final scale = age < .15 ? .5 + age / .15 * .7 : (age < .3 ? 1.2 - (age - .15) / .15 * .2 : 1.0);
      final alpha = t.life < .2 ? t.life / .2 : 1.0;
      c.save();
      c.translate(t.pos.dx, t.pos.dy);
      c.scale(scale);
      if (alpha < 1) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      D.text(c, t.text, Offset.zero, size: t.size, color: t.color, stroke: Pal.ink, direction: t.direction);
      if (alpha < 1) c.restore();
      c.restore();
    }
  }
}
