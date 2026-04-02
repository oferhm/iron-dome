import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ExplosionComponent extends PositionComponent with HasGameRef {
  double _elapsed = 0;
  static const double _duration  = 0.8;  // was 1.1
  static const double _baseSize  = 200.0;
  static const double _ringMax   = 100.0;
  static const double _flashMax  = 45.0;
  static const double _smokeBase = 50.0;
  static const double _smokeGrow = 80.0;

  final Random _random = Random();
  late final List<_Particle> _particles;

  ExplosionComponent({required Vector2 position})
      : super(position: position, size: Vector2.all(_baseSize), anchor: Anchor.center);

  @override
  void onLoad() {
    _particles = List.generate(4, (_) => _Particle(_random)); // was 42
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
    final prog = (_elapsed / _duration).clamp(0.0, 1.0);
    final cx = size.x / 2;
    final cy = size.y / 2;

    // ── Shockwave ring — no blur, just stroke ──
    canvas.drawCircle(Offset(cx, cy), _ringMax * prog,
      Paint()
        ..color = Colors.orangeAccent.withOpacity((1 - prog) * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * (1 - prog));

    // ── Core flash — ONE blur only ──
    if (prog < 0.30) {
      final op = (1 - prog / 0.30).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(cx, cy), _flashMax * (1.5 - prog),
        Paint()
          ..color = Colors.yellow.withOpacity(op * 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
      // white core — no blur
      canvas.drawCircle(Offset(cx, cy), _flashMax * 0.5 * (1 - prog),
        Paint()..color = Colors.white.withOpacity(op * 0.9));
    }

    // ── Fire particles — NO blur, just solid circles ──
    for (final p in _particles) {
      final alpha = (p.life * (1 - prog)).clamp(0.0, 1.0);
      if (alpha <= 0.02) continue;
      canvas.drawCircle(
        Offset(cx + p.x, cy + p.y),
        p.radius * (1 - prog * 0.5),
        Paint()..color = Color.lerp(Colors.yellow, Colors.deepOrange, p.colorT)!
            .withOpacity(alpha));
    }

    // ── Smoke — ONE blur ──
    if (prog > 0.25) {
      final st  = (prog - 0.25) / 0.75;
      final op  = (st * (1 - st) * 2.5).clamp(0.0, 0.60);
      final r   = _smokeBase + _smokeGrow * st;
      canvas.drawCircle(Offset(cx, cy - r * 0.25), r * 0.6,
        Paint()
          ..color = Colors.grey.shade700.withOpacity(op)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    }
  }
}

class _Particle {
  final double angle, speed, radius, colorT;
  double x = 0, y = 0, life = 1.0;

  _Particle(Random r)
    : angle  = r.nextDouble() * 2 * pi,
      speed  = 50 + r.nextDouble() * 100,
      radius = 5 + r.nextDouble() * 14,
      colorT = r.nextDouble();

  void update(double dt) {
    x += cos(angle) * speed * dt;
    y += sin(angle) * speed * dt;
    life = (life - dt * 1.5).clamp(0.0, 1.0);
  }
}
