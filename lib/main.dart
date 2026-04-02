import 'dart:io';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/iron_dome_game.dart';
import 'game/high_score_manager.dart';
import 'game/sound_manager.dart';
import 'loading_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IronDomeApp());
}

class IronDomeApp extends StatelessWidget {
  const IronDomeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Iron Dome',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      fontFamily: 'monospace',
    ),
    navigatorKey: navigatorKey,
    home: const LoadingScreen(),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// LIGHTNING TITLE WIDGET
// ══════════════════════════════════════════════════════════════════════════════
class _LightningTitle extends StatefulWidget {
  const _LightningTitle();
  @override State<_LightningTitle> createState() => _LightningTitleState();
}

class _LightningTitleState extends State<_LightningTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final Random _rng = Random();
  double _shimmerPos = -0.3;
  List<_Bolt> _bolts = [];
  double _nextBolt = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))
      ..addListener(_tick)
      ..repeat();
  }

  void _tick() {
    setState(() {
      _shimmerPos += 0.018;
      if (_shimmerPos > 1.3) _shimmerPos = -0.3;

      _nextBolt -= 0.05;
      if (_nextBolt <= 0) {
        _bolts.add(_Bolt(_rng));
        _nextBolt = 0.4 + _rng.nextDouble() * 1.2;
      }
      _bolts = _bolts.where((b) { b.life -= 0.08; return b.life > 0; }).toList();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: CustomPaint(
        painter: _LightningPainter(_shimmerPos, _bolts),
        child: const Center(
          child: Text('IRON DOME', style: TextStyle(
            color: Colors.white, fontSize: 54,
            fontWeight: FontWeight.bold, letterSpacing: 7,
            shadows: [Shadow(color: Colors.black, blurRadius: 14),
                      Shadow(color: Color(0xFF2596d4), blurRadius: 20)],
          )),
        ),
      ),
    );
  }
}

class _Bolt {
  final double x;
  double life;
  final List<Offset> points;
  _Bolt(Random rng) : x = rng.nextDouble(), life = 1.0,
    points = _genPoints(rng, rng.nextDouble());

  static List<Offset> _genPoints(Random r, double sx) {
    final pts = <Offset>[Offset(sx, -0.05)];
    double cx = sx;
    for (int i = 0; i < 5; i++) {
      cx += (r.nextDouble() - 0.5) * 0.15;
      pts.add(Offset(cx.clamp(0, 1), (i + 1) / 5.0));
    }
    return pts;
  }
}

class _LightningPainter extends CustomPainter {
  final double shimmer;
  final List<_Bolt> bolts;
  _LightningPainter(this.shimmer, this.bolts);

  @override
  void paint(Canvas canvas, Size size) {
    // Shimmer sweep
    final sw = size.width * 0.25;
    final sx = shimmer * size.width;
    canvas.drawRect(
      Rect.fromLTWH(sx - sw / 2, 0, sw, size.height),
      Paint()..shader = LinearGradient(
        colors: [Colors.transparent,
          Colors.white.withOpacity(0.25),
          Colors.white.withOpacity(0.45),
          Colors.white.withOpacity(0.25),
          Colors.transparent],
      ).createShader(Rect.fromLTWH(sx - sw / 2, 0, sw, size.height)),
    );

    // Lightning bolts above title
    for (final bolt in bolts) {
      if (bolt.points.length < 2) continue;
      final paint = Paint()
        ..color = const Color(0xFF80d8ff).withOpacity(bolt.life * 0.9)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final glow = Paint()
        ..color = Colors.white.withOpacity(bolt.life * 0.4)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      final path = Path()..moveTo(bolt.points[0].dx * size.width, bolt.points[0].dy * size.height);
      for (int i = 1; i < bolt.points.length; i++) {
        path.lineTo(bolt.points[i].dx * size.width, bolt.points[i].dy * size.height);
      }
      canvas.drawPath(path, glow);
      canvas.drawPath(path, paint);
    }
  }

  @override bool shouldRepaint(_LightningPainter old) => true;
}

// ══════════════════════════════════════════════════════════════════════════════
// LOBBY MODE
// ══════════════════════════════════════════════════════════════════════════════
class LobbyMode extends StatefulWidget {
  const LobbyMode({super.key});
  @override State<LobbyMode> createState() => _LobbyModeState();
}

class _LobbyModeState extends State<LobbyMode>
    with SingleTickerProviderStateMixin {
  final sound = SoundManager();
  late AnimationController _pulse;
  late Animation<double> _scale;
  bool _audioStarted = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1300))..repeat(reverse: true);
    _scale = Tween(begin: 0.96, end: 1.04).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _startAudio();
  }

  Future<void> _startAudio() async {
    if (!_audioStarted) {
      _audioStarted = true;
      // Small delay ensures game BGM is fully stopped before lobby music starts
      await Future.delayed(const Duration(milliseconds: 300));
      await sound.startLobbyMusic();
    }
  }

  @override void dispose() { _pulse.dispose(); super.dispose(); }

  void _startGame() => Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameMode()));
  void _exit() => exit(0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06101e),
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF040e1a), Color(0xFF0a1c38), Color(0xFF060e1c)]))),
        CustomPaint(painter: _StarPainter(), size: Size.infinite),
        Center(child: SingleChildScrollView(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            // Animated lightning title
            const _LightningTitle(),
            const SizedBox(height: 6),
            // Hebrew subtitle
            const Text('\u05db\u05d9\u05e4\u05ea \u05d1\u05e8\u05d6\u05dc',
              textDirection: TextDirection.rtl,
              style: TextStyle(color: Color(0xFF7ab8d4), fontSize: 24,
                  fontWeight: FontWeight.bold, letterSpacing: 2,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)])),
            const SizedBox(height: 10),
            const Text('Ready to save the city?', style: TextStyle(
                color: Colors.white54, fontSize: 16,
                fontStyle: FontStyle.italic, letterSpacing: 1.5)),
            const SizedBox(height: 50),
            // Start
            ScaleTransition(scale: _scale, child: GestureDetector(
              onTap: _startGame,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1260a0), Color(0xFF1e88d4)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                      color: const Color(0xFF1e88d4).withOpacity(0.55),
                      blurRadius: 28, spreadRadius: 2)]),
                child: const Text('START', style: TextStyle(color: Colors.white,
                    fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 5)),
              ),
            )),
            const SizedBox(height: 36),
            _LobbyToggle(icon: Icons.music_note, label: 'Game Music',
                notifier: sound.musicEnabledNotifier, onToggle: () { debugPrint('[UI] MUSIC toggled at ${DateTime.now()}'); sound.toggleMusic(); }),
            const SizedBox(height: 14),
            _LobbyToggle(icon: Icons.volume_up, label: 'Sound Effects',
                notifier: sound.sfxEnabledNotifier, onToggle: () { debugPrint('[UI] SFX toggled at ${DateTime.now()}'); sound.toggleSfx(); }),
            const SizedBox(height: 40),
            GestureDetector(onTap: _exit, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
              decoration: BoxDecoration(border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.exit_to_app, color: Colors.white38, size: 20),
                SizedBox(width: 8),
                Text('EXIT', style: TextStyle(color: Colors.white38,
                    fontSize: 16, letterSpacing: 2)),
              ]),
            )),
            const SizedBox(height: 40),
          ],
        ))),
      ]),
    );
  }
}

class _LobbyToggle extends StatelessWidget {
  final IconData icon; final String label;
  final ValueNotifier<bool> notifier; final VoidCallback onToggle;
  const _LobbyToggle({required this.icon, required this.label,
      required this.notifier, required this.onToggle});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: notifier,
    builder: (_, on, __) => GestureDetector(onTap: onToggle, child: Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(on ? 0.08 : 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: on ? Colors.lightBlueAccent.withOpacity(0.5) : Colors.white12)),
      child: Row(children: [
        Icon(on ? icon : Icons.music_off,
            color: on ? Colors.lightBlueAccent : Colors.white24, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: TextStyle(
            color: on ? Colors.white : Colors.white38,
            fontSize: 16, fontWeight: FontWeight.w500))),
        Switch(value: on, onChanged: (_) => onToggle(),
            activeColor: Colors.lightBlueAccent,
            inactiveThumbColor: Colors.white24, inactiveTrackColor: Colors.white10),
      ]),
    )),
  );
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = _Rng(42);
    for (int i = 0; i < 90; i++) {
      canvas.drawCircle(Offset(rng.next()*size.width, rng.next()*size.height),
          rng.next()*1.6+0.3,
          Paint()..color = Colors.white.withOpacity(0.15 + rng.next()*0.45));
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _Rng {
  int _s; _Rng(this._s);
  double next() { _s=(_s*1664525+1013904223)&0xFFFFFFFF; return (_s&0xFFFF)/0xFFFF; }
}

// ══════════════════════════════════════════════════════════════════════════════
// GAME MODE
// ══════════════════════════════════════════════════════════════════════════════
class GameMode extends StatefulWidget {
  const GameMode({super.key});
  @override State<GameMode> createState() => _GameModeState();
}

class _GameModeState extends State<GameMode> {
  late IronDomeGame _game;
  @override void initState() { super.initState(); _game = IronDomeGame(); }
  @override
  Widget build(BuildContext context) => Scaffold(body: GameWidget(
    game: _game,
    overlayBuilderMap: {
      'HUD':      (ctx, g) => _HudOverlay(game: g as IronDomeGame),
      'GameOver': (ctx, g) => _GameOverOverlay(game: g as IronDomeGame),
    },
    initialActiveOverlays: const ['HUD'],
  ));
}

// ── HUD ──────────────────────────────────────────────────────────────────────
class _HudOverlay extends StatelessWidget {
  final IronDomeGame game;
  const _HudOverlay({required this.game});
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Left column
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFF4fc3f7), Colors.white, Color(0xFF4fc3f7)]).createShader(b),
              child: const Text('IRON DOME', style: TextStyle(color: Colors.white,
                  fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
            ),
            // Level — muted blue fits the night sky
            ValueListenableBuilder<int>(valueListenable: game.difficulty.levelNotifier,
              builder: (_, lv, __) => Text('LEVEL $lv', style: const TextStyle(
                color: Color(0xFF7ab8d4), fontSize: 13,
                fontWeight: FontWeight.bold, letterSpacing: 1.5,
                shadows: [Shadow(color: Colors.black, blurRadius: 3)]))),
            const SizedBox(height: 2),
            ValueListenableBuilder<int>(valueListenable: game.scoreNotifier,
                builder: (_, s, __) => _HudText('SCORE  $s')),
            ValueListenableBuilder<List<HighScoreEntry>>(
              valueListenable: game.highScores.scoresNotifier,
              builder: (_, entries, __) => _HudText(
                  'BEST   ${entries.isEmpty ? 0 : entries.first.score}',
                  small: true, color: Colors.amberAccent)),
            ListenableBuilder(
              listenable: Listenable.merge([game.hitsNotifier, game.shotsFiredNotifier]),
              builder: (_, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _HudText('INTERCEPT  ${game.hits}',    small: true, color: Colors.lightGreenAccent),
                _HudText('FIRED      ${game.shotsFired}', small: true, color: Colors.white60),
              ])),
            const SizedBox(height: 4),
            _LivesWidget(game: game),
            const SizedBox(height: 4),
            _EfficiencyWidget(game: game),
          ],
        ),
        const Spacer(),
        // Right — exit + settings
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            // Exit button on top
            GestureDetector(
              onTap: () {
                debugPrint('[UI] EXIT clicked at ${DateTime.now().toIso8601String()}');
                game.fullCleanup();
                navigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LobbyMode()),
                  (_) => false,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2a2a3a),  // dark navy, not red
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24)),
                child: const Text('EXIT', style: TextStyle(
                    color: Colors.white70, fontSize: 11,
                    fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 6),
            // Settings below
            GestureDetector(
              onTap: () { debugPrint('[UI] SETTINGS clicked at ${DateTime.now()}'); _showSettings(context); },
              child: const Padding(padding: EdgeInsets.all(4),
                child: Icon(Icons.settings, color: Colors.white54, size: 26))),
          ]),
        ]),
      ]),
    ));
  }

  void _showSettings(BuildContext ctx) {
    final s = SoundManager();
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF0d1f35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.white24)),
      title: const Row(children: [
        Icon(Icons.settings, color: Colors.lightBlueAccent, size: 22),
        SizedBox(width: 10),
        Text('Settings', style: TextStyle(color: Colors.white, fontSize: 20)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Divider(color: Colors.white12),
        _LobbyToggle(icon: Icons.music_note, label: 'Game Music',
            notifier: s.musicEnabledNotifier, onToggle: () { debugPrint('[UI] MUSIC toggled at ${DateTime.now().toIso8601String()}'); s.toggleMusic(); }),
        const SizedBox(height: 8),
        _LobbyToggle(icon: Icons.volume_up, label: 'Sound Effects',
            notifier: s.sfxEnabledNotifier, onToggle: () { debugPrint('[UI] SFX toggled at ${DateTime.now().toIso8601String()}'); s.toggleSfx(); }),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('CLOSE', style: TextStyle(color: Colors.lightBlueAccent)))],
    ));
  }
}

class _HudText extends StatelessWidget {
  final String text; final bool small; final Color color;
  const _HudText(this.text, {this.small=false, this.color=Colors.white});
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
    color: color, fontSize: small ? 13 : 20, fontWeight: FontWeight.bold,
    letterSpacing: 1.2, shadows: const [Shadow(color: Colors.black, blurRadius: 4)]));
}


// ── Lives widget with shield fly-in animation and blink on hit ────────────
class _LivesWidget extends StatefulWidget {
  final IronDomeGame game;
  const _LivesWidget({required this.game});
  @override State<_LivesWidget> createState() => _LivesWidgetState();
}

class _LivesWidgetState extends State<_LivesWidget>
    with TickerProviderStateMixin {
  bool _blinking = false;
  int  _lastShieldHit = 0;
  int  _lastLivesHit  = 0;

  // Each fly-in: controller + unique key
  final List<_FlyIn> _flyIns = [];

  @override
  void initState() {
    super.initState();
    widget.game.shieldHitNotifier.addListener(_onShieldHit);
    widget.game.livesHitNotifier.addListener(_onLivesHit);
  }

  @override
  void dispose() {
    widget.game.shieldHitNotifier.removeListener(_onShieldHit);
    widget.game.livesHitNotifier.removeListener(_onLivesHit);
    for (final f in _flyIns) f.ctrl.dispose();
    super.dispose();
  }

  void _onShieldHit() {
    if (widget.game.shieldHitNotifier.value == _lastShieldHit) return;
    _lastShieldHit = widget.game.shieldHitNotifier.value;
    final ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    final flyIn = _FlyIn(ctrl: ctrl, id: DateTime.now().microsecondsSinceEpoch);
    setState(() => _flyIns.add(flyIn));
    ctrl.forward().whenComplete(() {
      if (mounted) setState(() => _flyIns.remove(flyIn));
      ctrl.dispose();
    });
  }

  void _onLivesHit() {
    if (widget.game.livesHitNotifier.value == _lastLivesHit) return;
    _lastLivesHit = widget.game.livesHitNotifier.value;
    if (_blinking) return;
    _doBlink(3);
  }

  void _doBlink(int remaining) {
    if (!mounted || remaining <= 0) {
      if (mounted) setState(() => _blinking = false);
      return;
    }
    setState(() => _blinking = true);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _blinking = false);
      Future.delayed(const Duration(milliseconds: 130), () => _doBlink(remaining - 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.game.livesNotifier,
      builder: (ctx, lives, __) {
        // Use LayoutBuilder to get position of lives row on screen
        return Stack(clipBehavior: Clip.none, children: [
          // ── Lives row ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            decoration: _blinking ? BoxDecoration(
              color: Colors.redAccent.withOpacity(0.45),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.8),
                  blurRadius: 16, spreadRadius: 3)],
            ) : const BoxDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Row(mainAxisSize: MainAxisSize.min,
              children: List.generate(lives.clamp(0, 9), (_) =>
                Padding(padding: const EdgeInsets.only(right: 3),
                  child: Image.asset('assets/images/shield.png',
                      width: 18, height: 24, fit: BoxFit.contain)))),
          ),

          // ── Flying shields ──
          for (final f in _flyIns)
            AnimatedBuilder(
              animation: f.ctrl,
              builder: (_, __) {
                final t = CurvedAnimation(
                    parent: f.ctrl, curve: Curves.easeInCubic).value;

                // Get the actual shield hit position from the game
                final hitPos = widget.game.shieldHitPosition;

                // End: near (0,0) in this local Stack = the lives row
                const endX = 4.0;
                const endY = -80.0;

                double flyT = 0;
                double scale, opacity;

                if (t < 0.30) {
                  // Phase 1: appear at hit location, big glow
                  flyT    = 0;
                  scale   = 2.0 + (t / 0.30) * 0.5; // grows 2.0→2.5
                  opacity = t / 0.30;                  // fade in
                } else {
                  // Phase 2: fly from hit position to HUD
                  flyT    = (t - 0.30) / 0.70;
                  scale   = 2.5 - flyT * 1.8;          // 2.5→0.7
                  opacity = 1.0 - flyT * 0.15;
                }

                final x = hitPos.dx - 14 + (endX - (hitPos.dx - 14)) * flyT;
                final y = hitPos.dy - 18 + (endY - (hitPos.dy - 18)) * flyT;

                final glowRadius = (1.0 - flyT) * 20.0 + 6;

                return Positioned(
                  left: x, top: y,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.scale(scale: scale.clamp(0.5, 2.5),
                      alignment: Alignment.center,
                      child: Container(
                        width: 28, height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purpleAccent.withOpacity(
                                  (0.9 * (1 - flyT)).clamp(0,1)),
                              blurRadius: glowRadius * 1.8,
                              spreadRadius: glowRadius * 0.5,
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(
                                  (0.6 * (1 - flyT * 1.5)).clamp(0,1)),
                              blurRadius: glowRadius * 0.8,
                            ),
                          ],
                        ),
                        child: Image.asset('assets/images/shield.png',
                            fit: BoxFit.contain),
                      ),
                    ),
                  ),
                );
              },
            ),
        ]);
      },
    );
  }
}

class _FlyIn {
  final AnimationController ctrl;
  final int id;
  _FlyIn({required this.ctrl, required this.id});
}

class _EfficiencyWidget extends StatelessWidget {
  final IronDomeGame game;
  const _EfficiencyWidget({required this.game});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([game.shotsFiredNotifier, game.hitsNotifier]),
    builder: (_, __) {
      final eff = game.efficiency;
      final color = eff >= 75 ? Colors.greenAccent
                  : eff >= 50 ? Colors.yellowAccent : Colors.redAccent;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _HudText('EFF ', small: true, color: Colors.white54),
          _HudText('${eff.toStringAsFixed(0)}%', small: true, color: color),
          const SizedBox(width: 6),
          _HudText('${game.hits}/${game.shotsFired}', small: true, color: Colors.white38),
        ]),
        const SizedBox(height: 3),
        Container(width: 110, height: 5,
          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(3)),
          child: FractionallySizedBox(alignment: Alignment.centerLeft,
            widthFactor: (eff/100).clamp(0,1),
            child: Container(decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))))),
      ]);
    });
}

// ── GAME OVER ─────────────────────────────────────────────────────────────────
class _GameOverOverlay extends StatelessWidget {
  final IronDomeGame game;
  const _GameOverOverlay({required this.game});

  String _effLabel(double e) {
    if (e >= 90) return 'Iron Dome Elite 🏆';
    if (e >= 75) return 'Sharp Shooter ⭐';
    if (e >= 50) return 'Getting There 👍';
    if (e >= 25) return 'Needs Practice 💪';
    return 'Wild Fire 🔥';
  }

  @override
  Widget build(BuildContext context) {
    final eff = game.efficiency;
    final effColor = eff >= 75 ? Colors.greenAccent
                   : eff >= 50 ? Colors.yellowAccent : Colors.redAccent;
    return Center(child: Container(
      width: 380,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent, width: 2),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 30)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('MISSION FAILED', style: TextStyle(color: Colors.redAccent,
            fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 4),
        const Text("You couldn't save your city", style: TextStyle(
            color: Colors.white54, fontSize: 14, fontStyle: FontStyle.italic)),
        const SizedBox(height: 4),
        ValueListenableBuilder<int>(valueListenable: game.difficulty.levelNotifier,
          builder: (_, lv, __) => Text('Reached Level $lv',
              style: TextStyle(color: Color(game.difficulty.levelBannerColor), fontSize: 15))),
        const SizedBox(height: 12),
        ValueListenableBuilder<int>(valueListenable: game.scoreNotifier,
          builder: (_, score, __) => Column(children: [
            Text('$score', style: const TextStyle(color: Colors.white,
                fontSize: 44, fontWeight: FontWeight.bold)),
            const Text('POINTS', style: TextStyle(color: Colors.white54,
                fontSize: 12, letterSpacing: 3)),
          ])),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            const Text('EFFICIENCY', style: TextStyle(color: Colors.white54,
                fontSize: 11, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text('${eff.toStringAsFixed(1)}%', style: TextStyle(
                color: effColor, fontSize: 30, fontWeight: FontWeight.bold)),
            Text('${game.hits} hits / ${game.shotsFired} shots',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: (eff/100).clamp(0,1),
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(effColor), minHeight: 7)),
            const SizedBox(height: 4),
            Text(_effLabel(eff), style: TextStyle(color: effColor.withOpacity(0.8),
                fontSize: 12, fontStyle: FontStyle.italic)),
          ]),
        ),
        const SizedBox(height: 12),
        const Divider(color: Colors.white12),
        const SizedBox(height: 4),
        const Text('HIGH SCORES', style: TextStyle(color: Colors.amberAccent,
            fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ValueListenableBuilder<List<HighScoreEntry>>(
          valueListenable: game.highScores.scoresNotifier,
          builder: (_, entries, __) => _HighScoreTable(entries: entries)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _Btn('PLAY AGAIN', Icons.replay, Colors.green, () {
            debugPrint('[UI] PLAY AGAIN clicked at ${DateTime.now().toIso8601String()}');
            game.fullCleanup();
            navigatorKey.currentState?.pushReplacement(
              MaterialPageRoute(builder: (_) => const GameMode()),
            );
          })),
          const SizedBox(width: 10),
          Expanded(child: _LobbyBtn(game: game)),
        ]),
      ]),
    ));
  }
}

class _HighScoreTable extends StatelessWidget {
  final List<HighScoreEntry> entries;
  const _HighScoreTable({required this.entries});
  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const Text('No scores yet',
        style: TextStyle(color: Colors.white38, fontSize: 13));
    return Column(children: entries.take(5).toList().asMap().entries.map((e) {
      final i = e.key; final entry = e.value; final isFirst = i == 0;
      return Padding(padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 24, child: Text('${i+1}.',
            style: TextStyle(color: isFirst ? Colors.amber : Colors.white38,
                fontWeight: isFirst ? FontWeight.bold : FontWeight.normal, fontSize: 13))),
          Expanded(child: Text('${entry.score} pts  •  Level ${entry.level}',
              style: TextStyle(color: isFirst ? Colors.white : Colors.white60, fontSize: 13))),
          Text('${entry.date.day}/${entry.date.month}',
              style: const TextStyle(color: Colors.white30, fontSize: 11)),
        ]));
    }).toList());
  }
}

class _LobbyBtn extends StatelessWidget {
  final IronDomeGame game;
  const _LobbyBtn({required this.game});
  @override
  Widget build(BuildContext context) {
    return _Btn('LOBBY', Icons.home, Colors.blueGrey, () {
      debugPrint('[UI] LOBBY clicked at ${DateTime.now().toIso8601String()}');
      game.fullCleanup();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LobbyMode()),
        (_) => false,
      );
    });
  }
}

class _Btn extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final VoidCallback onTap;
  const _Btn(this.label, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10)]),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
      ]),
    ));
}
