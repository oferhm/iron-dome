import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Fully drawn sniper crosshair — no image needed.
class CrosshairComponent extends PositionComponent with HasGameRef {
  double _pulseTime = 0;
  static const double _size = 80.0;

  CrosshairComponent({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(_size),
          anchor: Anchor.center,
        );

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTime += dt;
  }

  @override
  void render(Canvas canvas) {
    final pulse = 1.0 + 0.06 * sin(_pulseTime * 4.0);
    final s = _size * pulse;
    final half = s / 2;
    final offset = (s - _size) / 2;

    canvas.save();
    canvas.translate(-offset, -offset);

    final redPaint = Paint()
      ..color = const Color(0xFFee2222)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final dimPaint = Paint()
      ..color = const Color(0xFFee2222).withOpacity(0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // ── Outer circle ──
    canvas.drawCircle(Offset(half, half), half * 0.92, redPaint);

    // ── Inner circle ──
    canvas.drawCircle(Offset(half, half), half * 0.30, redPaint);

    // ── Cross lines with gap around center ──
    final innerGap = half * 0.38; // gap between center and line start
    final outerGap = half * 0.88; // line ends just inside outer circle

    // Top line
    canvas.drawLine(Offset(half, half - outerGap), Offset(half, half - innerGap), redPaint);
    // Bottom line
    canvas.drawLine(Offset(half, half + innerGap), Offset(half, half + outerGap), redPaint);
    // Left line
    canvas.drawLine(Offset(half - outerGap, half), Offset(half - innerGap, half), redPaint);
    // Right line
    canvas.drawLine(Offset(half + innerGap, half), Offset(half + outerGap, half), redPaint);

    // ── Tick marks at 45° (smaller) ──
    final tickDist = half * 0.70;
    final tickLen  = half * 0.14;
    for (int i = 0; i < 4; i++) {
      final a = pi / 4 + i * pi / 2;
      final cx = half + cos(a) * tickDist;
      final cy = half + sin(a) * tickDist;
      canvas.drawLine(
        Offset(cx - cos(a) * tickLen, cy - sin(a) * tickLen),
        Offset(cx + cos(a) * tickLen, cy + sin(a) * tickLen),
        dimPaint,
      );
    }

    // ── Center dot ──
    canvas.drawCircle(
      Offset(half, half),
      3.0,
      Paint()..color = const Color(0xFFee2222),
    );

    // ── Subtle glow behind outer circle ──
    canvas.drawCircle(
      Offset(half, half),
      half * 0.92,
      Paint()
        ..color = const Color(0xFFee2222).withOpacity(0.10)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.restore();
  }
}
