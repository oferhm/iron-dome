import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/iron_dome_game.dart';
import 'game/high_score_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IronDomeApp());
}

class IronDomeApp extends StatelessWidget {
  const IronDomeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Iron Dome',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        fontFamily: 'monospace',
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late IronDomeGame _game;

  @override
  void initState() {
    super.initState();
    _game = IronDomeGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'HUD':      (ctx, game) => _HudOverlay(game: game as IronDomeGame),
          'GameOver': (ctx, game) => _GameOverOverlay(game: game as IronDomeGame),
        },
        initialActiveOverlays: const ['HUD'],
      ),
    );
  }
}

// ─── HUD ─────────────────────────────────────────────────────────────────────

class _HudOverlay extends StatelessWidget {
  final IronDomeGame game;
  const _HudOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left column: title / score / best / lives ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Game title — same size as SCORE
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF4fc3f7), Color(0xFFffffff), Color(0xFF4fc3f7)],
                  ).createShader(bounds),
                  child: const Text(
                    'IRON DOME',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<int>(
                  valueListenable: game.scoreNotifier,
                  builder: (_, score, __) => _HudText('SCORE  $score'),
                ),
                ValueListenableBuilder<List<HighScoreEntry>>(
                  valueListenable: game.highScores.scoresNotifier,
                  builder: (_, entries, __) {
                    final best = entries.isEmpty ? 0 : entries.first.score;
                    return _HudText('BEST   $best', small: true, color: Colors.amberAccent);
                  },
                ),
                ListenableBuilder(
                  listenable: Listenable.merge([game.hitsNotifier, game.shotsFiredNotifier]),
                  builder: (_, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HudText('INTERCEPT  ${game.hits}', small: true, color: Colors.lightGreenAccent),
                      _HudText('FIRED      ${game.shotsFired}', small: true, color: Colors.white60),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<int>(
                  valueListenable: game.livesNotifier,
                  builder: (_, lives, __) => Row(
                    children: List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.location_city,
                          color: i < lives ? Colors.lightBlueAccent : Colors.white12,
                          size: 24),
                    )),
                  ),
                ),
                const SizedBox(height: 6),
                // ── Efficiency ──
                _EfficiencyWidget(game: game),
              ],
            ),
            const Spacer(),
            // ── Right column: wave + sound toggle ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: game.difficulty.levelNotifier,
                  builder: (_, level, __) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(game.difficulty.levelBannerColor).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('LEVEL $level',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: game.sound.enabledNotifier,
                  builder: (_, enabled, __) => GestureDetector(
                    onTap: () => game.sound.enabled = !enabled,
                    child: Icon(enabled ? Icons.volume_up : Icons.volume_off,
                        color: Colors.white70, size: 28),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Live efficiency bar shown in HUD
class _EfficiencyWidget extends StatelessWidget {
  final IronDomeGame game;
  const _EfficiencyWidget({required this.game});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([game.shotsFiredNotifier, game.hitsNotifier]),
      builder: (_, __) {
        final shots = game.shotsFired;
        final hits  = game.hits;
        final eff   = game.efficiency;
        final color = eff >= 75 ? Colors.greenAccent
                    : eff >= 50 ? Colors.yellowAccent
                    : Colors.redAccent;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _HudText('EFF ', small: true, color: Colors.white54),
                _HudText('${eff.toStringAsFixed(0)}%', small: true, color: color),
                const SizedBox(width: 6),
                _HudText('$hits/$shots', small: true, color: Colors.white38),
              ],
            ),
            const SizedBox(height: 3),
            // Progress bar
            Container(
              width: 110,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (eff / 100).clamp(0, 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HudText extends StatelessWidget {
  final String text;
  final bool small;
  final Color color;
  const _HudText(this.text, {this.small = false, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
          color: color,
          fontSize: small ? 13 : 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ));
  }
}

// ─── Game Over ────────────────────────────────────────────────────────────────

class _GameOverOverlay extends StatelessWidget {
  final IronDomeGame game;
  const _GameOverOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    final shots = game.shotsFired;
    final hits  = game.hits;
    final eff   = game.efficiency;
    final effColor = eff >= 75 ? Colors.greenAccent
                   : eff >= 50 ? Colors.yellowAccent
                   : Colors.redAccent;

    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.90),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent, width: 2),
          boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 30)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('MISSION FAILED',
                style: TextStyle(color: Colors.redAccent, fontSize: 26,
                    fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 4),
            ValueListenableBuilder<int>(
              valueListenable: game.difficulty.levelNotifier,
              builder: (_, level, __) => Text('Reached Level $level',
                  style: TextStyle(color: Color(game.difficulty.levelBannerColor), fontSize: 15)),
            ),
            const SizedBox(height: 14),
            // Score
            ValueListenableBuilder<int>(
              valueListenable: game.scoreNotifier,
              builder: (_, score, __) => Column(children: [
                Text('$score',
                    style: const TextStyle(color: Colors.white, fontSize: 44,
                        fontWeight: FontWeight.bold)),
                const Text('POINTS', style: TextStyle(color: Colors.white54,
                    fontSize: 12, letterSpacing: 3)),
              ]),
            ),
            const SizedBox(height: 16),
            // ── Efficiency summary ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Text('EFFICIENCY', style: TextStyle(color: Colors.white54,
                      fontSize: 11, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Text('${eff.toStringAsFixed(1)}%',
                      style: TextStyle(color: effColor, fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$hits hits / $shots shots fired',
                      style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 8),
                  // Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (eff / 100).clamp(0, 1),
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(effColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_efficiencyLabel(eff),
                      style: TextStyle(color: effColor.withOpacity(0.8),
                          fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            const Text('HIGH SCORES', style: TextStyle(color: Colors.amberAccent,
                fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ValueListenableBuilder<List<HighScoreEntry>>(
              valueListenable: game.highScores.scoresNotifier,
              builder: (_, entries, __) => _HighScoreTable(entries: entries),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: game.restartGame,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 12)],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.replay, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('PLAY AGAIN', style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _efficiencyLabel(double eff) {
    if (eff >= 90) return 'Iron Dome Elite 🏆';
    if (eff >= 75) return 'Sharp Shooter ⭐';
    if (eff >= 50) return 'Getting There 👍';
    if (eff >= 25) return 'Needs Practice 💪';
    return 'Wild Fire 🔥';
  }
}

class _HighScoreTable extends StatelessWidget {
  final List<HighScoreEntry> entries;
  const _HighScoreTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text('No scores yet', style: TextStyle(color: Colors.white38, fontSize: 13));
    }
    return Column(
      children: entries.take(5).toList().asMap().entries.map((e) {
        final i    = e.key;
        final entry = e.value;
        final isFirst = i == 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 26,
              child: Text('${i + 1}.',
                  style: TextStyle(
                      color: isFirst ? Colors.amber : Colors.white38,
                      fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13))),
            Expanded(child: Text('${entry.score} pts  •  Level ${entry.level}',
                style: TextStyle(color: isFirst ? Colors.white : Colors.white60, fontSize: 13))),
            Text('${entry.date.day}/${entry.date.month}',
                style: const TextStyle(color: Colors.white30, fontSize: 11)),
          ]),
        );
      }).toList(),
    );
  }
}
