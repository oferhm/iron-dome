import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// Manages all game sounds.
/// 
/// Sound files should be placed in: assets/audio/
/// Required files:
///   launch.mp3       - interceptor fires
///   explosion.mp3    - successful intercept / big boom
///   missile_fly.mp3  - looping incoming missile sound (optional)
///   hit_city.mp3     - missile hits city / life lost
///   game_over.mp3    - game over sting
///   level_up.mp3     - new wave / difficulty increase
///
/// You can find free sounds at:
///   https://freesound.org  (search: missile, explosion, rocket launch)
///   https://mixkit.co/free-sound-effects/
///
/// If audio files are missing, all calls silently do nothing.
class SoundManager {
  static final SoundManager _instance = SoundManager._();
  factory SoundManager() => _instance;
  SoundManager._();

  bool _enabled = true;
  bool _loaded = false;

  final ValueNotifier<bool> enabledNotifier = ValueNotifier(true);

  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
    enabledNotifier.value = value;
    if (!value) FlameAudio.bgm.stop();
  }

  Future<void> initialize() async {
    try {
      await FlameAudio.audioCache.loadAll([
        'launch.mp3',
        'explosion.mp3',
        'hit_city.mp3',
        'game_over.mp3',
        'level_up.mp3',
      ]);
      _loaded = true;
    } catch (_) {
      // Audio files not present — silent mode
      _loaded = false;
    }
  }

  Future<void> _play(String file, {double volume = 1.0}) async {
    if (!_enabled || !_loaded) return;
    try {
      await FlameAudio.play(file, volume: volume);
    } catch (_) {}
  }

  /// Called when interceptor missile is fired
  void playLaunch() => _play('launch.mp3', volume: 0.7);

  /// Called when interceptor hits an Iranian missile
  void playExplosion() => _play('explosion.mp3', volume: 1.0);

  /// Called when an Iranian missile hits the city
  void playHitCity() => _play('hit_city.mp3', volume: 0.9);

  /// Called on game over
  void playGameOver() => _play('game_over.mp3', volume: 1.0);

  /// Called when difficulty increases (new wave)
  void playLevelUp() => _play('level_up.mp3', volume: 0.8);

  void dispose() {
    FlameAudio.bgm.dispose();
  }
}
