import 'dart:math';
import 'package:flutter/material.dart';

/// Shared flame trail particle — a small glowing dot left behind in local space.
class FlameParticle {
  double x, y;
  double life;       // 1.0 → 0.0
  final double radius;
  final Color color;

  FlameParticle({required this.x, required this.y, required this.radius, required this.color})
      : life = 1.0;

  void update(double dt) {
    life -= dt * 6.0;  // burn out fast — these are small fire sparks
    y    += dt * 18;   // drift slightly in nozzle direction
    x    += (Random().nextDouble() - 0.5) * dt * 10;
  }

  bool get isDead => life <= 0;
}

/// Draws a slim, fast-flickering rocket flame at the nozzle area.
/// Call this every render() from any missile that wants the same flame style.
///
/// [canvas]   — the canvas to draw on
/// [w], [h]   — component size
/// [t]        — elapsed time in seconds (for animation)
/// [particles] — list of FlameParticles maintained by the missile (pass same list every frame)
/// [dt]       — delta time for particle update (pass 0 if calling from render only)
/// [nozzleY]  — Y fraction where nozzle is (default 0.79 — after fins)
void drawMissileFlame(
  Canvas canvas,
  double w,
  double h,
  double t,
  List<FlameParticle> particles, {
  double nozzleY = 0.79,
}) {
  // ── Very fast flicker frequencies ──
  final f1 = sin(t * 65.0);               // ultra-fast main flicker
  final f2 = sin(t * 48.0 + 1.3);         // fast secondary
  final f3 = sin(t * 35.0 + 2.6);         // fast sway
  final f4 = sin(t * 80.0 + 0.5);         // shimmer

  // Slim width — only 28% of missile width total
  final halfW  = w * 0.14;                // half-width of outer flame
  final cx     = w * 0.50;
  final ny     = h * nozzleY;
  final sway   = f3 * w * 0.025;          // very tight sway

  // ── Outer flame — slim orange cone ──
  final outerLen = h * (0.38 + f1 * 0.07);
  canvas.drawPath(
    Path()
      ..moveTo(cx - halfW, ny)
      ..cubicTo(
        cx - halfW * 0.8 + f2,    ny + outerLen * 0.30,
        cx - halfW * 0.3 + sway,  ny + outerLen * 0.75,
        cx + sway,                 ny + outerLen,
      )
      ..cubicTo(
        cx + halfW * 0.3 + sway,  ny + outerLen * 0.75,
        cx + halfW * 0.8 + f1,    ny + outerLen * 0.30,
        cx + halfW,                ny,
      )
      ..close(),
    Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0xFFcc3300), const Color(0xFFff6600),
               const Color(0xFFffbb00), Colors.transparent],
      stops: const [0.0, 0.28, 0.60, 1.0],
    ).createShader(Rect.fromLTWH(cx - halfW, ny, halfW * 2, outerLen + 8)),
  );

  // ── Mid flame — tighter yellow-white ──
  final midHalfW = halfW * 0.55;
  final midLen   = h * (0.26 + f2 * 0.06);
  final midSway  = f4 * w * 0.018;
  canvas.drawPath(
    Path()
      ..moveTo(cx - midHalfW, ny)
      ..cubicTo(
        cx - midHalfW * 0.7 + f1,     ny + midLen * 0.35,
        cx - midHalfW * 0.2 + midSway, ny + midLen * 0.75,
        cx + midSway,                   ny + midLen,
      )
      ..cubicTo(
        cx + midHalfW * 0.2 + midSway, ny + midLen * 0.75,
        cx + midHalfW * 0.7 + f2,      ny + midLen * 0.35,
        cx + midHalfW,                  ny,
      )
      ..close(),
    Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Colors.white, Colors.yellowAccent, Colors.transparent],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromLTWH(cx - midHalfW, ny, midHalfW * 2, midLen + 5)),
  );

  // ── Inner blue-white core spike ──
  final coreHalfW = halfW * 0.25;
  final coreLen   = h * (0.18 + f4 * 0.04);
  final coreSway  = f1 * w * 0.012;
  canvas.drawPath(
    Path()
      ..moveTo(cx - coreHalfW, ny)
      ..quadraticBezierTo(cx + coreSway, ny + coreLen * 0.6, cx + coreSway, ny + coreLen)
      ..quadraticBezierTo(cx + coreSway, ny + coreLen * 0.6, cx + coreHalfW, ny)
      ..close(),
    Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Colors.white, const Color(0xFFaaddff), Colors.transparent],
    ).createShader(Rect.fromLTWH(cx - coreHalfW, ny, coreHalfW * 2, coreLen + 3)),
  );

  // ── Nozzle glow ──
  canvas.drawCircle(
    Offset(cx, ny),
    halfW * 0.8 + f4.abs() * halfW * 0.3,
    Paint()
      ..color = Colors.white.withOpacity(0.72 + f1 * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );

  // ── Fire spark trail — draw lingering particles ──
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

/// Call this every update() to spawn new particles and age existing ones.
void updateFlameParticles(List<FlameParticle> particles, double w, double dt, Random rng) {
  // Remove dead particles
  particles.removeWhere((p) => p.isDead);

  // Spawn 2–3 new sparks per frame
  final count = 2 + rng.nextInt(2);
  for (int i = 0; i < count; i++) {
    final hot = rng.nextDouble() > 0.4;
    particles.add(FlameParticle(
      x:      (rng.nextDouble() - 0.5) * w * 0.12,
      y:      2 + rng.nextDouble() * 4,
      radius: hot ? 1.5 + rng.nextDouble() * 2.0 : 1.0 + rng.nextDouble() * 1.5,
      color:  hot ? const Color(0xFFffcc44) : const Color(0xFFff6600),
    ));
  }

  // Age all particles
  for (final p in particles) {
    p.update(dt);
  }
}
