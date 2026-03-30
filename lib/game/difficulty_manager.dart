import 'package:flutter/foundation.dart';

class DifficultyManager {
  static final DifficultyManager _instance = DifficultyManager._();
  factory DifficultyManager() => _instance;
  DifficultyManager._();

  final ValueNotifier<int> levelNotifier = ValueNotifier(1);
  int get level => levelNotifier.value;

  void reset() => levelNotifier.value = 1;

  bool updateForScore(int score) {
    final newLevel = _levelForScore(score);
    if (newLevel != levelNotifier.value) {
      levelNotifier.value = newLevel;
      return true;
    }
    return false;
  }

  int _levelForScore(int score) {
    if (score >= 3500) return 5;
    if (score >= 2200) return 4;
    if (score >= 1200) return 3;
    if (score >= 500)  return 2;
    return 1;
  }

  int get spawnIntervalMs {
    switch (level) {
      case 1: return 4500;
      case 2: return 4000;
      case 3: return 3500;
      case 4: return 3000;
      default: return 2500;
    }
  }

  int get missilesPerBurst {
    switch (level) {
      case 1:
      case 2: return 1;
      case 3:
      case 4: return 2;
      default: return 3;
    }
  }

  int get burstDelayMs {
    switch (level) {
      case 1:
      case 2: return 0;
      case 3: return 600;
      case 4: return 500;
      default: return 400;
    }
  }

  double get missileSpeedMultiplier {
    switch (level) {
      case 1: return 1.00;
      case 2: return 1.10;
      case 3: return 1.20;
      case 4: return 1.35;
      default: return 1.50;
    }
  }

  String get levelLabel => 'Level $level';

  int get levelBannerColor {
    switch (level) {
      case 1: return 0xFF4CAF50;
      case 2: return 0xFFFFEB3B;
      case 3: return 0xFFFF9800;
      case 4: return 0xFFf44336;
      default: return 0xFFAA00FF;
    }
  }
}
