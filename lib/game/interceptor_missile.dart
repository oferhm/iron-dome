import 'dart:math';
import 'game_config.dart';
import 'iron_dome_game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'iranian_missile.dart';
import 'fragmentation_bomb.dart';
import 'uav_component.dart';
import 'shield_component.dart';
import 'fragmentation_warhead.dart';
import 'smoke_trail_component.dart';
import 'explosion_component.dart';

/// Iron Dome interceptor.
/// Phase 1: launches straight up/forward from the launcher at a fixed angle.
/// Phase 2: smoothly arcs toward the target.
class InterceptorMissile extends PositionComponent with HasGameRef, CollisionCallbacks {
  final Vector2 startPosition;
  final Vector2 targetPosition;
  final double launchAngle;   // angle of launcher arm — missiles fire in this direction
  final void Function(dynamic hit) onHit;
  final VoidCallback onMiss;

  // Speed from GameConfig — scales with level
  static double get blastRadius => GameConfig.interceptorBlastRadius;
  static const double _w          = 14.0; // 20% slimmer
  static const double _h          = 66.0;

  // Arc behaviour
  static const double _launchAngleDeg = 60.0; // initial angle above horizontal (toward upper-left)
  static const double _arcDuration    = 0.35;  // seconds of straight launch (was 0.45)

  late Vector2 _velocity;
  late double  _angle;
  double       _elapsed = 0;
  bool         _arcing  = false; // true once in arc phase

  // Initial launch direction
  late Vector2 _launchDir;
  late double  _speed;
  late double  _launchAngleSaved;
  bool         _locked = false; // once true: fly straight, no more steering

  bool _isDestroyed = false;
  bool get isDestroyed => _isDestroyed;
  void markDestroyed() => _isDestroyed = true;

  static const double _puffInterval = 18.0;  // was 8.0 → spawn smoke less often
  double _distSinceLastPuff = 0;
  final Random _rng = Random();

  InterceptorMissile({
    required this.startPosition,
    required this.targetPosition,
    required this.launchAngle,
    required this.onHit,
    required this.onMiss,
  }) : super(
          position: startPosition.clone(),
          size: Vector2(_w, _h),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    // Launch in exactly the same direction the launcher arm points
    final speed = GameConfig.interceptorBaseSpeed * GameConfig.speedMultiplier((gameRef as IronDomeGame).difficulty.level);
    _launchDir = Vector2(cos(launchAngle), sin(launchAngle)).normalized();
    _velocity  = _launchDir * speed;
    _angle     = launchAngle;
    _speed     = speed;
    _launchAngleSaved = launchAngle; // save for turn limit check

    add(RectangleHitbox(size: Vector2(_w * 0.9, _h * 0.9)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDestroyed) return;

    _elapsed += dt;

    if (_elapsed < _arcDuration) {
      // Phase 1: straight launch — velocity stays constant
    } else if (!_locked) {
      // Phase 2: arc toward target until aligned, then lock direction
      final toTarget = targetPosition - position;
      if (toTarget.length > 1) {
        final targetAngle  = atan2(toTarget.y, toTarget.x);
        final currentAngle = atan2(_velocity.y, _velocity.x);

        var delta = targetAngle - currentAngle;
        while (delta >  pi) delta -= 2 * pi;
        while (delta < -pi) delta += 2 * pi;

        if (delta.abs() < 0.09) {
          // Aligned — lock onto this angle forever
          _velocity = Vector2(cos(targetAngle), sin(targetAngle)) * _speed;
          _locked = true;
        } else {
          final arcProgress = ((_elapsed - _arcDuration) / 0.6).clamp(0.0, 1.0);
          final turnRate    = 6.0 + arcProgress * 8.0;
          final turn        = delta.sign * min(delta.abs(), turnRate * dt);
          var newAngle      = currentAngle + turn;

          // Clamp to ±180° from launch to prevent loops
          var totalTurn = newAngle - _launchAngleSaved;
          while (totalTurn >  pi) totalTurn -= 2 * pi;
          while (totalTurn < -pi) totalTurn += 2 * pi;
          if (totalTurn.abs() > pi) {
            newAngle = _launchAngleSaved + totalTurn.sign * pi;
          }

          _velocity = Vector2(cos(newAngle), sin(newAngle)) * _speed;
        }
      }
    }
    // Phase 3: _locked == true → velocity unchanged, flies perfectly straight

    _angle = atan2(_velocity.y, _velocity.x);

    // Smoke puffs
    final step = _velocity * dt;
    _distSinceLastPuff += step.length;
    position += step;

    if (_distSinceLastPuff >= _puffInterval) {
      _distSinceLastPuff = 0;
      _spawnSmokePuff();
    }

    // ── Explode when reaching target ──
    final distToTarget = (position - targetPosition).length;
    if (distToTarget < 28.0) {
      _isDestroyed = true;
      _explodeAtTarget();
      return;
    }

    // Off-screen check
    final s = gameRef.size;
    if (position.x < -80 || position.x > s.x + 80 ||
        position.y < -80 || position.y > s.y + 80) {
      _isDestroyed = true;
      onMiss();
      removeFromParent();
    }
  }

  /// Returns closest distance from a point to a missile's body segment.
  /// Missile center is at [missilePos], half-length is [halfLen],
  /// traveling in direction [angle] (atan2 of velocity).
  double _distToBody(Vector2 point, Vector2 missilePos, double halfLen, double angle) {
    // The missile body runs ALONG the travel direction
    final axisX = cos(angle);  // travel direction unit vector
    final axisY = sin(angle);
    final dx = point.x - missilePos.x;
    final dy = point.y - missilePos.y;
    // Project onto travel axis — clamp to body length
    final proj = (dx * axisX + dy * axisY).clamp(-halfLen, halfLen);
    // Closest point on body centerline
    final closestX = missilePos.x + axisX * proj;
    final closestY = missilePos.y + axisY * proj;
    return Vector2(closestX - point.x, closestY - point.y).length;
  }

  /// Explode at target position. Anything within blastRadius of the target is destroyed.
  /// For missiles we check distance to the closest point on the body, not just center.
  void _explodeAtTarget() {
    bool hitAnything = false;

    for (final child in gameRef.children.toList()) {
      if (child is IranianMissile && !child.isDestroyed && !child.isRemoving) {
        // Iranian: h=148 → halfLen=74
        final d = _distToBody(targetPosition, child.position, 74.0, child.travelAngle);
        if (d <= blastRadius) { onHit(child); hitAnything = true; }

      } else if (child is FragmentationWarhead && !child.isDestroyed && !child.isRemoving) {
        // Warhead: h=148 → halfLen=74
        final d = _distToBody(targetPosition, child.position, 74.0, child.travelAngle);
        if (d <= blastRadius) { onHit(child); hitAnything = true; }

      } else if (child is FragmentationBomb && !child.isDestroyed && !child.isRemoving) {
        // Bomb: smaller, use center distance
        if ((targetPosition - child.position).length <= blastRadius) {
          onHit(child); hitAnything = true;
        }
      } else if (child is UavComponent && !child.isDestroyed && !child.isRemoving) {
        if ((targetPosition - child.position).length <= blastRadius + 20) {
          onHit(child); hitAnything = true;
        }
      } else if (child is ShieldComponent && !child.isDestroyed && !child.isRemoving) {
        // Shield: use center distance — smaller target, reward precision
        if ((targetPosition - child.position).length <= blastRadius + 10) {
          onHit(child); hitAnything = true;
        }
      }
    }

    if (!hitAnything) onMiss();

    gameRef.add(MissExplosion(position: targetPosition.clone()));
    removeFromParent();
  }

  void _spawnSmokePuff() {
    // Fast cap using game counter — no whereType scan
    if ((gameRef as IronDomeGame).smokeAtCap) return;
    final tailOffset = Vector2(-cos(_angle), -sin(_angle)) * (_h * 0.42);
    final spread     = Vector2(
      (_rng.nextDouble() - 0.5) * 4,
      (_rng.nextDouble() - 0.5) * 4,
    );
    final isHot = _rng.nextDouble() > 0.45;
    gameRef.add(SmokePuff(
      position: position + tailOffset + spread,
      lifetime: isHot ? 5.0 + _rng.nextDouble() * 2.0 : 6.0 + _rng.nextDouble() * 2.0,
      radius:   isHot ? 3.0 + _rng.nextDouble() * 2.5  : 4.0 + _rng.nextDouble() * 3.5,
      opacity:  isHot ? 0.60 : 0.45,
      color:    isHot ? const Color(0xFFd0e8f0) : const Color(0xFFb0b0b0),
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
    } else if (target is FragmentationBomb && !target.isRemoving && !target.isDestroyed) {
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
    final w = size.x; final h = size.y;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w*0.2, h*0.16, w*0.6, h*0.62), const Radius.circular(4));
    canvas.drawRRect(bodyRect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [const Color(0xFFb0c8d8), const Color(0xFFe8f4fc), const Color(0xFFb0c8d8)],
      ).createShader(Rect.fromLTWH(w*0.2, h*0.16, w*0.6, h*0.62)));
    canvas.drawRRect(bodyRect, Paint()
      ..color = const Color(0xFF7090a8)..style = PaintingStyle.stroke..strokeWidth = 0.8);

    canvas.drawPath(
      Path()..moveTo(w*0.2,h*0.16)..lineTo(w*0.5,0.0)..lineTo(w*0.8,h*0.16)..close(),
      Paint()..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [const Color(0xFF8aaabb), const Color(0xFFccdde8), const Color(0xFF8aaabb)],
      ).createShader(Rect.fromLTWH(w*0.2, 0, w*0.6, h*0.16)),
    );

    canvas.drawRect(Rect.fromLTWH(w*0.2, h*0.40, w*0.6, h*0.07), Paint()..color = const Color(0xFF1155cc));
    canvas.drawRect(Rect.fromLTWH(w*0.2, h*0.38, w*0.6, h*0.02), Paint()..color = Colors.white.withOpacity(0.7));
    canvas.drawRect(Rect.fromLTWH(w*0.2, h*0.47, w*0.6, h*0.02), Paint()..color = Colors.white.withOpacity(0.7));

    final finPaint = Paint()..shader = LinearGradient(
      colors: [const Color(0xFF8aaabb), const Color(0xFFccdde8)],
    ).createShader(Rect.fromLTWH(0, h*0.68, w, h*0.2));
    canvas.drawPath(Path()..moveTo(w*0.2,h*0.68)..lineTo(0.0,h*0.86)..lineTo(w*0.22,h*0.76)..close(), finPaint);
    canvas.drawPath(Path()..moveTo(w*0.8,h*0.68)..lineTo(w,h*0.86)..lineTo(w*0.78,h*0.76)..close(), finPaint);
    canvas.drawPath(Path()..moveTo(w*0.32,h*0.70)..lineTo(w*0.10,h*0.84)..lineTo(w*0.32,h*0.78)..close(),
        Paint()..color = const Color(0xFF8aaabb).withOpacity(0.6));
    canvas.drawPath(Path()..moveTo(w*0.68,h*0.70)..lineTo(w*0.90,h*0.84)..lineTo(w*0.68,h*0.78)..close(),
        Paint()..color = const Color(0xFF8aaabb).withOpacity(0.6));

    canvas.drawOval(Rect.fromLTWH(w*0.3, h*0.76, w*0.4, h*0.05), Paint()..color = const Color(0xFF334455));

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

/// Small blue-white explosion shown when interceptor reaches target but misses.
class MissExplosion extends PositionComponent with HasGameRef {
  double _elapsed = 0;
  static const double _dur = 0.55;
  static const double _sz  = 70.0;

  MissExplosion({required Vector2 position})
      : super(position: position, size: Vector2.all(_sz), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _dur) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final prog = (_elapsed / _dur).clamp(0.0, 1.0);
    final cx = size.x / 2;
    final cy = size.y / 2;

    // Expanding ring
    canvas.drawCircle(
      Offset(cx, cy),
      _sz * 0.5 * prog,
      Paint()
        ..color = Colors.lightBlueAccent.withOpacity((1 - prog) * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - prog),
    );

    // Central flash
    if (prog < 0.3) {
      canvas.drawCircle(
        Offset(cx, cy),
        _sz * 0.3 * (1 - prog / 0.3),
        Paint()
          ..color = Colors.white.withOpacity((1 - prog / 0.3) * 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // 6 spark dots flying outward
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3 + prog * 2;
      final r     = _sz * 0.4 * prog;
      canvas.drawCircle(
        Offset(cx + cos(angle) * r, cy + sin(angle) * r),
        3 * (1 - prog),
        Paint()..color = Colors.lightBlueAccent.withOpacity((1 - prog) * 0.9),
      );
    }
  }
}
