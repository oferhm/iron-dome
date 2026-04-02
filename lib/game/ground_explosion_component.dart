import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GroundExplosionComponent extends PositionComponent with HasGameRef {
  double _elapsed = 0;
  static const double _duration = 0.85; // slightly longer for fire phase
  static const double _size     = 360.0;

  final Random _rng = Random();
  late final List<_Fire>  _fires;
  late final List<_Shard> _shards;

  GroundExplosionComponent({required Vector2 position})
      : super(position: position, size: Vector2.all(_size), anchor: Anchor.center);

  @override
  void onLoad() {
    _fires  = List.generate(8,  (_) => _Fire(_rng));
    _shards = List.generate(6, (i) => _Shard(_rng, i));
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
    final cx = size.x / 2;
    final cy = size.y / 2;

    // ── Flash — ONE blur ──
    if (prog < 0.20) {
      final op = (1 - prog / 0.20).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(cx, cy), 90 * (1 - prog),
        Paint()
          ..color = Colors.yellow.withOpacity(op * 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));
    }

    // ── Ground fire pool — stays at center for first 350ms ──
    // Simple overlapping circles, no blur, cheap
    if (_elapsed < 0.35) {
      final fireProgress = (_elapsed / 0.35).clamp(0.0, 1.0);
      final fireOp = (1 - fireProgress).clamp(0.0, 1.0);
      final flicker = sin(_elapsed * 40) * 0.15; // fast flicker
      // Outer orange pool
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: 120, height: 40),
        Paint()..color = const Color(0xFFff4400).withOpacity((fireOp * 0.7 + flicker).clamp(0,1)));
      // Inner yellow hot core
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: 70, height: 24),
        Paint()..color = const Color(0xFFffcc00).withOpacity((fireOp * 0.9 + flicker).clamp(0,1)));
      // White hot center
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: 30, height: 12),
        Paint()..color = Colors.white.withOpacity((fireOp * 0.95).clamp(0,1)));
    }

    // ── Scorch mark ──
    if (prog > 0.05) {
      final r = 70 * (prog.clamp(0.0, 0.5) / 0.5);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: r * 2.2, height: r * 0.45),
        Paint()..color = const Color(0xFF1a0800).withOpacity(0.55 * (1 - prog * 0.4)));
    }

    // ── Flying fire particles — upward ──
    for (final f in _fires) {
      final alpha = (f.life * (1 - prog)).clamp(0.0, 1.0);
      if (alpha < 0.02) continue;
      canvas.drawCircle(Offset(cx + f.x, cy + f.y), f.r * (1 - prog * 0.4),
        Paint()..color = Color.lerp(
            const Color(0xFFffee00), const Color(0xFFff3300), f.t)!
              .withOpacity(alpha * 0.85));
    }

    // ── Shards — LARGER, fly sideways/up ──
    for (final s in _shards) {
      if (s.life <= 0.01) continue;
      final alpha = (s.life * pow(1 - prog, 0.4)).clamp(0.0, 1.0).toDouble();
      if (alpha < 0.02) continue;
      canvas.save();
      canvas.translate(cx + s.x, cy + s.y);
      canvas.rotate(s.rot);
      final cool = (s.age / s.maxAge).clamp(0.0, 1.0);
      // Main shard body
      canvas.drawPath(
        Path()
          ..moveTo(0, -s.len * 0.6)..lineTo(s.wid * 0.5, 0)
          ..lineTo(0, s.len * 0.6)..lineTo(-s.wid * 0.5, 0)..close(),
        Paint()..color = Color.lerp(
            const Color(0xFFffaa00), const Color(0xFF555555), cool)!
              .withOpacity(alpha));
      // Hot glow edge (no blur — just a slightly wider brighter version)
      if (cool < 0.4) {
        canvas.drawPath(
          Path()
            ..moveTo(0, -s.len * 0.62)..lineTo(s.wid * 0.55, 0)
            ..lineTo(0, s.len * 0.62)..lineTo(-s.wid * 0.55, 0)..close(),
          Paint()
            ..color = const Color(0xFFffdd44).withOpacity(alpha * (1 - cool * 2.5) * 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      }
      canvas.restore();
    }

    // ── Smoke — ONE blur ──
    if (prog > 0.20) {
      final t  = ((prog - 0.20) / 0.80).clamp(0.0, 1.0);
      final op = (t * (1 - t) * 3.0).clamp(0.0, 0.55);
      final r  = 50 + 150 * t;
      canvas.drawCircle(Offset(cx, cy - r * 0.8), r * 0.6,
        Paint()
          ..color = Colors.grey.shade600.withOpacity(op)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    }
  }
}

class _Fire {
  final double angle, speed, r, t;
  double x = 0, y = 0, life = 1.0;
  _Fire(Random rng)
    : angle = -(pi * 0.11 + rng.nextDouble() * pi * 0.78),
      speed = 60 + rng.nextDouble() * 160,
      r     = 6 + rng.nextDouble() * 16,
      t     = rng.nextDouble();
  void update(double dt) {
    x += cos(angle) * speed * dt;
    y += sin(angle) * speed * dt + 25 * dt;
    life = (life - dt * 1.0).clamp(0.0, 1.0);
  }
}

class _Shard {
  final double angle, len, wid, rotSpeed, maxAge;
  double speed, rot, age = 0, x = 0, y = 0, life = 1.0;
  _Shard(Random r, int i)
    : angle    = _ang(i),            // deterministic angles
      speed    = i < 3 ? 620.0 : 580.0,
      len      = i < 3 ? 240.0 : 170.0,   // big: 140px, small: 70px
      wid      = i < 3 ? 36.0  : 18.0,   // big: 36px,  small: 18px
      rot      = _ang(i) + pi / 2,  // point along travel direction, no spin
      rotSpeed = 0.0,
      maxAge   = i < 3 ? 0.90 : 0.65;
  static double _ang(int i) {
    // 6 fixed angles spread across upper hemisphere
    const angles = [-2.4, -1.57, -0.75, -2.8, -1.2, -0.4];
    return angles[i % angles.length];
  }
  void update(double dt) {
    age += dt;
    x += cos(angle) * speed * dt;
    y += sin(angle) * speed * dt + 50 * dt * (age / maxAge);
    rot   += rotSpeed * dt;
    speed *= (1 - dt * 2.0);
    life   = (1 - age / maxAge).clamp(0.0, 1.0);
  }
}
