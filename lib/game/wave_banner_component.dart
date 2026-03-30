import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Level-up banner — centered, noticeable but clean.
class WaveBannerComponent extends PositionComponent with HasGameRef {
  final String label;
  final Color color;

  double _elapsed = 0;
  static const double _totalDuration = 2.5;
  static const double _fadeIn  = 0.25;
  static const double _fadeOut = 1.9;

  WaveBannerComponent({required this.label, required this.color});

  @override
  Future<void> onLoad() async {
    size = Vector2(220, 52);
    // Center of screen
    position = Vector2(
      (gameRef.size.x - size.x) / 2,
      gameRef.size.y * 0.38,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _totalDuration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    double opacity;
    if (_elapsed < _fadeIn) {
      opacity = _elapsed / _fadeIn;
    } else if (_elapsed < _fadeOut) {
      opacity = 1.0;
    } else {
      opacity = 1.0 - (_elapsed - _fadeOut) / (_totalDuration - _fadeOut);
    }
    opacity = opacity.clamp(0.0, 1.0);

    final scale = _elapsed < _fadeIn
        ? 0.7 + 0.3 * (_elapsed / _fadeIn)
        : 1.0;

    canvas.save();
    // Scale from center
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(scale, scale);
    canvas.translate(-size.x / 2, -size.y / 2);

    // Outer glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-4, -4, size.x + 8, size.y + 8), const Radius.circular(18)),
      Paint()
        ..color = color.withOpacity(opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Background pill
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(14)),
      Paint()..color = Colors.black.withOpacity(opacity * 0.80),
    );

    // Colored border
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(14)),
      Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Text
    final tp = TextPainter(
      text: TextSpan(
        text: '▲  $label  ▲',
        style: TextStyle(
          color: Colors.white.withOpacity(opacity),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.5,
          shadows: [Shadow(color: color.withOpacity(opacity * 0.9), blurRadius: 12)],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);

    tp.paint(canvas, Offset((size.x - tp.width) / 2, (size.y - tp.height) / 2));
    canvas.restore();
  }
}
