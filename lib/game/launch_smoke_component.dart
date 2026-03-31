import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Small smoke burst at the launcher when an interceptor fires.
class LaunchSmokeComponent extends PositionComponent with HasGameRef {
  double _elapsed = 0;
  static const double _duration = 0.7;
  final Random _rng = Random();
  late List<_SmokePuff> _puffs;

  LaunchSmokeComponent({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(80),
          anchor: Anchor.center,
        );

  @override
  void onLoad() {
    _puffs = List.generate(10, (_) => _SmokePuff(_rng));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) {
      removeFromParent();
      return;
    }
    for (final p in _puffs) p.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _duration).clamp(0.0, 1.0);
    final cx = size.x / 2;
    final cy = size.y / 2;

    // Initial bright flash
    if (progress < 0.20) {
      final op = (1 - progress / 0.20).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(cx, cy),
        14 * (1 - progress / 0.20),
        Paint()
          ..color = Colors.orangeAccent.withOpacity(op * 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        8 * (1 - progress / 0.20),
        Paint()..color = Colors.white.withOpacity(op * 0.90),
      );
    }

    // Smoke puffs expand and fade
    for (final p in _puffs) {
      final alpha = (p.life * (1 - progress * 0.8)).clamp(0.0, 1.0);
      if (alpha < 0.01) continue;
      canvas.drawCircle(
        Offset(cx + p.x, cy + p.y),
        p.r * (1 + progress * 1.5), // expand as they age
        Paint()
          ..color = Color.lerp(
            const Color(0xFFdddddd),
            const Color(0xFF888888),
            progress,
          )!.withOpacity(alpha * 0.65)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.r * 0.5),
      );
    }
  }
}

class _SmokePuff {
  final double angle, speed, r;
  double x = 0, y = 0, life = 1.0;

  _SmokePuff(Random rng)
      : angle = rng.nextDouble() * 2 * pi,
        speed = 15 + rng.nextDouble() * 30,
        r     = 4 + rng.nextDouble() * 8;

  void update(double dt) {
    x    += cos(angle) * speed * dt;
    y    += sin(angle) * speed * dt - 10 * dt; // drift upward
    life  = (life - dt * 2.0).clamp(0.0, 1.0);
  }
}
