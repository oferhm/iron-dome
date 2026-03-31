import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GroundExplosionComponent extends PositionComponent with HasGameRef {
  double _elapsed = 0;
  static const double _duration = 2.2;
  static const double _size     = 420.0; // smaller radius

  final Random _rng = Random();
  late final List<_Fire>  _fires;
  late final List<_Shard> _shards;

  GroundExplosionComponent({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(_size),
          anchor: Anchor.center,
        );

  @override
  void onLoad() {
    _fires  = List.generate(90,  (_) => _Fire(_rng));   // more fire
    _shards = List.generate(70,  (i) => _Shard(_rng, i)); // more shards, upward/sideways
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) removeFromParent();
    for (final f in _fires)  f.update(dt);
    for (final s in _shards) s.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final prog = (_elapsed / _duration).clamp(0.0, 1.0);
    final cx   = size.x / 2;
    final cy   = size.y / 2;

    // ── Initial bright flash (no ring) ──
    if (prog < 0.25) {
      final op = (1 - prog / 0.25).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(cx, cy), 90 * (1 - prog),
        Paint()
          ..color = Colors.white.withOpacity(op * 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
      canvas.drawCircle(Offset(cx, cy), 130 * (1 - prog),
        Paint()
          ..color = Colors.yellow.withOpacity(op * 0.70)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    }

    // ── Ground scorch mark ──
    if (prog > 0.05) {
      final r = (80 * prog.clamp(0.0, 0.5) / 0.5);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: r * 2.0, height: r * 0.4),
        Paint()..color = const Color(0xFF1a0800).withOpacity(0.6 * (1 - prog * 0.6)));
    }

    // ── Fire particles (upward biased) ──
    for (final f in _fires) {
      final alpha = (f.life * (1 - prog)).clamp(0.0, 1.0);
      if (alpha < 0.01) continue;
      canvas.drawCircle(
        Offset(cx + f.x, cy + f.y),
        f.r * (1 - prog * 0.4),
        Paint()
          ..color = Color.lerp(
            const Color(0xFFffee00), const Color(0xFFff3300), f.t)!
              .withOpacity(alpha * 0.9)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, f.r * 0.5),
      );
    }

    // ── Shards — flying sideways and upward ──
    for (final s in _shards) {
      if (s.life <= 0.01) continue;
      final alpha = (s.life * pow(1 - prog, 0.4)).clamp(0.0, 1.0).toDouble();
      if (alpha < 0.01) continue;

      canvas.save();
      canvas.translate(cx + s.x, cy + s.y);
      canvas.rotate(s.rot);

      final cool  = (s.age / s.maxAge).clamp(0.0, 1.0);
      final color = Color.lerp(
          const Color(0xFFffaa00), const Color(0xFF555555), cool)!
            .withOpacity(alpha);

      // Elongated shard shape
      final path = Path()
        ..moveTo(0, -s.len * 0.6)
        ..lineTo(s.wid * 0.5, 0)
        ..lineTo(0, s.len * 0.6)
        ..lineTo(-s.wid * 0.5, 0)
        ..close();

      canvas.drawPath(path, Paint()..color = color);
      if (cool < 0.4) {
        canvas.drawPath(path, Paint()
          ..color = Colors.orangeAccent.withOpacity(alpha * (1 - cool * 2.5) * 0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.wid * 0.9));
      }
      canvas.restore();
    }

    // ── Rising smoke ──
    if (prog > 0.15) {
      final t  = ((prog - 0.15) / 0.85).clamp(0.0, 1.0);
      final op = (t * (1 - t) * 3.5).clamp(0.0, 0.70);
      final r  = 60 + 200 * t;
      canvas.drawCircle(Offset(cx, cy - r * 0.9), r * 0.65,
        Paint()
          ..color = Colors.grey.shade600.withOpacity(op)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    }
  }
}

class _Fire {
  final double angle, speed, r, t;
  double x = 0, y = 0, life = 1.0;

  _Fire(Random rng)
    // Upward bias: spread -160° to -20° (mostly upward cone)
    : angle = -(pi * 0.11 + rng.nextDouble() * pi * 0.78),
      speed = 70 + rng.nextDouble() * 180,
      r     = 7 + rng.nextDouble() * 20,
      t     = rng.nextDouble();

  void update(double dt) {
    x += cos(angle) * speed * dt;
    y += sin(angle) * speed * dt;
    // slight gravity pull downward
    y += 30 * dt;
    life = (life - dt * 0.8).clamp(0.0, 1.0);
  }
}

class _Shard {
  final double angle, len, wid, rotSpeed, maxAge;
  double speed, rot, age = 0, x = 0, y = 0, life = 1.0;

  _Shard(Random r, int i)
    : angle    = _angle(r, i),
      speed    = 160 + r.nextDouble() * 320,
      len      = 16 + r.nextDouble() * 30,
      wid      = 5  + r.nextDouble() * 10,
      rot      = r.nextDouble() * 2 * pi,
      rotSpeed = (r.nextDouble() - 0.5) * 22,
      maxAge   = 0.7 + r.nextDouble() * 0.9;

  // Shards fly sideways and upward — no downward shards
  static double _angle(Random r, int i) {
    // Distribute in upper 3 quadrants only (left/up/right), not downward
    final normalized = i / 70.0;
    if (normalized < 0.35) {
      // Left side: -175° to -95°
      return -(pi * 0.53 + r.nextDouble() * pi * 0.44);
    } else if (normalized < 0.65) {
      // Straight up with spread: -100° to -80°
      return -(pi * 0.44 + r.nextDouble() * pi * 0.11);
    } else {
      // Right side: -85° to -5°
      return -(r.nextDouble() * pi * 0.47);
    }
  }

  void update(double dt) {
    age += dt;
    x += cos(angle) * speed * dt;
    y += sin(angle) * speed * dt + 60 * dt * (age / maxAge); // gravity
    rot   += rotSpeed * dt;
    speed *= (1 - dt * 2.0); // air resistance
    life   = (1 - age / maxAge).clamp(0.0, 1.0);
  }
}
