import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Subtle red police-light sweep on the city skyline at level end.
/// Positioned at bottom of screen, sweeping like a siren beacon.
class PoliceLightComponent extends PositionComponent with HasGameRef {
  double _elapsed = 0;
  static const double _duration = 5.0;

  PoliceLightComponent();

  @override
  Future<void> onLoad() async {
    // Full width strip at the bottom city area
    size = Vector2(gameRef.size.x, gameRef.size.y);
    position = Vector2.zero();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final progress = _elapsed / _duration;
    // Fade in quickly, hold, fade out at the end
    final fadeOpacity = progress < 0.1
        ? progress / 0.1
        : progress > 0.85
            ? 1.0 - (progress - 0.85) / 0.15
            : 1.0;

    // Strobe pulse: fast on/off 2Hz
    final pulse = (sin(_elapsed * pi * 2.5) + 1) / 2; // 0..1
    final lightOpacity = fadeOpacity * (0.25 + pulse * 0.30);

    // Light source positioned at bottom-center-left of city
    final lightX = size.x * 0.38;
    final lightY = size.y * 0.82; // sits on city rooftop level

    // Red sweeping cone — rotates like a beacon
    final sweepAngle = _elapsed * 2.8; // rotation speed

    for (int i = 0; i < 2; i++) {
      final baseAngle = sweepAngle + i * pi; // two opposing beams
      final beamPath = Path();
      beamPath.moveTo(lightX, lightY);

      const beamWidth = 0.18; // radians
      const beamLength = 380.0;

      beamPath.lineTo(
        lightX + cos(baseAngle - beamWidth) * beamLength,
        lightY + sin(baseAngle - beamWidth) * beamLength,
      );
      beamPath.lineTo(
        lightX + cos(baseAngle + beamWidth) * beamLength,
        lightY + sin(baseAngle + beamWidth) * beamLength,
      );
      beamPath.close();

      canvas.drawPath(
        beamPath,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFff1111).withOpacity(lightOpacity * 0.55),
              const Color(0xFFff1111).withOpacity(0),
            ],
          ).createShader(Rect.fromCircle(center: Offset(lightX, lightY), radius: beamLength)),
      );
    }

    // Central beacon glow
    canvas.drawCircle(
      Offset(lightX, lightY),
      10 + pulse * 6,
      Paint()
        ..color = const Color(0xFFff2222).withOpacity(lightOpacity * 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      Offset(lightX, lightY),
      4,
      Paint()..color = Colors.white.withOpacity(lightOpacity * 0.9),
    );
  }
}
