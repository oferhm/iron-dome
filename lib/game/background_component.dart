import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

class BackgroundComponent extends Component with HasGameRef {
  late final Sprite _skylineSprite;
  bool _loaded = false;

  @override
  Future<void> onLoad() async {
    try {
      final image = await Flame.images.load('city_skyline.png');
      _skylineSprite = Sprite(image);
      _loaded = true;
    } catch (e) {
      _loaded = false;
    }
  }

  @override
  void render(Canvas canvas) {
    final size = gameRef.size;

    if (_loaded) {
      // Draw skyline image as full background
      _skylineSprite.render(
        canvas,
        position: Vector2.zero(),
        size: size,
      );
      // Dark overlay for atmosphere
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Colors.black.withOpacity(0.15),
      );
    } else {
      // Fallback gradient background
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0a1628),
            const Color(0xFF1a2a4a),
            const Color(0xFF0d1f35),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    }
  }
}
