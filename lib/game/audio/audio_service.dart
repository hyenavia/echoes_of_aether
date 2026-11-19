import 'dart:io' show Platform;

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;

import '../../domain/entities/game_settings.dart';

enum AudioCue {
  slash('sfx_slash.wav', cooldownMs: 75),
  magic('sfx_magic.wav', cooldownMs: 90),
  hit('sfx_hit.wav', cooldownMs: 75),
  heal('sfx_heal.wav', cooldownMs: 120),
  loot('sfx_loot.wav', cooldownMs: 120),
  levelUp('sfx_level_up.wav', cooldownMs: 250),
  roomClear('sfx_room_clear.wav', cooldownMs: 250);

  const AudioCue(this.assetFile, {required this.cooldownMs});

  final String assetFile;
  final int cooldownMs;
}

abstract interface class AudioBackend {
  Future<void> preloadAll(List<String> files);
  Future<void> playSfx(String file, {required double volume});
  Future<void> playBgm(String file, {required double volume});
  Future<void> stopBgm();
  Future<void> pauseBgm();
  Future<void> resumeBgm();
  Future<void> setBgmVolume(double volume);
  Future<void> dispose();
}

class NoopAudioBackend implements AudioBackend {
  const NoopAudioBackend();

  @override
  Future<void> preloadAll(List<String> files) async {}

  @override
  Future<void> playSfx(String file, {required double volume}) async {}

  @override
  Future<void> playBgm(String file, {required double volume}) async {}

  @override
  Future<void> stopBgm() async {}

  @override
  Future<void> pauseBgm() async {}

  @override
  Future<void> resumeBgm() async {}

  @override
  Future<void> setBgmVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
}

class FlameAudioBackend implements AudioBackend {
  FlameAudioBackend();

  final Map<String, AudioPool> _sfxPools = {};
  final Map<String, Future<AudioPool>> _pendingPools = {};
  bool _disposed = false;

  @override
  Future<void> preloadAll(List<String> files) async {
    await FlameAudio.audioCache.loadAll(files);
  }

  Future<AudioPool?> _getOrCreatePool(String file) async {
    if (_disposed) return null;
    final existing = _sfxPools[file];
    if (existing != null) return existing;

    final pending = _pendingPools.putIfAbsent(
      file,
      () => FlameAudio.createPool(file, minPlayers: 1, maxPlayers: 1),
    );
    try {
      final pool = await pending;
      if (_disposed) {
        await pool.dispose();
        return null;
      }
      _sfxPools[file] = pool;
      return pool;
    } finally {
      _pendingPools.remove(file);
    }
  }

  @override
  Future<void> playSfx(String file, {required double volume}) async {
    final pool = await _getOrCreatePool(file);
    if (pool == null || _disposed) return;
    await pool.start(volume: volume);
  }

  @override
  Future<void> playBgm(String file, {required double volume}) async {
    FlameAudio.bgm.initialize();
    await FlameAudio.bgm.play(file, volume: volume);
  }

  @override
  Future<void> stopBgm() => FlameAudio.bgm.stop();

  @override
  Future<void> pauseBgm() => FlameAudio.bgm.pause();

  @override
  Future<void> resumeBgm() => FlameAudio.bgm.resume();

  @override
  Future<void> setBgmVolume(double volume) =>
      FlameAudio.bgm.audioPlayer.setVolume(volume);

  @override
  Future<void> dispose() async {
    _disposed = true;
    final pools = List<AudioPool>.of(_sfxPools.values);
    _sfxPools.clear();
    for (final pool in pools) {
      await pool.dispose();
    }
  }
}

/// Layanan audio game yang aman di device maupun lingkungan headless/test.
/// Menghormati pengaturan [GameSettingsData] (BGM/SFX mute & volume) serta
/// mencegah spam efek suara beruntun via per-cue cooldown.
class AudioService {
  AudioService({
    AudioBackend? backend,
    GameSettingsData initialSettings = const GameSettingsData(),
    int Function()? nowMs,
  }) : _backend = backend ?? _defaultBackend(),
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       settingsNotifier = ValueNotifier<GameSettingsData>(initialSettings);

  static AudioBackend _defaultBackend() {
    if (!kIsWeb) {
      try {
        if (Platform.environment.containsKey('FLUTTER_TEST')) {
          return const NoopAudioBackend();
        }
      } catch (_) {}
    }
    return FlameAudioBackend();
  }

  static const String bgmForestFile = 'bgm_forest.wav';
  static const int minGlobalSfxIntervalMs = 50;

  final AudioBackend _backend;
  final int Function() _nowMs;
  final ValueNotifier<GameSettingsData> settingsNotifier;
  final Map<AudioCue, int> _lastPlayedAtMs = {};
  int _lastGlobalSfxAtMs = 0;
  bool _sfxBusy = false;

  bool _preloaded = false;
  bool _bgmPlaying = false;
  bool _bgmPaused = false;
  String? _activeBgmFile;

  GameSettingsData get settings => settingsNotifier.value;
  bool get isBgmActive => _bgmPlaying && !_bgmPaused && settings.bgmEnabled;

  Future<void> preload() async {
    if (_preloaded) return;
    _preloaded = true;
    await _runSafe(
      () => _backend.preloadAll([
        bgmForestFile,
        for (final cue in AudioCue.values) cue.assetFile,
      ]),
    );
  }

  Future<void> applySettings(GameSettingsData next) async {
    final prev = settingsNotifier.value;
    settingsNotifier.value = next;

    if (!next.bgmEnabled || next.bgmVolume <= 0) {
      if (_bgmPlaying) {
        await stopBgm();
      }
      return;
    }

    if (_bgmPlaying) {
      if ((prev.bgmVolume - next.bgmVolume).abs() > 1e-6) {
        await _runSafe(() => _backend.setBgmVolume(next.bgmVolume));
      }
    } else if (_activeBgmFile != null) {
      await startBgm(_activeBgmFile!);
    }
  }

  Future<void> startBgm([String file = bgmForestFile]) async {
    _activeBgmFile = file;
    _bgmPaused = false;
    final current = settingsNotifier.value;
    if (!current.bgmEnabled || current.bgmVolume <= 0) {
      _bgmPlaying = false;
      return;
    }
    _bgmPlaying = true;
    await _runSafe(() => _backend.playBgm(file, volume: current.bgmVolume));
  }

  Future<void> stopBgm() async {
    _bgmPlaying = false;
    _bgmPaused = false;
    await _runSafe(_backend.stopBgm);
  }

  Future<void> pauseBgm() async {
    if (!_bgmPlaying || _bgmPaused) return;
    _bgmPaused = true;
    await _runSafe(_backend.pauseBgm);
  }

  Future<void> resumeBgm() async {
    if (!_bgmPlaying || !_bgmPaused) return;
    final current = settingsNotifier.value;
    if (!current.bgmEnabled || current.bgmVolume <= 0) {
      await stopBgm();
      return;
    }
    _bgmPaused = false;
    await _runSafe(_backend.resumeBgm);
  }

  Future<void> playSfx(AudioCue cue) async {
    final current = settingsNotifier.value;
    if (!current.sfxEnabled || current.sfxVolume <= 0) return;
    if (_sfxBusy) return;

    final now = _nowMs();
    if (now - _lastGlobalSfxAtMs < minGlobalSfxIntervalMs) return;

    final last = _lastPlayedAtMs[cue];
    if (last != null && (now - last) < cue.cooldownMs) {
      return;
    }
    _lastPlayedAtMs[cue] = now;
    _lastGlobalSfxAtMs = now;
    _sfxBusy = true;
    try {
      await _runSafe(
        () => _backend.playSfx(cue.assetFile, volume: current.sfxVolume),
      );
    } finally {
      _sfxBusy = false;
    }
  }

  Future<void> dispose() async {
    await stopBgm();
    await _runSafe(_backend.dispose);
  }

  Future<void> _runSafe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Abaikan kegagalan audio platform/test headless agar gameplay tetap berjalan.
    }
  }
}
