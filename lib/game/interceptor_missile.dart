import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'iranian_missile.dart';
import 'smoke_trail_component.dart';

class InterceptorMissile extends PositionComponent with HasGameRef, CollisionCallbacks {
  final Vector2 startPosition;
  final Vector2 targetPosition;
  final void Function(IranianMissile hit) onHit;
  final VoidCallback onMiss;

  static const double _speed = 680.0;
  static const double _w     = 17.0;  // +20% wider
  static const double _h     = 66.0;  // +50% longer

  // Spawn a puff every 8px for a dense trail
  static const double _puffInterval = 8.0;
  double _distSinceLastPuff = 0;

  final Random _rng = Random();

  late Vector2 _velocity;
  late double  _angle;
  bool _isDestroyed = false;
  bool get isDestroyed => _isDestroyed;
  void markDestroyed() => _isDestroyed = true;

  InterceptorMissile({
    required this.startPosition,
    required this.targetPosition,
    required this.onHit,
    required this.onMiss,
  }) : super(
          position: startPosition.clone(),
          size: Vector2(_w, _h),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    final dir = targetPosition - startPosition;
    _angle    = atan2(dir.y, dir.x);
    _velocity = Vector2(cos(_angle), sin(_angle)) * _speed;

    add(RectangleHitbox(size: Vector2(_w * 0.9, _h * 0.9)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDestroyed) return;

    final step = _velocity * dt;
    _distSinceLastPuff += step.length;
    position += step;

    if (_distSinceLastPuff >= _puffInterval) {
      _distSinceLastPuff = 0;
      _spawnSmokePuff();
    }

    final s = gameRef.size;
    if (position.x < -80 || position.x > s.x + 80 ||
        position.y < -80 || position.y > s.y + 80) {
      _isDestroyed = true;
      onMiss();
      removeFromParent();
    }
  }

  void _spawnSmokePuff() {
  final tailOffset = Vector2(-cos(_angle), -sin(_angle)) * (_h * 0.42);
  final spread = Vector2(
    (_rng.nextDouble() - 0.5) * 4,
    (_rng.nextDouble() - 0.5) * 4,
  );

  final isHot = _rng.nextDouble() > 0.45;

  gameRef.add(SmokePuff(
    position: position + tailOffset + spread,
    lifetime: isHot ? 5.0 + _rng.nextDouble() * 2.0
                    : 6.0 + _rng.nextDouble() * 2.0,
    radius:   isHot ? 3.0 + _rng.nextDouble() * 2.5
                    : 4.0 + _rng.nextDouble() * 3.5,
    opacity:  isHot ? 0.60 : 0.45,
    color:    isHot
                ? const Color(0xFFd0e8f0)
                : const Color(0xFFb0b0b0),
  ));
}

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_isDestroyed) return;
    final target = other.parent;
    if (target is IranianMissile && !target.isRemoving && !target.isDestroyed) {
      _isDestroyed = true;
      onHit(target);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_isDestroyed) return;

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(_angle + pi / 2);
    canvas.translate(-size.x / 2, -size.y / 2);
    _drawMissile(canvas);
    canvas.restore();
  }

  void _drawMissile(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, h * 0.16, w * 0.6, h * 0.62), const Radius.circular(4));
    canvas.drawRRect(bodyRect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [const Color(0xFFb0c8d8), const Color(0xFFe8f4fc), const Color(0xFFb0c8d8)],
      ).createShader(Rect.fromLTWH(w * 0.2, h * 0.16, w * 0.6, h * 0.62)));
    canvas.drawRRect(bodyRect, Paint()
      ..color = const Color(0xFF7090a8)
      ..style = PaintingStyle.stroke ..strokeWidth = 0.8);

    // Nose
    canvas.drawPath(
      Path()..moveTo(w*0.2, h*0.16)..lineTo(w*0.5, 0.0)..lineTo(w*0.8, h*0.16)..close(),
      Paint()..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [const Color(0xFF8aaabb), const Color(0xFFccdde8), const Color(0xFF8aaabb)],
      ).createShader(Rect.fromLTWH(w*0.2, 0, w*0.6, h*0.16)),
    );

    // Blue band
    canvas.drawRect(Rect.fromLTWH(w*0.2, h*0.40, w*0.6, h*0.07), Paint()..color = const Color(0xFF1155cc));
    canvas.drawRect(Rect.fromLTWH(w*0.2, h*0.38, w*0.6, h*0.02), Paint()..color = Colors.white.withOpacity(0.7));
    canvas.drawRect(Rect.fromLTWH(w*0.2, h*0.47, w*0.6, h*0.02), Paint()..color = Colors.white.withOpacity(0.7));

    // Fins
    final finPaint = Paint()..shader = LinearGradient(
      colors: [const Color(0xFF8aaabb), const Color(0xFFccdde8)],
    ).createShader(Rect.fromLTWH(0, h*0.68, w, h*0.2));
    canvas.drawPath(Path()..moveTo(w*0.2,h*0.68)..lineTo(0.0,h*0.86)..lineTo(w*0.22,h*0.76)..close(), finPaint);
    canvas.drawPath(Path()..moveTo(w*0.8,h*0.68)..lineTo(w,h*0.86)..lineTo(w*0.78,h*0.76)..close(), finPaint);
    canvas.drawPath(Path()..moveTo(w*0.32,h*0.70)..lineTo(w*0.10,h*0.84)..lineTo(w*0.32,h*0.78)..close(),
        Paint()..color = const Color(0xFF8aaabb).withOpacity(0.6));
    canvas.drawPath(Path()..moveTo(w*0.68,h*0.70)..lineTo(w*0.90,h*0.84)..lineTo(w*0.68,h*0.78)..close(),
        Paint()..color = const Color(0xFF8aaabb).withOpacity(0.6));

    // Nozzle
    canvas.drawOval(Rect.fromLTWH(w*0.3, h*0.76, w*0.4, h*0.04), Paint()..color = const Color(0xFF334455));

    // Exhaust flame
    canvas.drawPath(
      Path()..moveTo(w*0.28,h*0.79)..lineTo(w*0.50,h*1.04)..lineTo(w*0.72,h*0.79)..close(),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.lightBlueAccent, Colors.blue.withOpacity(0.2)],
      ).createShader(Rect.fromLTWH(w*0.28, h*0.79, w*0.44, h*0.25)),
    );
    canvas.drawPath(
      Path()..moveTo(w*0.38,h*0.79)..lineTo(w*0.50,h*0.99)..lineTo(w*0.62,h*0.79)..close(),
      Paint()..color = Colors.white.withOpacity(0.95),
    );
  }
}
