import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'explosion_component.dart';
import 'ground_explosion_component.dart';

class IranianMissile extends PositionComponent with HasGameRef, CollisionCallbacks {
  final Vector2 startPosition;
  final VoidCallback onReachedGround;
  final double speedMultiplier;

  final List<Vector2> _trail = [];
  double _flameTime = 0.0; // for animated flame

  static const double _baseSpeed = 126.0;
  static const double _angleDeg  = 85.0; // +5° more sideways
  static final  double _angleRad  = _angleDeg * pi / 180.0;

  late final Vector2 _velocity;
  late final double  _travelAngle;

  bool _isDestroyed = false;

  static const double _w = 36.0;
  static const double _h = 148.0; // +30% longer

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
    final speed = _baseSpeed * speedMultiplier;
    _velocity    = Vector2(cos(_angleRad) * speed * 0.50, sin(_angleRad) * speed);
    _travelAngle = atan2(_velocity.y, _velocity.x);

    // FIX: no anchor/position offset — Anchor.center already centers the hitbox
    add(RectangleHitbox(
      size: Vector2(_w * 0.55, _h * 0.75),
    )..collisionType = CollisionType.passive);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDestroyed) return;

    _flameTime += dt;
    if (_trail.isEmpty || (_trail.last - position).length > 10) {
      _trail.add(position.clone());
      if (_trail.length > 22) _trail.removeAt(0);
    }

    position += _velocity * dt;

    final groundY = gameRef.size.y;

    // explode when 10% from ground
    if (!_isDestroyed && position.y >= groundY * 0.78) {
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
    // Spawn explosion at current position
    gameRef.add(GroundExplosionComponent(position: position.clone()));
    onReachedGround(); // still counts as a hit on the city
    removeFromParent();
  }

  bool get isDestroyed => _isDestroyed;
  void destroy() => _isDestroyed = true;
  void markDestroyed() => _isDestroyed = true;
  double get travelAngle => _travelAngle;

  @override
  void render(Canvas canvas) {
    if (_isDestroyed) return;
    _drawTrail(canvas);

    final rotation = _travelAngle + pi / 2;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(rotation);
    canvas.translate(-size.x / 2, -size.y / 2);
    _drawMissile(canvas, _flameTime);
    canvas.restore();
  }

  void _drawTrail(Canvas canvas) {
    for (int i = 0; i < _trail.length; i++) {
      final t = i / _trail.length;
      final trailPos = _trail[i] - position + size / 2;
      canvas.drawCircle(
        Offset(trailPos.x, trailPos.y),
        t * 10,
        Paint()..color = const Color(0xFF999999).withOpacity(t * 0.4),
      );
    }
  }

  void _drawMissile(Canvas canvas, double t) {
    final w = size.x;
    final h = size.y;

    // Body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.25, h * 0.14, w * 0.5, h * 0.62),
      const Radius.circular(5),
    );
    canvas.drawRRect(bodyRect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [const Color(0xFF6b7a5a), const Color(0xFFa0b080), const Color(0xFF7a8a68)],
      ).createShader(Rect.fromLTWH(w * 0.25, h * 0.14, w * 0.5, h * 0.62)));
    canvas.drawRRect(bodyRect, Paint()
      ..color = const Color(0xFF4a5540)
      ..style = PaintingStyle.stroke ..strokeWidth = 1.0);

    // Nose
    canvas.drawPath(
      Path()..moveTo(w*0.25, h*0.14)..lineTo(w*0.5, 0.0)..lineTo(w*0.75, h*0.14)..close(),
      Paint()..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [const Color(0xFF3a4430), const Color(0xFF5a6848), const Color(0xFF3a4430)],
      ).createShader(Rect.fromLTWH(w*0.25, 0, w*0.5, h*0.14)),
    );

    // Flag stripes
    final sl = w*0.25; final sw = w*0.5; final st = h*0.18; final sh = h*0.05;
    canvas.drawRect(Rect.fromLTWH(sl, st,        sw, sh), Paint()..color = const Color(0xFF1a7a30));
    canvas.drawRect(Rect.fromLTWH(sl, st+sh,     sw, sh), Paint()..color = const Color(0xFFeeeeee));
    canvas.drawRect(Rect.fromLTWH(sl, st+sh*2,   sw, sh), Paint()..color = const Color(0xFFcc1010));

    // Mid ring
    canvas.drawRect(Rect.fromLTWH(w*0.25, h*0.52, w*0.5, h*0.02), Paint()..color = const Color(0xFF333a28));

    // Fins
    final finPaint = Paint()..shader = LinearGradient(
      colors: [const Color(0xFF4a5540), const Color(0xFF6b7a5a)],
    ).createShader(Rect.fromLTWH(0, h*0.70, w, h*0.18));
    canvas.drawPath(Path()..moveTo(w*0.25,h*0.70)..lineTo(0.0,h*0.88)..lineTo(w*0.25,h*0.78)..close(), finPaint);
    canvas.drawPath(Path()..moveTo(w*0.75,h*0.70)..lineTo(w,h*0.88)..lineTo(w*0.75,h*0.78)..close(), finPaint);
    canvas.drawPath(Path()..moveTo(w*0.35,h*0.72)..lineTo(w*0.15,h*0.86)..lineTo(w*0.35,h*0.80)..close(),
        Paint()..color = const Color(0xFF3a4430).withOpacity(0.65));
    canvas.drawPath(Path()..moveTo(w*0.65,h*0.72)..lineTo(w*0.85,h*0.86)..lineTo(w*0.65,h*0.80)..close(),
        Paint()..color = const Color(0xFF3a4430).withOpacity(0.65));

    // Nozzle
    canvas.drawOval(Rect.fromLTWH(w*0.33, h*0.76, w*0.34, h*0.05), Paint()..color = const Color(0xFF222820));

    // ── Fast animated rocket exhaust flames — 50% slimmer, jet-speed flicker ──
    // High-frequency sin waves for fast turbine-like movement
    final f1 = sin(t * 55.0);                    // very fast — main flicker
    final f2 = sin(t * 42.0 + 1.1);              // fast — secondary offset
    final f3 = sin(t * 28.0 + 2.3);              // fast sway
    final f4 = sin(t * 70.0 + 0.7);              // ultra-fast shimmer

    // Width is now 50% of original (was ~0.60w, now ~0.30w max)
    // Sway is also proportionally reduced
    final sway = f3 * w * 0.04;

    // Outer flame — slim, 50% narrower than before
    final outerLen  = h * (0.50 + f1 * 0.08);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.34, h * 0.78)                          // left nozzle edge (slim)
        ..cubicTo(
          w * 0.28 + f2 * 2, h * 0.86,
          w * 0.40 + sway,   h * 0.78 + outerLen * 0.65,
          w * 0.50 + sway,   h * 0.78 + outerLen,             // tip
        )
        ..cubicTo(
          w * 0.60 + sway,   h * 0.78 + outerLen * 0.65,
          w * 0.72 + f1 * 2, h * 0.86,
          w * 0.66, h * 0.78,                                  // right nozzle edge
        )
        ..close(),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFFcc3300), const Color(0xFFff6600),
                 const Color(0xFFffaa00), Colors.transparent],
        stops: const [0.0, 0.30, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(w * 0.28, h * 0.78, w * 0.44, outerLen + 8)),
    );

    // Mid flame — tighter, fast independent sway
    final midLen  = h * (0.38 + f2 * 0.07);
    final midSway = f4 * w * 0.03;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.38, h * 0.79)
        ..cubicTo(
          w * 0.34 + f1 * 1.5, h * 0.87,
          w * 0.43 + midSway,  h * 0.79 + midLen * 0.70,
          w * 0.50 + midSway,  h * 0.79 + midLen,
        )
        ..cubicTo(
          w * 0.57 + midSway,  h * 0.79 + midLen * 0.70,
          w * 0.66 + f2 * 1.5, h * 0.87,
          w * 0.62, h * 0.79,
        )
        ..close(),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.orangeAccent, Colors.yellow, Colors.transparent],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromLTWH(w * 0.34, h * 0.79, w * 0.32, midLen + 6)),
    );

    // Inner hot core — ultra-slim white spike, fastest movement
    final coreLen  = h * (0.28 + f4 * 0.06);
    final coreSway = f1 * w * 0.025;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.43, h * 0.80)
        ..cubicTo(
          w * 0.41, h * 0.88,
          w * 0.47 + coreSway, h * 0.80 + coreLen * 0.75,
          w * 0.50 + coreSway, h * 0.80 + coreLen,
        )
        ..cubicTo(
          w * 0.53 + coreSway, h * 0.80 + coreLen * 0.75,
          w * 0.59, h * 0.88,
          w * 0.57, h * 0.80,
        )
        ..close(),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.white, const Color(0xFF88ccff), Colors.transparent],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromLTWH(w * 0.41, h * 0.80, w * 0.18, coreLen + 4)),
    );

    // Nozzle glow — pulses fast with f4
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.79),
      w * 0.14 + f4.abs() * w * 0.04,
      Paint()
        ..color = Colors.white.withOpacity(0.80 + f1 * 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }
}
