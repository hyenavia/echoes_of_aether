import 'dart:math' as math;

import '../entities/player_progress.dart';
import '../entities/progression_config.dart';

class ProgressionResult {
  const ProgressionResult(this.progress, this.levelsGained);

  final PlayerProgress progress;
  final int levelsGained;
}

/// Aturan EXP dan leveling (GDD 3.3). Fungsi murni: tidak mengubah input.
class ProgressionService {
  const ProgressionService(this.config);

  static const int kMaxGold = 999999999999;

  final ProgressionConfig config;

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

    final maxLvl = config.maxLevel ?? ProgressionConfig.kTechnicalMaxLevel;
    while (level < maxLvl &&
        currentExp >= config.expToNext(level) &&
        gained < maxIterations) {
      currentExp -= config.expToNext(level);
      level++;
      gained++;
    }
    // Pada level maksimum EXP tidak lagi terkumpul hanya jika maxLevel ditentukan.
    if (config.maxLevel != null && level >= config.maxLevel!) {
      currentExp = 0;
    }

    return ProgressionResult(
      PlayerProgress(
        level: level,
        currentExp: currentExp,
        gold: current.gold + math.max<int>(0, gold),
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
    );
  }
}
