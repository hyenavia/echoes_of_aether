import 'dart:math' as math;

import '../entities/hero_ascension.dart';
import '../entities/player_progress.dart';
import '../entities/player_save_snapshot.dart';

/// Alasan kegagalan validasi atau eksekusi Hero Ascension.
enum HeroAscensionFailureReason {
  none,
  maxPhaseReached,
  levelTooLow,
  insufficientGold,
  insufficientMaterials,
  insufficientCurrencies,
}

/// Hasil evaluasi kelayakan melakukan terobosan (*Can Ascend*).
class HeroAscensionCanAscendResult {
  const HeroAscensionCanAscendResult({
    required this.canAscend,
    this.failureReason = HeroAscensionFailureReason.none,
    this.nextPhase,
    this.missingGold = 0,
    this.missingItems = const {},
    this.missingCurrencies = const {},
  });

  final bool canAscend;
  final HeroAscensionFailureReason failureReason;
  final HeroAscensionPhaseDefinition? nextPhase;
  final int missingGold;
  final Map<String, int> missingItems;
  final Map<String, int> missingCurrencies;
}

/// Hasil eksekusi terobosan Hero Ascension secara atomik.
class HeroAscensionResult {
  const HeroAscensionResult({
    required this.succeeded,
    required this.previousPhase,
    required this.newPhase,
    this.failureReason = HeroAscensionFailureReason.none,
    this.phaseDefinition,
    this.updatedProgress,
    this.updatedInventoryStacks = const {},
    this.updatedCurrencies = const {},
    this.statBoost = const HeroAscensionStatBoost(),
    this.hasGoldenAura = false,
  });

  final bool succeeded;
  final int previousPhase;
  final int newPhase;
  final HeroAscensionFailureReason failureReason;
  final HeroAscensionPhaseDefinition? phaseDefinition;
  final PlayerProgress? updatedProgress;
  final Map<String, int> updatedInventoryStacks;
  final Map<String, int> updatedCurrencies;
  final HeroAscensionStatBoost statBoost;
  final bool hasGoldenAura;
}

/// Layanan domain murni untuk memvalidasi dan mengeksekusi terobosan Hero Ascension
/// (Level Cap & Breakthrough) secara atomik dan idempoten (GDD Addendum v1.5).
class HeroAscensionService {
  const HeroAscensionService(this.config);

  final HeroAscensionConfig config;

  /// Memeriksa apakah karakter memenuhi syarat level dan material untuk terobosan berikutnya.
  HeroAscensionCanAscendResult canAscend({
    required PlayerProgress progress,
    required Map<String, int> inventoryStacks,
    Map<String, int> currencies = const {},
  }) {
    if (progress.ascensionPhase >= config.maxPhase) {
      return const HeroAscensionCanAscendResult(
        canAscend: false,
        failureReason: HeroAscensionFailureReason.maxPhaseReached,
      );
    }

    final nextPhaseIndex = progress.ascensionPhase + 1;
    final nextPhaseDef = config.phase(nextPhaseIndex);
    if (nextPhaseDef == null) {
      return const HeroAscensionCanAscendResult(
        canAscend: false,
        failureReason: HeroAscensionFailureReason.maxPhaseReached,
      );
    }

    if (progress.level < nextPhaseDef.requiredPlayerLevel) {
      return HeroAscensionCanAscendResult(
        canAscend: false,
        failureReason: HeroAscensionFailureReason.levelTooLow,
        nextPhase: nextPhaseDef,
      );
    }

    final cost = nextPhaseDef.cost;
    var missingGold = 0;
    if (progress.gold < cost.gold) {
      missingGold = cost.gold - progress.gold;
    }

    final missingItems = <String, int>{};
    for (final entry in cost.items.entries) {
      final available = inventoryStacks[entry.key] ?? 0;
      if (available < entry.value) {
        missingItems[entry.key] = entry.value - available;
      }
    }

    final missingCurrencies = <String, int>{};
    for (final entry in cost.currencies.entries) {
      final available = currencies[entry.key] ?? 0;
      if (available < entry.value) {
        missingCurrencies[entry.key] = entry.value - available;
      }
    }

    if (missingGold > 0) {
      return HeroAscensionCanAscendResult(
        canAscend: false,
        failureReason: HeroAscensionFailureReason.insufficientGold,
        nextPhase: nextPhaseDef,
        missingGold: missingGold,
        missingItems: missingItems,
        missingCurrencies: missingCurrencies,
      );
    }

    if (missingItems.isNotEmpty) {
      return HeroAscensionCanAscendResult(
        canAscend: false,
        failureReason: HeroAscensionFailureReason.insufficientMaterials,
        nextPhase: nextPhaseDef,
        missingItems: missingItems,
        missingCurrencies: missingCurrencies,
      );
    }

    if (missingCurrencies.isNotEmpty) {
      return HeroAscensionCanAscendResult(
        canAscend: false,
        failureReason: HeroAscensionFailureReason.insufficientCurrencies,
        nextPhase: nextPhaseDef,
        missingCurrencies: missingCurrencies,
      );
    }

    return HeroAscensionCanAscendResult(
      canAscend: true,
      nextPhase: nextPhaseDef,
    );
  }

  /// Melakukan transaksi terobosan secara atomik:
  /// - Seluruh kondisi divalidasi terlebih dahulu (`canAscend`).
  /// - Jika valid: mengurangi gold, item material, dan mata uang yang dikonsumsi,
  ///   menaikkan `ascensionPhase` menjadi +1, serta memberikan bonus stat permanen.
  /// - Jika tidak valid: tidak ada mutasi data yang dilakukan.
  HeroAscensionResult ascendHero({
    required PlayerProgress progress,
    required Map<String, int> inventoryStacks,
    Map<String, int> currencies = const {},
  }) {
    final check = canAscend(
      progress: progress,
      inventoryStacks: inventoryStacks,
      currencies: currencies,
    );

    if (!check.canAscend || check.nextPhase == null) {
      return HeroAscensionResult(
        succeeded: false,
        previousPhase: progress.ascensionPhase,
        newPhase: progress.ascensionPhase,
        failureReason: check.failureReason,
        phaseDefinition: check.nextPhase,
        updatedProgress: progress,
        updatedInventoryStacks: inventoryStacks,
        updatedCurrencies: currencies,
      );
    }

    final nextPhaseDef = check.nextPhase!;
    final cost = nextPhaseDef.cost;

    final updatedGold = math.max(0, progress.gold - cost.gold);
    final updatedProgress = PlayerProgress(
      level: progress.level,
      currentExp: progress.currentExp,
      gold: updatedGold,
      ascensionPhase: nextPhaseDef.phase,
    );

    final updatedStacks = Map<String, int>.from(inventoryStacks);
    for (final entry in cost.items.entries) {
      final currentQty = updatedStacks[entry.key] ?? 0;
      final remaining = currentQty - entry.value;
      if (remaining > 0) {
        updatedStacks[entry.key] = remaining;
      } else {
        updatedStacks.remove(entry.key);
      }
    }

    final updatedCurrencies = Map<String, int>.from(currencies);
    for (final entry in cost.currencies.entries) {
      final currentQty = updatedCurrencies[entry.key] ?? 0;
      final remaining = math.max(0, currentQty - entry.value);
      updatedCurrencies[entry.key] = remaining;
    }

    return HeroAscensionResult(
      succeeded: true,
      previousPhase: progress.ascensionPhase,
      newPhase: nextPhaseDef.phase,
      phaseDefinition: nextPhaseDef,
      updatedProgress: updatedProgress,
      updatedInventoryStacks: Map<String, int>.unmodifiable(updatedStacks),
      updatedCurrencies: Map<String, int>.unmodifiable(updatedCurrencies),
      statBoost: nextPhaseDef.statBoost,
      hasGoldenAura: nextPhaseDef.hasGoldenAura,
    );
  }

  /// Helper untuk memproses transaksi terobosan langsung dari snapshot save data pemain.
  (HeroAscensionResult, PlayerSaveSnapshot) ascendSnapshot(
    PlayerSaveSnapshot snapshot,
  ) {
    final result = ascendHero(
      progress: snapshot.character.progress,
      inventoryStacks: snapshot.inventory.stacks,
      currencies: snapshot.currencies,
    );

    if (!result.succeeded || result.updatedProgress == null) {
      return (result, snapshot);
    }

    final nextChar = PlayerCharacterSnapshot(
      progress: result.updatedProgress!,
      specializationId: snapshot.character.specializationId,
      skillLevels: snapshot.character.skillLevels,
      skillCooldownTicks: snapshot.character.skillCooldownTicks,
      equipped: snapshot.character.equipped,
      currentHp: snapshot.character.currentHp,
    );

    final nextInv = snapshot.inventory.copyWith(
      stacks: result.updatedInventoryStacks,
    );

    final updatedSnapshot = snapshot.copyWith(
      character: nextChar,
      inventory: nextInv,
      currencies: result.updatedCurrencies,
    );

    return (result, updatedSnapshot);
  }
}
