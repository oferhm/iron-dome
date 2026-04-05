import 'dart:math';
import 'dart:ui' as ui;
import 'game_config.dart';
import 'iron_dome_game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'ground_explosion_component.dart';

class IranianMissile extends PositionComponent with HasGameRef, CollisionCallbacks {
  final Vector2 startPosition;
  final VoidCallback onReachedGround;
  final double speedMultiplier;

  static ui.Image? _img;

  static Future<void> preload() async {
    try {
      _img = await Flame.images.load('iranian_missile.png');
      debugPrint('Iranian missile PNG loaded: ${_img!.width}x${_img!.height}');
    } catch (e) {
      debugPrint('Iranian missile load failed: \$e');
    }
  }

  final List<Vector2> _trail = [];

  static const double _angleDeg = 85.0;
  static final  double _angleRad = _angleDeg * pi / 180.0;

  late final Vector2 _velocity;
  late final double  _travelAngle;

  bool _isDestroyed = false;

  static const double _w = 50.0;
  static const double _h = 140.0;

  IranianMissile({
    required this.startPosition,
    required this.onReachedGround,
    this.speedMultiplier = 1.0,
  }) : super(
          position: startPosition.clone(),
          size: Vector2(_w, _h),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    final speed = GameConfig.iranianBaseSpeed *
        GameConfig.speedMultiplier((gameRef as IronDomeGame).difficulty.level);
    _velocity    = Vector2(cos(_angleRad) * speed * 0.50, sin(_angleRad) * speed);
    _travelAngle = atan2(_velocity.y, _velocity.x);

    add(RectangleHitbox(
      size: Vector2(_w * 0.55, _h * 0.75),
    )..collisionType = CollisionType.passive);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDestroyed) return;

    if (_trail.isEmpty || (_trail.last - position).length > 10) {
      _trail.add(position.clone());
      if (_trail.length > 22) _trail.removeAt(0);
    }

    position += _velocity * dt;

    final groundY = gameRef.size.y;
    if (!_isDestroyed && position.y >= groundY * GameConfig.groundExplosionHeightFraction) {
      _explodeAtGround();
      return;
    }
    if (position.y > groundY + 20) {
      _isDestroyed = true;
      removeFromParent();
    }
  }

  void _explodeAtGround() {
    _isDestroyed = true;
    gameRef.add(GroundExplosionComponent(position: position.clone()));
    onReachedGround();
    removeFromParent();
  }

  bool get isDestroyed => _isDestroyed;
  void destroy()       => _isDestroyed = true;
  void markDestroyed() => _isDestroyed = true;
  double get travelAngle => _travelAngle;

  @override
  void render(Canvas canvas) {
    if (_isDestroyed) return;

    // Smoke trail
    for (int i = 0; i < _trail.length; i++) {
      final t = i / _trail.length;
      final tp = _trail[i] - position + size / 2;
      canvas.drawCircle(Offset(tp.x, tp.y), t * 10,
          Paint()..color = const Color(0xFF999999).withOpacity(t * 0.4));
    }

    // Rotate to travel direction
    final rotation = _travelAngle + pi / 2;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(rotation);
    canvas.translate(-size.x / 2, -size.y / 2);

    if (_img != null) {
      // Draw from PNG — already transparent
      canvas.drawImageRect(
        _img!,
        Rect.fromLTWH(0, 0, _img!.width.toDouble(), _img!.height.toDouble()),
        Rect.fromLTWH(0, 0, _w, _h),
        Paint()..isAntiAlias = true,
      );
    } else {
      _drawFallback(canvas);
    }

    canvas.restore();
  }

  // Fallback if image fails to load — simple green rectangle
  void _drawFallback(Canvas canvas) {
    final w = size.x; final h = size.y;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w*0.25, h*0.1, w*0.5, h*0.8), const Radius.circular(4)),
      Paint()..color = const Color(0xFF5a7040));
    canvas.drawPath(
      Path()..moveTo(w*0.25,h*0.1)..lineTo(w*0.5,0)..lineTo(w*0.75,h*0.1)..close(),
      Paint()..color = const Color(0xFF3a4a28));
  }
}
