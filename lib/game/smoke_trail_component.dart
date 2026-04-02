import 'dart:math';
import 'package:flame/components.dart';
import 'iron_dome_game.dart';
import 'package:flutter/material.dart';

/// Smoke puff — simplified for performance.
/// Max 60 on screen (enforced by spawner).
class SmokePuff extends PositionComponent with HasGameRef {
  double _elapsed = 0;
  final double lifetime;
  final double _startRadius;
  final double _driftX;
  final double _driftY;
  final double _peakOpacity;
  final Color  _color;

  SmokePuff({
    required Vector2 position,
    this.lifetime    = 2.0,   // was 7.0 → 2s lifetime
    double radius    = 5.0,
    double opacity   = 0.45,
    Color? color,
    double? driftX,
    double? driftY,
  })  : _startRadius  = radius,
        _peakOpacity  = opacity.clamp(0.0, 1.0),
        _color        = color ?? const Color(0xFFc0c0c0),
        _driftX       = driftX ?? -(8 + Random().nextDouble() * 6),
        _driftY       = driftY ?? -(1.0 + Random().nextDouble() * 2),
        super(
          position: position,
          size: Vector2.all(radius * 6),
          anchor: Anchor.center,
        );

  @override
  void onMount() {
    super.onMount();
    (gameRef as IronDomeGame).onSmokePuffAdded();
  }

  @override
  void onRemove() {
    (gameRef as IronDomeGame).onSmokePuffRemoved();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    position.x += _driftX * dt;
    position.y += _driftY * dt;
    if (_elapsed >= lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / lifetime).clamp(0.0, 1.0);
    final opacity = (t < 0.1
        ? (t / 0.1) * _peakOpacity
        : _peakOpacity * (1.0 - t)).clamp(0.0, 1.0);

    if (opacity <= 0.01) return;

    final r  = _startRadius * (1.0 + t * 2.0);
    final cx = size.x / 2;
    final cy = size.y / 2;

    // Single blurred circle — no slices, no loops
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = _color.withOpacity(opacity * 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4),
    );
    canvas.drawCircle(
      Offset(cx, cy), r * 0.4,
      Paint()..color = _color.withOpacity(opacity * 0.65),
    );
  }
}
