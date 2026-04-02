import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Small smoke burst at launcher when interceptor fires — minimal version.
class LaunchSmokeComponent extends PositionComponent with HasGameRef {
  double _elapsed = 0;
  static const double _duration = 0.5; // was 0.7
  final Random _rng = Random();
  late List<_SmokePuff> _puffs;

  LaunchSmokeComponent({required Vector2 position})
      : super(position: position, size: Vector2.all(60), anchor: Anchor.center);

  @override
  void onLoad() {
    _puffs = List.generate(4, (_) => _SmokePuff(_rng)); // was 10
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) { removeFromParent(); return; }
    for (final p in _puffs) p.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _duration).clamp(0.0, 1.0);
    final cx = size.x / 2;
    final cy = size.y / 2;

    // Flash — no blur
    if (progress < 0.20) {
      final op = (1 - progress / 0.20).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(cx, cy), 10 * (1 - progress),
        Paint()..color = Colors.orangeAccent.withOpacity(op * 0.80));
    }

    // Smoke puffs — no blur
    for (final p in _puffs) {
      final alpha = (p.life * (1 - progress * 0.8)).clamp(0.0, 1.0);
      if (alpha < 0.02) continue;
      canvas.drawCircle(Offset(cx + p.x, cy + p.y), p.r * (1 + progress),
        Paint()..color = Colors.grey.withOpacity(alpha * 0.55));
    }
  }
}

class _SmokePuff {
  final double angle, speed, r;
  double x = 0, y = 0, life = 1.0;

  _SmokePuff(Random rng)
      : angle = rng.nextDouble() * 2 * pi,
        speed = 12 + rng.nextDouble() * 20,
        r     = 3 + rng.nextDouble() * 6;

  void update(double dt) {
    x    += cos(angle) * speed * dt;
    y    += sin(angle) * speed * dt - 8 * dt;
    life  = (life - dt * 2.5).clamp(0.0, 1.0);
  }
}
