import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Realistic smoke puff. Drifts left and slightly upward.
/// Fades bottom-first: the lower portion vanishes first, then the top.
class SmokePuff extends PositionComponent with HasGameRef {
  double _elapsed = 0;
  final double lifetime;
  final double _startRadius;
  final double _driftX;   // leftward drift px/s
  final double _driftY;   // upward drift px/s
  final double _peakOpacity;
  final Color  _color;
  final _rng = Random();

  SmokePuff({
    required Vector2 position,
    this.lifetime    = 7.0,
    double radius    = 5.0,
    double opacity   = 0.50,
    Color? color,
    double? driftX,
    double? driftY,
  })  : _startRadius  = radius,
        _peakOpacity  = opacity,
        _color        = color ?? const Color(0xFFc0c0c0),
        _driftX       = driftX ?? -(8 + Random().nextDouble() * 6),   // leftward
        _driftY       = driftY ?? -(1.0 + Random().nextDouble() * 2), // upward
        super(
          position: position,
          size: Vector2.all(radius * 8),
          anchor: Anchor.center,
        );

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

    // Global fade envelope: quick in, long hold, slow out
    final globalOpacity = t < 0.06
        ? (t / 0.06) * _peakOpacity
        : _peakOpacity * pow(1.0 - t, 1.4).toDouble().clamp(0.0, 1.0);

    if (globalOpacity <= 0.01) return;

    final r      = _startRadius * (1.0 + t * 3.0);
    final cx     = size.x / 2;
    final cy     = size.y / 2;

    // ── Bottom-first fade ──
    // We clip the puff with a vertical gradient that removes the bottom
    // portion first as time progresses.
    // We simulate this by drawing the puff in segments: bottom half gets
    // an extra fade multiplier based on time.
    final bottomFade = (1.0 - t * 2.2).clamp(0.0, 1.0); // bottom fades at 2.2× speed
    final topFade    = (1.0 - t * 0.8).clamp(0.0, 1.0); // top lingers longer

    // Draw 4 vertical slices from bottom to top with decreasing opacity
    final slices = 6;
    for (int i = 0; i < slices; i++) {
      final frac        = i / slices;                     // 0=bottom, 1=top
      final sliceOpacity = globalOpacity *
          (bottomFade + (topFade - bottomFade) * frac);   // lerp bottom→top fade

      if (sliceOpacity <= 0.01) continue;

      // Vertical offset from center: bottom slices are at +r, top at -r
      final yOffset = cy + r * (0.5 - frac);
      final sliceR  = r * (0.55 + 0.45 * sin(frac * pi)); // elliptical shape

      // Outer soft layer
      canvas.drawCircle(
        Offset(cx, yOffset),
        sliceR,
        Paint()
          ..color = _color.withOpacity(sliceOpacity * 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sliceR * 0.5),
      );
      // Inner denser core
      canvas.drawCircle(
        Offset(cx, yOffset),
        sliceR * 0.45,
        Paint()
          ..color = _color.withOpacity(sliceOpacity * 0.70),
      );
    }
  }
}
