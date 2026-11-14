import 'dart:async';
import 'dart:math' as math;

import '../../domain/entities/cycle_progress.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/offline_activity.dart';
import '../../domain/entities/player_character.dart';
import '../../domain/entities/player_save_snapshot.dart';
import '../../domain/entities/player_status.dart';
import '../../domain/repositories/player_progress_repository.dart';
import '../../domain/services/combat_simulation.dart';
import '../../domain/services/equipment_factory.dart';
import '../../domain/services/offline_progression_service.dart';
import '../../domain/services/reward_processor.dart';

class LoadedGameSession {
  const LoadedGameSession({
    required this.character,
    required this.inventory,
    required this.dungeon,
    this.dungeonProgresses = const {},
    this.cycleProgress = const CycleProgress(),
    required this.session,
    required this.claimedEventIds,
    required this.offlineResult,
    required this.rewardProcessor,
    this.activeDungeonSession,
    this.offlineActivity = const OfflineActivitySnapshot.paused(),
    this.recoveredHp,
    this.recoveredSkillCooldownTicks = const {},
    this.isFirstLaunch = false,
    this.loadError,
    this.shopPurchases = const {},
  });

  final PlayerCharacter character;
  final Inventory inventory;
  final DungeonProgressSnapshot dungeon;
  final Map<String, DungeonProgressSnapshot> dungeonProgresses;
  final CycleProgress cycleProgress;
  final GameSessionSnapshot session;
  final Set<String> claimedEventIds;
  final OfflineProgressionResult offlineResult;
  final RewardProcessor rewardProcessor;
  final ActiveDungeonSessionSnapshot? activeDungeonSession;
  final OfflineActivitySnapshot offlineActivity;
  final int? recoveredHp;
  final Map<String, int> recoveredSkillCooldownTicks;
  final bool isFirstLaunch;
  final Object? loadError;
  final Map<String, int> shopPurchases;

  bool get hasRecoverableDungeonSession =>
      activeDungeonSession?.isRecoverable ?? false;

  bool get hasUnacknowledgedOfflineSummary =>
      offlineActivity.pendingSummary != null &&
      !offlineActivity.pendingSummary!.acknowledged;
}

/// Mengoordinasikan siklus load, Hybrid Offline Progression (checkpointed
/// batch atomic transactions), lifecycle resume, dan antrean penyimpanan
/// berurutan agar operasi save maupun trigger resume tidak saling menimpa.
class GameSessionCoordinator {
  GameSessionCoordinator({
    required this.repository,
    required this.config,
    this.offlineService = const OfflineProgressionService(),
    this.checkpointIterationsPerBatch = defaultCheckpointIterationsPerBatch,
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const int defaultCheckpointIterationsPerBatch = 2500;
  static const int _maxCheckpointBatches = 256;

  final PlayerSaveRepository repository;
  final GameConfig config;
  final OfflineProgressionService offlineService;
  final int checkpointIterationsPerBatch;
  final int Function() _nowMs;

  Future<void> _saveQueue = Future<void>.value();
  Future<void> _offlineQueue = Future<void>.value();
  int _highWaterTimestampMs = 0;
  Object? lastSaveError;

  /// Menjalankan boot load dan memproses aktivitas offline secara eksklusif.
  Future<LoadedGameSession> loadAndProcessOffline({int? maxBatches}) =>
      _runOfflineExclusive(
        () => _processFromRepository(maxBatches: maxBatches),
      );

  /// Memproses aktivitas offline saat `AppLifecycleState.resumed`.
  /// Menunggu seluruh antrean save sebelum membaca snapshot agar pause save
  /// tidak tertinggal atau berpacu dengan pemrosesan resume ganda.
  Future<LoadedGameSession> processOfflineOnResume({int? maxBatches}) =>
      _runOfflineExclusive(
        () => _processFromRepository(maxBatches: maxBatches),
      );

  /// Menyimpan [cycleProgress] secara berurutan melalui `_saveQueue` tanpa
  /// menimpa data karakter, equipment, maupun inventory.
  Future<void> saveCycleProgress(CycleProgress cycleProgress) {
    return _runQueuedSave(() async {
      final repo = repository;
      if (repo is CycleProgressRepository) {
        await (repo as CycleProgressRepository).saveCycleProgress(
          cycleProgress,
        );
        return;
      }
      final existing = await repo.loadSnapshot();
      if (existing == null) return;
      await repo.saveSnapshot(
        PlayerSaveSnapshot(
          playerId: existing.playerId,
          character: existing.character,
          inventory: existing.inventory,
          dungeon: existing.dungeon,
          dungeonProgresses: existing.dungeonProgresses,
          cycleProgress: cycleProgress,
          session: existing.session,
          claimedEventIds: existing.claimedEventIds,
          activeDungeonSession: existing.activeDungeonSession,
          offlineActivity: existing.offlineActivity,
          shopPurchases: existing.shopPurchases,
        ),
      );
    });
  }

  /// Menyimpan transisi siklus Ascension (`cycleProgress`, reset
  /// `clearedInCycleRank`, serta kunci idempoten `ascension:{runId}`) secara
  /// atomik dan terurut melalui `_saveQueue`.
  Future<void> saveCycleTransition({
    required CycleProgress cycleProgress,
    required Map<String, DungeonProgressSnapshot> dungeonProgresses,
    String? claimEventId,
    int? updatedAtMs,
  }) {
    return _runQueuedSave(() async {
      final repo = repository;
      final resolvedAtMs = math.max(0, updatedAtMs ?? _nowMs());
      if (repo is CycleProgressRepository) {
        await (repo as CycleProgressRepository).saveCycleTransition(
          cycleProgress: cycleProgress,
          dungeonProgresses: dungeonProgresses,
          claimEventId: claimEventId,
          updatedAtMs: resolvedAtMs,
        );
        return;
      }
      final existing = await repo.loadSnapshot();
      if (existing == null) return;
      final nextClaimed = <String>{
        ...existing.claimedEventIds,
        if (claimEventId != null && claimEventId.trim().isNotEmpty)
          claimEventId.trim(),
      };
      final nextProgresses = Map<String, DungeonProgressSnapshot>.unmodifiable(
        dungeonProgresses,
      );
      await repo.saveSnapshot(
        PlayerSaveSnapshot(
          playerId: existing.playerId,
          character: existing.character,
          inventory: existing.inventory,
          dungeon:
              nextProgresses[existing.dungeon.currentDungeonId] ??
              existing.dungeon,
          dungeonProgresses: nextProgresses,
          cycleProgress: cycleProgress,
          session: existing.session,
          claimedEventIds: Set<String>.unmodifiable(nextClaimed),
          activeDungeonSession: existing.activeDungeonSession,
          offlineActivity: existing.offlineActivity,
          shopPurchases: existing.shopPurchases,
        ),
      );
    });
  }

  /// Menyimpan transaksi shop (perubahan gold, inventory, equipment, dan
  /// [shopPurchases]) secara atomik dan terurut melalui `_saveQueue`.
  Future<void> saveShopTransaction({
    required PlayerCharacter character,
    required Inventory inventory,
    required Map<String, int> shopPurchases,
    String? actionId,
    int? updatedAtMs,
  }) {
    return _runQueuedSave(() async {
      final repo = repository;
      final resolvedAtMs = math.max(0, updatedAtMs ?? _nowMs());
      final charSnap = character.toSnapshot();
      final invSnap = inventory.toSnapshot();
      if (repo is ShopPurchaseRepository) {
        await (repo as ShopPurchaseRepository).saveShopTransaction(
          progress: charSnap.progress,
          inventory: invSnap,
          equipped: charSnap.equipped,
          shopPurchases: shopPurchases,
          actionId: actionId,
          updatedAtMs: resolvedAtMs,
        );
        return;
      }
      final existing = await repo.loadSnapshot();
      if (existing == null) return;
      final normalizedActionId = actionId?.trim();
      final claimKey =
          (normalizedActionId != null && normalizedActionId.isNotEmpty)
          ? 'shop:$normalizedActionId'
          : null;
      if (claimKey != null && existing.claimedEventIds.contains(claimKey)) {
        return;
      }
      final nextClaimed = <String>{...existing.claimedEventIds, ?claimKey};
      await repo.saveSnapshot(
        PlayerSaveSnapshot(
          playerId: existing.playerId,
          character: PlayerCharacterSnapshot(
            progress: charSnap.progress,
            specializationId: charSnap.specializationId,
            skillLevels: charSnap.skillLevels,
            skillCooldownTicks: charSnap.skillCooldownTicks,
            equipped: charSnap.equipped,
            currentHp: existing.character.currentHp,
          ),
          inventory: invSnap,
          dungeon: existing.dungeon,
          dungeonProgresses: existing.dungeonProgresses,
          cycleProgress: existing.cycleProgress,
          session: existing.session,
          claimedEventIds: Set<String>.unmodifiable(nextClaimed),
          activeDungeonSession: existing.activeDungeonSession,
          offlineActivity: existing.offlineActivity,
          shopPurchases: Map<String, int>.unmodifiable(shopPurchases),
        ),
      );
    });
  }

  Future<T> _runQueuedSave<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _saveQueue = _saveQueue.then((_) async {
      try {
        final value = await action();
        if (!completer.isCompleted) completer.complete(value);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<T> _runOfflineExclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _offlineQueue = _offlineQueue.then((_) async {
      try {
        await _saveQueue.catchError((_) {});
        final value = await action();
        if (!completer.isCompleted) completer.complete(value);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<LoadedGameSession> _processFromRepository({int? maxBatches}) async {
    final character = PlayerCharacter(
      config: config.progression,
      skillCatalog: config.skills,
      specializationConfig: config.specializations,
    );
    final inventory = Inventory(definitions: config.items);

    PlayerSaveSnapshot? loaded;
    Object? loadError;
    try {
      loaded = await repository.loadSnapshot();
    } catch (e) {
      loadError = e;
    }

    final now = math.max(0, _nowMs());
    if (loaded == null) {
      _highWaterTimestampMs = math.max(_highWaterTimestampMs, now);
      final initialSession = GameSessionSnapshot(
        lastActiveAtMs: now,
        lastSavedAtMs: now,
        lastOfflineClaimAtMs: now,
        autoSkillEnabled: true,
      );
      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      final offlineResult = OfflineProgressionResult.none(
        status: OfflineProgressionStatus.firstLaunch,
        claimAtMs: now,
      );
      final sortedNormals =
          config.dungeons.values.where((d) => d.isNormal).toList()
            ..sort((a, b) => a.order.compareTo(b.order));
      final firstNormal = sortedNormals.isNotEmpty
          ? sortedNormals.first
          : (config.dungeons.values.isNotEmpty
                ? config.dungeons.values.first
                : null);
      final initialDungeon = firstNormal != null
          ? DungeonProgressSnapshot(
              currentDungeonId: firstNormal.id,
              currentRoomId: firstNormal.startRoomId,
            )
          : const DungeonProgressSnapshot();
      final initialCycle = CycleProgress(lastNormalDungeonId: firstNormal?.id);
      return LoadedGameSession(
        character: character,
        inventory: inventory,
        dungeon: initialDungeon,
        dungeonProgresses: const {},
        cycleProgress: initialCycle,
        session: initialSession,
        claimedEventIds: <String>{},
        offlineResult: offlineResult,
        rewardProcessor: rewardProcessor,
        offlineActivity: const OfflineActivitySnapshot.paused(),
        isFirstLaunch: loadError == null,
        loadError: loadError,
      );
    }

    character.restoreSnapshot(loaded.character);
    inventory.restore(loaded.inventory);
    final claimedIds = {...loaded.claimedEventIds};
    final rewardProcessor = RewardProcessor(
      character: character,
      inventory: inventory,
      items: config.items,
      lootTables: config.lootTables,
      lootService: offlineService.lootService,
      equipmentFactory: EquipmentFactory(config.equipment),
      claimedEventIds: claimedIds,
    );

    final previousHighWater = math.max(
      loaded.session.lastSavedAtMs,
      loaded.session.lastOfflineClaimAtMs,
    );
    _highWaterTimestampMs = math.max(_highWaterTimestampMs, previousHighWater);

    final normalizedRecovery = _normalizeRecoveredSession(
      loaded: loaded,
      character: character,
    );

    var workingSession = loaded.session;
    var workingActivity = loaded.offlineActivity;
    var workingActiveSession = normalizedRecovery.activeSession;
    var workingDungeon = loaded.dungeon;
    final workingCycle = loaded.cycleProgress;
    final workingProgresses = Map<String, DungeonProgressSnapshot>.of(
      loaded.dungeonProgresses,
    );
    workingProgresses.putIfAbsent(
      workingDungeon.currentDungeonId,
      () => workingDungeon,
    );

    var simHp = workingActiveSession?.isRecoverable == true
        ? (normalizedRecovery.recoveredHp ?? loaded.character.currentHp)
        : null;
    var simSkillCooldowns = workingActiveSession?.isRecoverable == true
        ? Map<String, int>.of(loaded.character.skillCooldownTicks)
        : const <String, int>{};
    var simReviveTicks = workingActiveSession?.reviveCooldownTicks ?? 0;
    var attemptIndex = 1;

    final batchLimit = maxBatches == null
        ? _maxCheckpointBatches
        : math.max(1, maxBatches);
    final iterationsPerBatch = math.max(1, checkpointIterationsPerBatch);

    var firstResult = offlineService.process(
      character: character,
      inventory: inventory,
      config: config,
      session: workingSession,
      nowMs: now,
      offlineActivity: workingActivity,
      activeDungeonSession: workingActiveSession,
      dungeonProgress: workingDungeon,
      dungeonProgresses: workingProgresses,
      cycleProgress: workingCycle,
      rewardProcessor: rewardProcessor,
      claimedEventIds: claimedIds,
      maxIterations: iterationsPerBatch,
      initialHp: simHp,
      initialSkillCooldownTicks: simSkillCooldowns,
      initialReviveCooldownTicks: simReviveTicks,
      startingAttemptIndex: attemptIndex,
    );

    var aggregatedResult = firstResult;
    var batchCount = 0;

    if (firstResult.status == OfflineProgressionStatus.applied ||
        firstResult.status == OfflineProgressionStatus.interrupted ||
        firstResult.status == OfflineProgressionStatus.failed ||
        firstResult.status == OfflineProgressionStatus.noEligibleEncounter) {
      var currentBatch = firstResult;

      while (true) {
        batchCount++;
        workingActivity =
            currentBatch.updatedOfflineActivity ?? workingActivity;
        workingActiveSession = currentBatch.updatedActiveDungeonSession;
        if (currentBatch.updatedDungeonProgress != null) {
          final updatedProg = currentBatch.updatedDungeonProgress!;
          workingProgresses[updatedProg.currentDungeonId] = updatedProg;
          if (workingDungeon.currentDungeonId == updatedProg.currentDungeonId) {
            workingDungeon = updatedProg;
          }
        }
        simHp = currentBatch.remainingHp;
        simSkillCooldowns = currentBatch.remainingSkillCooldownTicks;
        simReviveTicks = currentBatch.remainingReviveCooldownTicks;
        attemptIndex = currentBatch.nextAttemptIndex;
        claimedIds.addAll(rewardProcessor.claimedEventIds);

        final isBatchInterrupted =
            currentBatch.status == OfflineProgressionStatus.interrupted;

        final batchCheckpointMs = isBatchInterrupted
            ? math.max(previousHighWater, workingActivity.lastCheckpointAtMs)
            : math.max(now, previousHighWater);

        final batchClaimAtMs = isBatchInterrupted
            ? math.max(
                workingSession.lastOfflineClaimAtMs,
                currentBatch.newLastOfflineClaimAtMs,
              )
            : math.max(
                workingSession.lastOfflineClaimAtMs,
                currentBatch.newLastOfflineClaimAtMs,
              );

        workingSession = loaded.session.copyWith(
          lastActiveAtMs: isBatchInterrupted
              ? batchCheckpointMs
              : math.max(now, loaded.session.lastActiveAtMs),
          lastSavedAtMs: batchCheckpointMs,
          lastOfflineClaimAtMs: batchClaimAtMs,
        );

        final baseCharSnap = character.toSnapshot();
        final isRecoverable = workingActiveSession?.isRecoverable == true;
        final checkpointCharSnap = PlayerCharacterSnapshot(
          progress: baseCharSnap.progress,
          specializationId: baseCharSnap.specializationId,
          skillLevels: baseCharSnap.skillLevels,
          skillCooldownTicks: isRecoverable ? simSkillCooldowns : const {},
          equipped: baseCharSnap.equipped,
          currentHp: isRecoverable ? simHp : null,
        );

        await saveSnapshot(
          PlayerSaveSnapshot(
            playerId: loaded.playerId,
            character: checkpointCharSnap,
            inventory: inventory.toSnapshot(),
            dungeon: workingDungeon,
            dungeonProgresses: Map.unmodifiable(workingProgresses),
            cycleProgress: workingCycle,
            session: workingSession,
            claimedEventIds: claimedIds,
            activeDungeonSession: workingActiveSession,
            offlineActivity: workingActivity,
          ),
        );

        if (!isBatchInterrupted || batchCount >= batchLimit) {
          break;
        }

        currentBatch = offlineService.process(
          character: character,
          inventory: inventory,
          config: config,
          session: workingSession,
          nowMs: now,
          offlineActivity: workingActivity,
          activeDungeonSession: workingActiveSession,
          dungeonProgress: workingDungeon,
          dungeonProgresses: workingProgresses,
          cycleProgress: workingCycle,
          rewardProcessor: rewardProcessor,
          claimedEventIds: claimedIds,
          maxIterations: iterationsPerBatch,
          initialHp: simHp,
          initialSkillCooldownTicks: simSkillCooldowns,
          initialReviveCooldownTicks: simReviveTicks,
          startingAttemptIndex: attemptIndex,
        );

        if (currentBatch.status != OfflineProgressionStatus.applied &&
            currentBatch.status != OfflineProgressionStatus.interrupted &&
            currentBatch.status != OfflineProgressionStatus.failed) {
          break;
        }
        aggregatedResult = _mergeResults(aggregatedResult, currentBatch);
      }
    } else {
      // Tidak menjalankan simulasi (paused / invalidClock / zeroElapsed /
      // alreadyClaimed / firstLaunch). Pertahankan high-water mark &
      // persistensikan normalisasi downed bila diperlukan.
      final isInvalidClock =
          firstResult.status == OfflineProgressionStatus.invalidClock;
      final effectiveSavedAtMs = isInvalidClock
          ? previousHighWater
          : math.max(now, previousHighWater);
      final effectiveActiveAtMs = isInvalidClock
          ? loaded.session.lastActiveAtMs
          : math.max(now, loaded.session.lastActiveAtMs);
      final effectiveClaimAtMs = math.max(
        loaded.session.lastOfflineClaimAtMs,
        firstResult.newLastOfflineClaimAtMs,
      );
      _highWaterTimestampMs = math.max(
        _highWaterTimestampMs,
        effectiveSavedAtMs,
      );

      workingSession = loaded.session.copyWith(
        lastActiveAtMs: effectiveActiveAtMs,
        lastSavedAtMs: effectiveSavedAtMs,
        lastOfflineClaimAtMs: effectiveClaimAtMs,
      );

      if (normalizedRecovery.normalized) {
        final baseCharSnap = character.toSnapshot();
        final isRecoverable = workingActiveSession?.isRecoverable == true;
        final persistedCharSnap = PlayerCharacterSnapshot(
          progress: baseCharSnap.progress,
          specializationId: baseCharSnap.specializationId,
          skillLevels: baseCharSnap.skillLevels,
          skillCooldownTicks: isRecoverable
              ? loaded.character.skillCooldownTicks
              : const {},
          equipped: baseCharSnap.equipped,
          currentHp: isRecoverable
              ? (normalizedRecovery.recoveredHp ?? loaded.character.currentHp)
              : null,
        );
        await saveSnapshot(
          PlayerSaveSnapshot(
            playerId: loaded.playerId,
            character: persistedCharSnap,
            inventory: inventory.toSnapshot(),
            dungeon: workingDungeon,
            dungeonProgresses: Map.unmodifiable(workingProgresses),
            cycleProgress: workingCycle,
            session: workingSession,
            claimedEventIds: claimedIds,
            activeDungeonSession: workingActiveSession,
            offlineActivity: workingActivity,
          ),
        );
      }
    }

    final finalRecoverable = workingActiveSession?.isRecoverable == true;
    return LoadedGameSession(
      character: character,
      inventory: inventory,
      dungeon: workingDungeon,
      dungeonProgresses: Map.unmodifiable(workingProgresses),
      cycleProgress: workingCycle,
      session: workingSession,
      claimedEventIds: claimedIds,
      offlineResult: aggregatedResult,
      rewardProcessor: rewardProcessor,
      activeDungeonSession: workingActiveSession,
      offlineActivity: workingActivity,
      recoveredHp: finalRecoverable ? simHp : null,
      recoveredSkillCooldownTicks: finalRecoverable
          ? Map.unmodifiable(simSkillCooldowns)
          : const {},
      shopPurchases: loaded.shopPurchases,
    );
  }

  OfflineProgressionResult _mergeResults(
    OfflineProgressionResult prev,
    OfflineProgressionResult next,
  ) {
    final addedStacks = <String, int>{...prev.addedStacks};
    for (final entry in next.addedStacks.entries) {
      addedStacks[entry.key] = (addedStacks[entry.key] ?? 0) + entry.value;
    }
    final overflowStacks = <String, int>{...prev.overflowStacks};
    for (final entry in next.overflowStacks.entries) {
      overflowStacks[entry.key] =
          (overflowStacks[entry.key] ?? 0) + entry.value;
    }
    final addedEquipment = <EquipmentInstance>[
      ...prev.addedEquipment,
      ...next.addedEquipment,
    ];
    final droppedEquipment = <EquipmentInstance>[
      ...prev.droppedEquipment,
      ...next.droppedEquipment,
    ];

    return OfflineProgressionResult(
      status: next.status,
      eventId: next.eventId.isNotEmpty ? next.eventId : prev.eventId,
      rawElapsed: prev.rawElapsed,
      effectiveElapsed: prev.effectiveElapsed + next.effectiveElapsed,
      cappedAtMaxDuration: prev.cappedAtMaxDuration || next.cappedAtMaxDuration,
      mode: next.mode,
      activityState: next.activityState,
      runsAttempted: prev.runsAttempted + next.runsAttempted,
      runsCompleted: prev.runsCompleted + next.runsCompleted,
      runsFailed: prev.runsFailed + next.runsFailed,
      roomsCleared: prev.roomsCleared + next.roomsCleared,
      encountersCleared: prev.encountersCleared + next.encountersCleared,
      expGained: prev.expGained + next.expGained,
      goldGained: prev.goldGained + next.goldGained,
      levelsGained: prev.levelsGained + next.levelsGained,
      addedStacks: Map.unmodifiable(addedStacks),
      overflowStacks: Map.unmodifiable(overflowStacks),
      addedEquipment: List.unmodifiable(addedEquipment),
      droppedEquipment: List.unmodifiable(droppedEquipment),
      newLastOfflineClaimAtMs: next.newLastOfflineClaimAtMs,
      stopReason: next.stopReason,
      updatedOfflineActivity: next.updatedOfflineActivity,
      updatedActiveDungeonSession: next.updatedActiveDungeonSession,
      updatedDungeonProgress: next.updatedDungeonProgress,
      remainingHp: next.remainingHp,
      remainingSkillCooldownTicks: next.remainingSkillCooldownTicks,
      remainingReviveCooldownTicks: next.remainingReviveCooldownTicks,
      processedDurationMs: prev.processedDurationMs + next.processedDurationMs,
      iterationsUsed: prev.iterationsUsed + next.iterationsUsed,
      nextAttemptIndex: next.nextAttemptIndex,
      failureReason: next.failureReason ?? prev.failureReason,
    );
  }

  ({
    ActiveDungeonSessionSnapshot? activeSession,
    int? recoveredHp,
    bool normalized,
  })
  _normalizeRecoveredSession({
    required PlayerSaveSnapshot loaded,
    required PlayerCharacter character,
  }) {
    final active = loaded.activeDungeonSession;
    if (active == null || !active.isRecoverable) {
      return (activeSession: active, recoveredHp: null, normalized: false);
    }

    final maxHp = character.stats.maxHp;
    var recoveredHp = loaded.character.currentHp;
    var reviveTicks = math.max(0, active.reviveCooldownTicks);
    var normalized = false;

    // Jika aplikasi ditutup ketika pemain sedang Downed, selesaikan konsekuensi
    // revive (30% Max HP + cooldown 90 detik) agar restart tidak memberi revive
    // ganda maupun memunculkan karakter dengan 0 HP.
    if (active.playerStatus == PlayerStatus.downed ||
        (recoveredHp != null && recoveredHp <= 0)) {
      normalized = true;
      recoveredHp = math.max(1, (maxHp * config.revive.hpPercent).round());
      if (reviveTicks == 0) {
        reviveTicks = math.max(
          1,
          (config.revive.cooldownSeconds * CombatSimulation.ticksPerSecond)
              .round(),
        );
      }
    } else if (recoveredHp != null) {
      final clamped = recoveredHp.clamp(1, maxHp);
      if (clamped != recoveredHp) {
        normalized = true;
      }
      recoveredHp = clamped;
    }

    return (
      activeSession: ActiveDungeonSessionSnapshot(
        runId: active.runId,
        dungeonId: active.dungeonId,
        currentRoomId: active.currentRoomId,
        currentRoomIndex: active.currentRoomIndex,
        status: active.status,
        clearedRoomIds: active.clearedRoomIds,
        completionRewardClaimed: active.completionRewardClaimed,
        reviveCooldownTicks: reviveTicks,
        playerStatus: PlayerStatus.alive,
        cycleRank: active.cycleRank,
      ),
      recoveredHp: recoveredHp,
      normalized: normalized,
    );
  }

  /// Menyimpan snapshot melalui antrean berurutan sehingga save berturut-turut
  /// selalu dijalankan satu per satu sesuai urutan pemanggilan.
  Future<void> saveSnapshot(PlayerSaveSnapshot snapshot) {
    _highWaterTimestampMs = math.max(
      _highWaterTimestampMs,
      math.max(
        snapshot.session.lastSavedAtMs,
        snapshot.session.lastOfflineClaimAtMs,
      ),
    );
    final completer = Completer<void>();
    _saveQueue = _saveQueue.then((_) async {
      try {
        await repository.saveSnapshot(snapshot);
        lastSaveError = null;
        if (!completer.isCompleted) completer.complete();
      } catch (e, st) {
        lastSaveError = e;
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> saveFromRuntime({
    required PlayerCharacter character,
    required Inventory inventory,
    required DungeonProgressSnapshot dungeon,
    required RewardProcessor rewardProcessor,
    required bool autoSkillEnabled,
    required int lastOfflineClaimAtMs,
    int? currentHp,
    Map<String, int> skillCooldownTicks = const {},
    ActiveDungeonSessionSnapshot? activeDungeonSession,
    Map<String, DungeonProgressSnapshot>? dungeonProgresses,
    CycleProgress cycleProgress = const CycleProgress(),
    OfflineActivitySnapshot? offlineActivity,
    Map<String, int> consecutiveDefeats = const {},
    String? lastFailedDungeonId,
  }) {
    final now = math.max(0, _nowMs());
    final monotonicSavedAtMs = math.max(now, _highWaterTimestampMs);
    final charSnap = character.toSnapshot();
    final updatedCharSnap = PlayerCharacterSnapshot(
      progress: charSnap.progress,
      specializationId: charSnap.specializationId,
      skillLevels: charSnap.skillLevels,
      skillCooldownTicks: skillCooldownTicks,
      equipped: charSnap.equipped,
      currentHp: currentHp,
    );

    // Simpan event offline, per-kill offline, dungeon clear, room clear, serta
    // penyelesaian siklus Ascension agar klaim ulang dicegah lintas restart.
    final persistentClaimed = {
      for (final id in rewardProcessor.claimedEventIds)
        if (id.startsWith('offline:') ||
            id.startsWith('offline_kill:') ||
            id.startsWith('dungeon_clear:') ||
            id.startsWith('room_clear:') ||
            id.startsWith('ascension:'))
          id,
    };

    final mergedProgresses = <String, DungeonProgressSnapshot>{
      ...?dungeonProgresses,
      dungeon.currentDungeonId: dungeon,
    };

    return saveSnapshot(
      PlayerSaveSnapshot(
        character: updatedCharSnap,
        inventory: inventory.toSnapshot(),
        dungeon: dungeon,
        dungeonProgresses: Map.unmodifiable(mergedProgresses),
        cycleProgress: cycleProgress,
        session: GameSessionSnapshot(
          lastActiveAtMs: now >= _highWaterTimestampMs
              ? now
              : monotonicSavedAtMs,
          lastSavedAtMs: monotonicSavedAtMs,
          lastOfflineClaimAtMs: math.max(0, lastOfflineClaimAtMs),
          autoSkillEnabled: autoSkillEnabled,
          consecutiveDefeats: Map<String, int>.unmodifiable({
            for (final entry in consecutiveDefeats.entries)
              if (entry.key.trim().isNotEmpty && entry.value > 0)
                entry.key.trim(): entry.value,
          }),
          lastFailedDungeonId: lastFailedDungeonId,
        ),
        claimedEventIds: persistentClaimed,
        activeDungeonSession: activeDungeonSession,
        offlineActivity:
            offlineActivity ?? const OfflineActivitySnapshot.paused(),
      ),
    );
  }
}
