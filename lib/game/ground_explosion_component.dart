import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GroundExplosionComponent extends PositionComponent with HasGameRef {
  double _elapsed = 0;
  static const double _duration  = 2.0;
  static const double _baseSize  = 560.0;
  static const double _ringMax   = 220.0;
  static const double _flashMax  = 100.0;
  static const double _smokeBase = 110.0;
  static const double _smokeGrow = 200.0;

  final Random _random = Random();
  late final List<_FireParticle> _fireParticles;
  late final List<_Shard>        _shards;

  GroundExplosionComponent({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(_baseSize),
          anchor: Anchor.center,
        );

  @override
  void onLoad() {
    _fireParticles = List.generate(70, (_) => _FireParticle(_random));
    // 28 shards — big visible chunks flying sideways
    _shards = List.generate(28, (i) => _Shard(_random, i));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) removeFromParent();
    for (final p in _fireParticles) p.update(dt);
    for (final s in _shards)        s.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _duration).clamp(0.0, 1.0);
    final cx = size.x / 2;
    final cy = size.y / 2;

    // ── Ground shockwave rings (flat ellipses) ──
    final ringOp = (1.0 - progress).clamp(0.0, 1.0);
    final shockW = _ringMax * 2.4 * progress;
    final shockH = _ringMax * 0.40 * progress;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: shockW, height: shockH),
      Paint()
        ..color = Colors.orangeAccent.withOpacity(ringOp * 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14 * (1 - progress),
    );
    if (progress > 0.10) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy),
          width: _ringMax * 2.8 * (progress - 0.10),
          height: _ringMax * 0.32 * (progress - 0.10)),
        Paint()
          ..color = Colors.orange.withOpacity(ringOp * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * (1 - progress),
      );
    }

    // ── Ground scorch mark ──
    if (progress > 0.05) {
      final scorchR = _ringMax * 0.6 * progress.clamp(0, 0.5) / 0.5;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy),
            width: scorchR * 2.2, height: scorchR * 0.5),
        Paint()..color = const Color(0xFF1a0a00).withOpacity(0.55 * (1 - progress * 0.5)),
      );
    }

    // ── Initial flash ──
    if (progress < 0.30) {
      final flashOp = (1 - progress / 0.30).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(cx, cy), _flashMax * 2.2 * (1 - progress),
        Paint()
          ..color = Colors.yellow.withOpacity(flashOp * 0.60)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28));
      canvas.drawCircle(Offset(cx, cy), _flashMax * (1 - progress),
        Paint()
          ..color = Colors.white.withOpacity(flashOp * 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    }

    // ── Fire particles ──
    for (final p in _fireParticles) {
      final alpha = (p.life * (1 - progress)).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;
      canvas.drawCircle(
        Offset(cx + p.x, cy + p.y),
        p.radius * (1 - progress * 0.35),
        Paint()
          ..color = Color.lerp(Colors.yellow, Colors.deepOrange, p.colorT)!
              .withOpacity(alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // ── Shards — drawn large and bright ──
    for (final s in _shards) {
      if (s.life <= 0.01) continue;
      // Shards stay visible longer than fire
      final alpha = (s.life * pow(1 - progress, 0.5)).clamp(0.0, 1.0).toDouble();
      if (alpha <= 0.01) continue;

      canvas.save();
      canvas.translate(cx + s.x, cy + s.y);
      canvas.rotate(s.rotation);

      // Shard color: hot orange → dark grey as it cools
      final coolT  = (s.age / s.maxAge).clamp(0.0, 1.0);
      final shardColor = Color.lerp(
        const Color(0xFFff8800), const Color(0xFF444444), coolT)!.withOpacity(alpha);

      // Main shard body — bigger and more angular
      final path = Path()
        ..moveTo(0, -s.length * 0.55)
        ..lineTo(s.width * 0.55, -s.length * 0.1)
        ..lineTo(s.width * 0.4, s.length * 0.55)
        ..lineTo(0, s.length * 0.35)
        ..lineTo(-s.width * 0.4, s.length * 0.55)
        ..lineTo(-s.width * 0.55, -s.length * 0.1)
        ..close();

      canvas.drawPath(path, Paint()..color = shardColor);

      // Hot glow around fresh shards
      if (coolT < 0.5) {
        canvas.drawPath(path, Paint()
          ..color = Colors.orangeAccent.withOpacity(alpha * (1 - coolT * 2) * 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.8));
      }

      // White glint edge on very fresh shards
      if (coolT < 0.25) {
        canvas.drawPath(path, Paint()
          ..color = Colors.white.withOpacity(alpha * (1 - coolT * 4) * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
      }

      canvas.restore();
    }

    // ── Rising smoke column ──
    if (progress > 0.18) {
      final smokeT  = ((progress - 0.18) / 0.82).clamp(0.0, 1.0);
      final smokeOp = (smokeT * (1 - smokeT) * 3.0).clamp(0.0, 0.75);
      final smokeR  = _smokeBase + _smokeGrow * smokeT;
      canvas.drawCircle(
        Offset(cx, cy - smokeR * 0.65),
        smokeR * 0.72,
        Paint()
          ..color = Colors.grey.shade600.withOpacity(smokeOp)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
      canvas.drawCircle(
        Offset(cx + smokeR * 0.18, cy - smokeR * 0.42),
        smokeR * 0.52,
        Paint()
          ..color = Colors.grey.shade800.withOpacity(smokeOp * 0.75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }
  }
}

class _FireParticle {
  final double angle;
  final double speed;
  final double radius;
  final double colorT;
  double x = 0, y = 0;
  double life = 1.0;

  _FireParticle(Random r)
      : angle  = (r.nextDouble() - 0.5) * pi * 1.6 - pi / 2,
        speed  = 60 + r.nextDouble() * 150,
        radius = 8 + r.nextDouble() * 22,
        colorT = r.nextDouble();

  void update(double dt) {
    x += cos(angle) * speed * dt;
    y += sin(angle) * speed * dt + 25 * dt;
    life = (life - dt * 0.75).clamp(0.0, 1.0);
  }
}

class _Shard {
  final double angle;
  double speed;          // mutable for air resistance
  final double length;
  final double width;
  double rotation;
  final double rotSpeed;
  final double maxAge;
  double age = 0;
  double x = 0, y = 0;
  double life = 1.0;

  _Shard(Random r, int index)
      : angle    = _shardAngle(r, index),
        speed    = 100 + r.nextDouble() * 240,
        length   = 14 + r.nextDouble() * 26,  // bigger shards
        width    = 6  + r.nextDouble() * 10,
        rotation = r.nextDouble() * 2 * pi,
        rotSpeed = (r.nextDouble() - 0.5) * 18,
        maxAge   = 0.8 + r.nextDouble() * 0.8;

  static double _shardAngle(Random r, int index) {
    // Spread across 4 quadrants but bias sideways-upward
    final sector = index % 4;
    switch (sector) {
      case 0: return -pi + r.nextDouble() * (pi * 0.6);         // hard left
      case 1: return -pi * 0.4 + r.nextDouble() * (pi * 0.4);  // upper-left arc
      case 2: return pi * 0.0 + r.nextDouble() * (pi * 0.4);   // upper-right arc
      default: return pi * 0.4 + r.nextDouble() * (pi * 0.6);  // hard right
    }
  }

  void update(double dt) {
    age += dt;
    x += cos(angle) * speed * dt;
    y += sin(angle) * speed * dt + 80 * dt * (age / maxAge);
    rotation += rotSpeed * dt;
    speed *= (1.0 - dt * 1.8);                // air resistance
    life = (1.0 - age / maxAge).clamp(0.0, 1.0);
  }
}
