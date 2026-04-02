import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'game_config.dart';
import 'iron_dome_game.dart';
import 'sound_manager.dart';
import 'missile_flame.dart';
import 'package:flame/flame.dart';
import 'fragmentation_bomb.dart';

class FragmentationWarhead extends PositionComponent
    with HasGameRef, CollisionCallbacks {

  static Sprite? _doorsSprite;
  static Future<void> preload() async {
    try {
      final img = await Flame.images.load('doors.png');
      _doorsSprite = Sprite(img);
    } catch (_) {}
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

  // Door-open animation state
  double _doorProgress = 0; // 0=closed, 1=fully open
  bool _isOpening = false;

  // Same size as Iranian missile
  static const double _w = 29.0; // 20% slimmer
  static const double _h = 148.0;

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
    if (!_isDestroyed && !_hasSplit) {

    }

    if (_trail.isEmpty || (_trail.last - position).length > 9) {
      _trail.add(position.clone());
      if (_trail.length > 18) _trail.removeAt(0);
    }

    final splitDelay = GameConfig.fragmentationSplitDelay + 0.3;
    if (!_hasSplit && _elapsed >= splitDelay - 0.35) {
      if (!_isOpening) SoundManager().playGunLoad();
      _isOpening = true;
    }
    if (_isOpening && !_hasSplit) {
      _doorProgress = ((_elapsed - (splitDelay - 0.35)) / 0.35).clamp(0.0, 1.0);
    }
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
    _drawWarhead(canvas);
    canvas.restore();
  }

  void _drawWarhead(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // ── Body — identical to Iranian missile + thin red border ──
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w*0.25, h*0.14, w*0.50, h*0.62), const Radius.circular(5));
    canvas.drawRRect(bodyRect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [const Color(0xFF6b7a5a), const Color(0xFFa0b080), const Color(0xFF7a8a68)],
      ).createShader(Rect.fromLTWH(w*0.25, h*0.14, w*0.50, h*0.62)));
    canvas.drawRRect(bodyRect, Paint()
      ..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Nose
    canvas.drawPath(
      Path()..moveTo(w*0.25,h*0.14)..lineTo(w*0.50,0)..lineTo(w*0.75,h*0.14)..close(),
      Paint()..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [const Color(0xFF3a4430), const Color(0xFF5a6848), const Color(0xFF3a4430)],
      ).createShader(Rect.fromLTWH(w*0.25, 0, w*0.50, h*0.14)),
    );
    canvas.drawPath(
      Path()..moveTo(w*0.25,h*0.14)..lineTo(w*0.50,0)..lineTo(w*0.75,h*0.14)..close(),
      Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 1.2,
    );

    // Flag stripes
    final sl = w*0.25; final sw = w*0.50; final st = h*0.18; final sh = h*0.05;
    canvas.drawRect(Rect.fromLTWH(sl, st,      sw, sh), Paint()..color = const Color(0xFF1a7a30));
    canvas.drawRect(Rect.fromLTWH(sl, st+sh,   sw, sh), Paint()..color = const Color(0xFFeeeeee));
    canvas.drawRect(Rect.fromLTWH(sl, st+sh*2, sw, sh), Paint()..color = const Color(0xFFcc1010));

    // Mid ring
    canvas.drawRect(Rect.fromLTWH(w*0.25, h*0.52, w*0.50, h*0.02),
        Paint()..color = const Color(0xFF333a28));

    // ── Door animation on the lower body (warhead section) ──
    if (_isOpening && _doorProgress > 0) {
      _drawOpeningDoors(canvas, w, h, _doorProgress);
    } else if (!_isOpening) {
      // Closed: show warhead rectangle on lower body
      canvas.drawRect(
        Rect.fromLTWH(w*0.25, h*0.56, w*0.50, h*0.18),
        Paint()..color = const Color(0xFF2a3520),
      );
      canvas.drawRect(
        Rect.fromLTWH(w*0.25, h*0.56, w*0.50, h*0.18),
        Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 1.0,
      );
    }

    // Fins
    final fin = Paint()..shader = LinearGradient(
      colors: [const Color(0xFF4a5540), const Color(0xFF6b7a5a)],
    ).createShader(Rect.fromLTWH(0, h*0.70, w, h*0.18));
    canvas.drawPath(Path()..moveTo(w*0.25,h*0.70)..lineTo(0,h*0.88)..lineTo(w*0.25,h*0.78)..close(), fin);
    canvas.drawPath(Path()..moveTo(w*0.75,h*0.70)..lineTo(w,h*0.88)..lineTo(w*0.75,h*0.78)..close(), fin);
    canvas.drawPath(Path()..moveTo(w*0.35,h*0.72)..lineTo(w*0.15,h*0.86)..lineTo(w*0.35,h*0.80)..close(),
        Paint()..color = const Color(0xFF3a4430).withOpacity(0.65));
    canvas.drawPath(Path()..moveTo(w*0.65,h*0.72)..lineTo(w*0.85,h*0.86)..lineTo(w*0.65,h*0.80)..close(),
        Paint()..color = const Color(0xFF3a4430).withOpacity(0.65));

    // Nozzle
    canvas.drawOval(Rect.fromLTWH(w*0.34, h*0.76, w*0.32, h*0.04),
        Paint()..color = const Color(0xFF222820));

    // Flame
    drawMissileFlame(canvas, w, h, _elapsed, const [], nozzleY: 0.79);
  }

  void _drawOpeningDoors(Canvas canvas, double w, double h, double p) {
    final doorTop  = h * 0.54;
    final doorH    = h * 0.20;
    final doorLeft = w * 0.22;
    final doorW    = w * 0.56;
    final halfW    = doorW / 2;
    final pivotX   = doorLeft + halfW;
    final pivotY   = doorTop + doorH / 2;

    if (_doorsSprite != null) {
      // Left door — uses left half of doors image, swings left
      canvas.save();
      canvas.translate(pivotX, pivotY);
      canvas.rotate(-p * pi / 2);
      // Clip to left half
      canvas.clipRect(Rect.fromLTWH(-halfW, -doorH / 2, halfW, doorH));
      _doorsSprite!.render(canvas,
        position: Vector2(-halfW, -doorH / 2),
        size: Vector2(halfW * 2, doorH),
        overridePaint: Paint()..color = Colors.white.withOpacity(0.9),
      );
      canvas.restore();

      // Right door — uses right half, swings right
      canvas.save();
      canvas.translate(pivotX, pivotY);
      canvas.rotate(p * pi / 2);
      canvas.clipRect(Rect.fromLTWH(0, -doorH / 2, halfW, doorH));
      _doorsSprite!.render(canvas,
        position: Vector2(-halfW, -doorH / 2),
        size: Vector2(halfW * 2, doorH),
        overridePaint: Paint()..color = Colors.white.withOpacity(0.9),
      );
      canvas.restore();
    } else {
      // Fallback: grey panels
      for (int side = 0; side < 2; side++) {
        canvas.save();
        canvas.translate(pivotX, pivotY);
        canvas.rotate(side == 0 ? -p * pi / 2 : p * pi / 2);
        final dx = side == 0 ? -halfW : 0.0;
        canvas.drawRect(Rect.fromLTWH(dx, -doorH/2, halfW, doorH),
            Paint()..color = const Color(0xFF5a4030));
        canvas.drawRect(Rect.fromLTWH(dx, -doorH/2, halfW, doorH),
            Paint()..color = const Color(0xFF8a6040)..style = PaintingStyle.stroke..strokeWidth = 1.5);
        canvas.restore();
      }
    }
  }
}
