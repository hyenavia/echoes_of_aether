import 'dart:math' as math;

import '../entities/cycle_progress.dart';
import '../entities/difficulty_config.dart';
import '../entities/dungeon_definition.dart';
import '../entities/player_save_snapshot.dart';
import 'difficulty_service.dart';

/// Saran perlindungan death loop saat pemain kalah beruntun di satu dungeon.
class DeathLoopSuggestion {
  const DeathLoopSuggestion({
    required this.failedDungeon,
    required this.consecutiveDefeats,
    this.suggestedDungeon,
  });

  final DungeonDefinition failedDungeon;
  final int consecutiveDefeats;
  final DungeonDefinition? suggestedDungeon;
}

/// Layanan domain murni untuk memeriksa status clear pada siklus saat ini,
/// syarat buka kunci dungeon, pemilihan target farm, serta rekomendasi level.
class DungeonProgressionService {
  const DungeonProgressionService([
    this.difficultyConfig = const DifficultyConfig(),
  ]);

  final DifficultyConfig difficultyConfig;

  /// Dungeon dianggap clear pada siklus saat ini jika `clearedInCycleRank`
  /// sama dengan `cycle.ascensionRank`, atau jika pemain sedang berada di rank
  /// di bawah `cycle.highestAscensionRank` (rank tersebut sudah pernah tamat).
  bool isClearedInCurrentCycle(
    String dungeonId,
    CycleProgress cycle,
    Map<String, DungeonProgressSnapshot> progresses,
  ) {
    if (cycle.ascensionRank < 0) return false;
    if (cycle.ascensionRank < cycle.highestAscensionRank) {
      return true;
    }
    final snap = progresses[dungeonId];
    if (snap == null) return false;
    return snap.clearedInCycleRank == cycle.ascensionRank;
  }

  /// Level minimal untuk masuk [dungeon] pada [cycleRank] (Hard Lock).
  /// Dungeon normal pertama (`order == 1`) selalu terbuka dari Lv 1 pada
  /// semua rank (Opsi 3) agar pemain tidak pernah terkunci di Town.
  int requiredLevel(DungeonDefinition dungeon, int cycleRank) {
    if (dungeon.isNormal && dungeon.order == 1) {
      return 1;
    }
    return recommendedLevel(dungeon, cycleRank);
  }

  /// Mengembalikan `true` jika level pemain memenuhi batas minimal untuk [dungeon]
  /// pada [cycleRank] (Hard Lock).
  bool meetsLevelRequirement(
    DungeonDefinition dungeon,
    int cycleRank,
    int playerLevel,
  ) => playerLevel >= requiredLevel(dungeon, cycleRank);

  /// Menentukan apakah [dungeon] terbuka untuk dimasuki pada [cycle] saat ini.
  /// Jika [playerLevel] diberikan, turut menegakkan hard lock level minimal.
  bool isUnlocked(
    DungeonDefinition dungeon,
    CycleProgress cycle,
    Map<String, DungeonProgressSnapshot> progresses, {
    Iterable<DungeonDefinition>? allDungeons,
    int? playerLevel,
  }) {
    if (dungeon.isBossEvent) return false;
    if (playerLevel != null &&
        !meetsLevelRequirement(dungeon, cycle.ascensionRank, playerLevel)) {
      return false;
    }
    final reqId = dungeon.unlockRequiresDungeonId;
    if (reqId != null) {
      return isClearedInCurrentCycle(reqId, cycle, progresses);
    }
    switch (dungeon.kind) {
      case DungeonKind.normal:
        return true;
      case DungeonKind.ascension:
        if (allDungeons != null) {
          final normalDungeons = allDungeons.where((d) => d.isNormal).toList();
          if (normalDungeons.isEmpty) return false;
          return normalDungeons.every(
            (d) => isClearedInCurrentCycle(d.id, cycle, progresses),
          );
        }
        final baseId = dungeon.baseDungeonId;
        if (baseId == null) return false;
        return isClearedInCurrentCycle(baseId, cycle, progresses);
      case DungeonKind.bossDaily:
      case DungeonKind.bossWeekly:
        return false;
    }
  }

  /// Memilih dungeon normal untuk offline Auto Farming:
  /// - Hanya dungeon `kind == normal` yang sudah clear di [cycle] saat ini.
  /// - Memakai [preferredDungeonId] bila valid & memenuhi syarat di atas.
  /// - Jika [preferredDungeonId] tidak diberikan, memakai [cycle.lastNormalDungeonId]
  ///   bila sudah clear pada siklus ini.
  /// - Fallback ke dungeon normal ber-`order` tertinggi yang clear pada siklus ini.
  /// - Mengembalikan `null` bila belum ada dungeon normal yang clear di siklus ini.
  String? resolveFarmDungeonId({
    required Iterable<DungeonDefinition> dungeons,
    required CycleProgress cycle,
    required Map<String, DungeonProgressSnapshot> progresses,
    String? preferredDungeonId,
  }) {
    final clearedNormals =
        dungeons
            .where(
              (d) =>
                  d.isNormal &&
                  isClearedInCurrentCycle(d.id, cycle, progresses),
            )
            .toList()
          ..sort((a, b) {
            final orderCmp = b.order.compareTo(a.order);
            return orderCmp != 0 ? orderCmp : a.id.compareTo(b.id);
          });

    if (clearedNormals.isEmpty) return null;

    for (final candidateId in [preferredDungeonId, cycle.lastNormalDungeonId]) {
      if (candidateId == null) continue;
      for (final d in clearedNormals) {
        if (d.id == candidateId) {
          return d.id;
        }
      }
    }

    return clearedNormals.first.id;
  }

  /// Memperbarui [CycleProgress.lastNormalDungeonId] saat pemain memasuki
  /// dungeon normal, dan mempertahankannya tetap utuh saat memasuki Ascension
  /// Dungeon agar titik kembali pasca-kalah di Ascension tetap dungeon normal
  /// pra-Ascension.
  CycleProgress recordDungeonEntered(
    CycleProgress cycle,
    DungeonDefinition dungeon,
  ) {
    if (!dungeon.isNormal) return cycle;
    return cycle.copyWith(lastNormalDungeonId: dungeon.id);
  }

  /// Menentukan dungeon tujuan saat pemain respawn / kembali ke Town setelah
  /// run berakhir atau kalah:
  /// - Jika [exitedDungeonId] adalah dungeon normal yang terbuka pada [cycle],
  ///   kembali ke [exitedDungeonId].
  /// - Jika pemain baru saja keluar/kalah di dungeon Ascension (atau ID tidak
  ///   valid), pertahankan [cycle.lastNormalDungeonId] bila masih valid & terbuka.
  /// - Fallback ke Farm Dungeon yang sudah clear di siklus ini, atau dungeon
  ///   normal pertama yang terbuka pada siklus ini.
  String? resolveRespawnDungeonId({
    required Iterable<DungeonDefinition> dungeons,
    required CycleProgress cycle,
    required Map<String, DungeonProgressSnapshot> progresses,
    String? exitedDungeonId,
  }) {
    final normalAsc = dungeons.where((d) => d.isNormal).toList()
      ..sort((a, b) {
        final orderCmp = a.order.compareTo(b.order);
        return orderCmp != 0 ? orderCmp : a.id.compareTo(b.id);
      });
    if (normalAsc.isEmpty) return null;

    final byId = {for (final d in dungeons) d.id: d};
    bool isUnlockedNormal(DungeonDefinition d) =>
        d.isNormal && isUnlocked(d, cycle, progresses, allDungeons: dungeons);

    for (final candidateId in [exitedDungeonId, cycle.lastNormalDungeonId]) {
      if (candidateId == null) continue;
      final candidate = byId[candidateId];
      if (candidate != null && isUnlockedNormal(candidate)) {
        return candidate.id;
      }
    }

    final farmId = resolveFarmDungeonId(
      dungeons: dungeons,
      cycle: cycle,
      progresses: progresses,
    );
    if (farmId != null) return farmId;

    for (final d in normalAsc) {
      if (isUnlockedNormal(d)) return d.id;
    }
    return normalAsc.first.id;
  }

  /// Menghitung level rekomendasi/requirement pada [cycleRank].
  /// Jika `cycleLevelStep` dikonfigurasi, memakai kenaikan linear
  /// `rec(d, 0) + cycleRank * cycleLevelStep`; jika tidak, memakai rumus
  /// baseline `rec(d, 0) + ceil(8 * ln(C(rank)) / ln(1.5))`.
  int recommendedLevel(DungeonDefinition dungeon, int cycleRank) {
    final baseRec = dungeon.recommendedLevel < 1 ? 1 : dungeon.recommendedLevel;
    if (cycleRank <= 0) return baseRec;

    final step = difficultyConfig.cycleLevelStep;
    if (step != null && step >= 0) {
      final int total = baseRec + (cycleRank * step);
      return math.min<int>(DifficultyService.kMaxScaledValue, total);
    }

    final cyclePerRank =
        (!difficultyConfig.cyclePerRank.isFinite ||
            difficultyConfig.cyclePerRank < 0)
        ? 0.0
        : difficultyConfig.cyclePerRank;
    final cycleFactor = 1.0 + cyclePerRank * cycleRank;
    if (!cycleFactor.isFinite) {
      return DifficultyService.kMaxScaledValue;
    }
    if (cycleFactor <= 1.0) return baseRec;

    final rawBonus = 8.0 * math.log(cycleFactor) / math.log(1.5);
    if (!rawBonus.isFinite) {
      return DifficultyService.kMaxScaledValue;
    }
    if (rawBonus <= 0.0) return baseRec;

    // Kurangi epsilon kecil agar pangkat eksak 1.5 tidak naik +1 akibat noise IEEE-754.
    final int bonus = math.max<int>(0, (rawBonus - 1e-12).ceil());
    final int total = baseRec + bonus;
    return math.min<int>(DifficultyService.kMaxScaledValue, total);
  }

  /// Menambah penghitung kekalahan beruntun untuk [dungeonId] sebesar +1.
  Map<String, int> recordDungeonDefeat(
    Map<String, int> current,
    String dungeonId,
  ) {
    final normalizedId = dungeonId.trim();
    if (normalizedId.isEmpty) return current;
    final next = <String, int>{
      for (final entry in current.entries)
        if (entry.key.trim().isNotEmpty && entry.value > 0)
          entry.key.trim(): entry.value,
    };
    next[normalizedId] = (next[normalizedId] ?? 0) + 1;
    return Map<String, int>.unmodifiable(next);
  }

  /// Mereset penghitung kekalahan beruntun untuk [dungeonId] saat menang.
  Map<String, int> recordDungeonVictory(
    Map<String, int> current,
    String dungeonId,
  ) {
    final normalizedId = dungeonId.trim();
    if (normalizedId.isEmpty || !current.containsKey(normalizedId)) {
      return current;
    }
    final next = <String, int>{
      for (final entry in current.entries)
        if (entry.key.trim().isNotEmpty &&
            entry.key.trim() != normalizedId &&
            entry.value > 0)
          entry.key.trim(): entry.value,
    };
    return Map<String, int>.unmodifiable(next);
  }

  /// Mengevaluasi apakah pemain perlu disarankan memilih dungeon yang lebih
  /// rendah karena kalah beruntun >= [suggestAfter] pada satu dungeon.
  DeathLoopSuggestion? evaluateDeathLoop({
    required Iterable<DungeonDefinition> dungeons,
    required CycleProgress cycle,
    required Map<String, DungeonProgressSnapshot> progresses,
    required Map<String, int> consecutiveDefeats,
    required int suggestAfter,
    String? selectedDungeonId,
    String? lastFailedDungeonId,
  }) {
    if (suggestAfter < 1 || consecutiveDefeats.isEmpty) return null;

    final byId = {for (final d in dungeons) d.id: d};
    DungeonDefinition? triggered;
    var defeatCount = 0;

    for (final candidateId in [selectedDungeonId, lastFailedDungeonId]) {
      if (candidateId == null) continue;
      final def = byId[candidateId];
      if (def == null) continue;
      final count = consecutiveDefeats[candidateId] ?? 0;
      if (count >= suggestAfter) {
        triggered = def;
        defeatCount = count;
        break;
      }
    }

    if (triggered == null) return null;

    final lowerCandidates =
        dungeons.where((d) => d.isNormal && d.order < triggered!.order).toList()
          ..sort((a, b) {
            final orderCmp = b.order.compareTo(a.order);
            return orderCmp != 0 ? orderCmp : a.id.compareTo(b.id);
          });

    DungeonDefinition? suggested;
    for (final d in lowerCandidates) {
      if (isUnlocked(d, cycle, progresses, allDungeons: dungeons)) {
        suggested = d;
        break;
      }
    }

    return DeathLoopSuggestion(
      failedDungeon: triggered,
      consecutiveDefeats: defeatCount,
      suggestedDungeon: suggested,
    );
  }
}
