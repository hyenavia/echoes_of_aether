import 'dart:math' as math;

import '../entities/cycle_progress.dart';
import '../entities/player_save_snapshot.dart';

/// Konverter domain murni untuk menormalkan snapshot save sistem lama
/// (`schemaVersion < 11`) ke aturan M16 (`Lv 90 Max`, `Fase A0..A6`,
/// `Rank 5 Peak World Tier`, serta paket kompensasi *Aether Legacy Gift*).
class LegacySaveConverter {
  const LegacySaveConverter._();

  static const int m16SchemaVersion = 11;
  static const int legacyMaxLevel = 90;
  static const int legacyMaxRank = CycleProgress.kPeakWorldRank;
  static const int legacyGoldPerLevel = 5000;
  static const int legacyShardPerLevel = 20;
  static const int legacyLevelsPerSoulPrism = 10;

  /// Mengonversi [snapshot] ke aturan M16 bila berasal dari `fromSchemaVersion < 11`
  /// atau masih membawa nilai level/rank di atas batas sistem baru.
  static PlayerSaveSnapshot convertToV11IfNeeded(
    PlayerSaveSnapshot snapshot, {
    required int fromSchemaVersion,
  }) {
    final oldProgress = snapshot.character.progress;
    final oldCycle = snapshot.cycleProgress;
    if (fromSchemaVersion >= m16SchemaVersion &&
        oldProgress.level <= legacyMaxLevel &&
        oldCycle.highestAscensionRank <= legacyMaxRank &&
        oldCycle.ascensionRank <= legacyMaxRank) {
      return snapshot;
    }

    final oldLevel = math.max(1, oldProgress.level);
    final mappedPhase = _mappedAscensionPhase(oldLevel);
    final nextPhase = math.max(oldProgress.ascensionPhase, mappedPhase);

    var nextLevel = oldLevel;
    var nextExp = math.max(0, oldProgress.currentExp);
    var nextGold = math.max(0, oldProgress.gold);
    final nextCurrencies = Map<String, int>.from(snapshot.currencies);

    if (oldLevel > legacyMaxLevel) {
      final diff = oldLevel - legacyMaxLevel;
      final bonusGold = diff * legacyGoldPerLevel;
      final bonusShard = diff * legacyShardPerLevel;
      final bonusSoulPrism = diff ~/ legacyLevelsPerSoulPrism;

      nextLevel = legacyMaxLevel;
      nextExp = 0;
      nextGold += bonusGold;
      if (bonusShard > 0) {
        nextCurrencies['aether_shard'] =
            (nextCurrencies['aether_shard'] ?? 0) + bonusShard;
      }
      if (bonusSoulPrism > 0) {
        nextCurrencies['soul_prism'] =
            (nextCurrencies['soul_prism'] ?? 0) + bonusSoulPrism;
      }
    }

    final clampedHighestRank = math.min(
      legacyMaxRank,
      math.max(0, oldCycle.highestAscensionRank),
    );
    final clampedRank = math.min(
      clampedHighestRank,
      math.max(0, oldCycle.ascensionRank),
    );

    return snapshot.copyWith(
      character: snapshot.character.copyWith(
        progress: oldProgress.copyWith(
          level: nextLevel,
          currentExp: nextExp,
          gold: nextGold,
          ascensionPhase: nextPhase,
        ),
      ),
      cycleProgress: oldCycle.copyWith(
        ascensionRank: clampedRank,
        highestAscensionRank: clampedHighestRank,
      ),
      currencies: Map<String, int>.unmodifiable(nextCurrencies),
    );
  }

  static int _mappedAscensionPhase(int level) {
    if (level <= 20) return 0;
    if (level <= 40) return 1;
    if (level <= 50) return 2;
    if (level <= 60) return 3;
    if (level <= 70) return 4;
    if (level <= 80) return 5;
    return 6;
  }
}
