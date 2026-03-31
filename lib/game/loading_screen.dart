import 'package:flutter/material.dart';
import 'game/sound_manager.dart';
import 'game/cloud_component.dart';
import 'game/uav_component.dart';
import 'game/fragmentation_warhead.dart';
import 'main.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});
  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  String _status   = 'Initializing...';
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this,
        duration: const Duration(seconds: 2))..repeat();
    _load();
  }

  @override
  void dispose() { _spin.dispose(); super.dispose(); }

  Future<void> _load() async {
    final steps = [
      ('Loading assets...', () async {
        await CloudComponent.preload();
        await UavComponent.preload();
        await FragmentationWarhead.preload();
      }),
      ('Loading sounds...', () async {
        await SoundManager().initialize();
      }),
      ('Starting music...', () async {
        await SoundManager().startLobbyMusic();
      }),
      ('Preparing city...', () async {
        await Future.delayed(const Duration(milliseconds: 350));
      }),
      ('Arming Iron Dome...', () async {
        await Future.delayed(const Duration(milliseconds: 300));
      }),
      ('Ready!', () async {
        await Future.delayed(const Duration(milliseconds: 200));
      }),
    ];

    for (int i = 0; i < steps.length; i++) {
      if (!mounted) return;
      setState(() {
        _status   = steps[i].$1;
        _progress = i / steps.length;
      });
      await steps[i].$2();
      if (!mounted) return;
      setState(() { _progress = (i + 1) / steps.length; });
      await Future.delayed(const Duration(milliseconds: 80));
    }

    if (!mounted) return;
    // Navigate to lobby
    await SoundManager().startLobbyMusic();
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LobbyMode()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04090f),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF04090f), Color(0xFF071828), Color(0xFF04090f)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 90),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // ── Logo ──────────────────────────────────────────────────
              AnimatedBuilder(
                animation: _spin,
                builder: (_, __) => Transform.rotate(
                  angle: _spin.value * 2 * 3.14159 * 0.05, // subtle sway
                  child: _buildLogo(),
                ),
              ),
              const SizedBox(height: 32),

              // ── Title ─────────────────────────────────────────────────
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFF4fc3f7), Colors.white, Color(0xFF4fc3f7)],
                ).createShader(b),
                child: const Text('IRON DOME',
                  style: TextStyle(color: Colors.white, fontSize: 38,
                    fontWeight: FontWeight.bold, letterSpacing: 6,
                    shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
              ),
              const SizedBox(height: 6),
              const Text('MISSILE DEFENSE SYSTEM',
                style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 3)),
              const SizedBox(height: 48),

              // ── Progress bar ──────────────────────────────────────────
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 14,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2596d4)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_status,
                    style: const TextStyle(color: Colors.white54, fontSize: 12,
                        letterSpacing: 0.5)),
                  Text('${(_progress * 100).toInt()}%',
                    style: const TextStyle(color: Color(0xFF4fc3f7),
                        fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    // Shield logo with missile silhouette
    return SizedBox(
      width: 110, height: 110,
      child: CustomPaint(painter: _ShieldPainter(progress: _progress)),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  final double progress;
  _ShieldPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;

    // Shield outline
    final shieldPath = Path()
      ..moveTo(cx, 4)
      ..lineTo(size.width - 6, 20)
      ..lineTo(size.width - 6, size.height * 0.58)
      ..quadraticBezierTo(cx, size.height, 4, size.height * 0.58)
      ..lineTo(4, 20)
      ..close();

    // Shield fill gradient
    canvas.drawPath(shieldPath, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF0d2840), Color(0xFF071828)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Shield border — glow blue
    canvas.drawPath(shieldPath, Paint()
      ..color = const Color(0xFF2596d4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);

    // Outer glow
    canvas.drawPath(shieldPath, Paint()
      ..color = const Color(0xFF2596d4).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // Missile icon inside shield (simple upward rocket)
    final mx = cx; final my = cy + 8;
    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(mx, my), width: 14, height: 34),
        const Radius.circular(4)),
      Paint()..color = const Color(0xFF4fc3f7));
    // Nose
    canvas.drawPath(Path()
      ..moveTo(mx-7, my-17)..lineTo(mx, my-27)..lineTo(mx+7, my-17)..close(),
      Paint()..color = const Color(0xFF80d8ff));
    // Fins
    canvas.drawPath(Path()
      ..moveTo(mx-7,my+10)..lineTo(mx-14,my+20)..lineTo(mx-7,my+17)..close(),
      Paint()..color = const Color(0xFF1a6fa8));
    canvas.drawPath(Path()
      ..moveTo(mx+7,my+10)..lineTo(mx+14,my+20)..lineTo(mx+7,my+17)..close(),
      Paint()..color = const Color(0xFF1a6fa8));
    // Flame
    canvas.drawPath(Path()
      ..moveTo(mx-4,my+17)..lineTo(mx,my+26)..lineTo(mx+4,my+17)..close(),
      Paint()..color = Colors.orangeAccent.withOpacity(0.9));

    // Progress fill inside shield
    if (progress > 0) {
      final fillH = size.height * 0.72 * progress;
      canvas.save();
      canvas.clipPath(shieldPath);
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - fillH - 6, size.width, fillH),
        Paint()..color = const Color(0xFF2596d4).withOpacity(0.18));
      canvas.restore();
    }
  }

  @override bool shouldRepaint(_ShieldPainter old) => old.progress != progress;
}
