import 'dart:math' as math;

import '../entities/cycle_progress.dart';
import '../entities/dungeon_definition.dart';
import '../entities/equipment.dart';
import '../entities/game_config.dart';
import '../entities/inventory.dart';
import '../entities/offline_activity.dart';
import '../entities/player_character.dart';
import '../entities/player_save_snapshot.dart';
import 'dungeon_progression_service.dart';
import 'equipment_factory.dart';
import 'loot_service.dart';
import 'offline_dungeon_runner.dart';
import 'offline_time_calculator.dart';
import 'reward_processor.dart';

enum OfflineProgressionStatus {
  applied,
  paused,
  interrupted,
  failed,
  firstLaunch,
  zeroElapsed,
  invalidClock,
  alreadyClaimed,
  noEligibleEncounter,
}

class OfflineProgressionResult {
  const OfflineProgressionResult({
    required this.status,
    required this.eventId,
    required this.rawElapsed,
    required this.effectiveElapsed,
    required this.cappedAtMaxDuration,
    this.mode = OfflineActivityMode.pauseProgression,
    this.activityState = OfflineActivityState.inactive,
    this.runsAttempted = 0,
    this.runsCompleted = 0,
    this.runsFailed = 0,
    this.roomsCleared = 0,
    this.encountersCleared = 0,
    this.expGained = 0,
    this.goldGained = 0,
    this.levelsGained = 0,
    this.addedStacks = const {},
    this.overflowStacks = const {},
    this.addedEquipment = const [],
    this.droppedEquipment = const [],
    required this.newLastOfflineClaimAtMs,
    this.stopReason,
    this.updatedOfflineActivity,
    this.updatedActiveDungeonSession,
    this.updatedDungeonProgress,
    this.remainingHp,
    this.remainingSkillCooldownTicks = const {},
    this.remainingReviveCooldownTicks = 0,
    this.processedDurationMs = 0,
    this.iterationsUsed = 0,
    this.nextAttemptIndex = 1,
    this.failureReason,
  });

  factory OfflineProgressionResult.none({
    required OfflineProgressionStatus status,
    required int claimAtMs,
    Duration rawElapsed = Duration.zero,
    String eventId = '',
    OfflineActivityMode mode = OfflineActivityMode.pauseProgression,
    OfflineActivityState activityState = OfflineActivityState.inactive,
    OfflineActivitySnapshot? updatedOfflineActivity,
    ActiveDungeonSessionSnapshot? updatedActiveDungeonSession,
    DungeonProgressSnapshot? updatedDungeonProgress,
    String? failureReason,
  }) {
    return OfflineProgressionResult(
      status: status,
      eventId: eventId,
      rawElapsed: rawElapsed,
      effectiveElapsed: Duration.zero,
      cappedAtMaxDuration: false,
      mode: mode,
      activityState: activityState,
      newLastOfflineClaimAtMs: claimAtMs,
      updatedOfflineActivity: updatedOfflineActivity,
      updatedActiveDungeonSession: updatedActiveDungeonSession,
      updatedDungeonProgress: updatedDungeonProgress,
      failureReason: failureReason,
    );
  }

  final OfflineProgressionStatus status;
  final String eventId;
  final Duration rawElapsed;
  final Duration effectiveElapsed;
  final bool cappedAtMaxDuration;
  final OfflineActivityMode mode;
  final OfflineActivityState activityState;
  final int runsAttempted;
  final int runsCompleted;
  final int runsFailed;
  final int roomsCleared;
  final int encountersCleared;
  final int expGained;
  final int goldGained;
  final int levelsGained;
  final Map<String, int> addedStacks;
  final Map<String, int> overflowStacks;
  final List<EquipmentInstance> addedEquipment;
  final List<EquipmentInstance> droppedEquipment;
  final int newLastOfflineClaimAtMs;
  final OfflineDungeonStopReason? stopReason;
  final OfflineActivitySnapshot? updatedOfflineActivity;
  final ActiveDungeonSessionSnapshot? updatedActiveDungeonSession;
  final DungeonProgressSnapshot? updatedDungeonProgress;
  final int? remainingHp;
  final Map<String, int> remainingSkillCooldownTicks;
  final int remainingReviveCooldownTicks;
  final int processedDurationMs;
  final int iterationsUsed;
  final int nextAttemptIndex;
  final String? failureReason;

  bool get hasRewards =>
      expGained > 0 ||
      goldGained > 0 ||
      addedStacks.isNotEmpty ||
      addedEquipment.isNotEmpty;
}

/// Orkestrator **Hybrid Offline Progression** (M6 Stage 2):
/// - **Default (`pauseProgression`):** tidak menjalankan simulasi / reward.
/// - **Mode A (`continueDungeon`):** melanjutkan dungeon aktif dari checkpoint
///   room terakhir, menjaga `runId`, aturan combat/skill/revive M5, berhenti
///   saat selesai atau kalah, tanpa memulai dungeon baru.
/// - **Mode B (`autoFarming`):** menjalankan auto-farming hanya pada dungeon
///   normal terbuka yang sudah diselesaikan pada siklus saat ini
///   (`clearedInCycleRank == cycleProgress.ascensionRank`), dengan `runId` unik
///   tiap attempt dan kebijakan `stopOnDefeat`.
class OfflineProgressionService {
  const OfflineProgressionService({
    this.lootService = const LootService(),
    this.timeCalculator = const OfflineTimeCalculator(),
    this.runner = const OfflineDungeonRunner(),
  });

  static const Duration maxOfflineDuration =
      OfflineTimeCalculator.defaultMaxOfflineDuration;

  final LootService lootService;
  final OfflineTimeCalculator timeCalculator;
  final OfflineDungeonRunner runner;

  OfflineProgressionResult process({
    required PlayerCharacter character,
    required Inventory inventory,
    required GameConfig config,
    required GameSessionSnapshot session,
    required int nowMs,
    OfflineActivitySnapshot offlineActivity =
        const OfflineActivitySnapshot.paused(),
    ActiveDungeonSessionSnapshot? activeDungeonSession,
    DungeonProgressSnapshot? dungeonProgress,
    Map<String, DungeonProgressSnapshot> dungeonProgresses = const {},
    CycleProgress cycleProgress = const CycleProgress(),
    RewardProcessor? rewardProcessor,
    Set<String>? claimedEventIds,
    int? simulationSeed,
    int maxIterations = OfflineDungeonRunRequest.defaultMaxIterations,
    int? initialHp,
    Map<String, int> initialSkillCooldownTicks = const {},
    int initialReviveCooldownTicks = 0,
    int startingAttemptIndex = 1,
    math.Random? random,
  }) {
    final mergedClaimedIds = <String>{
      ...?claimedEventIds,
      ...?rewardProcessor?.claimedEventIds,
    };

    final timeWindow = timeCalculator.calculate(
      session: session,
      nowMs: nowMs,
      activity: offlineActivity,
      claimedEventIds: mergedClaimedIds,
    );

    if (timeWindow.status == OfflineTimeValidationStatus.firstLaunch) {
      return OfflineProgressionResult.none(
        status: OfflineProgressionStatus.firstLaunch,
        claimAtMs: timeWindow.newLastOfflineClaimAtMs,
        mode: offlineActivity.mode,
        activityState: offlineActivity.state,
        updatedOfflineActivity: offlineActivity,
        updatedActiveDungeonSession: activeDungeonSession,
        updatedDungeonProgress: dungeonProgress,
      );
    }

    if (timeWindow.status == OfflineTimeValidationStatus.invalidClock) {
      return OfflineProgressionResult.none(
        status: OfflineProgressionStatus.invalidClock,
        claimAtMs: timeWindow.newLastOfflineClaimAtMs,
        rawElapsed: timeWindow.rawElapsed,
        mode: offlineActivity.mode,
        activityState: offlineActivity.state,
        updatedOfflineActivity: offlineActivity,
        updatedActiveDungeonSession: activeDungeonSession,
        updatedDungeonProgress: dungeonProgress,
      );
    }

    // Default mode: Pause Progression tidak menjalankan simulasi maupun
    // menghasilkan reward dan tidak membangkitkan summary offline.
    if (offlineActivity.isPaused) {
      return OfflineProgressionResult.none(
        status: OfflineProgressionStatus.paused,
        claimAtMs: session.lastOfflineClaimAtMs,
        rawElapsed: timeWindow.rawElapsed,
        mode: offlineActivity.mode,
        activityState: offlineActivity.state,
        updatedOfflineActivity: offlineActivity,
        updatedActiveDungeonSession: activeDungeonSession,
        updatedDungeonProgress: dungeonProgress,
      );
    }

    // State terminal (completed/failed) tidak boleh di-replay tanpa aktivitas
    // baru dari pemain.
    if (offlineActivity.state == OfflineActivityState.completed ||
        offlineActivity.state == OfflineActivityState.failed) {
      return OfflineProgressionResult.none(
        status: OfflineProgressionStatus.alreadyClaimed,
        claimAtMs: session.lastOfflineClaimAtMs,
        rawElapsed: timeWindow.rawElapsed,
        mode: offlineActivity.mode,
        activityState: offlineActivity.state,
        updatedOfflineActivity: offlineActivity,
        updatedActiveDungeonSession: activeDungeonSession,
        updatedDungeonProgress: dungeonProgress,
      );
    }

    if (!offlineActivity.isRunnableOnResume) {
      return OfflineProgressionResult.none(
        status: OfflineProgressionStatus.paused,
        claimAtMs: session.lastOfflineClaimAtMs,
        rawElapsed: timeWindow.rawElapsed,
        mode: offlineActivity.mode,
        activityState: offlineActivity.state,
        updatedOfflineActivity: offlineActivity,
        updatedActiveDungeonSession: activeDungeonSession,
        updatedDungeonProgress: dungeonProgress,
      );
    }

    if (timeWindow.status == OfflineTimeValidationStatus.zeroElapsed) {
      return OfflineProgressionResult.none(
        status: OfflineProgressionStatus.zeroElapsed,
        claimAtMs: timeWindow.newLastOfflineClaimAtMs,
        rawElapsed: timeWindow.rawElapsed,
        mode: offlineActivity.mode,
        activityState: offlineActivity.state,
        updatedOfflineActivity: offlineActivity,
        updatedActiveDungeonSession: activeDungeonSession,
        updatedDungeonProgress: dungeonProgress,
      );
    }

    if (timeWindow.status == OfflineTimeValidationStatus.alreadyClaimed) {
      return OfflineProgressionResult.none(
        status: OfflineProgressionStatus.alreadyClaimed,
        claimAtMs: timeWindow.newLastOfflineClaimAtMs,
        rawElapsed: timeWindow.rawElapsed,
        eventId: timeWindow.eventId,
        mode: offlineActivity.mode,
        activityState: offlineActivity.state,
        updatedOfflineActivity: offlineActivity,
        updatedActiveDungeonSession: activeDungeonSession,
        updatedDungeonProgress: dungeonProgress,
      );
    }

    if (timeWindow.status == OfflineTimeValidationStatus.budgetExhausted) {
      if (offlineActivity.state == OfflineActivityState.interrupted) {
        final processing = _advanceToProcessing(offlineActivity);
        final prevSummary = processing.pendingSummary;
        final finalSummary = OfflineSummarySnapshot(
          eventId:
              prevSummary?.eventId ?? 'offline:${session.lastSavedAtMs}:$nowMs',
          mode: processing.mode,
          finalState: OfflineActivityState.completed,
          effectiveElapsedMs:
              prevSummary?.effectiveElapsedMs ??
              processing.processedOfflineDurationMs,
          cappedAtMaxDuration:
              (prevSummary?.cappedAtMaxDuration ?? false) ||
              timeWindow.cappedAtMaxDuration,
          runsAttempted: prevSummary?.runsAttempted ?? 0,
          runsCompleted: prevSummary?.runsCompleted ?? 0,
          runsFailed: prevSummary?.runsFailed ?? 0,
          roomsCleared: prevSummary?.roomsCleared ?? 0,
          encountersCleared: prevSummary?.encountersCleared ?? 0,
          expGained: prevSummary?.expGained ?? 0,
          goldGained: prevSummary?.goldGained ?? 0,
          levelsGained: prevSummary?.levelsGained ?? 0,
          addedStacks: prevSummary?.addedStacks ?? const {},
          overflowStacks: prevSummary?.overflowStacks ?? const {},
          addedEquipmentCount: prevSummary?.addedEquipmentCount ?? 0,
          droppedEquipmentCount: prevSummary?.droppedEquipmentCount ?? 0,
          generatedAtMs: nowMs,
          cycleRank: cycleProgress.ascensionRank,
        );
        final completed = processing.transitionTo(
          OfflineActivityState.completed,
          pendingSummary: finalSummary,
        );
        return OfflineProgressionResult.none(
          status: OfflineProgressionStatus.applied,
          claimAtMs: nowMs,
          rawElapsed: timeWindow.rawElapsed,
          mode: completed.mode,
          activityState: completed.state,
          updatedOfflineActivity: completed,
          updatedActiveDungeonSession:
              completed.mode == OfflineActivityMode.autoFarming
              ? null
              : activeDungeonSession,
          updatedDungeonProgress: dungeonProgress,
        );
      }
      return OfflineProgressionResult.none(
        status: OfflineProgressionStatus.alreadyClaimed,
        claimAtMs: session.lastOfflineClaimAtMs,
        rawElapsed: timeWindow.rawElapsed,
        mode: offlineActivity.mode,
        activityState: offlineActivity.state,
        updatedOfflineActivity: offlineActivity,
        updatedActiveDungeonSession: activeDungeonSession,
        updatedDungeonProgress: dungeonProgress,
      );
    }

    // Validasi syarat mode sebelum masuk ke eksekusi simulasi.
    if (offlineActivity.mode == OfflineActivityMode.continueDungeon) {
      final active = activeDungeonSession;
      final runMismatch =
          active == null ||
          !active.isRecoverable ||
          (offlineActivity.activeRunId != null &&
              offlineActivity.activeRunId != active.runId);
      final missingDungeon =
          active == null ||
          (!active.isBossEvent &&
              !config.dungeons.containsKey(active.dungeonId)) ||
          (active.isBossEvent &&
              config.bossEvents?.findBossById(active.bossEventId ?? '') ==
                  null);
      if (runMismatch || missingDungeon) {
        const reason = 'Sesi Continue Dungeon tidak valid atau sudah berakhir.';
        final pending = _advanceToPending(offlineActivity);
        final failedSummary = OfflineSummarySnapshot(
          eventId: timeWindow.eventId,
          mode: OfflineActivityMode.continueDungeon,
          finalState: OfflineActivityState.failed,
          effectiveElapsedMs: 0,
          generatedAtMs: nowMs,
          failureReason: reason,
        );
        final failedActivity = pending.transitionTo(
          OfflineActivityState.failed,
          pendingSummary: failedSummary,
        );
        return OfflineProgressionResult.none(
          status: OfflineProgressionStatus.failed,
          claimAtMs: session.lastOfflineClaimAtMs,
          rawElapsed: timeWindow.rawElapsed,
          eventId: timeWindow.eventId,
          mode: failedActivity.mode,
          activityState: failedActivity.state,
          updatedOfflineActivity: failedActivity,
          updatedActiveDungeonSession: activeDungeonSession,
          updatedDungeonProgress: dungeonProgress,
          failureReason: reason,
        );
      }

      final targetDungeonId = active.dungeonId;
      final activeDungeonDef = config.dungeons[targetDungeonId];
      final isBossRun =
          active.isBossEvent || (activeDungeonDef?.isBossEvent ?? false);
      final isManualOnly =
          isBossRun || (activeDungeonDef?.isAscension ?? false);
      if (isManualOnly) {
        final reason = isBossRun
            ? 'Boss Event hanya dapat dimainkan secara manual; aktivitas offline dialihkan ke Pause Progression.'
            : 'Ascension Dungeon hanya dapat dimainkan secara manual; aktivitas offline dialihkan ke Pause Progression.';
        final pending = _advanceToPending(offlineActivity);
        final forcedSummary = OfflineSummarySnapshot(
          eventId: timeWindow.eventId,
          mode: OfflineActivityMode.pauseProgression,
          finalState: OfflineActivityState.failed,
          effectiveElapsedMs: 0,
          generatedAtMs: nowMs,
          cycleRank: cycleProgress.ascensionRank,
          failureReason: reason,
        );
        final resetActivity = pending.transitionTo(
          OfflineActivityState.inactive,
          mode: OfflineActivityMode.pauseProgression,
          clearSelectedDungeonId: true,
          clearActiveRunId: true,
          clearSimulationSeed: true,
          processedOfflineDurationMs: 0,
          pendingSummary: forcedSummary,
        );
        return OfflineProgressionResult.none(
          status: OfflineProgressionStatus.noEligibleEncounter,
          claimAtMs: session.lastOfflineClaimAtMs,
          rawElapsed: timeWindow.rawElapsed,
          eventId: timeWindow.eventId,
          mode: OfflineActivityMode.pauseProgression,
          activityState: resetActivity.state,
          updatedOfflineActivity: resetActivity,
          updatedActiveDungeonSession: activeDungeonSession,
          updatedDungeonProgress: dungeonProgress,
          failureReason: reason,
        );
      }

      final progress = _resolveProgress(
        dungeonId: targetDungeonId,
        primary: dungeonProgress,
        progressMap: dungeonProgresses,
      );
      return _executeSimulation(
        character: character,
        inventory: inventory,
        config: config,
        session: session,
        nowMs: nowMs,
        timeWindow: timeWindow,
        offlineActivity: offlineActivity,
        targetDungeonId: targetDungeonId,
        targetProgress: progress,
        cycleProgress: cycleProgress,
        activeDungeonSession: active,
        rewardProcessor: rewardProcessor,
        claimedEventIds: claimedEventIds,
        mergedClaimedIds: mergedClaimedIds,
        simulationSeed: simulationSeed,
        maxIterations: maxIterations,
        initialHp: initialHp,
        initialSkillCooldownTicks: initialSkillCooldownTicks,
        initialReviveCooldownTicks: math.max(
          initialReviveCooldownTicks,
          active.reviveCooldownTicks,
        ),
        startingAttemptIndex: startingAttemptIndex,
        random: random,
      );
    }

    // Mode B: Auto Farming
    final targetDungeonId = offlineActivity.selectedDungeonId;
    final dungeonDef = targetDungeonId == null
        ? null
        : config.dungeons[targetDungeonId];
    final targetProgress = targetDungeonId == null
        ? const DungeonProgressSnapshot()
        : _resolveProgress(
            dungeonId: targetDungeonId,
            primary: dungeonProgress,
            progressMap: dungeonProgresses,
          );
    final effectiveProgresses = targetDungeonId == null
        ? dungeonProgresses
        : <String, DungeonProgressSnapshot>{
            ...dungeonProgresses,
            targetDungeonId: targetProgress,
          };
    final progressionService = DungeonProgressionService(config.difficulty);
    final isCycleCleared =
        targetDungeonId != null &&
        progressionService.isClearedInCurrentCycle(
          targetDungeonId,
          cycleProgress,
          effectiveProgresses,
        );

    if (dungeonDef == null || !dungeonDef.isNormal || !isCycleCleared) {
      final reason = dungeonDef == null
          ? 'Auto Farming ditolak: dungeon "$targetDungeonId" tidak ditemukan.'
          : switch (dungeonDef.kind) {
              DungeonKind.bossDaily || DungeonKind.bossWeekly =>
                'Auto Farming ditolak: Boss Event ("$targetDungeonId") hanya dimainkan manual.',
              DungeonKind.ascension =>
                'Auto Farming ditolak: Ascension Dungeon ("$targetDungeonId") hanya dimainkan manual.',
              DungeonKind.normal =>
                'Auto Farming ditolak: dungeon "$targetDungeonId" belum diselesaikan pada siklus saat ini (rank ${cycleProgress.ascensionRank}).',
            };
      final pending = _advanceToPending(offlineActivity);
      final resetActivity = pending.transitionTo(
        OfflineActivityState.inactive,
        mode: OfflineActivityMode.pauseProgression,
        clearSelectedDungeonId: true,
        clearActiveRunId: true,
        clearSimulationSeed: true,
      );
      return OfflineProgressionResult.none(
        status: OfflineProgressionStatus.noEligibleEncounter,
        claimAtMs: session.lastOfflineClaimAtMs,
        rawElapsed: timeWindow.rawElapsed,
        eventId: timeWindow.eventId,
        mode: OfflineActivityMode.autoFarming,
        activityState: resetActivity.state,
        updatedOfflineActivity: resetActivity,
        updatedActiveDungeonSession: activeDungeonSession,
        updatedDungeonProgress: dungeonProgress,
        failureReason: reason,
      );
    }

    return _executeSimulation(
      character: character,
      inventory: inventory,
      config: config,
      session: session,
      nowMs: nowMs,
      timeWindow: timeWindow,
      offlineActivity: offlineActivity,
      targetDungeonId: targetDungeonId,
      targetProgress: targetProgress,
      cycleProgress: cycleProgress,
      activeDungeonSession: activeDungeonSession,
      rewardProcessor: rewardProcessor,
      claimedEventIds: claimedEventIds,
      mergedClaimedIds: mergedClaimedIds,
      simulationSeed: simulationSeed,
      maxIterations: maxIterations,
      initialHp: initialHp,
      initialSkillCooldownTicks: initialSkillCooldownTicks,
      initialReviveCooldownTicks: initialReviveCooldownTicks,
      startingAttemptIndex: startingAttemptIndex,
      random: random,
    );
  }

  OfflineProgressionResult _executeSimulation({
    required PlayerCharacter character,
    required Inventory inventory,
    required GameConfig config,
    required GameSessionSnapshot session,
    required int nowMs,
    required OfflineTimeWindow timeWindow,
    required OfflineActivitySnapshot offlineActivity,
    required String targetDungeonId,
    required DungeonProgressSnapshot targetProgress,
    required CycleProgress cycleProgress,
    required ActiveDungeonSessionSnapshot? activeDungeonSession,
    required RewardProcessor? rewardProcessor,
    required Set<String>? claimedEventIds,
    required Set<String> mergedClaimedIds,
    required int? simulationSeed,
    required int maxIterations,
    required int? initialHp,
    required Map<String, int> initialSkillCooldownTicks,
    required int initialReviveCooldownTicks,
    required int startingAttemptIndex,
    required math.Random? random,
  }) {
    final processing = _advanceToProcessing(offlineActivity);

    final baseSeed =
        processing.simulationSeed ??
        simulationSeed ??
        (random != null
            ? random.nextInt(0x7fffffff)
            : ((timeWindow.anchorTimestampMs ^ timeWindow.endTimestampMs) &
                  0x7fffffff));
    // Bila batch lanjutan memakai seed aktivitas yang sama, geser seed
    // secara deterministik berdasar progres ms agar roll RNG tidak identik.
    final batchSeed = timeWindow.previouslyProcessedMs > 0
        ? (baseSeed ^ timeWindow.previouslyProcessedMs) & 0x7fffffff
        : baseSeed;

    final effectiveRewardProcessor =
        rewardProcessor ??
        RewardProcessor(
          character: character,
          inventory: inventory,
          items: config.items,
          lootTables: config.lootTables,
          lootService: lootService,
          equipmentFactory: EquipmentFactory(config.equipment),
          claimedEventIds: mergedClaimedIds,
        );

    final effectiveRunner =
        runner.damageCalculator.formula == config.damage.formula
        ? runner
        : runner.copyWith(damageCalculator: config.damage.createCalculator());

    final outcome = effectiveRunner.runBatch(
      OfflineDungeonRunRequest(
        mode: processing.mode,
        character: character,
        inventory: inventory,
        config: config,
        rewardProcessor: effectiveRewardProcessor,
        dungeonId: targetDungeonId,
        dungeonProgress: targetProgress,
        activeDungeonSession: activeDungeonSession,
        timeWindow: timeWindow,
        simulationSeed: batchSeed,
        maxIterations: maxIterations,
        autoSkillEnabled: session.autoSkillEnabled,
        initialHp: initialHp,
        initialReviveCooldownTicks: initialReviveCooldownTicks,
        initialSkillCooldownTicks: initialSkillCooldownTicks,
        startingAttemptIndex: startingAttemptIndex,
        cycleRank: cycleProgress.ascensionRank,
      ),
    );

    if (claimedEventIds != null) {
      claimedEventIds.addAll(effectiveRewardProcessor.claimedEventIds);
    }

    final isInterrupted =
        outcome.stopReason == OfflineDungeonStopReason.iterationLimitReached;
    final isFailed =
        outcome.stopReason == OfflineDungeonStopReason.playerDefeated ||
        outcome.stopReason == OfflineDungeonStopReason.invalidSetup;

    final OfflineActivityState nextState;
    final OfflineProgressionStatus resultStatus;
    if (isInterrupted) {
      nextState = OfflineActivityState.interrupted;
      resultStatus = OfflineProgressionStatus.interrupted;
    } else if (isFailed) {
      nextState = OfflineActivityState.failed;
      resultStatus = OfflineProgressionStatus.failed;
    } else {
      nextState = OfflineActivityState.completed;
      resultStatus = OfflineProgressionStatus.applied;
    }

    final batchProcessedMs = math.max(0, outcome.processedDurationMs);
    final cumulativeProcessedMs =
        timeWindow.previouslyProcessedMs + batchProcessedMs;
    final checkpointAtMs = math.min(
      nowMs,
      math.max(
        timeWindow.anchorTimestampMs,
        timeWindow.anchorTimestampMs + batchProcessedMs,
      ),
    );

    final newClaimAtMs = isInterrupted
        ? math.max(session.lastOfflineClaimAtMs, checkpointAtMs)
        : (outcome.stopReason == OfflineDungeonStopReason.invalidSetup
              ? session.lastOfflineClaimAtMs
              : timeWindow.newLastOfflineClaimAtMs);

    if (!isInterrupted &&
        outcome.stopReason != OfflineDungeonStopReason.invalidSetup) {
      effectiveRewardProcessor.markClaimed(timeWindow.eventId);
      claimedEventIds?.add(timeWindow.eventId);
    }

    final summary = _mergeSummary(
      previous: processing.pendingSummary,
      outcome: outcome,
      eventId: timeWindow.eventId,
      mode: processing.mode,
      finalState: nextState,
      cappedAtMaxDuration:
          (processing.pendingSummary?.cappedAtMaxDuration ?? false) ||
          timeWindow.cappedAtMaxDuration,
      generatedAtMs: nowMs,
      cycleRank: cycleProgress.ascensionRank,
    );

    final updatedActivity = processing.transitionTo(
      nextState,
      activeRunId: processing.mode == OfflineActivityMode.continueDungeon
          ? processing.activeRunId
          : outcome.updatedActiveDungeonSession?.runId,
      clearActiveRunId:
          processing.mode == OfflineActivityMode.autoFarming && !isInterrupted,
      lastCheckpointAtMs: checkpointAtMs,
      processedOfflineDurationMs: cumulativeProcessedMs,
      simulationSeed: baseSeed,
      pendingSummary: summary,
    );

    return OfflineProgressionResult(
      status: resultStatus,
      eventId: timeWindow.eventId,
      rawElapsed: timeWindow.rawElapsed,
      effectiveElapsed: Duration(milliseconds: batchProcessedMs),
      cappedAtMaxDuration: timeWindow.cappedAtMaxDuration,
      mode: processing.mode,
      activityState: updatedActivity.state,
      runsAttempted: outcome.runsAttempted,
      runsCompleted: outcome.runsCompleted,
      runsFailed: outcome.runsFailed,
      roomsCleared: outcome.roomsCleared,
      encountersCleared: outcome.encountersCleared,
      expGained: outcome.expGained,
      goldGained: outcome.goldGained,
      levelsGained: outcome.levelsGained,
      addedStacks: outcome.addedStacks,
      overflowStacks: outcome.overflowStacks,
      addedEquipment: outcome.addedEquipment,
      droppedEquipment: outcome.droppedEquipment,
      newLastOfflineClaimAtMs: newClaimAtMs,
      stopReason: outcome.stopReason,
      updatedOfflineActivity: updatedActivity,
      updatedActiveDungeonSession: outcome.updatedActiveDungeonSession,
      updatedDungeonProgress: outcome.updatedDungeonProgress,
      remainingHp: outcome.remainingHp,
      remainingSkillCooldownTicks: outcome.remainingSkillCooldownTicks,
      remainingReviveCooldownTicks: outcome.remainingReviveCooldownTicks,
      processedDurationMs: batchProcessedMs,
      iterationsUsed: outcome.iterationsUsed,
      nextAttemptIndex: outcome.nextAttemptIndex,
      failureReason: outcome.failureReason,
    );
  }

  OfflineSummarySnapshot _mergeSummary({
    required OfflineSummarySnapshot? previous,
    required OfflineDungeonRunOutcome outcome,
    required String eventId,
    required OfflineActivityMode mode,
    required OfflineActivityState finalState,
    required bool cappedAtMaxDuration,
    required int generatedAtMs,
    required int cycleRank,
  }) {
    final prev =
        previous != null &&
            previous.finalState == OfflineActivityState.interrupted
        ? previous
        : null;

    final addedStacks = <String, int>{...?prev?.addedStacks};
    for (final entry in outcome.addedStacks.entries) {
      addedStacks[entry.key] = (addedStacks[entry.key] ?? 0) + entry.value;
    }

    final overflowStacks = <String, int>{...?prev?.overflowStacks};
    for (final entry in outcome.overflowStacks.entries) {
      overflowStacks[entry.key] =
          (overflowStacks[entry.key] ?? 0) + entry.value;
    }

    return OfflineSummarySnapshot(
      eventId: eventId,
      mode: mode,
      finalState: finalState,
      effectiveElapsedMs:
          (prev?.effectiveElapsedMs ?? 0) + outcome.processedDurationMs,
      cappedAtMaxDuration: cappedAtMaxDuration,
      runsAttempted: (prev?.runsAttempted ?? 0) + outcome.runsAttempted,
      runsCompleted: (prev?.runsCompleted ?? 0) + outcome.runsCompleted,
      runsFailed: (prev?.runsFailed ?? 0) + outcome.runsFailed,
      roomsCleared: (prev?.roomsCleared ?? 0) + outcome.roomsCleared,
      encountersCleared:
          (prev?.encountersCleared ?? 0) + outcome.encountersCleared,
      expGained: (prev?.expGained ?? 0) + outcome.expGained,
      goldGained: (prev?.goldGained ?? 0) + outcome.goldGained,
      levelsGained: (prev?.levelsGained ?? 0) + outcome.levelsGained,
      addedStacks: Map.unmodifiable(addedStacks),
      overflowStacks: Map.unmodifiable(overflowStacks),
      addedEquipmentCount:
          (prev?.addedEquipmentCount ?? 0) + outcome.addedEquipment.length,
      droppedEquipmentCount:
          (prev?.droppedEquipmentCount ?? 0) + outcome.droppedEquipment.length,
      acknowledged: false,
      generatedAtMs: generatedAtMs,
      cycleRank: cycleRank,
      failureReason: outcome.failureReason,
    );
  }

  DungeonProgressSnapshot _resolveProgress({
    required String dungeonId,
    required DungeonProgressSnapshot? primary,
    required Map<String, DungeonProgressSnapshot> progressMap,
  }) =>
      progressMap[dungeonId] ??
      (primary != null && primary.currentDungeonId == dungeonId
          ? primary
          : DungeonProgressSnapshot(currentDungeonId: dungeonId));

  OfflineActivitySnapshot _advanceToPending(OfflineActivitySnapshot current) {
    if (current.state == OfflineActivityState.pending) return current;
    if (current.state == OfflineActivityState.configured ||
        current.state == OfflineActivityState.interrupted) {
      return current.transitionTo(OfflineActivityState.pending);
    }
    throw StateError(
      'Tidak bisa memasuki state pending dari ${current.state.name}.',
    );
  }

  OfflineActivitySnapshot _advanceToProcessing(
    OfflineActivitySnapshot current,
  ) {
    final pending = _advanceToPending(current);
    return pending.transitionTo(OfflineActivityState.processing);
  }
}
