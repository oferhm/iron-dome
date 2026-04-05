import 'dart:math';
import 'dart:ui' as ui;
import 'game_config.dart';
import 'package:flame/collisions.dart';
import 'package:flame/flame.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'explosion_component.dart';
import 'ground_explosion_component.dart';

/// One of the two bombs released by a FragmentationWarhead.
/// Looks like the warhead image — olive oval body, tip pointing in travel direction.
/// Must be intercepted separately.
class FragmentationBomb extends PositionComponent
    with HasGameRef, CollisionCallbacks {

  static ui.Image? _img;
  static Future<void> preload() async {
    try {
      _img = await Flame.images.load('warhead_missile.png');
      debugPrint('Warhead bomb PNG loaded: ${_img!.width}x${_img!.height}');
    } catch (e) { debugPrint('Warhead bomb load failed: \$e'); }
  }

  final Vector2 initialVelocity;
  final VoidCallback onReachedGround;

  bool _isDestroyed = false;
  bool get isDestroyed => _isDestroyed;
  void markDestroyed() => _isDestroyed = true;
  double get travelAngle => atan2(_velocity.y, _velocity.x);

  late Vector2 _velocity;
  final List<Vector2> _trail = [];

  final Random _rng = Random();

  // Size: a bit smaller than Iranian missile (36×148), no image used
  static const double _w = 20.0;
  static const double _h = 40.0;

  FragmentationBomb({
    required Vector2 position,
    required this.initialVelocity,
    required this.onReachedGround,
  }) : super(
          position: position.clone(),
          size: Vector2(_w, _h),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    _velocity = initialVelocity.clone();
    add(RectangleHitbox(
      size: Vector2(_w * 0.60, _h * 0.70),
    )..collisionType = CollisionType.passive);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDestroyed) return;



    if (_trail.isEmpty || (_trail.last - position).length > 7) {
      _trail.add(position.clone());
      if (_trail.length > 16) _trail.removeAt(0);
    }

    position += _velocity * dt;

    final groundY = gameRef.size.y;
    if (!_isDestroyed && position.y >= groundY * GameConfig.groundExplosionHeightFraction) {
      _isDestroyed = true;
      gameRef.add(GroundExplosionComponent(position: position.clone()));
      onReachedGround();
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
      canvas.drawCircle(Offset(tp.x, tp.y), t * 7,
          Paint()..color = const Color(0xFF888888).withOpacity(t * 0.32));
    }

    final tAngle = atan2(_velocity.y, _velocity.x);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(tAngle + pi / 2);
    canvas.translate(-size.x / 2, -size.y / 2);

    if (_img != null) {
      // Image is flipped — rotate 180° before drawing
      canvas.save();
      canvas.translate(size.x / 2, size.y / 2);
      canvas.rotate(pi);
      canvas.translate(-size.x / 2, -size.y / 2);
      canvas.drawImageRect(
        _img!,
        Rect.fromLTWH(0, 0, _img!.width.toDouble(), _img!.height.toDouble()),
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..isAntiAlias = true,
      );
      canvas.restore();
    }

    canvas.restore();
  }

}
