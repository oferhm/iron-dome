import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'game_config.dart';
import 'fragmentation_bomb.dart';

/// Fragmentation warhead — flies in, then splits open releasing 2 bombs.
/// The warhead itself does NOT explode; only the released bombs do.
class FragmentationWarhead extends PositionComponent
    with HasGameRef, CollisionCallbacks {

  final Vector2 startPosition;
  final double speedMultiplier;
  final VoidCallback onReachedGround; // called when a BOMB hits ground

  bool _isDestroyed = false;
  bool get isDestroyed => _isDestroyed;
  void markDestroyed() => _isDestroyed = true;

  // Travel angle (same as Iranian missile)
  static const double _angleDeg = 85.0;
  static final double _angleRad = _angleDeg * pi / 180.0;
  static const double _baseSpeed = 126.0;

  late Vector2 _velocity;
  late double _travelAngle;
  double get travelAngle => _travelAngle;

  double _elapsed = 0;
  bool _hasSplit = false;

  // Opening animation
  double _openProgress = 0; // 0=closed, 1=fully open
  bool _isOpening = false;

  // Size: slightly smaller than Iranian missile (which is 36×148)
  static const double _w = 34.0;
  static const double _h = 92.0;

  final List<Vector2> _trail = [];

  FragmentationWarhead({
    required this.startPosition,
    required this.speedMultiplier,
    required this.onReachedGround,
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

    add(RectangleHitbox(
      size: Vector2(_w * 0.60, _h * 0.70),
    )..collisionType = CollisionType.passive);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDestroyed) return;

    _elapsed += dt;

    if (_trail.isEmpty || (_trail.last - position).length > 9) {
      _trail.add(position.clone());
      if (_trail.length > 18) _trail.removeAt(0);
    }

    // Start opening animation just before split
    final splitDelay = GameConfig.fragmentationSplitDelay + 1.0; // extra 1s lower on screen
    if (!_hasSplit && _elapsed >= splitDelay - 0.3) {
      _isOpening = true;
    }

    if (_isOpening && !_hasSplit) {
      _openProgress = ((_elapsed - (splitDelay - 0.3)) / 0.3).clamp(0.0, 1.0);
    }

    // Split when delay reached
    if (!_hasSplit && _elapsed >= splitDelay) {
      _split();
      return;
    }

    position += _velocity * dt;

    if (position.y > gameRef.size.y + 30) {
      _isDestroyed = true;
      removeFromParent();
    }
  }

  void _split() {
    _hasSplit = true;
    _isDestroyed = true;

    // Bomb speed = parent speed × factor
    final bombSpeed = _velocity.length *
        GameConfig.fragmentationBombSpeedFactor;

    // Split angle: 30° apart, centered on current travel direction
    final splitHalfRad =
        (GameConfig.fragmentationSplitAngleDeg / 2) * pi / 180.0;

    // Base downward angle
    final baseAngle = pi / 2; // straight down + slight variation

    for (int i = 0; i < 2; i++) {
      final angle = baseAngle + (i == 0 ? -splitHalfRad : splitHalfRad);
      final vel   = Vector2(cos(angle) * bombSpeed, sin(angle) * bombSpeed);

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
      final t = i / _trail.length;
      final tp = _trail[i] - position + size / 2;
      canvas.drawCircle(Offset(tp.x, tp.y), t * 9,
          Paint()..color = const Color(0xFF999999).withOpacity(t * 0.38));
    }

    final rotation = _travelAngle + pi / 2;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(rotation);
    canvas.translate(-size.x / 2, -size.y / 2);
    _drawWarhead(canvas);
    canvas.restore();
  }

  void _drawWarhead(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    if (_isOpening) {
      _drawOpeningWarhead(canvas, w, h, _openProgress);
      return;
    }

    // ── Identical to Iranian missile + thin red border ──

    // Body gradient (olive)
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.25, h * 0.14, w * 0.50, h * 0.62),
      const Radius.circular(5),
    );
    canvas.drawRRect(bodyRect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [const Color(0xFF6b7a5a), const Color(0xFFa0b080), const Color(0xFF7a8a68)],
      ).createShader(Rect.fromLTWH(w*0.25, h*0.14, w*0.50, h*0.62)));

    // Thin red border on body
    canvas.drawRRect(bodyRect, Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    // Nose cone
    canvas.drawPath(
      Path()..moveTo(w*0.25,h*0.14)..lineTo(w*0.50,0)..lineTo(w*0.75,h*0.14)..close(),
      Paint()..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [const Color(0xFF3a4430), const Color(0xFF5a6848), const Color(0xFF3a4430)],
      ).createShader(Rect.fromLTWH(w*0.25, 0, w*0.50, h*0.14)),
    );
    // Thin red border on nose
    canvas.drawPath(
      Path()..moveTo(w*0.25,h*0.14)..lineTo(w*0.50,0)..lineTo(w*0.75,h*0.14)..close(),
      Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 1.2,
    );

    // Iranian flag stripes
    final sl = w*0.25; final sw = w*0.50;
    final st = h*0.18; final sh = h*0.05;
    canvas.drawRect(Rect.fromLTWH(sl, st,      sw, sh), Paint()..color = const Color(0xFF1a7a30));
    canvas.drawRect(Rect.fromLTWH(sl, st+sh,   sw, sh), Paint()..color = const Color(0xFFeeeeee));
    canvas.drawRect(Rect.fromLTWH(sl, st+sh*2, sw, sh), Paint()..color = const Color(0xFFcc1010));

    // Mid ring
    canvas.drawRect(Rect.fromLTWH(w*0.25, h*0.52, w*0.50, h*0.02),
        Paint()..color = const Color(0xFF333a28));

    // Fins
    final finPaint = Paint()..shader = LinearGradient(
      colors: [const Color(0xFF4a5540), const Color(0xFF6b7a5a)],
    ).createShader(Rect.fromLTWH(0, h*0.70, w, h*0.18));
    canvas.drawPath(Path()..moveTo(w*0.25,h*0.70)..lineTo(0,h*0.88)..lineTo(w*0.25,h*0.78)..close(), finPaint);
    canvas.drawPath(Path()..moveTo(w*0.75,h*0.70)..lineTo(w,h*0.88)..lineTo(w*0.75,h*0.78)..close(), finPaint);
    canvas.drawPath(Path()..moveTo(w*0.35,h*0.72)..lineTo(w*0.15,h*0.86)..lineTo(w*0.35,h*0.80)..close(),
        Paint()..color = const Color(0xFF3a4430).withOpacity(0.65));
    canvas.drawPath(Path()..moveTo(w*0.65,h*0.72)..lineTo(w*0.85,h*0.86)..lineTo(w*0.65,h*0.80)..close(),
        Paint()..color = const Color(0xFF3a4430).withOpacity(0.65));

    // Nozzle
    canvas.drawOval(Rect.fromLTWH(w*0.34, h*0.76, w*0.32, h*0.04),
        Paint()..color = const Color(0xFF222820));

    // Fast flames (same as Iranian)
    final f1 = sin(_elapsed * 52.0);
    final f2 = sin(_elapsed * 38.0 + 1.1);
    final f3 = sin(_elapsed * 28.0 + 2.3);
    final sway    = f3 * w * 0.04;
    final outerLen = h * (0.38 + f1 * 0.06);
    final midLen   = h * (0.28 + f2 * 0.05);

    canvas.drawPath(
      Path()
        ..moveTo(w*0.34, h*0.78)
        ..cubicTo(w*0.28+f2*2, h*0.86, w*0.40+sway, h*0.78+outerLen*0.65,
            w*0.50+sway, h*0.78+outerLen)
        ..cubicTo(w*0.60+sway, h*0.78+outerLen*0.65, w*0.72+f1*2, h*0.86,
            w*0.66, h*0.78)
        ..close(),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFFcc3300), const Color(0xFFff6600),
                 const Color(0xFFffaa00), Colors.transparent],
        stops: const [0.0, 0.30, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(w*0.28, h*0.78, w*0.44, outerLen+8)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w*0.38, h*0.79)
        ..cubicTo(w*0.34+f1*1.5, h*0.87, w*0.43+sway*0.5, h*0.79+midLen*0.70,
            w*0.50+sway*0.5, h*0.79+midLen)
        ..cubicTo(w*0.57+sway*0.5, h*0.79+midLen*0.70, w*0.66+f2*1.5, h*0.87,
            w*0.62, h*0.79)
        ..close(),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.yellowAccent, Colors.transparent],
      ).createShader(Rect.fromLTWH(w*0.34, h*0.79, w*0.32, midLen+5)),
    );
  }

  void _drawOpeningWarhead(Canvas canvas, double w, double h, double p) {
    // Two halves of the missile body slide apart sideways
    final offset = p * w * 0.35;

    for (int side = 0; side < 2; side++) {
      final dx = side == 0 ? -offset : offset;
      final lx = side == 0 ? w*0.25 : w*0.50;
      final hw = w * 0.25; // half width

      canvas.save();
      canvas.translate(dx, 0);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(lx, h*0.14, hw, h*0.62), const Radius.circular(5)),
        Paint()..color = const Color(0xFF6b7a5a),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(lx, h*0.14, hw, h*0.62), const Radius.circular(5)),
        Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 1.2,
      );

      canvas.restore();
    }
  }
}
