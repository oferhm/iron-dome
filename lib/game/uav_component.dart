import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'explosion_component.dart';

/// UAV drone — appears from level 6.
/// Flies horizontally from one side of the screen, then randomly dives.
/// Size: ~30% of Iranian missile (36×148 → ~24×44).
class UavComponent extends PositionComponent with HasGameRef, CollisionCallbacks {
  final bool fromLeft;      // true = enters from left, flies right; false = right→left
  final double flyHeight;   // Y position in pixels
  final double diveDelay;   // seconds before diving
  final VoidCallback onReachedGround;

  bool _isDestroyed = false;
  bool get isDestroyed => _isDestroyed;
  void markDestroyed() => _isDestroyed = true;

  static const double _w = 52.0;  // wider than tall — drone shape
  static const double _h = 28.0;
  static const double _flySpeed  = 90.0;
  static const double _diveSpeed = 140.0;

  static Sprite? _sprite;
  static bool _spriteLoaded = false;

  double _elapsed = 0;
  bool   _diving  = false;
  // Propeller spin angle
  double _propAngle = 0;

  UavComponent({
    required this.fromLeft,
    required this.flyHeight,
    required this.diveDelay,
    required this.onReachedGround,
    required Vector2 position,
  }) : super(
          position: position,
          size: Vector2(_w, _h),
          anchor: Anchor.center,
        );

  static Future<void> preload() async {
    try {
      final img = await Flame.images.load('uav.png');
      _sprite = Sprite(img);
      _spriteLoaded = true;
    } catch (_) {
      _spriteLoaded = false;
    }
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(
      size: Vector2(_w * 0.70, _h * 0.60),
    )..collisionType = CollisionType.passive);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDestroyed) return;

    _elapsed    += dt;
    _propAngle  += dt * 18.0; // fast prop spin

    if (!_diving && _elapsed >= diveDelay) {
      _diving = true;
    }

    if (_diving) {
      position.y += _diveSpeed * dt;
    } else {
      position.x += fromLeft ? _flySpeed * dt : -_flySpeed * dt;
    }

    // Check ground — explode at 78% screen height (same as Iranian)
    final groundY = gameRef.size.y;
    if (!_isDestroyed && position.y >= groundY * 0.78) {
      _isDestroyed = true;
      // Half-size explosion
      gameRef.add(_SmallExplosion(position: position.clone()));
      onReachedGround();
      removeFromParent();
      return;
    }

    // Off-screen horizontally (flew past without diving)
    if (position.x < -100 || position.x > gameRef.size.x + 100) {
      _isDestroyed = true;
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_isDestroyed) return;

    if (_spriteLoaded && _sprite != null) {
      _drawSpriteUav(canvas);
    } else {
      _drawFallbackUav(canvas);
    }
  }

  void _drawSpriteUav(Canvas canvas) {
    canvas.save();
    // Flip horizontally if flying left
    if (!fromLeft) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    // Tilt slightly down when diving
    if (_diving) {
      canvas.translate(size.x / 2, size.y / 2);
      canvas.rotate(0.3);
      canvas.translate(-size.x / 2, -size.y / 2);
    }
    _sprite!.render(canvas, size: size);
    canvas.restore();
  }

  void _drawFallbackUav(Canvas canvas) {
    final w = size.x; final h = size.y;

    canvas.save();
    if (!fromLeft) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    if (_diving) {
      canvas.translate(w/2, h/2);
      canvas.rotate(0.3);
      canvas.translate(-w/2, -h/2);
    }

    // Central body
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w*0.28, h*0.18, w*0.44, h*0.60), const Radius.circular(5)),
      Paint()..color = const Color(0xFFddaa00),
    );

    // Arms (4 diagonal arms to props)
    final armPaint = Paint()..color = const Color(0xFF333333)..strokeWidth = 3..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w*0.28, h*0.25), Offset(w*0.05, h*0.15), armPaint);
    canvas.drawLine(Offset(w*0.72, h*0.25), Offset(w*0.95, h*0.15), armPaint);
    canvas.drawLine(Offset(w*0.28, h*0.72), Offset(w*0.05, h*0.82), armPaint);
    canvas.drawLine(Offset(w*0.72, h*0.72), Offset(w*0.95, h*0.82), armPaint);

    // 4 spinning propellers
    final propCenters = [
      Offset(w*0.05, h*0.12),
      Offset(w*0.95, h*0.12),
      Offset(w*0.05, h*0.85),
      Offset(w*0.95, h*0.85),
    ];
    final propPaint = Paint()
      ..color = const Color(0xFF444444).withOpacity(0.75)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final center in propCenters) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(_propAngle);
      canvas.drawLine(const Offset(-10, 0), const Offset(10, 0), propPaint);
      canvas.rotate(pi / 2);
      canvas.drawLine(const Offset(-8, 0), const Offset(8, 0), propPaint);
      canvas.restore();
    }

    // Camera
    canvas.drawCircle(Offset(w*0.50, h*0.70),
        h*0.12, Paint()..color = const Color(0xFF222222));
    canvas.drawCircle(Offset(w*0.50, h*0.70),
        h*0.07, Paint()..color = const Color(0xFF4488cc));

    canvas.restore();
  }
}

/// Half-size explosion for UAV ground impact
class _SmallExplosion extends PositionComponent with HasGameRef {
  double _elapsed = 0;
  static const double _dur  = 0.8;
  static const double _size = 120.0; // half of ground explosion (240)
  final Random _rng = Random();
  late List<_SP> _particles;

  _SmallExplosion({required Vector2 position})
      : super(position: position, size: Vector2.all(_size), anchor: Anchor.center);

  @override
  void onLoad() {
    _particles = List.generate(20, (_) => _SP(_rng));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _dur) removeFromParent();
    for (final p in _particles) p.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final prog = (_elapsed / _dur).clamp(0.0, 1.0);
    final cx = size.x / 2; final cy = size.y / 2;

    // Flash
    if (prog < 0.25) {
      final op = (1 - prog / 0.25).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(cx, cy), 30 * (1 - prog),
          Paint()..color = Colors.white.withOpacity(op * 0.9)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    // Shockwave
    canvas.drawCircle(Offset(cx, cy), 50 * prog,
        Paint()
          ..color = Colors.orangeAccent.withOpacity((1 - prog) * 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - prog));

    // Particles
    for (final p in _particles) {
      final alpha = (p.life * (1 - prog)).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(cx + p.x, cy + p.y), p.r * (1 - prog * 0.4),
          Paint()..color = Color.lerp(Colors.yellow, Colors.orange, p.t)!.withOpacity(alpha));
    }
  }
}

class _SP {
  final double angle, speed, r, t;
  double x = 0, y = 0, life = 1.0;
  _SP(Random rng)
      : angle = (rng.nextDouble() - 0.5) * pi * 1.5 - pi / 2,
        speed = 30 + rng.nextDouble() * 70,
        r     = 4 + rng.nextDouble() * 10,
        t     = rng.nextDouble();
  void update(double dt) {
    x += cos(angle) * speed * dt;
    y += sin(angle) * speed * dt + 15 * dt;
    life = (life - dt * 1.2).clamp(0.0, 1.0);
  }
}
