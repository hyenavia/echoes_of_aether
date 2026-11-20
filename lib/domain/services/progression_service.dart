import 'dart:math' as math;

import '../entities/hero_ascension.dart';
import '../entities/player_progress.dart';
import '../entities/progression_config.dart';

class ProgressionResult {
  const ProgressionResult(this.progress, this.levelsGained);

  final PlayerProgress progress;
  final int levelsGained;
}

/// Aturan EXP dan leveling (GDD 3.3, Addendum v1.5). Fungsi murni: tidak mengubah input.
class ProgressionService {
  const ProgressionService(this.config, [this.heroAscensionConfig]);

  static const int kMaxGold = 999999999999;

  final ProgressionConfig config;
  final HeroAscensionConfig? heroAscensionConfig;

  /// Level cap efektif untuk karakter dengan fase [ascensionPhase].
  int effectiveLevelCap(int ascensionPhase) {
    final maxGlobal = config.maxLevel ?? ProgressionConfig.kTechnicalMaxLevel;
    final phaseCap = heroAscensionConfig?.levelCapForPhase(ascensionPhase);
    return phaseCap != null ? math.min(maxGlobal, phaseCap) : maxGlobal;
  }

  /// Memeriksa apakah karakter sudah menyentuh batas level untuk fase aktifnya.
  bool isAtPhaseCap(PlayerProgress current) =>
      current.level >= effectiveLevelCap(current.ascensionPhase);

  /// Memeriksa apakah karakter sudah siap melakukan terobosan (*Ascend Ready*).
  bool isAscendReady(PlayerProgress current) {
    final cfg = heroAscensionConfig;
    if (cfg == null) return false;
    if (current.ascensionPhase >= cfg.maxPhase) return false;
    final nextPhaseDef = cfg.phase(current.ascensionPhase + 1);
    if (nextPhaseDef == null) return false;
    return current.level >= nextPhaseDef.requiredPlayerLevel;
  }

  ProgressionResult grant(
    PlayerProgress current, {
    int exp = 0,
    int gold = 0,
    int maxIterations = 10000,
  }) {
    var level = current.level;
    final bonusExp = math.max<int>(0, exp);
    var currentExp = current.currentExp + bonusExp;
    var gained = 0;

    final maxGlobal = config.maxLevel ?? ProgressionConfig.kTechnicalMaxLevel;
    final effectiveCap = effectiveLevelCap(current.ascensionPhase);

    while (level < effectiveCap &&
        currentExp >= config.expToNext(level) &&
        gained < maxIterations) {
      currentExp -= config.expToNext(level);
      level++;
      gained++;
    }

    if (config.maxLevel != null && level >= maxGlobal) {
      currentExp = 0;
    } else if (level >= effectiveCap) {
      // EXP terhenti pada level cap fase aktif (Ascend Ready)
      currentExp = math.min(currentExp, config.expToNext(level));
    }

    return ProgressionResult(
      PlayerProgress(
        level: level,
        currentExp: currentExp,
        gold: current.gold + math.max<int>(0, gold),
        ascensionPhase: current.ascensionPhase,
      ),
      gained,
    );
  }

  /// Mengurangi gold sebesar [amount] bila valid dan saldo mencukupi.
  /// Mengembalikan `null` jika [amount] negatif atau saldo tidak cukup.
  PlayerProgress? spendGold(PlayerProgress current, int amount) {
    if (amount < 0 || current.gold < amount) return null;
    if (amount == 0) return current;
    return PlayerProgress(
      level: current.level,
      currentExp: current.currentExp,
      gold: current.gold - amount,
      ascensionPhase: current.ascensionPhase,
    );
  }

  /// Menambahkan gold hasil penjualan secara aman dengan validasi dan clamp
  /// tanpa melewati jalur reward/EXP.
  PlayerProgress addGold(PlayerProgress current, int amount) {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'harus >= 0');
    }
    if (amount == 0) return current;
    final currentGold = math.max(0, current.gold);
    final remainingCapacity = math.max(0, kMaxGold - currentGold);
    final added = math.min(amount, remainingCapacity);
    return PlayerProgress(
      level: current.level,
      currentExp: current.currentExp,
      gold: currentGold + added,
      ascensionPhase: current.ascensionPhase,
    );
  }
}
