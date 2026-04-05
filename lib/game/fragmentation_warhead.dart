import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/collisions.dart';
import 'package:flame/flame.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'game_config.dart';
import 'iron_dome_game.dart';
import 'fragmentation_bomb.dart';

class FragmentationWarhead extends PositionComponent
    with HasGameRef, CollisionCallbacks {

  static ui.Image? _img;

  static Future<void> preload() async {
    try {
      _img = await Flame.images.load('frag_missle.png');
      debugPrint('Frag missile PNG loaded: ${_img!.width}x${_img!.height}');
    } catch (e) {
      debugPrint('Frag missile image failed: \$e');
    }
  }

  final Vector2 startPosition;
  final double speedMultiplier;
  final VoidCallback onReachedGround;
  final int level; // current game level — determines bomb count

  bool _isDestroyed = false;
  bool get isDestroyed => _isDestroyed;
  void markDestroyed() => _isDestroyed = true;

  // Angle and speed from GameConfig

  late Vector2 _velocity;
  late double _travelAngle;
  double get travelAngle => _travelAngle;

  double _elapsed = 0;
  bool _hasSplit = false;

  final Random _rng = Random();

  // Same size as Iranian missile
  static const double _w = 60.0; // 20% slimmer
  static const double _h = 140.0;

  final List<Vector2> _trail = [];

  FragmentationWarhead({
    required this.startPosition,
    required this.speedMultiplier,
    required this.onReachedGround,
    required this.level,
  }) : super(
          position: startPosition.clone(),
          size: Vector2(_w, _h),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    final speed = GameConfig.iranianBaseSpeed * GameConfig.speedMultiplier((gameRef as IronDomeGame).difficulty.level);
    _velocity    = Vector2(cos(GameConfig.iranianAngleRad) * speed * 0.35, sin(GameConfig.iranianAngleRad) * speed);
    _travelAngle = atan2(_velocity.y, _velocity.x);

    add(RectangleHitbox(
      size: Vector2(_w * 0.60, _h * 0.70),
    )..collisionType = CollisionType.passive);
  }

  // How many bombs to release: 2 for levels 1-4, 3 for level 5+
  int get _bombCount => level >= GameConfig.fragmentationBombsLevel5 ? GameConfig.fragmentationBombsLevel5 : 2;

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDestroyed) return;

    _elapsed += dt;

    if (_trail.isEmpty || (_trail.last - position).length > 9) {
      _trail.add(position.clone());
      if (_trail.length > 18) _trail.removeAt(0);
    }

    position += _velocity * dt;

    // Split at configured delay — no door animation, just split directly
    if (!_hasSplit && _elapsed >= GameConfig.fragmentationSplitDelay) {
      _split();
      return;
    }

    if (position.y > gameRef.size.y + 30) {
      _isDestroyed = true;
      removeFromParent();
    }
  }

  void _split() {
    _hasSplit    = true;
    _isDestroyed = true;

    final bombSpeed = _velocity.length * GameConfig.fragmentationBombSpeedFactor;
    final count     = _bombCount;

    // Spread bombs evenly across splitAngle range, centered on straight-down
    final totalSpreadRad =
        (GameConfig.fragmentationSplitAngleDeg * (count - 1) / 2) * pi / 180.0;

    for (int i = 0; i < count; i++) {
      final fraction = count == 1 ? 0.0 : i / (count - 1) - 0.5;
      final angle    = pi / 2 + fraction * totalSpreadRad * 2;
      final vel      = Vector2(cos(angle) * bombSpeed, sin(angle) * bombSpeed);

      gameRef.add(FragmentationBomb(
        position:        position.clone(),
        initialVelocity: vel,
        onReachedGround: onReachedGround,
      ));
    }

    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (_isDestroyed) return;

    // Smoke trail
    for (int i = 0; i < _trail.length; i++) {
      final t  = i / _trail.length;
      final tp = _trail[i] - position + size / 2;
      canvas.drawCircle(Offset(tp.x, tp.y), t * 9,
          Paint()..color = const Color(0xFF999999).withOpacity(t * 0.38));
    }

    final rotation = _travelAngle + pi / 2;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(rotation);
    canvas.translate(-size.x / 2, -size.y / 2);

    if (_img != null) {
      // Draw from PNG
      canvas.drawImageRect(
        _img!,
        Rect.fromLTWH(0, 0, _img!.width.toDouble(), _img!.height.toDouble()),
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..isAntiAlias = true,
      );
    }

    canvas.restore();
  }


}
