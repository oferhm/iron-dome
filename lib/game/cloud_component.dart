import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'game_config.dart';

/// A cloud drawn with overlapping circles — fluffy, semi-transparent,
/// drifts left. Rendered at high priority above all missiles.
class CloudComponent extends PositionComponent with HasGameRef {
  static final Random _rng = Random();

  final List<_Puff> _puffs;
  final double _speed;
  final double _opacity;
  final double _cloudWidth;
  final double _cloudHeight;

  CloudComponent._({
    required Vector2 position,
    required List<_Puff> puffs,
    required double speed,
    required double opacity,
    required double cloudWidth,
    required double cloudHeight,
  })  : _puffs       = puffs,
        _speed       = speed,
        _opacity     = opacity,
        _cloudWidth  = cloudWidth,
        _cloudHeight = cloudHeight,
        super(
          position:  position,
          size:      Vector2(cloudWidth, cloudHeight),
          priority:  200, // always on top
        );

  static Future<void> preload() async {} // no image needed

  factory CloudComponent.random({
    required double screenW,
    required double screenH,
    bool spawnOffScreen = false,
  }) {
    final rng   = _rng;
    final speed = 12 + rng.nextDouble() * 22;

    // Build a realistic multi-puff cloud shape like the reference photo
    // 1–3 cloud "clusters" stacked vertically
    final clusterCount = 1 + rng.nextInt(3);
    final puffs        = <_Puff>[];
    final baseScale    = 0.7 + rng.nextDouble() * 0.8;

    double yOffset = 0;
    double maxRight = 0;

    for (int c = 0; c < clusterCount; c++) {
      final clusterW = (100 + rng.nextDouble() * 160) * baseScale;
      final clusterH = (40 + rng.nextDouble() * 55) * baseScale;
      final xShift   = (rng.nextDouble() - 0.3) * clusterW * 0.4;

      // Each cluster = 5–8 overlapping circles forming a fluffy shape
      final puffCount = 5 + rng.nextInt(4);
      for (int i = 0; i < puffCount; i++) {
        final frac  = i / puffCount;
        final px    = xShift + frac * clusterW * 0.85;
        // Vary height: taller in middle
        final py    = yOffset + clusterH * (0.1 + 0.5 * (1 - 4 * pow(frac - 0.5, 2).toDouble()).clamp(0, 1));
        final r     = clusterH * (0.35 + rng.nextDouble() * 0.35);
        // Top puffs slightly brighter
        final bright = i < puffCount ~/ 2 ? 1.0 : 0.88;
        puffs.add(_Puff(px, py, r, bright));
        if (px + r > maxRight) maxRight = px + r;
      }
      // Bottom flat base
      final baseY = yOffset + clusterH * 0.75;
      puffs.add(_Puff(xShift + clusterW * 0.1, baseY, clusterH * 0.28, 0.82));
      puffs.add(_Puff(xShift + clusterW * 0.5, baseY, clusterH * 0.32, 0.82));
      puffs.add(_Puff(xShift + clusterW * 0.85, baseY, clusterH * 0.26, 0.82));

      yOffset += clusterH * 0.60; // overlap clusters vertically
    }

    final w = maxRight + 20;
    final h = yOffset + 60.0;

    // Upper third of screen
    final y = screenH * 0.01 + rng.nextDouble() * screenH * 0.28;
    final x = spawnOffScreen
        ? screenW + 20 + rng.nextDouble() * 200
        : rng.nextDouble() * (screenW + w) - w * 0.5;

    return CloudComponent._(
      position:    Vector2(x, y),
      puffs:       puffs,
      speed:       speed,
      opacity:     GameConfig.cloudOpacity,
      cloudWidth:  w,
      cloudHeight: h,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= _speed * dt;
  }

  bool get isOffScreen => position.x < -(_cloudWidth + 60);

  @override
  void render(Canvas canvas) {
    // Draw shadow puffs first (grey-blue tint at bottom, like reference)
    for (final p in _puffs) {
      if (p.brightness < 0.9) {
        canvas.drawCircle(
          Offset(p.x + 2, p.y + 3),
          p.r,
          Paint()..color = const Color(0xFFb8cce0).withOpacity(_opacity * 0.55),
        );
      }
    }

    // Draw main white puffs
    for (final p in _puffs) {
      final col = Color.lerp(
        const Color(0xFFddeeff), // light blue-white (shadow areas)
        Colors.white,            // bright white (lit areas)
        p.brightness,
      )!;
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.r,
        Paint()..color = col.withOpacity(_opacity * (0.85 + p.brightness * 0.15)),
      );
    }

    // Soft edge highlight on top puffs
    for (final p in _puffs) {
      if (p.brightness > 0.95) {
        canvas.drawCircle(
          Offset(p.x - p.r * 0.2, p.y - p.r * 0.2),
          p.r * 0.45,
          Paint()..color = Colors.white.withOpacity(_opacity * 0.50),
        );
      }
    }
  }
}

class _Puff {
  final double x, y, r, brightness;
  const _Puff(this.x, this.y, this.r, this.brightness);
}
