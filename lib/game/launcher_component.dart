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

  // Tubes tip: upper-right area of image
  Vector2 get missileExitPoint => Vector2(
    _pos.x + _sz.x * 0.20,
    _pos.y + _sz.y * 0.12,
  );

  double get launchAngle => -2.60; // ~120° upper-left, matches real Iron Dome tubes

  Vector2 get launcherArmBase => Vector2(
    _pos.x + _sz.x * 0.72,
    _pos.y + _sz.y * 0.22,
  );

  @override
  void render(Canvas canvas) {
    final screen = gameRef.size;
    _sz  = Vector2(360, 298);
    _pos = Vector2(screen.x - _sz.x - 60, screen.y - _sz.y - 0);

    if (_img != null) {
      final src = Rect.fromLTWH(0, 0,
          _img!.width.toDouble(), _img!.height.toDouble());
      final dst = Rect.fromLTWH(_pos.x, _pos.y, _sz.x, _sz.y);

      // PNG already has transparency — draw directly
      canvas.drawImageRect(_img!, src, dst, Paint()..isAntiAlias = true);

      // Ground shadow
      canvas.drawOval(
        Rect.fromLTWH(_pos.x + 20, _pos.y + _sz.y - 10, _sz.x - 40, 18),
        Paint()
          ..color = Colors.black.withOpacity(0.40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }
}
