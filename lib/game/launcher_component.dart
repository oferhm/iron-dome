import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Drawn Iron Dome launcher truck — bottom right, shifted left a bit.
class LauncherComponent extends Component with HasGameRef {
  late Vector2 _pos;
  late Vector2 _sz;

  Vector2 get missileExitPoint => Vector2(
        _pos.x + _sz.x * 0.08,
        _pos.y + _sz.y * 0.12,
      );

  @override
  void render(Canvas canvas) {
    final screen = gameRef.size;
    _sz = Vector2(200, 120);
    // Shifted left: was -6, now -60 from right edge
    _pos = Vector2(screen.x - _sz.x - 60, screen.y - _sz.y - 4);
    _drawTruck(canvas, _pos, _sz);
  }

  void _drawTruck(Canvas canvas, Vector2 p, Vector2 s) {
    // Shadow
    canvas.drawOval(
      Rect.fromLTWH(p.x + 10, p.y + s.y - 8, s.x - 20, 14),
      Paint()..color = Colors.black.withOpacity(0.3),
    );

    // Truck body
    final truckBodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(p.x + s.x * 0.08, p.y + s.y * 0.42, s.x * 0.88, s.y * 0.44),
      const Radius.circular(5),
    );
    canvas.drawRRect(truckBodyRect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFF6b7a40), const Color(0xFF4a5830)],
      ).createShader(Rect.fromLTWH(p.x, p.y + s.y * 0.42, s.x, s.y * 0.44)));
    canvas.drawRRect(truckBodyRect, Paint()
      ..color = const Color(0xFF333d20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Cab
    final cabRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(p.x + s.x * 0.72, p.y + s.y * 0.30, s.x * 0.24, s.y * 0.56),
      const Radius.circular(6),
    );
    canvas.drawRRect(cabRect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFF7a8a48), const Color(0xFF556038)],
      ).createShader(Rect.fromLTWH(p.x + s.x * 0.72, p.y + s.y * 0.30, s.x * 0.24, s.y * 0.56)));
    canvas.drawRRect(cabRect, Paint()
      ..color = const Color(0xFF333d20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    // Window
    final windowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(p.x + s.x * 0.745, p.y + s.y * 0.34, s.x * 0.175, s.y * 0.20),
      const Radius.circular(3),
    );
    canvas.drawRRect(windowRect, Paint()..color = const Color(0xFF88ccee).withOpacity(0.85));
    canvas.drawRRect(windowRect, Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Headlight
    canvas.drawCircle(
      Offset(p.x + s.x * 0.945, p.y + s.y * 0.60),
      s.x * 0.022,
      Paint()..color = const Color(0xFFffee88),
    );

    // Chassis underline
    canvas.drawRect(
      Rect.fromLTWH(p.x + s.x * 0.06, p.y + s.y * 0.84, s.x * 0.90, s.y * 0.04),
      Paint()..color = const Color(0xFF222a14),
    );

    // Wheels
    for (final wx in [0.16, 0.34, 0.58, 0.76]) {
      final cx = p.x + s.x * wx;
      final cy = p.y + s.y * 0.91;
      final r  = s.y * 0.095;
      canvas.drawCircle(Offset(cx, cy), r,        Paint()..color = const Color(0xFF1a1a1a));
      canvas.drawCircle(Offset(cx, cy), r * 0.60, Paint()..color = const Color(0xFF888888));
      canvas.drawCircle(Offset(cx, cy), r * 0.22, Paint()..color = const Color(0xFF555555));
      for (int n = 0; n < 4; n++) {
        final na = n * pi / 2;
        canvas.drawCircle(
          Offset(cx + cos(na) * r * 0.42, cy + sin(na) * r * 0.42),
          r * 0.08, Paint()..color = const Color(0xFF444444),
        );
      }
    }

    // Launcher arm (angled upper-left)
    final armBase = Offset(p.x + s.x * 0.50, p.y + s.y * 0.44);
    final armTip  = Offset(p.x + s.x * 0.06, p.y + s.y * 0.10);

    canvas.drawLine(Offset(p.x + s.x * 0.50, p.y + s.y * 0.55), armTip,
      Paint()..color = const Color(0xFF3a4428)..strokeWidth = 6..strokeCap = StrokeCap.round);
    canvas.drawLine(armBase, armTip,
      Paint()..color = const Color(0xFF556035)..strokeWidth = 14..strokeCap = StrokeCap.round);
    canvas.drawLine(
      Offset(armBase.dx + 3, armBase.dy - 3), Offset(armTip.dx + 3, armTip.dy - 3),
      Paint()..color = const Color(0xFF7a9050).withOpacity(0.6)..strokeWidth = 4..strokeCap = StrokeCap.round);

    // Pivot mount
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(armBase.dx - 10, armBase.dy - 8, 20, 16), const Radius.circular(3)),
      Paint()..color = const Color(0xFF3a4428),
    );

    _drawMissileOnTube(canvas, armTip, armBase);
  }

  void _drawMissileOnTube(Canvas canvas, Offset tip, Offset base) {
    final dx = tip.dx - base.dx;
    final dy = tip.dy - base.dy;
    final tubeAngle = atan2(dy, dx);
    final midX = tip.dx + (base.dx - tip.dx) * 0.25;
    final midY = tip.dy + (base.dy - tip.dy) * 0.25;

    canvas.save();
    canvas.translate(midX, midY);
    canvas.rotate(tubeAngle + pi / 2);

    const mw = 10.0; const mh = 28.0;
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(-mw / 2, -mh * 0.35, mw, mh * 0.65), const Radius.circular(2)),
      Paint()..color = const Color(0xFFccdde8));
    canvas.drawPath(Path()
      ..moveTo(-mw / 2, -mh * 0.35)..lineTo(0, -mh * 0.50)..lineTo(mw / 2, -mh * 0.35)..close(),
      Paint()..color = const Color(0xFF99bbcc));
    canvas.drawRect(Rect.fromLTWH(-mw / 2, -mh * 0.05, mw, mh * 0.10),
        Paint()..color = const Color(0xFF1155cc));
    canvas.drawPath(Path()
      ..moveTo(-mw / 2, mh * 0.20)..lineTo(-mw, mh * 0.38)..lineTo(-mw / 2, mh * 0.30)..close(),
      Paint()..color = const Color(0xFF8aaabb));
    canvas.drawPath(Path()
      ..moveTo(mw / 2, mh * 0.20)..lineTo(mw, mh * 0.38)..lineTo(mw / 2, mh * 0.30)..close(),
      Paint()..color = const Color(0xFF8aaabb));
    canvas.restore();
  }
}
