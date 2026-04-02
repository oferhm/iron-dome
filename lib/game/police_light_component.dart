import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Dramatic red police-light sweep between levels — more visible.
class PoliceLightComponent extends PositionComponent with HasGameRef {
  double _elapsed = 0;
  static const double _duration = 5.0;

  PoliceLightComponent();

  @override
  Future<void> onLoad() async {
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
    final fadeOpacity = progress < 0.1
        ? progress / 0.1
        : progress > 0.80
            ? 1.0 - (progress - 0.80) / 0.20
            : 1.0;

    // Fast strobe — 4Hz flash
    final strobe = ((sin(_elapsed * pi * 4.0) + 1) / 2).clamp(0.0, 1.0);
    final lightOpacity = (fadeOpacity * (0.35 + strobe * 0.45)).clamp(0.0, 1.0);

    // Two beacon sources for more dramatic effect
    final sources = [
      Offset(size.x * 0.30, size.y * 0.80),
      Offset(size.x * 0.65, size.y * 0.80),
    ];

    for (int si = 0; si < sources.length; si++) {
      final lightX = sources[si].dx;
      final lightY = sources[si].dy;
      // Alternating rotation direction
      final sweepAngle = _elapsed * 3.5 * (si == 0 ? 1 : -1);

      for (int i = 0; i < 2; i++) {
        final baseAngle = sweepAngle + i * pi;
        const beamWidth = 0.22;
        const beamLength = 600.0;

        final beamPath = Path()
          ..moveTo(lightX, lightY)
          ..lineTo(lightX + cos(baseAngle - beamWidth) * beamLength,
                   lightY + sin(baseAngle - beamWidth) * beamLength)
          ..lineTo(lightX + cos(baseAngle + beamWidth) * beamLength,
                   lightY + sin(baseAngle + beamWidth) * beamLength)
          ..close();

        canvas.drawPath(
          beamPath,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFff0000).withOpacity((lightOpacity * 0.65).clamp(0.0, 1.0)),
                const Color(0xFFff0000).withOpacity(0),
              ],
            ).createShader(
                Rect.fromCircle(center: Offset(lightX, lightY), radius: beamLength)),
        );
      }

      // Bright beacon glow
      canvas.drawCircle(
        Offset(lightX, lightY),
        14 + strobe * 8,
        Paint()
          ..color = const Color(0xFFff2222).withOpacity((lightOpacity * 0.95).clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      // White hot center
      canvas.drawCircle(
        Offset(lightX, lightY), 5,
        Paint()..color = Colors.white.withOpacity((lightOpacity * 0.95).clamp(0.0, 1.0)),
      );
    }

    // Full-screen red tint pulse
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFFff0000).withOpacity((strobe * fadeOpacity * 0.12).clamp(0.0, 1.0)),
    );
  }
}
