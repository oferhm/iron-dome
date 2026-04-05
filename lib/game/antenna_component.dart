import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

class AntennaComponent extends Component with HasGameRef {
  static ui.Image? _img;

  static Future<void> preload() async {
    try {
      _img = await Flame.images.load('antenna.png');
      debugPrint('Antenna PNG loaded: ${_img!.width}x${_img!.height}');
    } catch (e) {
      debugPrint('Antenna load failed: $e');
    }
  }

  @override
  void render(Canvas canvas) {
    if (_img == null) return;
    final s = gameRef.size;

    const w = 200.0;
    const h = 300.0;
    final x = 120.0;
    final y = s.y - h - 20.0;

    final src = Rect.fromLTWH(0, 0,
        _img!.width.toDouble(), _img!.height.toDouble());
    final dst = Rect.fromLTWH(x, y, w, h);

    // PNG has transparency — draw directly
    canvas.drawImageRect(_img!, src, dst, Paint()..isAntiAlias = true);

    // Ground shadow
    canvas.drawOval(
      Rect.fromLTWH(x + 8, y + h - 4, w - 16, 10),
      Paint()..color = Colors.black.withOpacity(0.35),
    );
  }
}
