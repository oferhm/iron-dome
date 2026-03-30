import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ExplosionComponent extends PositionComponent with HasGameRef {
  double _elapsed = 0;
  static const double _duration = 1.1;

  // 2× bigger radius: component was 120, now 240
  static const double _baseSize   = 240.0;
  static const double _ringMax    = 120.0; // was 60
  static const double _flashMax   = 50.0;  // was 25
  static const double _smokeBase  = 60.0;  // was 30
  static const double _smokeGrow  = 100.0; // was 50

  final Random _random = Random();
  late final List<_Particle> _particles;

  ExplosionComponent({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(_baseSize),
          anchor: Anchor.center,
        );

  @override
  void onLoad() {
    // More particles for a bigger explosion
    _particles = List.generate(42, (_) => _Particle(_random));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) removeFromParent();
    for (final p in _particles) p.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _duration).clamp(0.0, 1.0);
    final center = size / 2;
    final cx = center.x;
    final cy = center.y;

    // ── Shockwave ring ──
    final ringRadius  = _ringMax * progress;
    final ringOpacity = (1.0 - progress).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(cx, cy), ringRadius,
      Paint()
        ..color = Colors.orangeAccent.withOpacity(ringOpacity * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * (1 - progress),
    );
    // Second outer ring, slightly delayed
    if (progress > 0.15) {
      final r2 = _ringMax * (progress - 0.15) * 1.3;
      canvas.drawCircle(
        Offset(cx, cy), r2,
        Paint()
          ..color = Colors.orange.withOpacity((ringOpacity * 0.3).clamp(0, 1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - progress),
      );
    }

    // ── Core flash ──
    if (progress < 0.30) {
      final flashOpacity = (1 - progress / 0.30).clamp(0.0, 1.0);
      // Outer glow
      canvas.drawCircle(
        Offset(cx, cy), _flashMax * 1.6 * (1 - progress),
        Paint()
          ..color = Colors.yellow.withOpacity(flashOpacity * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      // Bright white core
      canvas.drawCircle(
        Offset(cx, cy), _flashMax * (1 - progress),
        Paint()
          ..color = Colors.white.withOpacity(flashOpacity * 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // ── Fire particles ──
    for (final p in _particles) {
      final alpha = (p.life * (1 - progress)).clamp(0.0, 1.0);
      if (alpha <= 0) continue;
      final color = Color.lerp(Colors.yellow, Colors.deepOrange, p.colorT)!
          .withOpacity(alpha);
      canvas.drawCircle(
        Offset(cx + p.x, cy + p.y),
        p.radius * (1 - progress * 0.4),
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // ── Smoke ──
    if (progress > 0.25) {
      final smokeT   = (progress - 0.25) / 0.75;
      final smokeOp  = (smokeT * (1 - smokeT) * 2.5).clamp(0.0, 0.65);
      final smokeR   = _smokeBase + _smokeGrow * smokeT;
      canvas.drawCircle(
        Offset(cx, cy - smokeR * 0.25),
        smokeR * 0.65,
        Paint()
          ..color = Colors.grey.shade700.withOpacity(smokeOp)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      // Second smoke puff offset
      canvas.drawCircle(
        Offset(cx + smokeR * 0.2, cy - smokeR * 0.15),
        smokeR * 0.45,
        Paint()
          ..color = Colors.grey.shade800.withOpacity(smokeOp * 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double radius;
  final double colorT;
  double x;
  double y;
  double life = 1.0;

  _Particle(Random random)
      : angle  = random.nextDouble() * 2 * pi,
        // Faster spread for bigger explosion
        speed  = 40 + random.nextDouble() * 110,
        radius = 6 + random.nextDouble() * 18,
        colorT = random.nextDouble(),
        x = 0,
        y = 0;

  void update(double dt) {
    x += cos(angle) * speed * dt;
    y += sin(angle) * speed * dt;
    life = (life - dt * 1.2).clamp(0.0, 1.0);
  }
}
