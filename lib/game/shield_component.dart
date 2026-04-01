import 'dart:math';
import 'game_config.dart';
import 'dart:ui' as ui;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

/// Shield power-up — falls straight down from the sky.
/// If intercepted by Iron Dome: player gains +1 life.
/// If it reaches the bottom: silently vanishes, no penalty.
class ShieldComponent extends PositionComponent with HasGameRef, CollisionCallbacks {
  static ui.Image? _img;

  static Future<void> preload() async {
    try { _img = await Flame.images.load('shield.png'); }
    catch (e) { debugPrint('Shield load failed: $e'); }
  }

  static const double _w     = 44.0;
  static const double _h     = 60.0;
  static const double _speed = 100.0;

  bool _isDestroyed = false;
  bool get isDestroyed => _isDestroyed;
  void markDestroyed() => _isDestroyed = true;

  final VoidCallback onIntercepted; // called when player hits it → +1 life

  // Gentle wobble
  double _wobble = 0;
  final Random _rng = Random();
  final double _wobbleSpeed;
  final double _wobbleAmp;

  ShieldComponent({
    required Vector2 position,
    required this.onIntercepted,
  })  : _wobbleSpeed = 1.5 + Random().nextDouble() * 1.5,
        _wobbleAmp   = 8 + Random().nextDouble() * 8,
        super(
          position: position.clone(),
          size: Vector2(_w, _h),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(
      size: Vector2(_w * 0.75, _h * 0.85),
    )..collisionType = CollisionType.passive);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDestroyed) return;

    _wobble += dt * _wobbleSpeed;
    position.y += _speed * dt;
    position.x += sin(_wobble) * _wobbleAmp * dt; // gentle side-to-side drift

    // Reached ground height — vanish silently (same height as missile explosions)
    if (position.y >= gameRef.size.y * GameConfig.groundHeightFraction) {
      _isDestroyed = true;
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_isDestroyed) return;

    // Glow effect behind shield
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x * 0.7,
      Paint()
        ..color = const Color(0xFF9900ff).withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    if (_img != null) {
      canvas.drawImageRect(
        _img!,
        Rect.fromLTWH(0, 0, _img!.width.toDouble(), _img!.height.toDouble()),
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..isAntiAlias = true,
      );
    } else {
      _drawFallback(canvas);
    }

    // "+1" label
    final tp = TextPainter(
      text: const TextSpan(
        text: '+1',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.x / 2 - tp.width / 2, size.y + 3));
  }

  void _drawFallback(Canvas canvas) {
    final cx = size.x / 2; final cy = size.y / 2;
    final shieldPath = Path()
      ..moveTo(cx, 4)
      ..lineTo(size.x - 4, 16)
      ..lineTo(size.x - 4, size.y * 0.60)
      ..quadraticBezierTo(cx, size.y - 2, 4, size.y * 0.60)
      ..lineTo(4, 16)
      ..close();
    canvas.drawPath(shieldPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFFbb44ff), const Color(0xFF6600cc)],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y)));
    canvas.drawPath(shieldPath, Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }
}
