import '../entities/cycle_progress.dart';
import '../entities/dungeon_definition.dart';
import '../entities/player_save_snapshot.dart';
import 'difficulty_service.dart';
import 'dungeon_progression_service.dart';
import 'reward_processor.dart';

/// Hasil eksekusi transisi siklus Ascension oleh [AscensionService].
class AscensionResult {
  const AscensionResult({
    required this.alreadyCompleted,
    required this.eventId,
    required this.previousRank,
    required this.newRank,
    required this.cycleProgress,
    required this.dungeonProgresses,
    required this.claimedEventIds,
  });

  /// `true` jika `ascension:{runId}` sudah pernah diklaim sebelumnya sehingga
  /// tidak ada kenaikan rank maupun reset ulang.
  final bool alreadyCompleted;

  /// Event ID kanonik (`ascension:{runId}`).
  final String eventId;

  final int previousRank;
  final int newRank;
  final CycleProgress cycleProgress;
  final Map<String, DungeonProgressSnapshot> dungeonProgresses;
  final Set<String> claimedEventIds;

  bool get rankIncremented => !alreadyCompleted && newRank > previousRank;
}

/// Layanan domain murni untuk mengevaluasi akses dan menyelesaikan siklus
/// Ascension Dungeon tanpa mengubah level, EXP, gold, skill, equipment,
/// inventory, maupun lifetime `clearsCount` pemain.
class AscensionService {
  const AscensionService({
    this.progressionService = const DungeonProgressionService(),
  });

  /// Batas atas aman untuk rank agar aritmatika rank tinggi tetap stabil.
  static const int kMaxAscensionRank = DifficultyService.kMaxScaledValue;

  final DungeonProgressionService progressionService;

  /// Membuat event ID idempoten kanonik untuk penyelesaian Ascension.
  static String ascensionEventId(String runId) => 'ascension:${runId.trim()}';

  /// Mengembalikan `true` jika dungeon prasyarat Ascension (Dungeon normal
  /// terakhir / Dungeon 5) sudah selesai pada [cycleProgress] saat ini,
  /// serta level pemain memenuhi requirement Ascension jika [playerLevel] diberikan.
  bool canEnterAscension({
    required Iterable<DungeonDefinition> dungeons,
    required CycleProgress cycleProgress,
    required Map<String, DungeonProgressSnapshot> dungeonProgresses,
    int? playerLevel,
  }) {
    final targetId = _resolveRequiredNormalDungeonId(dungeons);
    if (targetId == null) return false;
    if (!progressionService.isClearedInCurrentCycle(
      targetId,
      cycleProgress,
      dungeonProgresses,
    )) {
      return false;
    }
    if (playerLevel != null) {
      for (final d in dungeons) {
        if (d.isAscension) {
          return progressionService.meetsLevelRequirement(
            d,
            cycleProgress.ascensionRank,
            playerLevel,
          );
        }
      }
    }
    return true;
  }

  /// Menyelesaikan satu Ascension run secara idempoten dengan kunci
  /// `ascension:{runId}`:
  /// - Jika belum pernah diklaim: menaikkan `ascensionRank` +1 (terbatas
  ///   [kMaxAscensionRank]), mereset penanda clear siklus (`clearedInCycleRank
  ///   = -1`) sambil menjaga lifetime `clearsCount`, dan mengembalikan
  ///   `lastNormalDungeonId` ke Dungeon 1 (normal ber-`order` terendah).
  /// - Jika `ascension:{runId}` sudah ada di [rewardProcessor] atau
  ///   [claimedEventIds]: tidak mengubah rank maupun progres siklus.
  AscensionResult complete({
    required String runId,
    required Iterable<DungeonDefinition> dungeons,
    required CycleProgress cycleProgress,
    required Map<String, DungeonProgressSnapshot> dungeonProgresses,
    RewardProcessor? rewardProcessor,
    Set<String>? claimedEventIds,
  }) {
    final trimmedRunId = runId.trim();
    if (trimmedRunId.isEmpty) {
      throw ArgumentError.value(runId, 'runId', 'cannot be empty');
    }

    final normals = _sortedNormalDungeons(dungeons);
    if (normals.isEmpty) {
      throw StateError('No normal dungeons defined for ascension cycle reset.');
    }

    final firstNormalDungeon = normals.first;
    final eventId = ascensionEventId(trimmedRunId);
    final sanitizedPreviousRank = cycleProgress.ascensionRank < 0
        ? 0
        : cycleProgress.ascensionRank;
    final sanitizedHighestRank =
        cycleProgress.highestAscensionRank < sanitizedPreviousRank
        ? sanitizedPreviousRank
        : cycleProgress.highestAscensionRank;
    final sanitizedCycle = CycleProgress(
      ascensionRank: sanitizedPreviousRank,
      highestAscensionRank: sanitizedHighestRank,
      lastNormalDungeonId: cycleProgress.lastNormalDungeonId,
    );

    final combinedClaimed = <String>{
      ...?claimedEventIds,
      ...?rewardProcessor?.claimedEventIds,
    };

    final alreadyClaimed =
        combinedClaimed.contains(eventId) ||
        (rewardProcessor?.isClaimed(eventId) ?? false);

    if (alreadyClaimed) {
      return AscensionResult(
        alreadyCompleted: true,
        eventId: eventId,
        previousRank: sanitizedPreviousRank,
        newRank: sanitizedPreviousRank,
        cycleProgress: sanitizedCycle,
        dungeonProgresses: Map<String, DungeonProgressSnapshot>.unmodifiable(
          dungeonProgresses,
        ),
        claimedEventIds: Set<String>.unmodifiable({
          ...combinedClaimed,
          eventId,
        }),
      );
    }

    rewardProcessor?.markClaimed(eventId);
    combinedClaimed.add(eventId);

    // Jika pemain menyelesaikan Ascension di rank bawah (< highestAscensionRank),
    // beri reward tanpa menaikkan rank tertinggi maupun mereset progres frontier.
    if (sanitizedPreviousRank < sanitizedHighestRank) {
      return AscensionResult(
        alreadyCompleted: false,
        eventId: eventId,
        previousRank: sanitizedPreviousRank,
        newRank: sanitizedPreviousRank,
        cycleProgress: sanitizedCycle,
        dungeonProgresses: Map<String, DungeonProgressSnapshot>.unmodifiable(
          dungeonProgresses,
        ),
        claimedEventIds: Set<String>.unmodifiable(combinedClaimed),
      );
    }

    final nextRank = sanitizedPreviousRank >= kMaxAscensionRank
        ? kMaxAscensionRank
        : sanitizedPreviousRank + 1;

    final resetProgresses = <String, DungeonProgressSnapshot>{
      for (final entry in dungeonProgresses.entries)
        entry.key: DungeonProgressSnapshot(
          currentDungeonId: entry.value.currentDungeonId,
          currentRoomId: entry.value.currentRoomId,
          currentRoomIndex: entry.value.currentRoomIndex,
          highestClearedRoomIndex: entry.value.highestClearedRoomIndex,
          clearsCount: entry.value.clearsCount,
          clearedInCycleRank: -1,
          rewardState: entry.value.rewardState,
        ),
    };

    final nextCycle = CycleProgress(
      ascensionRank: nextRank,
      highestAscensionRank: nextRank,
      lastNormalDungeonId: firstNormalDungeon.id,
    );

    return AscensionResult(
      alreadyCompleted: false,
      eventId: eventId,
      previousRank: sanitizedPreviousRank,
      newRank: nextRank,
      cycleProgress: nextCycle,
      dungeonProgresses: Map<String, DungeonProgressSnapshot>.unmodifiable(
        resetProgresses,
      ),
      claimedEventIds: Set<String>.unmodifiable(combinedClaimed),
    );
  }

  String? _resolveRequiredNormalDungeonId(
    Iterable<DungeonDefinition> dungeons,
  ) {
    final byId = {for (final d in dungeons) d.id: d};
    for (final d in dungeons) {
      if (!d.isAscension) continue;
      final reqId = d.unlockRequiresDungeonId ?? d.baseDungeonId;
      if (reqId != null && (byId[reqId]?.isNormal ?? false)) {
        return reqId;
      }
    }
    final normals = _sortedNormalDungeons(dungeons);
    if (normals.isEmpty) return null;
    return normals.last.id;
  }

  List<DungeonDefinition> _sortedNormalDungeons(
    Iterable<DungeonDefinition> dungeons,
  ) {
    final normals = dungeons.where((d) => d.isNormal).toList()
      ..sort((a, b) {
        final orderCmp = a.order.compareTo(b.order);
        return orderCmp != 0 ? orderCmp : a.id.compareTo(b.id);
      });
    return normals;
  }
}
