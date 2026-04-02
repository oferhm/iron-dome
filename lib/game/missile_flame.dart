import 'dart:math';
import 'package:flutter/material.dart';

class FlameParticle {
  double x, y, life;
  final double radius;
  final Color color;

  FlameParticle({required this.x, required this.y, required this.radius, required this.color})
      : life = 1.0;

  void update(double dt) {
    life -= dt * 6.0;
    y    += dt * 18;
    x    += (Random().nextDouble() - 0.5) * dt * 10;
  }

  bool get isDead => life <= 0;
}

void drawMissileFlame(
  Canvas canvas, double w, double h, double t,
  List<FlameParticle> particles, { double nozzleY = 0.79 }) {

  final f1 = sin(t * 65.0);
  final f2 = sin(t * 48.0 + 1.3);
  final f3 = sin(t * 35.0 + 2.6);
  final f4 = sin(t * 80.0 + 0.5);

  final halfW = w * 0.14;
  final cx    = w * 0.50;
  final ny    = h * nozzleY;
  final sway  = f3 * w * 0.025;

  // Outer flame
  final outerLen = h * (0.38 + f1 * 0.07);
  canvas.drawPath(
    Path()
      ..moveTo(cx - halfW, ny)
      ..cubicTo(cx - halfW * 0.8 + f2, ny + outerLen * 0.30,
                cx - halfW * 0.3 + sway, ny + outerLen * 0.75,
                cx + sway, ny + outerLen)
      ..cubicTo(cx + halfW * 0.3 + sway, ny + outerLen * 0.75,
                cx + halfW * 0.8 + f1, ny + outerLen * 0.30,
                cx + halfW, ny)
      ..close(),
    Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [const Color(0xFFcc3300), const Color(0xFFff6600),
               const Color(0xFFffbb00), Colors.transparent],
      stops: const [0.0, 0.28, 0.60, 1.0],
    ).createShader(Rect.fromLTWH(cx - halfW, ny, halfW * 2, outerLen + 8)),
  );

  // Mid flame
  final midHalfW = halfW * 0.55;
  final midLen   = h * (0.26 + f2 * 0.06);
  final midSway  = f4 * w * 0.018;
  canvas.drawPath(
    Path()
      ..moveTo(cx - midHalfW, ny)
      ..cubicTo(cx - midHalfW * 0.7 + f1, ny + midLen * 0.35,
                cx - midHalfW * 0.2 + midSway, ny + midLen * 0.75,
                cx + midSway, ny + midLen)
      ..cubicTo(cx + midHalfW * 0.2 + midSway, ny + midLen * 0.75,
                cx + midHalfW * 0.7 + f2, ny + midLen * 0.35,
                cx + midHalfW, ny)
      ..close(),
    Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Colors.white, Colors.yellowAccent, Colors.transparent],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromLTWH(cx - midHalfW, ny, midHalfW * 2, midLen + 5)),
  );

  // Nozzle glow — NO blur (was causing GC pressure)
  canvas.drawCircle(
    Offset(cx, ny),
    halfW * 0.8 + f4.abs() * halfW * 0.3,
    Paint()..color = Colors.white.withOpacity((0.72 + f1 * 0.15).clamp(0.0, 1.0)),
  );

  // Spark trail — capped at 8 particles
  for (final p in particles) {
    if (p.isDead) continue;
    final alpha = p.life.clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(w * 0.50 + p.x, h * nozzleY + p.y),
      p.radius * alpha,
      Paint()..color = p.color.withOpacity(alpha * 0.85),
    );
  }
}

void updateFlameParticles(List<FlameParticle> particles, double w, double dt, Random rng) {
  particles.removeWhere((p) => p.isDead);

  // Hard cap — never more than 8 particles per missile
  if (particles.length < 8) {
    final hot = rng.nextDouble() > 0.4;
    particles.add(FlameParticle(
      x:      (rng.nextDouble() - 0.5) * w * 0.12,
      y:      2 + rng.nextDouble() * 4,
      radius: hot ? 1.5 + rng.nextDouble() * 2.0 : 1.0 + rng.nextDouble() * 1.5,
      color:  hot ? const Color(0xFFffcc44) : const Color(0xFFff6600),
    ));
  }

  for (final p in particles) { p.update(dt); }
}
