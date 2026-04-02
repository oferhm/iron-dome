import 'package:flutter/foundation.dart';
import 'game_config.dart';

class DifficultyManager {
  static final DifficultyManager _instance = DifficultyManager._();
  factory DifficultyManager() => _instance;
  DifficultyManager._();

  final ValueNotifier<int> levelNotifier = ValueNotifier(1);
  int get level => levelNotifier.value;
  double _elapsedGameSeconds = 0;

  void reset() {
    levelNotifier.value = 1;
    _elapsedGameSeconds = 0;
  }

  /// Call every frame with dt. Returns true if level changed.
  bool updateTime(double dt) {
    _elapsedGameSeconds += dt;
    final newLevel = (_elapsedGameSeconds / GameConfig.levelDurationSeconds).floor() + 1;
    if (newLevel != levelNotifier.value) {
      levelNotifier.value = newLevel;
      return true;
    }
    return false;
  }

  /// Keep score-based update for compatibility (now unused but harmless)
  bool updateForScore(int score) => false;

  int get spawnIntervalMs => GameConfig.spawnIntervalMs;

  int get missilesPerBurst {
    if (level <= 2) return 1;
    if (level <= 4) return 2;
    if (level <= 7) return 3;
    return 4;
  }

  int get burstDelayMs {
    if (level <= 2) return 0;
    if (level <= 4) return 600;
    if (level <= 6) return 450;
    return 300;
  }

  double get missileSpeedMultiplier => GameConfig.speedMultiplier(level);

  String get levelLabel => 'Level $level';

  int get levelBannerColor {
    switch (level) {
      case 1:  return 0xFF4CAF50; // green
      case 2:  return 0xFFFFEB3B; // yellow
      case 3:  return 0xFFFF9800; // orange
      case 4:  return 0xFFf44336; // red
      case 5:  return 0xFFAA00FF; // purple
      case 6:  return 0xFF00BCD4; // cyan
      case 7:  return 0xFFFF4081; // pink
      case 8:  return 0xFFFF6D00; // deep orange
      case 9:  return 0xFF76FF03; // lime
      default: return 0xFFFFFFFF; // white for 10+
    }
  }
}
