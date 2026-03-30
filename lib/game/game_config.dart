/// ─────────────────────────────────────────────────────────────────────────
/// GAME CONFIGURATION — edit here to tune everything
/// ─────────────────────────────────────────────────────────────────────────
class GameConfig {

  // ── Missile toggles ─────────────────────────────────────────────────────
  static const bool iranianMissile          = true;
  static const bool fragmentationWarhead    = true;
  static const bool uavDrone               = true;

  // ── Min level for each missile type ─────────────────────────────────────
  static const int iranianMissileMinLevel       = 1;
  static const int fragmentationWarheadMinLevel = 2;
  static const int uavDroneMinLevel             = 6;

  // ── Fragmentation warhead ────────────────────────────────────────────────
  static const double fragmentationSplitDelay      = 1.2;
  static const double fragmentationSplitAngleDeg   = 30.0;
  static const double fragmentationBombSpeedFactor = 0.70;
  static const double fragmentationSpawnChance     = 0.30;
  // Level 5+: split into 3 bombs instead of 2
  static const int    fragmentationBombsLevel5     = 3;

  // ── UAV drone ────────────────────────────────────────────────────────────
  /// Chance per spawn cycle that a UAV spawns (when eligible)
  static const double uavSpawnChance           = 0.25;
  /// Height range UAV flies at: 30%–80% of screen height
  static const double uavHeightMin             = 0.30;
  static const double uavHeightMax             = 0.80;
  /// UAV speed px/s
  static const double uavSpeed                 = 90.0;
  /// Seconds before UAV randomly dives (min / max)
  static const double uavDiveDelayMin          = 1.5;
  static const double uavDiveDelayMax          = 4.0;

  // ── Level transition ─────────────────────────────────────────────────────
  static const int levelPauseSeconds = 5;

  // ── Clouds ───────────────────────────────────────────────────────────────
  static const bool   cloudsEnabled   = true;
  static const int    cloudsMinLevel  = 2;
  static const int    cloudCount      = 5;
  static const double cloudOpacity    = 0.40; // 40% visible = 60% transparent

  // ── Future missile types ─────────────────────────────────────────────────
  // static const bool clusterBomb        = false;
  // static const int  clusterBombMinLevel = 3;
}
