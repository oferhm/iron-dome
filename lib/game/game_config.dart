/// ─────────────────────────────────────────────────────────────────────────
/// GAME CONFIGURATION
/// Edit this file to enable/disable missile types and set their minimum level.
/// ─────────────────────────────────────────────────────────────────────────

class GameConfig {

  // ── Missile type toggles ────────────────────────────────────────────────

  /// Standard Iranian ballistic missile — always enabled
  static const bool iranianMissile = true;

  /// Fragmentation warhead: splits into 2 bombs after appearing.
  /// Each bomb must be intercepted separately.
  static const bool fragmentationWarhead = true;

  // ── Minimum level each missile type first appears ───────────────────────

  /// Iranian missile appears from level 1
  static const int iranianMissileMinLevel = 1;

  /// Fragmentation warhead first appears from this level
  static const int fragmentationWarheadMinLevel = 2;

  // ── Fragmentation warhead tuning ────────────────────────────────────────

  /// Seconds after spawn before the warhead splits open
  static const double fragmentationSplitDelay = 1.2;

  /// Angle between the two bomb trajectories (degrees)
  static const double fragmentationSplitAngleDeg = 30.0;

  /// Speed of released bombs relative to parent missile speed (0.0–1.0)
  static const double fragmentationBombSpeedFactor = 0.70;

  /// Chance (0.0–1.0) that a spawn slot is a fragmentation warhead
  /// (when level >= fragmentationWarheadMinLevel)
  static const double fragmentationSpawnChance = 0.30;

  // ── Future missile types — add here ─────────────────────────────────────
  // static const bool clusterBomb       = false;
  // static const int  clusterBombMinLevel = 3;
  //
  // static const bool hypersonicMissile = false;
  // static const int  hypersonicMissileMinLevel = 4;
}
