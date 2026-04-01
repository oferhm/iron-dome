import 'dart:math';

/// ─────────────────────────────────────────────────────────────────────────
/// GAME CONFIGURATION — single source of truth for all tunable values
/// ─────────────────────────────────────────────────────────────────────────
class GameConfig {

  // ── Missile toggles ─────────────────────────────────────────────────────
  static const bool iranianMissile       = true;
  static const bool fragmentationWarhead = true;
  static const bool uavDrone             = true;

  // ── Min level for each type ──────────────────────────────────────────────
  static const int iranianMissileMinLevel       = 1;
  static const int fragmentationWarheadMinLevel = 3;
  static const int uavDroneMinLevel             = 2;

  // ── Iranian missile physics ──────────────────────────────────────────────
  static const double iranianBaseSpeed = 70.0;
  static const double iranianAngleDeg  = 70.0;
  static final  double iranianAngleRad = iranianAngleDeg * pi / 180.0;

  // ── Fragmentation warhead / bomb ─────────────────────────────────────────
  static const double fragmentationSplitDelay      = 1.2;
  static const double fragmentationSplitAngleDeg   = 30.0;
  static const double fragmentationSpawnChance     = 0.30;
  static const double fragmentationBombSpeedFactor = 0.70;
  static const double fragmentationBombAngleDeg    = iranianAngleDeg;
  static final  double fragmentationBombAngleRad   = fragmentationBombAngleDeg * pi / 180.0;

  // ── UAV drone ────────────────────────────────────────────────────────────
  static const double uavHeightMin     = 0.10;
  static const double uavHeightMax     = 0.45;
  static const double uavBaseSpeed     = 80.0;
  static const double uavDiveBaseSpeed = 100.0;

  // ── Interceptor missile ──────────────────────────────────────────────────
  static const double interceptorBaseSpeed = 520.0;

  // ── Speed scaling per level ──────────────────────────────────────────────
  static double speedMultiplier(int level) {
    return pow(1.05, level - 1).toDouble(); // 1.05^(level-1) exponential
  }

  // ── Ground explosion height ──────────────────────────────────────────────
  static const double groundExplosionHeightFraction = 0.70;

  // ── Fragmentation 3-bomb split level ────────────────────────────────────
  static const int fragmentationBombsLevel5 = 3;

  // ── Level transition ─────────────────────────────────────────────────────
  static const int levelPauseSeconds = 3;

  // ── Score thresholds for each level ──────────────────────────────────────
  /// Score needed to reach level N. Level 1 = 0, level 2 = 500, etc.
  /// Add more entries to add more levels. Levels above list size use formula.
  static const List<int> levelScoreThresholds = [
    0,    // level 1
    500,  // level 2
    1200, // level 3
    2200, // level 4
    3500, // level 5
    5200, // level 6
    7200, // level 7
    9800, // level 8
    13000,// level 9
    17000,// level 10
  ];

  /// Returns the level for a given score (unlimited levels)
  static int levelForScore(int score) {
    // Check explicit thresholds first
    for (int i = levelScoreThresholds.length - 1; i >= 0; i--) {
      if (score >= levelScoreThresholds[i]) return i + 1;
    }
    return 1;
  }

  // ── Shield power-up ─────────────────────────────────────────────────────
  /// Probability: 0 shields (50%), 1 shield (35%), 2 shields (10%), 3 shields (5%)
  static const List<double> shieldSpawnWeights = [0.50, 0.35, 0.10, 0.05];

  /// Shield fall speed (px/sec)
  static const double shieldBaseSpeed = 100.0;

  // ── Clouds ───────────────────────────────────────────────────────────────
  static const bool   cloudsEnabled  = true;
  static const int    cloudsMinLevel = 2;
  static const int    cloudCount     = 5;
  static const double cloudOpacity   = 0.40;
}
