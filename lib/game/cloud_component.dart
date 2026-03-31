import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'game_config.dart';

/// Feathery cloud — built entirely from blurred circles.
/// No hard edges anywhere: every circle has a blur radius of at least 40% of its own radius.
class CloudComponent extends PositionComponent with HasGameRef {
  static final Random _rng = Random();

  final List<_Blob> _blobs;
  final double _speed;
  final double _opacity;
  final double _totalW;

  CloudComponent._({
    required Vector2 position,
    required List<_Blob> blobs,
    required double speed,
    required double opacity,
    required double totalW,
    required double totalH,
  })  : _blobs   = blobs,
        _speed   = speed,
        _opacity = opacity,
        _totalW  = totalW,
        super(position: position, size: Vector2(totalW, totalH), priority: 200);

  static Future<void> preload() async {}

  factory CloudComponent.random({
    required double screenW,
    required double screenH,
    bool spawnOffScreen = false,
    double staggerX = 0,
  }) {
    final rng    = _rng;
    final speed  = 10 + rng.nextDouble() * 18;
    final scale  = 0.7 + rng.nextDouble() * 1.0;

    final blobs  = <_Blob>[];
    double maxX  = 0;
    double maxY  = 0;

    // 1–3 cloud clusters stacked
    final clusters = 1 + rng.nextInt(3);
    double yBase = 0;

    for (int ci = 0; ci < clusters; ci++) {
      final cw   = (80 + rng.nextDouble() * 130) * scale;
      final ch   = (30 + rng.nextDouble() * 45)  * scale;
      final xOff = (rng.nextDouble() * 0.35) * cw;

      // ── Outermost wisps: very large, very blurred, very transparent ──
      for (int i = 0; i < 12; i++) {
        final a = rng.nextDouble() * 2 * pi;
        final d = cw * (0.38 + rng.nextDouble() * 0.28);
        final r = ch * (0.5 + rng.nextDouble() * 0.5);
        blobs.add(_Blob(
          x: xOff + cw*0.5 + cos(a)*d,
          y: yBase + ch*0.5 + sin(a)*d*0.45,
          r: r,
          opacity: 0.04 + rng.nextDouble() * 0.06,
          blur: r * 0.90, // nearly fully blurred
        ));
      }

      // ── Mid feather ring ──
      for (int i = 0; i < 14; i++) {
        final a = rng.nextDouble() * 2 * pi;
        final d = cw * (0.18 + rng.nextDouble() * 0.22);
        final r = ch * (0.35 + rng.nextDouble() * 0.35);
        blobs.add(_Blob(
          x: xOff + cw*0.5 + cos(a)*d,
          y: yBase + ch*0.5 + sin(a)*d*0.45,
          r: r,
          opacity: 0.08 + rng.nextDouble() * 0.10,
          blur: r * 0.70,
        ));
      }

      // ── Inner body: medium blurred ──
      for (int i = 0; i < 10; i++) {
        final frac = i / 10.0;
        final px   = xOff + frac * cw * 0.88 + rng.nextDouble() * cw * 0.12;
        final py   = yBase + ch * (0.12 + 0.55*sin(frac*pi)) + rng.nextDouble()*ch*0.18;
        final r    = ch * (0.32 + rng.nextDouble() * 0.28);
        blobs.add(_Blob(
          x: px, y: py, r: r,
          opacity: 0.22 + rng.nextDouble() * 0.18,
          blur: r * 0.45,
        ));
      }

      // ── Core body: less blurred, gives body substance ──
      for (int i = 0; i < 7; i++) {
        final frac = i / 7.0;
        final px   = xOff + cw*(0.08 + frac*0.82) + rng.nextDouble()*cw*0.08;
        final py   = yBase + ch*(0.15 + 0.50*sin(frac*pi)) + rng.nextDouble()*ch*0.12;
        final r    = ch * (0.25 + rng.nextDouble() * 0.20);
        blobs.add(_Blob(
          x: px, y: py, r: r,
          opacity: 0.30 + rng.nextDouble() * 0.20,
          blur: r * 0.30,
        ));
      }

      // ── Top bright highlights ──
      for (int i = 0; i < 5; i++) {
        final px = xOff + cw*(0.12 + i*0.18) + rng.nextDouble()*cw*0.10;
        final py = yBase + ch*(0.08 + rng.nextDouble()*0.22);
        final r  = ch * (0.18 + rng.nextDouble() * 0.14);
        blobs.add(_Blob(
          x: px, y: py, r: r,
          opacity: 0.38 + rng.nextDouble() * 0.18,
          blur: r * 0.18, // least blur = brightest/sharpest on top
          bright: true,
        ));
      }

      // ── Shadow underside (grey-blue) ──
      for (int i = 0; i < 5; i++) {
        final px = xOff + cw*(0.08 + i*0.20) + rng.nextDouble()*cw*0.12;
        final py = yBase + ch*(0.68 + rng.nextDouble()*0.20);
        final r  = ch * (0.20 + rng.nextDouble() * 0.14);
        blobs.add(_Blob(
          x: px, y: py, r: r,
          opacity: 0.10 + rng.nextDouble() * 0.10,
          blur: r * 0.55,
          shadow: true,
        ));
      }

      final right = xOff + cw;
      final bottom = yBase + ch * 1.1;
      if (right > maxX) maxX = right;
      if (bottom > maxY) maxY = bottom;
      yBase += ch * 0.52;
    }

    final w = maxX + 24;
    final h = maxY + 18;

    // Always spawn from the right
    final x = screenW + 30 + staggerX + rng.nextDouble() * 60;
    final y = screenH * 0.01 + rng.nextDouble() * screenH * 0.27;

    return CloudComponent._(
      position: Vector2(x, y),
      blobs: blobs,
      speed: speed,
      opacity: GameConfig.cloudOpacity,
      totalW: w,
      totalH: h,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= _speed * dt;
  }

  bool get isOffScreen => position.x < -(_totalW + 80);

  @override
  void render(Canvas canvas) {
    // Draw all blobs — sorted: shadows first, then body, then highlights
    // Shadow layer
    for (final b in _blobs.where((b) => b.shadow)) {
      canvas.drawCircle(
        Offset(b.x + 1.5, b.y + 2.5),
        b.r,
        Paint()
          ..color = const Color(0xFF9ab5cc).withOpacity(_opacity * b.opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, b.blur),
      );
    }
    // Outer wisps + mid feather + body (all white/near-white)
    for (final b in _blobs.where((b) => !b.shadow && !b.bright)) {
      canvas.drawCircle(
        Offset(b.x, b.y),
        b.r,
        Paint()
          ..color = Colors.white.withOpacity(_opacity * b.opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, b.blur),
      );
    }
    // Top highlights last (on top)
    for (final b in _blobs.where((b) => b.bright)) {
      canvas.drawCircle(
        Offset(b.x, b.y),
        b.r,
        Paint()
          ..color = Colors.white.withOpacity(_opacity * b.opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, b.blur),
      );
    }
  }
}

class _Blob {
  final double x, y, r, opacity, blur;
  final bool bright, shadow;
  const _Blob({
    required this.x, required this.y, required this.r,
    required this.opacity, required this.blur,
    this.bright = false, this.shadow = false,
  });
}
