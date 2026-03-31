import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

class LauncherComponent extends Component with HasGameRef {
  static ui.Image? _img;
  late Vector2 _pos;
  late Vector2 _sz;

  static Future<void> preload() async {
    try {
      _img = await Flame.images.load('iron_dome_launcher.png');
      debugPrint('Launcher PNG loaded: ${_img!.width}x${_img!.height}');
    } catch (e) {
      debugPrint('Launcher load failed: $e');
    }
  }

  // Tubes tip: upper-right area of image (~68% right, 8% down)
  Vector2 get missileExitPoint => Vector2(
    _pos.x + _sz.x * 0.40,
    _pos.y + _sz.y * 0.01,
  );

  double get launchAngle => -2.5;

  Vector2 get launcherArmBase => Vector2(
    _pos.x + _sz.x * 0.52,
    _pos.y + _sz.y * 0.42,
  );

  @override
  void render(Canvas canvas) {
    final screen = gameRef.size;
    _sz  = Vector2(250, 180);
    _pos = Vector2(screen.x - _sz.x - 80, screen.y - _sz.y - 20);

    if (_img != null) {
      final src = Rect.fromLTWH(0, 0,
          _img!.width.toDouble(), _img!.height.toDouble());
      final dst = Rect.fromLTWH(_pos.x, _pos.y, _sz.x, _sz.y);

      // PNG already has transparency — draw directly
      canvas.drawImageRect(_img!, src, dst, Paint()
      ..isAntiAlias = true
      ..colorFilter = const ColorFilter.matrix([
        // R      G      B      A    offset
         1.3,   0.0,   0.0,   0.0,  10.0,  // boost red
         0.0,   1.4,   0.0,   0.0,  10.0,  // boost green more (military green)
         0.0,   0.0,   1.1,   0.0,   0.0,  // slight blue
         0.0,   0.0,   0.0,   1.0,   0.0,
      ]));

      // Ground shadow
      canvas.drawOval(
        Rect.fromLTWH(_pos.x + 20, _pos.y + _sz.y - 10, _sz.x - 40, 18),
        Paint()
          ..color = const ui.Color.fromARGB(255, 236, 232, 232).withOpacity(0.40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }
}
