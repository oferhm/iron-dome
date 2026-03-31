import 'dart:math';
import 'game_config.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'explosion_component.dart';
import 'missile_flame.dart';
import 'ground_explosion_component.dart';

/// One of the two bombs released by a FragmentationWarhead.
/// Looks like the warhead image — olive oval body, tip pointing in travel direction.
/// Must be intercepted separately.
class FragmentationBomb extends PositionComponent
    with HasGameRef, CollisionCallbacks {

  final Vector2 initialVelocity;
  final VoidCallback onReachedGround;

  bool _isDestroyed = false;
  bool get isDestroyed => _isDestroyed;
  void markDestroyed() => _isDestroyed = true;
  double get travelAngle => atan2(_velocity.y, _velocity.x);

  late Vector2 _velocity;
  final List<Vector2> _trail = [];
  double _flameTime = 0;
  final List<FlameParticle> _flameParticles = [];
  final Random _rng = Random();

  // Size: a bit smaller than Iranian missile (36×148), no image used
  static const double _w = 32.0;
  static const double _h = 58.0;

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

    _flameTime += dt;
    updateFlameParticles(_flameParticles, size.x, dt, _rng);

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

    // Rotate so nose (top of component) points in travel direction
    // Travel angle from horizontal; drawn nose points up (-pi/2)
    // rotation = travelAngle - (-pi/2) = travelAngle + pi/2
    final tAngle = atan2(_velocity.y, _velocity.x);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(tAngle + pi / 2);
    canvas.translate(-size.x / 2, -size.y / 2);
    _drawBomb(canvas, _flameTime);
    canvas.restore();
  }

  void _drawBomb(Canvas canvas, double t) {
    final w = size.x;
    final h = size.y;

    // ── Oval body — olive green like the photo ──
    final bodyPath = Path()
      ..addOval(Rect.fromLTWH(w * 0.12, h * 0.08, w * 0.76, h * 0.62));

    canvas.drawPath(bodyPath, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [const Color(0xFF7a9a50), const Color(0xFF3a5028)],
      ).createShader(Rect.fromLTWH(w * 0.12, h * 0.08, w * 0.76, h * 0.62)));

    // Thin red border frame
    canvas.drawPath(bodyPath, Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Sharp nose cone pointing UP (direction of travel)
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.22, h * 0.10)
        ..lineTo(w * 0.50, 0)
        ..lineTo(w * 0.78, h * 0.10)
        ..close(),
      Paint()..color = const Color(0xFF2a3820),
    );

    // Yellow stripe (like the image)
    canvas.drawArc(
      Rect.fromLTWH(w * 0.12, h * 0.45, w * 0.76, h * 0.25),
      pi, pi, false,
      Paint()..color = const Color(0xFFddaa00)..strokeWidth = h * 0.10..style = PaintingStyle.stroke,
    );

    // Small tail fins
    final fin = Paint()..color = const Color(0xFF3a4a28);
    canvas.drawPath(Path()
      ..moveTo(w*0.18, h*0.64)..lineTo(0, h*0.80)..lineTo(w*0.22, h*0.72)..close(), fin);
    canvas.drawPath(Path()
      ..moveTo(w*0.82, h*0.64)..lineTo(w, h*0.80)..lineTo(w*0.78, h*0.72)..close(), fin);

    // Rear nozzle
    canvas.drawOval(Rect.fromLTWH(w*0.36, h*0.74, w*0.28, h*0.04),
        Paint()..color = const Color(0xFF1a2010));

    // ── Shared slim fast flame + spark trail ──
    drawMissileFlame(canvas, w, h, t, _flameParticles, nozzleY: 0.78);
  }
}
