import 'dart:async' as async;
import 'dart:math';
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'background_component.dart';
import 'launcher_component.dart';
import 'iranian_missile.dart';
import 'interceptor_missile.dart';
import 'crosshair_component.dart';
import 'explosion_component.dart';
import 'ground_explosion_component.dart';
import 'wave_banner_component.dart';
import 'police_light_component.dart';
import 'smoke_trail_component.dart';
import 'difficulty_manager.dart';
import 'sound_manager.dart';
import 'high_score_manager.dart';
import 'fragmentation_warhead.dart';
import 'fragmentation_bomb.dart';
import 'game_config.dart';
import 'cloud_component.dart';
import 'antenna_component.dart';
import 'uav_component.dart';
import 'launch_smoke_component.dart';

class IronDomeGame extends FlameGame
    with TapCallbacks, DragCallbacks, HasCollisionDetection {

  final ValueNotifier<int>  scoreNotifier       = ValueNotifier(0);
  final ValueNotifier<int>  livesNotifier       = ValueNotifier(3);
  final ValueNotifier<int>  shotsFiredNotifier  = ValueNotifier(0);
  final ValueNotifier<int>  hitsNotifier        = ValueNotifier(0);

  final DifficultyManager difficulty = DifficultyManager();
  final SoundManager      sound      = SoundManager();
  final HighScoreManager  highScores = HighScoreManager();

  int    get score      => scoreNotifier.value;
  int    get lives      => livesNotifier.value;
  int    get shotsFired => shotsFiredNotifier.value;
  int    get hits       => hitsNotifier.value;
  double get efficiency =>
      shotsFired == 0 ? 100.0 : (hits / shotsFired * 100).clamp(0, 100);

  static const int    _maxMissilesOnScreen = 5;
  // Iranian missile: 36w x 148h → half-diagonal ~75px
  // Interceptor:     17w x 66h  → half-diagonal ~34px
  // Combined hit radius = sum of half-diagonals × 0.7 (conservative)
  static const double _collisionRadius = 70.0; // generous hit detection

  late LauncherComponent launcher;
  CrosshairComponent? crosshair;

  final Random  _random       = Random();
  async.Timer?  _spawnTimer;
  async.Timer?  _uavTimer;
  bool          _inLevelPause = false;
  bool          _gameOver     = false;
  Vector2       _crosshairPosition = Vector2.zero();


  @override
  Color backgroundColor() => const Color(0xFF0a1628);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;

    // Assets preloaded by loading screen; just start game music
    await sound.startGameMusic();
    await AntennaComponent.preload();
    await LauncherComponent.preload();
    await highScores.load();
    difficulty.reset();

    await add(BackgroundComponent());
    add(AntennaComponent());
    launcher = LauncherComponent();
    await add(launcher);

    _startSpawning();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_gameOver) return;

    // ── Cloud management ──
    if (GameConfig.cloudsEnabled &&
        difficulty.level >= GameConfig.cloudsMinLevel) {
      _updateClouds();
    }

    final interceptors = children.whereType<InterceptorMissile>().toList();
    final iranians     = children.whereType<IranianMissile>().toList();
    final bombs        = children.whereType<FragmentationBomb>().toList();
    final uavs         = children.whereType<UavComponent>().toList();
    final warheads     = children.whereType<FragmentationWarhead>().toList();

    // Check interceptor vs fragmentation bombs
    for (final interceptor in interceptors) {
      if (interceptor.isRemoving || interceptor.isDestroyed) continue;
      for (final bomb in bombs) {
        if (bomb.isRemoving || bomb.isDestroyed) continue;
        if ((interceptor.position - bomb.position).length < 45.0) {
          interceptor.markDestroyed();
          _onBombHit(bomb);
          interceptor.removeFromParent();
          break;
        }
      }
    }

    // Check interceptor vs UAV
    for (final interceptor in interceptors) {
      if (interceptor.isRemoving || interceptor.isDestroyed) continue;
      for (final uav in uavs) {
        if (uav.isRemoving || uav.isDestroyed) continue;
        if ((interceptor.position - uav.position).length < 50.0) {
          interceptor.markDestroyed();
          _onUavHit(uav);
          interceptor.removeFromParent();
          break;
        }
      }
    }

    for (final interceptor in interceptors) {
      if (interceptor.isRemoving || interceptor.isDestroyed) continue;
      for (final iranian in iranians) {
        if (iranian.isRemoving || iranian.isDestroyed) continue;
        // Project the distance onto both missile axes for accurate rotated-body check.
        // We test if the interceptor center is within the Iranian missile's body rectangle
        // (accounting for its travel angle) OR within the simple radius fallback.
        final diff   = interceptor.position - iranian.position;
        final dist   = diff.length;

        // Simple radius check — generous to catch near-misses on the body
        final radiusHit = dist < _collisionRadius;

        // Axis-aligned body check: project diff onto Iranian missile's long axis
        // Iranian travels at ~80° from horizontal, positive-x direction
        final iranianAngle = iranian.travelAngle;
        final alongBody  = (diff.x * sin(iranianAngle) - diff.y * cos(iranianAngle)).abs();
        final acrossBody = (diff.x * cos(iranianAngle) + diff.y * sin(iranianAngle)).abs();
        // Asymmetric: 120px toward nose/warhead, only 30px toward tail
        final signedAlong = diff.x * sin(iranianAngle) - diff.y * cos(iranianAngle);
        final noseHit  = signedAlong > -190.0 && signedAlong < 30.0;
        final bodyHit  = noseHit && acrossBody < 32.0;

        if (radiusHit || bodyHit) {
          interceptor.markDestroyed();
          _onInterceptorHit(iranian);
          interceptor.removeFromParent();
          break;
        }
      }

      // Also check interceptor vs fragmentation warhead carrier
      if (interceptor.isRemoving || interceptor.isDestroyed) continue;
      for (final wh in warheads) {
        if (wh.isRemoving || wh.isDestroyed) continue;
        final d = (interceptor.position - wh.position).length;
        if (d < _collisionRadius) {
          interceptor.markDestroyed();
          _onWarheadHit(wh);
          interceptor.removeFromParent();
          break;
        }
      }
    }
  }

  void _spawnLaunchSmoke() {
    final exit = launcher.missileExitPoint;
    add(LaunchSmokeComponent(position: exit.clone()));
    // Additional smoke at base of launcher arm
    final base = launcher.launcherArmBase;
    add(LaunchSmokeComponent(position: base.clone()));
  }

  void _spawnUav() {
    if (_gameOver || _inLevelPause) return;

    final fromLeft = _random.nextBool();
    final height   = size.y * (GameConfig.uavHeightMin +
        _random.nextDouble() * (GameConfig.uavHeightMax - GameConfig.uavHeightMin));
    final startX   = fromLeft ? -90.0 : size.x + 90.0;

    add(UavComponent(
      fromLeft:        fromLeft,
      position:        Vector2(startX, height),
      onReachedGround: _onMissileReachedGround,
    ));
    sound.playDrone();
  }

  void _scheduleUav() {
    _uavTimer?.cancel();
    if (!GameConfig.uavDrone) return;
    if (difficulty.level < GameConfig.uavDroneMinLevel) return;
    // Spawn UAV every 6–12 seconds independently
    final delay = 6000 + _random.nextInt(6000);
    _uavTimer = async.Timer(Duration(milliseconds: delay), () {
      if (!_gameOver && !_inLevelPause) {
        _spawnUav();
      }
      // Always reschedule regardless
      if (!_gameOver) _scheduleUav();
    });
  }

  void _updateClouds() {
    final clouds = children.whereType<CloudComponent>().toList();

    // Remove clouds that drifted off the left edge
    for (final cloud in clouds) {
      if (cloud.isOffScreen) {
        cloud.removeFromParent();
        // Immediately respawn one from the right edge to keep count constant
        final newCloud = CloudComponent.random(screenW: size.x, screenH: size.y, spawnOffScreen: true);
        newCloud.priority = 200;
        add(newCloud);
      }
    }

    // Cloud count varies randomly: sometimes 0, sometimes up to cloudCount*2
    final targetCount = _random.nextInt(GameConfig.cloudCount * 2 + 1); // 0 to cloudCount*2
    final current = children.whereType<CloudComponent>().length;
    // Remove excess if we have too many
    if (current > targetCount) {
      final excess = children.whereType<CloudComponent>().take(current - targetCount).toList();
      for (final c in excess) c.removeFromParent();
    }
    for (int i = current; i < targetCount; i++) {
      final newCloud = CloudComponent.random(
        screenW: size.x,
        screenH: size.y,
        spawnOffScreen: true,
        staggerX: i * (size.x / GameConfig.cloudCount),
      );
      newCloud.priority = 200;
      add(newCloud);
    }
  }

  void _startSpawning() {
    _spawnTimer?.cancel();
    _inLevelPause = false;
    _scheduleNextSpawn();
    _scheduleUav();
  }

  void _scheduleNextSpawn() {
    if (_gameOver) return;
    _spawnTimer = async.Timer(
      Duration(milliseconds: difficulty.spawnIntervalMs),
      () {
        if (!_gameOver && !_inLevelPause) {
          _spawnBurst();
          _scheduleNextSpawn();
        }
      },
    );
  }

  void _spawnBurst() {
    final count = difficulty.missilesPerBurst;
    for (int i = 0; i < count; i++) {
      if (i == 0) {
        _spawnIranianMissile();
      } else {
        async.Future.delayed(Duration(milliseconds: difficulty.burstDelayMs * i), () {
          if (!_gameOver && !_inLevelPause) _spawnIranianMissile();
        });
      }
    }
  }

  void _spawnIranianMissile() {
    if (_gameOver || _inLevelPause) return;

    // Count all active threat types toward screen cap
    final onScreen = children.whereType<IranianMissile>().length
                   + children.whereType<FragmentationWarhead>().length
                   + children.whereType<FragmentationBomb>().length;
    if (onScreen >= _maxMissilesOnScreen) return;

    final margin   = size.x * 0.15;
    final spawnW   = size.x * 0.70;
    final startX   = margin + _random.nextDouble() * spawnW;
    final startPos = Vector2(startX, -80);

    // Decide missile type based on config + current level
    final canSpawnFrag = GameConfig.fragmentationWarhead &&
        difficulty.level >= GameConfig.fragmentationWarheadMinLevel;

    if (canSpawnFrag &&
        _random.nextDouble() < GameConfig.fragmentationSpawnChance) {
      add(FragmentationWarhead(
        startPosition:   startPos,
        speedMultiplier: difficulty.missileSpeedMultiplier,
        onReachedGround: _onMissileReachedGround,
        level:           difficulty.level,
      ));
    } else if (GameConfig.iranianMissile &&
        difficulty.level >= GameConfig.iranianMissileMinLevel) {
      add(IranianMissile(
        startPosition:   startPos,
        speedMultiplier: difficulty.missileSpeedMultiplier,
        onReachedGround: _onMissileReachedGround,
      ));
    sound.playMissileIncoming();
    }
  }

  void _onLevelUp() {
    // Grant 1 extra life on level up
    livesNotifier.value += 1;
    sound.playSiren();
    sound.playLevelUp();
    _inLevelPause = true;
    _spawnTimer?.cancel();

    // Show centered level banner
    add(WaveBannerComponent(
      label: difficulty.levelLabel,
      color: Color(difficulty.levelBannerColor),
    ));

    // Police light effect on the city for 5 seconds
    add(PoliceLightComponent());

    _uavTimer?.cancel();
    async.Future.delayed(Duration(seconds: GameConfig.levelPauseSeconds), () {
      if (!_gameOver) {
        _startSpawning();
        _scheduleUav(); // restart UAV schedule after level pause
      }
    });
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_gameOver) return;
    _crosshairPosition = event.localPosition.clone();
    _placeCrosshair(_crosshairPosition);
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (_gameOver) return;
    _crosshairPosition = event.localPosition.clone();
    _placeCrosshair(_crosshairPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_gameOver) return;
    _crosshairPosition += event.localDelta;
    crosshair?.position = _crosshairPosition.clone();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (_gameOver) return;
    _fireInterceptor();
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (_gameOver) return;
    _fireInterceptor();
  }

  void _placeCrosshair(Vector2 position) {
    crosshair?.removeFromParent();
    crosshair = CrosshairComponent(position: position.clone());
    add(crosshair!);
  }

  void _fireInterceptor() {
    final target = crosshair?.position;
    if (target == null) return;

    sound.playLaunch();
    shotsFiredNotifier.value++;
    _spawnLaunchSmoke();

    add(InterceptorMissile(
      startPosition:  launcher.missileExitPoint.clone(),
      targetPosition: target.clone(),
      launchAngle:    launcher.launchAngle,
      onHit:          (target) {
        if (target is IranianMissile)       _onInterceptorHit(target);
        else if (target is FragmentationWarhead) _onWarheadHit(target);
        else if (target is FragmentationBomb)    _onBombHit(target);
      },
      onMiss:         () {},
    ));

    crosshair?.removeFromParent();
    crosshair = null;
  }

  void _onUavHit(UavComponent target) {
    if (target.isRemoving || target.isDestroyed) return;
    target.markDestroyed();

    hitsNotifier.value++;
    final basePoints    = 80 + (difficulty.level - 1) * 30;
    final effMultiplier = shotsFired == 0 ? 1.0 : (hits / shotsFired).clamp(0.1, 1.0);
    scoreNotifier.value += (basePoints * effMultiplier).round();

    sound.playExplosion();
    sound.playInterceptHit();
    add(ExplosionComponent(position: target.position.clone()));
    target.removeFromParent();

    final levelChanged = difficulty.updateForScore(score);
    if (levelChanged) _onLevelUp();
  }

  void _onBombHit(FragmentationBomb target) {
    if (target.isRemoving || target.isDestroyed) return;
    target.markDestroyed();

    hitsNotifier.value++;
    final basePoints    = 120 + (difficulty.level - 1) * 50; // slightly more points for harder target
    final effMultiplier = shotsFired == 0 ? 1.0 : (hits / shotsFired).clamp(0.1, 1.0);
    scoreNotifier.value += (basePoints * effMultiplier).round();

    sound.playExplosion();
    add(ExplosionComponent(position: target.position.clone()));
    target.removeFromParent();

    final levelChanged = difficulty.updateForScore(score);
    if (levelChanged) _onLevelUp();
  }

  void _onWarheadHit(FragmentationWarhead target) {
    // Always explode
    add(ExplosionComponent(position: target.position.clone()));
    sound.playExplosion();
    sound.playInterceptHit();

    if (target.isRemoving || target.isDestroyed) return;
    target.markDestroyed();

    hitsNotifier.value++;
    final basePoints    = 150 + (difficulty.level - 1) * 60;
    final effMultiplier = shotsFired == 0 ? 1.0 : (hits / shotsFired).clamp(0.1, 1.0);
    scoreNotifier.value += (basePoints * effMultiplier).round();

    target.removeFromParent();
    final levelChanged = difficulty.updateForScore(score);
    if (levelChanged) _onLevelUp();
  }

  void _onInterceptorHit(IranianMissile target) {
    // Always add explosion at target position regardless of destroyed state
    add(ExplosionComponent(position: target.position.clone()));
    sound.playExplosion();
    sound.playInterceptHit();

    if (target.isRemoving || target.isDestroyed) return; // already handled
    target.markDestroyed();

    hitsNotifier.value++;
    final basePoints    = 100 + (difficulty.level - 1) * 50;
    final effMultiplier = shotsFired == 0 ? 1.0 : (hits / shotsFired).clamp(0.1, 1.0);
    scoreNotifier.value += (basePoints * effMultiplier).round();

    target.removeFromParent();

    final levelChanged = difficulty.updateForScore(score);
    if (levelChanged) _onLevelUp();
  }

  void _onMissileReachedGround() {
    if (_gameOver) return;
    sound.playHitCity();
    sound.playBigBomb();
    livesNotifier.value--;
    if (livesNotifier.value <= 0) _triggerGameOver();
  }

  void _triggerGameOver() {
    _gameOver = true;
    _spawnTimer?.cancel();
    _uavTimer?.cancel();
    sound.playGameOver();
    // Stop SFX after game over sound, keep music
    Future.delayed(const Duration(seconds: 1), () => sound.stopSfx());
    highScores.submitScore(score, difficulty.level).then((_) {
      overlays.add('GameOver');
      overlays.remove('HUD');
    });
  }

  void restartGame() {
    _gameOver     = false;
    _inLevelPause = false;
    sound.restoreSfx();
    scoreNotifier.value      = 0;
    livesNotifier.value      = 3;
    shotsFiredNotifier.value = 0;
    hitsNotifier.value       = 0;
    difficulty.reset();

    overlays.remove('GameOver');
    overlays.add('HUD');

    children.whereType<IranianMissile>().toList().forEach((m) => m.removeFromParent());
    children.whereType<InterceptorMissile>().toList().forEach((m) => m.removeFromParent());
    children.whereType<ExplosionComponent>().toList().forEach((e) => e.removeFromParent());
    children.whereType<GroundExplosionComponent>().toList().forEach((e) => e.removeFromParent());
    children.whereType<WaveBannerComponent>().toList().forEach((b) => b.removeFromParent());
    children.whereType<FragmentationWarhead>().toList().forEach((f) => f.removeFromParent());
    children.whereType<CloudComponent>().toList().forEach((c) => c.removeFromParent());
    _uavTimer?.cancel();
    children.whereType<UavComponent>().toList().forEach((u) => u.removeFromParent());
    children.whereType<FragmentationBomb>().toList().forEach((f) => f.removeFromParent());
    children.whereType<SmokePuff>().toList().forEach((s) => s.removeFromParent());
    children.whereType<PoliceLightComponent>().toList().forEach((p) => p.removeFromParent());
    crosshair?.removeFromParent();
    crosshair = null;

    _startSpawning();
  }
}
