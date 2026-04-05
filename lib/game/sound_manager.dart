import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._();
  factory SoundManager() => _instance;
  SoundManager._();

  bool _musicEnabled = true;
  bool _sfxEnabled   = true;
  bool _sfxLoaded    = false;
  bool _sfxMuted     = false;
  bool _hardMuted    = false; // set true during navigation to kill all sound

  final ValueNotifier<bool> musicEnabledNotifier = ValueNotifier(true);
  final ValueNotifier<bool> sfxEnabledNotifier   = ValueNotifier(true);

  bool get musicEnabled => _musicEnabled;
  bool get sfxEnabled   => _sfxEnabled;

  void toggleMusic() {
    _musicEnabled = !_musicEnabled;
    musicEnabledNotifier.value = _musicEnabled;
    if (_musicEnabled) {
      FlameAudio.bgm.resume();
    } else {
      FlameAudio.bgm.pause();
    }
  }

  void toggleSfx() {
    _sfxEnabled = !_sfxEnabled;
    sfxEnabledNotifier.value = _sfxEnabled;
  }

  Future<void> initialize() async {
    // Load SFX cache
    int ok = 0;
    final files = [
      'launch.mp3', 'explosion.mp3', 'hit_city.mp3', 'game_over.mp3',
      'level_up.mp3', 'drone.mp3', 'siren.mp3', 'intercept_hit.mp3',
      'ground_hit.mp3', 'missile_incoming.mp3', 'metal_door.mp3',
      'big_bomb.mp3', 'gun_load.mp3',
    ];
    for (final f in files) {
      try { await FlameAudio.audioCache.load(f); ok++; }
      catch (e) { debugPrint('SFX miss: $f — $e'); }
    }
    _sfxLoaded = ok > 0;
    debugPrint('SFX: $ok/${files.length}');
  }

  Future<void> startLobbyMusic() async {
    // Do NOT unmute SFX here — only game music plays in lobby
    debugPrint('startLobbyMusic: musicEnabled=$_musicEnabled');
    try {
      FlameAudio.bgm.initialize();
      await Future.delayed(const Duration(milliseconds: 100));
      if (_musicEnabled) {
        await FlameAudio.bgm.play('lobby_music.mp3', volume: 0.45);
        debugPrint('lobby_music started');
      }
    } catch (e) {
      debugPrint('lobby music failed: $e');
    }
  }

  Future<void> startGameMusic() async {
    debugPrint('startGameMusic: musicEnabled=$_musicEnabled');
    try {
      try { await FlameAudio.bgm.stop(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
      if (_musicEnabled) {
        await FlameAudio.bgm.play('game_music.mp3', volume: 0.42);
        debugPrint('game_music started');
      }
    } catch (e) {
      debugPrint('game music failed: $e');
    }
  }

  Future<void> stopBgm() async {
    try { await FlameAudio.bgm.stop(); } catch (_) {}
  }

  void _play(String file, {double volume = 1.0}) {
    if (!_sfxEnabled || !_sfxLoaded || _sfxMuted || _hardMuted) return;
    Future(() async {
      try {
        await FlameAudio.play(file, volume: volume);
      } catch (e) {
        debugPrint('SFX fail: $file');
      }
    });
  }

  void playLaunch()          => _play('launch.mp3',          volume: 0.85);
  void playExplosion()       => _play('explosion.mp3',        volume: 1.00);
  void playInterceptHit()    => _play('intercept_hit.mp3',    volume: 1.00);
  void playHitCity()         => _play('big_bomb.mp3',         volume: 1.00);
  void playMissileIncoming() => _play('missile_incoming.mp3', volume: 0.55);
  void playMetalDoor()       => _play('metal_door.mp3',       volume: 1.00);
  void playGameOver()        => _play('game_over.mp3',        volume: 1.00);
  void playLevelUp()         => _play('level_up.mp3',         volume: 0.75);
  void playDrone()           => _play('drone.mp3',            volume: 0.65);
  void playSiren()           => _play('siren.mp3',            volume: 1.00);
  void playBigBomb()         => _play('big_bomb.mp3',         volume: 1.00);
  void playGunLoad()         => _play('gun_load.mp3',         volume: 1.00);

  void stopSfx()      { _sfxMuted = true; }
  void restoreSfx()   { _sfxMuted = false; _hardMuted = false; }
  void hardMuteAll() {
    _hardMuted = true;
    _sfxMuted  = true;
    try { FlameAudio.bgm.stop(); } catch (_) {}
    // Don't clearAll() — it removes cached SFX files needed for next game
  }
  void hardUnmute()   { _hardMuted = false; _sfxMuted = false; }

  void dispose() { try { FlameAudio.bgm.dispose(); } catch (_) {} }
}
