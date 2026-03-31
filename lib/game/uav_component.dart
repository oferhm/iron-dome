import 'dart:math';
import 'game_config.dart';
import 'iron_dome_game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'explosion_component.dart';
import 'ground_explosion_component.dart';

/// UAV Drone.
/// Flies in from left or right at 40–85% screen height.
/// When horizontally near the center (±25% of screen), dives straight down.
/// Explodes at 78% screen height like Iranian missiles.
/// Iron Dome can destroy it.
class UavComponent extends PositionComponent with HasGameRef, CollisionCallbacks {
  final bool fromLeft;
  final VoidCallback onReachedGround;

  bool _isDestroyed = false;
  bool get isDestroyed => _isDestroyed;
  void markDestroyed() => _isDestroyed = true;

  // Size: 40% of Iranian missile area — drone is wide/flat
  static const double _w = 59.0;
  static const double _h = 30.0; // 80% of previous

  static const double _flySpeed  = 80.0;
  static const double _diveSpeed = 110.0;

  static Sprite? _sprite;
  static bool _spriteLoaded = false;

  bool _diving = false;
  double _propAngle = 0;

  // Smoke trail
  final List<Vector2> _trail = [];

  UavComponent({
    required this.fromLeft,
    required Vector2 position,
    required this.onReachedGround,
  }) : super(
          position: position.clone(),
          size: Vector2(_w, _h),
          anchor: Anchor.center,
        );

  static Future<void> preload() async {
    try {
      final img = await Flame.images.load('uav.png');
      _sprite   = Sprite(img);
      _spriteLoaded = true;
    } catch (e) {
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

    _propAngle += dt * 22.0;

    // Trail
    if (_trail.isEmpty || (_trail.last - position).length > 8) {
      _trail.add(position.clone());
      if (_trail.length > 12) _trail.removeAt(0);
    }

    if (_diving) {
      position.y += GameConfig.uavDiveBaseSpeed * GameConfig.speedMultiplier((gameRef as IronDomeGame).difficulty.level) * dt;
    } else {
      position.x += fromLeft
          ? GameConfig.uavBaseSpeed * GameConfig.speedMultiplier((gameRef as IronDomeGame).difficulty.level) * dt
          : -GameConfig.uavBaseSpeed * GameConfig.speedMultiplier((gameRef as IronDomeGame).difficulty.level) * dt;

      // Dive ONLY when inside the middle 30% of screen (35%–65%)
      // This guarantees the explosion is well within the visible area
      final screenW = gameRef.size.x;
      final inMiddleZone = position.x > screenW * 0.35 && position.x < screenW * 0.65;
      if (inMiddleZone) {
        _diving = true;
      }
    }

    // Ground explosion at 78%
    final groundY = gameRef.size.y;
    if (position.y >= groundY * GameConfig.groundExplosionHeightFraction) {
      _isDestroyed = true;
      gameRef.add(GroundExplosionComponent(position: position.clone()));
      onReachedGround();
      removeFromParent();
      return;
    }

    // Flew off screen without diving
    if (!_diving && (position.x < -150 || position.x > gameRef.size.x + 150)) {
      _isDestroyed = true;
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_isDestroyed) return;

    // Smoke trail
    for (int i = 0; i < _trail.length; i++) {
      final t = i / _trail.length;
      final tp = _trail[i] - position + size / 2;
      canvas.drawCircle(Offset(tp.x, tp.y), t * 6,
          Paint()..color = const Color(0xFF888888).withOpacity(t * 0.25));
    }

    canvas.save();

    // Flip when flying right-to-left
    if (!fromLeft) {
      canvas.translate(_w, 0);
      canvas.scale(-1, 1);
    }

    // Tilt nose down when diving
    if (_diving) {
      canvas.translate(_w / 2, _h / 2);
      canvas.rotate(0.4);
      canvas.translate(-_w / 2, -_h / 2);
    }

_drawFallback(canvas); // always draw — sprite is JPEG with white BG

    canvas.restore();
  }

  void _drawFallback(Canvas canvas) {
    final w = _w; final h = _h;

    // Arms to propellers
    final arm = Paint()
      ..color = const Color(0xFF2a2a2a)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w*0.32, h*0.38), Offset(w*0.06, h*0.14), arm);
    canvas.drawLine(Offset(w*0.68, h*0.38), Offset(w*0.94, h*0.14), arm);
    canvas.drawLine(Offset(w*0.32, h*0.62), Offset(w*0.06, h*0.86), arm);
    canvas.drawLine(Offset(w*0.68, h*0.62), Offset(w*0.94, h*0.86), arm);

    // Propellers spinning
    final propCenters = [
      Offset(w*0.06, h*0.12), Offset(w*0.94, h*0.12),
      Offset(w*0.06, h*0.88), Offset(w*0.94, h*0.88),
    ];
    for (final c in propCenters) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(_propAngle);
      canvas.drawLine(const Offset(-13, 0), const Offset(13, 0),
          Paint()..color = const Color(0xFF555555).withOpacity(0.85)
            ..strokeWidth = 3..strokeCap = StrokeCap.round);
      canvas.restore();
    }

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w*0.28, h*0.22, w*0.44, h*0.56), const Radius.circular(7)),
      Paint()..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [const Color(0xFFeeaa00), const Color(0xFFcc8800)],
      ).createShader(Rect.fromLTWH(w*0.28, h*0.22, w*0.44, h*0.56)),
    );

    // Body outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w*0.28, h*0.22, w*0.44, h*0.56), const Radius.circular(7)),
      Paint()..color = const Color(0xFF884400)..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );

    // Camera lens
    canvas.drawCircle(Offset(w*0.50, h*0.68), h*0.11,
        Paint()..color = const Color(0xFF1a1a1a));
    canvas.drawCircle(Offset(w*0.50, h*0.68), h*0.07,
        Paint()..color = const Color(0xFF2255aa));
    canvas.drawCircle(Offset(w*0.50, h*0.68), h*0.03,
        Paint()..color = Colors.white.withOpacity(0.4));
  }
}
