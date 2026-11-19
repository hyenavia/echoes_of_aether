import 'dart:math' as math;

import '../entities/combat_stats.dart';
import '../entities/combatant.dart';
import '../entities/dungeon_definition.dart';
import '../entities/dungeon_session.dart';
import '../entities/enemy_definition.dart';
import '../entities/equipment.dart';
import '../entities/game_config.dart';
import '../entities/grid_point.dart';
import '../entities/inventory.dart';
import '../entities/offline_activity.dart';
import '../entities/player_character.dart';
import '../entities/player_save_snapshot.dart';
import '../entities/player_status.dart';
import '../entities/skill_definition.dart';
import '../entities/skill_runtime_state.dart';
import 'astar_pathfinder.dart';
import 'attack_position_finder.dart';
import 'combat_simulation.dart';
import 'damage_calculator.dart';
import 'difficulty_service.dart';
import 'dungeon_manager.dart';
import 'dungeon_reward_settlement_service.dart';
import 'encounter_tracker.dart';
import 'navigation_grid.dart';
import 'offline_time_calculator.dart';
import 'reward_processor.dart';
import 'room_completion_evaluator.dart';
import 'skill_selector.dart';
import 'target_selector.dart';

/// Alasan berhentinya satu batch eksekusi [OfflineDungeonRunner].
enum OfflineDungeonStopReason {
  timeBudgetExhausted,
  dungeonCompleted,
  playerDefeated,
  iterationLimitReached,
  invalidSetup,
}

/// Request eksekusi simulasi dungeon headless (bebas Flutter/Flame).
class OfflineDungeonRunRequest {
  const OfflineDungeonRunRequest({
    required this.mode,
    required this.character,
    required this.inventory,
    required this.config,
    required this.rewardProcessor,
    required this.dungeonId,
    required this.dungeonProgress,
    required this.timeWindow,
    required this.simulationSeed,
    this.activeDungeonSession,
    this.maxIterations = defaultMaxIterations,
    this.autoSkillEnabled = true,
    this.initialHp,
    this.initialReviveCooldownTicks = 0,
    this.initialSkillCooldownTicks = const {},
    this.startingAttemptIndex = 1,
    this.cycleRank = 0,
    this.difficultyProfileOverride,
  });

  static const int defaultMaxIterations = 50000;

  final OfflineActivityMode mode;
  final PlayerCharacter character;
  final Inventory inventory;
  final GameConfig config;
  final RewardProcessor rewardProcessor;
  final String dungeonId;
  final DungeonProgressSnapshot dungeonProgress;
  final ActiveDungeonSessionSnapshot? activeDungeonSession;
  final OfflineTimeWindow timeWindow;
  final int simulationSeed;
  final int maxIterations;
  final bool autoSkillEnabled;
  final int? initialHp;
  final int initialReviveCooldownTicks;
  final Map<String, int> initialSkillCooldownTicks;
  final int startingAttemptIndex;
  final int cycleRank;
  final DifficultyProfile? difficultyProfileOverride;
}

/// Hasil satu batch simulasi dari [OfflineDungeonRunner].
class OfflineDungeonRunOutcome {
  const OfflineDungeonRunOutcome({
    required this.stopReason,
    required this.updatedDungeonProgress,
    required this.remainingSkillCooldownTicks,
    required this.remainingReviveCooldownTicks,
    required this.nextAttemptIndex,
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
    this.autoSoldEquipmentCount = 0,
    this.autoSoldEquipmentGold = 0,
    this.ticksSimulated = 0,
    this.budgetTicks = 0,
    this.processedDurationMs = 0,
    this.iterationsUsed = 0,
    this.updatedActiveDungeonSession,
    this.remainingHp,
    this.finalPlayerHp,
    this.finalPlayerMaxHp,
    this.failureReason,
  });

  final OfflineDungeonStopReason stopReason;
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
  final int autoSoldEquipmentCount;
  final int autoSoldEquipmentGold;
  final int ticksSimulated;
  final int budgetTicks;
  final int processedDurationMs;
  final int iterationsUsed;
  final DungeonProgressSnapshot updatedDungeonProgress;
  final ActiveDungeonSessionSnapshot? updatedActiveDungeonSession;
  final int? remainingHp;

  /// HP aktual pemain pada akhir batch (termasuk saat selesai atau run ended),
  /// berguna untuk telemetri/simulator tanpa mengubah aturan pemulihan [remainingHp].
  final int? finalPlayerHp;

  /// Max HP efektif pemain pada akhir batch.
  final int? finalPlayerMaxHp;
  final Map<String, int> remainingSkillCooldownTicks;
  final int remainingReviveCooldownTicks;
  final int nextAttemptIndex;
  final String? failureReason;

  bool get isInterrupted =>
      stopReason == OfflineDungeonStopReason.iterationLimitReached;

  bool get isTerminalForActivity =>
      stopReason == OfflineDungeonStopReason.timeBudgetExhausted ||
      stopReason == OfflineDungeonStopReason.dungeonCompleted ||
      stopReason == OfflineDungeonStopReason.playerDefeated;

  bool get hasRewards =>
      expGained > 0 ||
      goldGained > 0 ||
      addedStacks.isNotEmpty ||
      addedEquipment.isNotEmpty;
}

/// Mesin simulasi dungeon offline berbasis event-step / coarse-jump yang
/// independen dari Flutter dan Flame.
///
/// Menggunakan ulang aturan domain resmi: [DungeonManager], [EncounterTracker],
/// [RoomCompletionEvaluator], [DamageCalculator], [SkillSelector],
/// [TargetSelector], [AStarPathfinder], [AttackPositionFinder], [ReviveConfig],
/// [RewardProcessor], dan [DungeonRewardSettlementService].
class OfflineDungeonRunner {
  const OfflineDungeonRunner({
    this.pathfinder = const AStarPathfinder(),
    this.damageCalculator = const DamageCalculator(),
    this.targetSelector = const TargetSelector(),
    this.skillSelector = const SkillSelector(),
    this.attackPositionFinder = const AttackPositionFinder(),
    this.completionEvaluator = const RoomCompletionEvaluator(),
    this.settlementService = const DungeonRewardSettlementService(),
  });

  static const int tickDurationMs = 50; // 20 TPS timeline resolution

  final AStarPathfinder pathfinder;
  final DamageCalculator damageCalculator;
  final TargetSelector targetSelector;
  final SkillSelector skillSelector;
  final AttackPositionFinder attackPositionFinder;
  final RoomCompletionEvaluator completionEvaluator;
  final DungeonRewardSettlementService settlementService;

  OfflineDungeonRunner copyWith({DamageCalculator? damageCalculator}) =>
      OfflineDungeonRunner(
        pathfinder: pathfinder,
        damageCalculator: damageCalculator ?? this.damageCalculator,
        targetSelector: targetSelector,
        skillSelector: skillSelector,
        attackPositionFinder: attackPositionFinder,
        completionEvaluator: completionEvaluator,
        settlementService: settlementService,
      );

  OfflineDungeonRunOutcome runBatch(OfflineDungeonRunRequest request) =>
      _executeBatch(request, allowManualAscension: false);

  /// Mensimulasikan satu kali eksekusi dungeon secara manual (termasuk dungeon
  /// bertipe ascension) dengan aturan tempur identik untuk kebutuhan simulator/QA
  /// tanpa membuka jalur progresi offline [runBatch].
  OfflineDungeonRunOutcome simulateManualRun(OfflineDungeonRunRequest request) {
    if (request.mode != OfflineActivityMode.continueDungeon ||
        request.activeDungeonSession == null) {
      return OfflineDungeonRunOutcome(
        stopReason: OfflineDungeonStopReason.invalidSetup,
        updatedDungeonProgress: request.dungeonProgress,
        remainingSkillCooldownTicks: request.initialSkillCooldownTicks,
        remainingReviveCooldownTicks: request.initialReviveCooldownTicks,
        nextAttemptIndex: request.startingAttemptIndex,
        updatedActiveDungeonSession: request.activeDungeonSession,
        remainingHp: request.initialHp,
        failureReason: 'simulateManualRun membutuhkan mode continueDungeon dan activeDungeonSession valid.',
      );
    }
    return _executeBatch(request, allowManualAscension: true);
  }

  OfflineDungeonRunOutcome _executeBatch(
    OfflineDungeonRunRequest request, {
    required bool allowManualAscension,
  }) {
    final dungeonDef = request.config.dungeons[request.dungeonId];
    if (dungeonDef == null) {
      return OfflineDungeonRunOutcome(
        stopReason: OfflineDungeonStopReason.invalidSetup,
        updatedDungeonProgress: request.dungeonProgress,
        remainingSkillCooldownTicks: request.initialSkillCooldownTicks,
        remainingReviveCooldownTicks: request.initialReviveCooldownTicks,
        nextAttemptIndex: request.startingAttemptIndex,
        updatedActiveDungeonSession: request.activeDungeonSession,
        remainingHp: request.initialHp,
        failureReason:
            'Definisi dungeon "${request.dungeonId}" tidak ditemukan.',
      );
    }

    if (request.mode == OfflineActivityMode.pauseProgression) {
      return OfflineDungeonRunOutcome(
        stopReason: OfflineDungeonStopReason.invalidSetup,
        updatedDungeonProgress: request.dungeonProgress,
        remainingSkillCooldownTicks: request.initialSkillCooldownTicks,
        remainingReviveCooldownTicks: request.initialReviveCooldownTicks,
        nextAttemptIndex: request.startingAttemptIndex,
        updatedActiveDungeonSession: request.activeDungeonSession,
        remainingHp: request.initialHp,
        failureReason: 'Pause Progression tidak menjalankan runner dungeon.',
      );
    }

    if (request.mode == OfflineActivityMode.continueDungeon &&
        !dungeonDef.isNormal &&
        !allowManualAscension) {
      final manualOnlyReason = switch (dungeonDef.kind) {
        DungeonKind.bossDaily ||
        DungeonKind.bossWeekly ||
        DungeonKind.bossSpire =>
          'Boss Event / Spire ("${request.dungeonId}") hanya dapat dimainkan secara manual.',
        DungeonKind.ascension =>
          'Ascension Dungeon ("${request.dungeonId}") hanya dapat dimainkan secara manual.',
        DungeonKind.normal => '',
      };
      return OfflineDungeonRunOutcome(
        stopReason: OfflineDungeonStopReason.invalidSetup,
        updatedDungeonProgress: request.dungeonProgress,
        remainingSkillCooldownTicks: request.initialSkillCooldownTicks,
        remainingReviveCooldownTicks: request.initialReviveCooldownTicks,
        nextAttemptIndex: request.startingAttemptIndex,
        updatedActiveDungeonSession: request.activeDungeonSession,
        remainingHp: request.initialHp,
        failureReason: manualOnlyReason,
      );
    }

    if (request.mode == OfflineActivityMode.autoFarming &&
        (!dungeonDef.isNormal ||
            request.dungeonProgress.clearedInCycleRank != request.cycleRank)) {
      final autoFarmReason = switch (dungeonDef.kind) {
        DungeonKind.bossDaily ||
        DungeonKind.bossWeekly ||
        DungeonKind.bossSpire =>
          'Auto Farming menolak Boss Event / Spire ("${request.dungeonId}"); hanya dungeon normal yang didukung.',
        DungeonKind.ascension =>
          'Auto Farming hanya mendukung dungeon normal ("${request.dungeonId}").',
        DungeonKind.normal =>
          'Dungeon "${request.dungeonId}" belum diselesaikan pada siklus saat ini '
              '(syarat clearedInCycleRank == ${request.cycleRank} untuk Auto Farming).',
      };
      return OfflineDungeonRunOutcome(
        stopReason: OfflineDungeonStopReason.invalidSetup,
        updatedDungeonProgress: request.dungeonProgress,
        remainingSkillCooldownTicks: const {},
        remainingReviveCooldownTicks: 0,
        nextAttemptIndex: request.startingAttemptIndex,
        failureReason: autoFarmReason,
      );
    }

    final budgetTicks =
        request.timeWindow.effectiveElapsed.inMilliseconds ~/ tickDurationMs;
    if (budgetTicks <= 0) {
      return OfflineDungeonRunOutcome(
        stopReason: OfflineDungeonStopReason.timeBudgetExhausted,
        updatedDungeonProgress: request.dungeonProgress,
        remainingSkillCooldownTicks: request.initialSkillCooldownTicks,
        remainingReviveCooldownTicks: request.initialReviveCooldownTicks,
        nextAttemptIndex: request.startingAttemptIndex,
        updatedActiveDungeonSession: request.activeDungeonSession,
        remainingHp: request.initialHp,
        budgetTicks: 0,
      );
    }

    final safeMaxIterations = math.max(1, request.maxIterations);
    final rng = math.Random(request.simulationSeed);
    final difficultyService = DifficultyService(request.config.difficulty);
    final difficultyProfile =
        request.difficultyProfileOverride ??
        difficultyService.profileFor(dungeonDef, request.cycleRank);
    final tracker = EncounterTracker(
      monsterCatalog: request.config.monsters,
      difficultyProfile: difficultyProfile,
      difficultyService: difficultyService,
    );
    final manager = DungeonManager(
      dungeons: request.config.dungeons,
      encounterTracker: tracker,
      completionEvaluator: completionEvaluator,
      difficultyService: difficultyService,
    );

    final stats = _RunAccumulators();
    var progress = request.dungeonProgress;
    var remainingTicks = budgetTicks;
    var iterations = 0;
    var attemptIndex = math.max(1, request.startingAttemptIndex);
    var firstRunNeedsRestore = _shouldRestoreInitialSession(request);

    var stopReason = OfflineDungeonStopReason.timeBudgetExhausted;
    String? failureReason;

    Combatant? playerCombatant;
    _OfflineCombatRuntime? combatRuntime;
    ActiveDungeonSessionSnapshot? finalSessionSnapshot;

    while (remainingTicks > 0 && iterations < safeMaxIterations) {
      final isRestoringThisRun =
          firstRunNeedsRestore && request.activeDungeonSession != null;
      firstRunNeedsRestore = false;

      DungeonSession? session;
      int? runInitialHp;
      int runReviveTicks = 0;
      Map<String, int> runSkillCooldowns = const {};

      if (isRestoringThisRun) {
        final saved = request.activeDungeonSession!;
        if (!saved.isRecoverable || saved.dungeonId != request.dungeonId) {
          stopReason = OfflineDungeonStopReason.invalidSetup;
          failureReason =
              'ActiveDungeonSession tidak dapat dipulihkan untuk ${request.dungeonId}.';
          break;
        }
        session = manager.restoreSession(
          saved,
          runtimeDifficultyProfile: request.difficultyProfileOverride,
        );
        if (session == null) {
          stopReason = OfflineDungeonStopReason.invalidSetup;
          failureReason =
              'Sesi "${saved.runId}" sudah tidak memiliki room tersisa.';
          break;
        }

        // Tangani bila aplikasi sebelumnya tersimpan saat Downed:
        final reviveConfig = request.config.revive;
        final maxHp = request.character.stats.maxHp;
        var restoredHp = request.initialHp;
        runReviveTicks = math.max(0, saved.reviveCooldownTicks);
        if (saved.playerStatus == PlayerStatus.downed ||
            (restoredHp != null && restoredHp <= 0)) {
          restoredHp = math.max(1, (maxHp * reviveConfig.hpPercent).round());
          if (runReviveTicks == 0) {
            runReviveTicks = math.max(
              1,
              (reviveConfig.cooldownSeconds * CombatSimulation.ticksPerSecond)
                  .round(),
            );
          }
        }
        runInitialHp = restoredHp;
        runSkillCooldowns = request.initialSkillCooldownTicks;
        // Mode A hanya menghitung run attempt saat benar-benar mulai mengeksekusi
        // sisa sesi pada cycle offline ini.
        stats.runsAttempted++;
      } else {
        if (request.mode == OfflineActivityMode.continueDungeon) {
          if (stats.runsAttempted > 0) {
            // Mode A tidak boleh memulai dungeon baru setelah 1 run selesai/gagal.
            break;
          }
          stopReason = OfflineDungeonStopReason.invalidSetup;
          failureReason = 'Mode Continue Dungeon wajib memiliki activeDungeonSession valid.';
          break;
        }

        final nextRunId = _generateFarmRunId(
          dungeonId: request.dungeonId,
          anchorMs: request.timeWindow.anchorTimestampMs,
          seed: request.simulationSeed,
          attemptIndex: attemptIndex,
        );
        attemptIndex++;
        session = manager.startDungeon(
          request.dungeonId,
          runId: nextRunId,
          cycleRank: request.cycleRank,
          difficultyProfileOverride: request.difficultyProfileOverride,
        );
        stats.runsAttempted++;
        runInitialHp = null;
        runReviveTicks = 0;
        runSkillCooldowns = const {};
      }

      var appliedLevel = request.character.level;
      playerCombatant = Combatant(
        id: 'player',
        team: Team.player,
        stats: request.character.stats,
        cell: manager.activeRoom!.entryPosition,
      );
      if (runInitialHp != null) {
        playerCombatant.hp = runInitialHp.clamp(
          1,
          request.character.stats.maxHp,
        );
      }

      combatRuntime = _OfflineCombatRuntime(
        player: playerCombatant,
        character: request.character,
        config: request.config,
        autoSkillEnabled: request.autoSkillEnabled,
        reviveCooldownTicks: runReviveTicks,
        initialSkillCooldownTicks: runSkillCooldowns,
        random: rng,
        damageCalculator: damageCalculator,
        targetSelector: targetSelector,
        skillSelector: skillSelector,
        pathfinder: pathfinder,
        attackPositionFinder: attackPositionFinder,
        cycleRank: session.cycleRank,
      );

      // Jalankan seluruh room secara berurutan pada satu run.
      while (manager.hasActiveSession &&
          remainingTicks > 0 &&
          iterations < safeMaxIterations) {
        final room = manager.activeRoom!;
        final grid = manager.activeGrid!;

        combatRuntime.prepareForRoom(grid: grid, entryCell: room.entryPosition);
        manager.activateRoom();
        final spawnShell = _createTrackerShell(
          grid: grid,
          player: playerCombatant,
        );
        tracker.onRoomLoaded(spawnShell, grid: grid);
        tracker.onRoomActivated(spawnShell, grid: grid);
        combatRuntime.attachEnemies(spawnShell.enemies, spawnShell);

        // Simulasi combat room + travel hingga syarat combat terpenuhi,
        // budget habis, maxIterations tercapai, atau karakter runEnded.
        while (remainingTicks > 0 &&
            iterations < safeMaxIterations &&
            combatRuntime.playerStatus != PlayerStatus.runEnded &&
            !completionEvaluator.areCombatRequirementsSatisfied(
              room,
              tracker.encounters,
            )) {
          iterations++;
          final tickResult = combatRuntime.stepOneTick();
          remainingTicks--;
          stats.ticksSimulated++;

          if (tickResult.defeatedEnemies.isNotEmpty) {
            for (final killed in tickResult.defeatedEnemies) {
              final killKey =
                  'offline_kill:${manager.session!.runId}:${killed.enemyId}';
              final reward = request.rewardProcessor.processEnemyDefeated(
                eventId: killKey,
                definition: killed.definition,
                random: rng,
                difficultyProfile: manager.activeDifficultyProfile,
                difficultyService: difficultyService,
              );
              if (!reward.alreadyClaimed) {
                stats.encountersCleared++;
                stats.recordReward(reward);
              }
              tracker.onEnemyDefeated(
                killed.enemyId,
                simulation: spawnShell,
                grid: grid,
              );
            }
            combatRuntime.syncEnemyRosterFromShell();
          }

          if (request.character.level != appliedLevel) {
            appliedLevel = request.character.level;
            combatRuntime.syncPlayerBuild();
          }

          if (combatRuntime.playerStatus == PlayerStatus.runEnded) {
            break;
          }
          if (completionEvaluator.areCombatRequirementsSatisfied(
            room,
            tracker.encounters,
          )) {
            break;
          }

          // Coarse event-jump atas fase tunggu / perjalanan murni.
          if (remainingTicks > 0) {
            final gap = combatRuntime.computeSafeJumpTicks(
              remainingBudgetTicks: remainingTicks,
              room: room,
            );
            if (gap > 0) {
              combatRuntime.jumpTicks(gap);
              remainingTicks -= gap;
              stats.ticksSimulated += gap;
            }
          }
        }

        if (combatRuntime.playerStatus == PlayerStatus.runEnded) {
          tracker.onRunFailed();
          manager.endRun(
            finalStatus: DungeonSessionStatus.failed,
            reason: DungeonEndReason.defeated,
          );
          stats.runsFailed++;
          failureReason = 'Karakter kalah saat revive sedang cooldown.';
          stopReason = OfflineDungeonStopReason.playerDefeated;
          break;
        }

        // Jika syarat combat sudah terpenuhi tetapi masih wajib menuju exit:
        if (completionEvaluator.areCombatRequirementsSatisfied(
              room,
              tracker.encounters,
            ) &&
            room.completionCondition.requiresExit &&
            playerCombatant.follower.currentCell != room.exitPosition) {
          if (remainingTicks <= 0) {
            stopReason = OfflineDungeonStopReason.timeBudgetExhausted;
            break;
          }
          if (iterations >= safeMaxIterations) {
            stopReason = OfflineDungeonStopReason.iterationLimitReached;
            break;
          }
          iterations++;
          final exitResult = combatRuntime.walkTowardExit(
            exitCell: room.exitPosition,
            maxTicks: remainingTicks,
          );
          remainingTicks -= exitResult.ticksUsed;
          stats.ticksSimulated += exitResult.ticksUsed;
          if (!exitResult.arrived) {
            stopReason = OfflineDungeonStopReason.timeBudgetExhausted;
            break;
          }
        }

        if (!completionEvaluator.areCombatRequirementsSatisfied(
          room,
          tracker.encounters,
        )) {
          if (iterations >= safeMaxIterations && remainingTicks > 0) {
            stopReason = OfflineDungeonStopReason.iterationLimitReached;
          } else {
            stopReason = OfflineDungeonStopReason.timeBudgetExhausted;
          }
          break;
        }

        final playerCell = room.completionCondition.requiresExit
            ? playerCombatant.follower.currentCell
            : room.exitPosition;
        final eval = manager.evaluateCurrentRoom(playerCell: playerCell);
        if (!eval.isCompleted) {
          if (iterations >= safeMaxIterations && remainingTicks > 0) {
            stopReason = OfflineDungeonStopReason.iterationLimitReached;
          } else {
            stopReason = OfflineDungeonStopReason.timeBudgetExhausted;
          }
          break;
        }

        final currentRunId = manager.session!.runId;
        final didCompleteRoom = manager.tryCompleteActiveRoom(
          playerCell: playerCell,
          expectedRunId: currentRunId,
          expectedRoomId: room.id,
        );
        if (!didCompleteRoom) break;

        stats.roomsCleared++;
        final roomIndex = dungeonDef.indexOfRoom(room.id);
        final roomReward = settlementService.settleRoomCompleted(
          session: manager.session!,
          room: room,
          rewardProcessor: request.rewardProcessor,
          random: rng,
          difficultyProfile: manager.activeDifficultyProfile,
          difficultyService: difficultyService,
        );
        if (roomReward != null && !roomReward.alreadyClaimed) {
          stats.recordReward(roomReward);
        }
        if (request.character.level != appliedLevel) {
          appliedLevel = request.character.level;
          combatRuntime.syncPlayerBuild();
        }

        final nextHighest = math.max(
          progress.highestClearedRoomIndex,
          roomIndex,
        );
        final updatedRoomClaims = Set<String>.unmodifiable({
          ...progress.rewardState.claimedRoomRewardIds,
          if (room.reward != null && !room.reward!.isEmpty) room.id,
        });
        progress = DungeonProgressSnapshot(
          currentDungeonId: request.dungeonId,
          currentRoomId: manager.session!.currentRoomId,
          currentRoomIndex: manager.session!.currentRoomIndex,
          highestClearedRoomIndex: nextHighest,
          clearsCount: progress.clearsCount,
          clearedInCycleRank: progress.clearedInCycleRank,
          rewardState: DungeonRewardStateSnapshot(
            lastRunId: currentRunId,
            completionRewardClaimed:
                progress.rewardState.completionRewardClaimed &&
                progress.rewardState.lastRunId == currentRunId,
            claimedRoomRewardIds: updatedRoomClaims,
          ),
        );

        final curSession = manager.session!;
        if (curSession.status == DungeonSessionStatus.completed) {
          final endedEvent = DungeonEndedEvent(
            curSession,
            DungeonSessionStatus.completed,
            reason: DungeonEndReason.completed,
            dungeon: dungeonDef,
          );
          final settled = settlementService.settleDungeonCompleted(
            event: endedEvent,
            config: request.config,
            rewardProcessor: request.rewardProcessor,
            random: rng,
            dungeonManager: manager,
            difficultyProfile: manager.activeDifficultyProfile,
            difficultyService: difficultyService,
          );
          if (settled.granted != null && !settled.granted!.alreadyClaimed) {
            stats.recordReward(settled.granted!);
          }
          if (request.character.level != appliedLevel) {
            appliedLevel = request.character.level;
            combatRuntime.syncPlayerBuild();
          }

          stats.runsCompleted++;
          progress = DungeonProgressSnapshot(
            currentDungeonId: request.dungeonId,
            currentRoomId: curSession.currentRoomId,
            currentRoomIndex: curSession.currentRoomIndex,
            highestClearedRoomIndex: math.max(
              progress.highestClearedRoomIndex,
              dungeonDef.roomOrder.length - 1,
            ),
            clearsCount: progress.clearsCount + 1,
            clearedInCycleRank: dungeonDef.isNormal
                ? math.max(progress.clearedInCycleRank, request.cycleRank)
                : progress.clearedInCycleRank,
            rewardState: DungeonRewardStateSnapshot(
              lastRunId: curSession.runId,
              completionRewardClaimed: true,
              claimedRoomRewardIds: updatedRoomClaims,
            ),
          );
          break;
        }

        // Masih ada room selanjutnya -> transisi room berikutnya.
        if (!manager.transitionToNextRoom()) {
          stopReason = OfflineDungeonStopReason.invalidSetup;
          failureReason =
              'Transisi room gagal pada dungeon ${request.dungeonId}.';
          stats.runsFailed++;
          break;
        }
        progress = DungeonProgressSnapshot(
          currentDungeonId: request.dungeonId,
          currentRoomId: manager.session!.currentRoomId,
          currentRoomIndex: manager.session!.currentRoomIndex,
          highestClearedRoomIndex: progress.highestClearedRoomIndex,
          clearsCount: progress.clearsCount,
          clearedInCycleRank: progress.clearedInCycleRank,
          rewardState: progress.rewardState,
        );
      }

      // Evaluasi status akhir run ini.
      final endSession = manager.session;
      finalSessionSnapshot = manager.toActiveSessionSnapshot(
        reviveCooldownTicks: combatRuntime.reviveCooldownTicks,
        playerStatus: combatRuntime.playerStatus,
      );

      if (stopReason == OfflineDungeonStopReason.playerDefeated ||
          stopReason == OfflineDungeonStopReason.invalidSetup) {
        manager.dispose();
        break;
      }

      if (endSession != null &&
          endSession.status == DungeonSessionStatus.completed) {
        if (request.mode == OfflineActivityMode.continueDungeon) {
          stopReason = OfflineDungeonStopReason.dungeonCompleted;
          manager.dispose();
          break;
        }
        // Mode B (Auto Farming): siap memulai attempt berikutnya jika masih ada waktu.
        manager.exitToTown();
        if (remainingTicks <= 0) {
          stopReason = OfflineDungeonStopReason.timeBudgetExhausted;
          finalSessionSnapshot = null;
          break;
        }
        if (iterations >= safeMaxIterations) {
          stopReason = OfflineDungeonStopReason.iterationLimitReached;
          finalSessionSnapshot = null;
          break;
        }
        continue;
      }

      // Run terhenti di tengah room sebelum selesai:
      if (iterations >= safeMaxIterations && remainingTicks > 0) {
        stopReason = OfflineDungeonStopReason.iterationLimitReached;
      } else {
        stopReason = OfflineDungeonStopReason.timeBudgetExhausted;
      }
      break;
    }

    // Jika Mode B selesai tanpa interupsi (budget habis / defeated), sesi aktif
    // tidak mengarahkan pemain kembali ke dungeon acak saat membuka app.
    if (request.mode == OfflineActivityMode.autoFarming &&
        stopReason != OfflineDungeonStopReason.iterationLimitReached) {
      finalSessionSnapshot = null;
    }

    final processedMs =
        stopReason == OfflineDungeonStopReason.timeBudgetExhausted
        ? request.timeWindow.effectiveElapsed.inMilliseconds
        : math.min(
            request.timeWindow.effectiveElapsed.inMilliseconds,
            stats.ticksSimulated * tickDurationMs,
          );

    return OfflineDungeonRunOutcome(
      stopReason: stopReason,
      runsAttempted: stats.runsAttempted,
      runsCompleted: stats.runsCompleted,
      runsFailed: stats.runsFailed,
      roomsCleared: stats.roomsCleared,
      encountersCleared: stats.encountersCleared,
      expGained: stats.expGained,
      goldGained: stats.goldGained,
      levelsGained: stats.levelsGained,
      addedStacks: Map.unmodifiable(stats.addedStacks),
      overflowStacks: Map.unmodifiable(stats.overflowStacks),
      addedEquipment: List.unmodifiable(stats.addedEquipment),
      droppedEquipment: List.unmodifiable(stats.droppedEquipment),
      autoSoldEquipmentCount: stats.autoSoldEquipmentCount,
      autoSoldEquipmentGold: stats.autoSoldEquipmentGold,
      ticksSimulated: stats.ticksSimulated,
      budgetTicks: budgetTicks,
      processedDurationMs: processedMs,
      iterationsUsed: iterations,
      updatedDungeonProgress: progress,
      updatedActiveDungeonSession: finalSessionSnapshot,
      remainingHp:
          finalSessionSnapshot != null && finalSessionSnapshot.isRecoverable
          ? playerCombatant?.hp
          : null,
      finalPlayerHp: playerCombatant?.hp,
      finalPlayerMaxHp: playerCombatant?.stats.maxHp,
      remainingSkillCooldownTicks:
          finalSessionSnapshot != null &&
              finalSessionSnapshot.isRecoverable &&
              combatRuntime != null
          ? combatRuntime.exportSkillCooldowns()
          : const {},
      remainingReviveCooldownTicks:
          finalSessionSnapshot != null &&
              finalSessionSnapshot.isRecoverable &&
              combatRuntime != null
          ? combatRuntime.reviveCooldownTicks
          : 0,
      nextAttemptIndex: attemptIndex,
      failureReason: failureReason,
    );
  }

  static bool _shouldRestoreInitialSession(OfflineDungeonRunRequest request) {
    final active = request.activeDungeonSession;
    if (active == null || !active.isRecoverable) return false;
    if (request.mode == OfflineActivityMode.continueDungeon) return true;
    // Mode B hanya memulihkan sesi apabila sedang melanjutkan batch Auto Farming
    // yang terinterupsi (runId berasal dari offline farm batch sebelumnya).
    return request.mode == OfflineActivityMode.autoFarming &&
        active.dungeonId == request.dungeonId &&
        active.runId.startsWith('offline_farm_');
  }

  static String _generateFarmRunId({
    required String dungeonId,
    required int anchorMs,
    required int seed,
    required int attemptIndex,
  }) => 'offline_farm_${dungeonId}_${anchorMs}_${seed}_$attemptIndex';

  CombatSimulation _createTrackerShell({
    required NavigationGrid grid,
    required Combatant player,
  }) {
    final shellPlayer = Combatant(
      id: player.id,
      team: Team.player,
      stats: player.stats,
      cell: player.follower.currentCell,
    );
    return CombatSimulation(
      grid: grid,
      pathfinder: pathfinder,
      player: shellPlayer,
      damageCalculator: damageCalculator,
    );
  }
}

class _DefeatedEnemyRecord {
  const _DefeatedEnemyRecord(this.enemyId, this.definition);

  final String enemyId;
  final EnemyDefinition definition;
}

class _RunAccumulators {
  int runsAttempted = 0;
  int runsCompleted = 0;
  int runsFailed = 0;
  int roomsCleared = 0;
  int encountersCleared = 0;
  int expGained = 0;
  int goldGained = 0;
  int levelsGained = 0;
  int ticksSimulated = 0;

  final Map<String, int> addedStacks = {};
  final Map<String, int> overflowStacks = {};
  final List<EquipmentInstance> addedEquipment = [];
  final List<EquipmentInstance> droppedEquipment = [];
  int autoSoldEquipmentCount = 0;
  int autoSoldEquipmentGold = 0;

  void recordReward(GrantedReward reward) {
    expGained += reward.expGranted;
    goldGained += reward.goldGranted;
    levelsGained += reward.levelsGained;
    for (final entry in reward.addedStacks.entries) {
      addedStacks[entry.key] = (addedStacks[entry.key] ?? 0) + entry.value;
    }
    for (final entry in reward.overflowStacks.entries) {
      overflowStacks[entry.key] =
          (overflowStacks[entry.key] ?? 0) + entry.value;
    }
    addedEquipment.addAll(reward.addedEquipment);
    droppedEquipment.addAll(reward.droppedEquipment);
    autoSoldEquipmentCount += reward.autoSoldEquipmentCount;
    autoSoldEquipmentGold += reward.autoSoldEquipmentGold;
  }
}

class _OfflineCombatRuntime {
  _OfflineCombatRuntime({
    required this.player,
    required this.character,
    required this.config,
    required this.autoSkillEnabled,
    required this.reviveCooldownTicks,
    required Map<String, int> initialSkillCooldownTicks,
    required this.random,
    required this.damageCalculator,
    required this.targetSelector,
    required this.skillSelector,
    required this.pathfinder,
    required this.attackPositionFinder,
    this.cycleRank = 0,
  }) {
    _syncSkills(initialCooldowns: initialSkillCooldownTicks);
  }

  final Combatant player;
  final PlayerCharacter character;
  final GameConfig config;
  final bool autoSkillEnabled;
  final math.Random random;
  final DamageCalculator damageCalculator;
  final TargetSelector targetSelector;
  final SkillSelector skillSelector;
  final AStarPathfinder pathfinder;
  final AttackPositionFinder attackPositionFinder;
  final int cycleRank;

  int reviveCooldownTicks;
  int _downedTicksLeft = 0;
  PlayerStatus playerStatus = PlayerStatus.alive;

  NavigationGrid? _grid;
  CombatSimulation? _spawnShell;
  final List<Combatant> _enemies = [];
  final List<Combatant> _allies = [];
  List<Combatant> get enemies => _enemies;
  List<Combatant> get allies => _allies;
  final Map<String, EnemyDefinition> _definitions = {};
  final Set<String> _processedDeaths = {};
  int _spawnCounter = 0;
  int _paladinHolyNovaCooldownTicks = 0;
  int _chronomancerSkillCasts = 0;

  List<SkillDefinition> _skills = const [];
  final Map<String, SkillRuntimeState> _skillStates = {};
  Map<String, double> _skillAffinities = const {};

  void prepareForRoom({
    required NavigationGrid grid,
    required GridPoint entryCell,
  }) {
    _grid = grid;
    _enemies.clear();
    _allies.clear();
    _definitions.clear();
    _processedDeaths.clear();
    player.resetNavigation(entryCell);
  }

  void attachEnemies(List<Combatant> spawned, CombatSimulation shell) {
    _spawnShell = shell;
    syncEnemyRosterFromShell();
  }

  void syncEnemyRosterFromShell() {
    final shell = _spawnShell;
    if (shell == null) return;
    final known = {for (final e in _enemies) e.id};
    for (final enemy in shell.enemies) {
      if (known.add(enemy.id)) {
        if (enemy.isBoss) {
          final mechanics = config.difficulty.mechanics;
          enemy.bossAoECooldownTicks =
              (mechanics.bossAoeCooldownSeconds *
                      CombatSimulation.ticksPerSecond)
                  .round();
          enemy.lifeSiphonCooldownTicks =
              (mechanics.weeklyLifeSiphonCooldownSeconds *
                      CombatSimulation.ticksPerSecond)
                  .round();
        }
        _enemies.add(enemy);
        final monsterId = _resolveMonsterIdFromEnemyId(enemy.id, enemy);
        if (monsterId != null && config.monsters.containsKey(monsterId)) {
          _definitions[enemy.id] = config.monsters[monsterId]!;
        }
      }
    }
  }

  String? _resolveMonsterIdFromEnemyId(String enemyId, Combatant enemy) {
    if (enemy.definitionId != null && enemy.definitionId!.isNotEmpty) {
      return enemy.definitionId;
    }
    // EncounterTracker membentuk id "${room.id}__${config.id}__$i"; lookup
    // definisi monster melalui catalog room spawns atau fallback stats/level.
    for (final d in config.dungeons.values) {
      for (final room in d.rooms.values) {
        final prefix = '${room.id}__';
        if (!enemyId.startsWith(prefix)) continue;
        for (final sp in room.spawns) {
          if (enemyId.startsWith('${room.id}__${sp.id}__')) {
            return sp.monsterId;
          }
        }
      }
    }
    for (final def in config.monsters.values) {
      if (def.isBoss == enemy.isBoss &&
          def.isElite == enemy.isElite &&
          def.stats.maxHp == enemy.stats.maxHp) {
        return def.id;
      }
    }
    return null;
  }

  void syncPlayerBuild() {
    player.applyStats(character.stats);
    _syncSkills();
  }

  void _syncSkills({Map<String, int>? initialCooldowns}) {
    _skills = character.activeSkills.toList(growable: false);
    _skillAffinities = character.activeSkillAffinities;
    final ids = _skills.map((s) => s.id).toSet();
    _skillStates.removeWhere((id, _) => !ids.contains(id));
    for (final skill in _skills) {
      final previous = _skillStates[skill.id];
      final incoming = character.skillRuntimeState(skill.id);
      final savedCd = initialCooldowns?[skill.id] ?? 0;
      _skillStates[skill.id] = SkillRuntimeState(
        skillId: skill.id,
        level: incoming.level,
        unlocked: incoming.unlocked,
        cooldownTicksRemaining:
            previous?.cooldownTicksRemaining ??
            (savedCd > 0 ? savedCd : incoming.cooldownTicksRemaining),
      );
    }
  }

  Map<String, int> exportSkillCooldowns() => Map.unmodifiable({
    for (final entry in _skillStates.entries)
      if (entry.value.cooldownTicksRemaining > 0)
        entry.key: entry.value.cooldownTicksRemaining,
  });

  ({List<_DefeatedEnemyRecord> defeatedEnemies}) stepOneTick() {
    final defeated = <_DefeatedEnemyRecord>[];
    if (playerStatus == PlayerStatus.runEnded) {
      return (defeatedEnemies: defeated);
    }

    if (playerStatus == PlayerStatus.downed) {
      _tickDowned();
      for (final enemy in _enemies.toList()) {
        if (enemy.isAlive && enemy.aiState == MonsterAiState.returning) {
          _returnToSpawn(enemy);
        }
      }
      return (defeatedEnemies: defeated);
    }

    if (reviveCooldownTicks > 0) reviveCooldownTicks--;
    if (player.invulnerableTicks > 0) player.invulnerableTicks--;
    if (_paladinHolyNovaCooldownTicks > 0) _paladinHolyNovaCooldownTicks--;
    for (final id in _skillStates.keys.toList()) {
      _skillStates[id] = _skillStates[id]!.decrementCooldown();
    }

    _updatePlayer(defeated);
    _updateAllies(defeated);
    for (final enemy in _enemies.toList()) {
      if (playerStatus != PlayerStatus.alive) break;
      if (enemy.isAlive) _updateEnemy(enemy, defeated);
    }
    return (defeatedEnemies: defeated);
  }

  void jumpTicks(int gap) {
    if (gap <= 0 || playerStatus == PlayerStatus.runEnded) return;
    if (playerStatus == PlayerStatus.downed) {
      _downedTicksLeft = math.max(1, _downedTicksLeft - gap);
      return;
    }

    reviveCooldownTicks = math.max(0, reviveCooldownTicks - gap);
    player.invulnerableTicks = math.max(0, player.invulnerableTicks - gap);
    if (_paladinHolyNovaCooldownTicks > 0) {
      _paladinHolyNovaCooldownTicks = math.max(
        0,
        _paladinHolyNovaCooldownTicks - gap,
      );
    }
    if (player.cooldownTicks > 0) {
      player.cooldownTicks = math.max(0, player.cooldownTicks - gap);
    }
    for (final id in _skillStates.keys.toList()) {
      final st = _skillStates[id]!;
      if (st.cooldownTicksRemaining > 0) {
        _skillStates[id] = st.copyWith(
          cooldownTicksRemaining: math.max(0, st.cooldownTicksRemaining - gap),
        );
      }
    }

    for (final enemy in _enemies) {
      if (enemy.shadowMarkTicks > 0) {
        enemy.shadowMarkTicks = math.max(0, enemy.shadowMarkTicks - gap);
        enemy.isShadowMarked = enemy.shadowMarkTicks > 0;
      }
      if (enemy.shockTicks > 0) {
        enemy.shockTicks = math.max(0, enemy.shockTicks - gap);
        enemy.isShocked = enemy.shockTicks > 0;
      }
      if (enemy.freezeTicks > 0) {
        enemy.freezeTicks = math.max(0, enemy.freezeTicks - gap);
      }
      if (enemy.eliteSpecialCooldownTicks > 0) {
        enemy.eliteSpecialCooldownTicks = math.max(
          0,
          enemy.eliteSpecialCooldownTicks - gap,
        );
      }
      if (enemy.bossAoECooldownTicks > 0) {
        enemy.bossAoECooldownTicks = math.max(
          0,
          enemy.bossAoECooldownTicks - gap,
        );
      }
      if (enemy.lifeSiphonCooldownTicks > 0) {
        enemy.lifeSiphonCooldownTicks = math.max(
          0,
          enemy.lifeSiphonCooldownTicks - gap,
        );
      }
      if (enemy.elementalWardTicks > 0) {
        enemy.elementalWardTicks = math.max(0, enemy.elementalWardTicks - gap);
      }
    }

    // Majukan gerakan player bila masih berjalan menuju target.
    final target = targetSelector.select(
      seeker: player,
      candidates: _aliveEnemies,
    );
    if (target != null &&
        player.distanceTo(target) > player.stats.attackRange &&
        player.follower.isMoving) {
      player.follower.advance(
        player.stats.moveSpeed * CombatSimulation.tickSeconds * gap,
      );
    }

    for (final enemy in _enemies) {
      if (!enemy.isAlive) continue;
      if (enemy.cooldownTicks > 0) {
        enemy.cooldownTicks = math.max(0, enemy.cooldownTicks - gap);
      }
      if (enemy.aggroed &&
          enemy.distanceTo(player) > enemy.stats.attackRange &&
          enemy.follower.isMoving) {
        enemy.follower.advance(
          enemy.stats.moveSpeed * CombatSimulation.tickSeconds * gap,
        );
      }
    }
  }

  int computeSafeJumpTicks({
    required int remainingBudgetTicks,
    required RoomDefinition room,
  }) {
    if (remainingBudgetTicks <= 0) return 0;
    if (playerStatus == PlayerStatus.downed) {
      return math.min(math.max(0, _downedTicksLeft - 1), remainingBudgetTicks);
    }

    var gap = remainingBudgetTicks;
    final target = targetSelector.select(
      seeker: player,
      candidates: _aliveEnemies,
    );
    final playerInRange =
        target != null && player.distanceTo(target) <= player.stats.attackRange;

    if (playerInRange) {
      if (player.cooldownTicks == 0) return 0;
      gap = math.min(gap, player.cooldownTicks - 1);
    } else if (target != null) {
      final distLeft = math.max(
        0.0,
        player.distanceTo(target) - player.stats.attackRange,
      );
      final closingSpeed =
          (player.stats.moveSpeed +
              (target.aggroed ? target.stats.moveSpeed : 0.0)) *
          CombatSimulation.tickSeconds;
      if (closingSpeed > 0) {
        final ticksToContact = (distLeft / closingSpeed).floor();
        // Batasi chunk perjalanan agar pathfinding/tujuan A* tetap akurat saat belok.
        final pathHorizon = math.min(12, math.max(0, ticksToContact - 1));
        gap = math.min(gap, pathHorizon);
      } else {
        gap = 0;
      }
    }

    if (autoSkillEnabled && _skills.isNotEmpty) {
      final maxHp = player.stats.maxHp;
      final hpRatio = maxHp <= 0 ? 1.0 : player.hp / maxHp;
      for (final skill in _skills) {
        final st = _skillStates[skill.id];
        if (!skill.isActive ||
            skill.effect == SkillEffectType.statModifier ||
            st == null ||
            st.level < 1 ||
            !st.unlocked) {
          continue;
        }
        if (skill.effect == SkillEffectType.healing) {
          final threshold =
              skill.useWhenHpBelow ?? skillSelector.defaultHealThreshold;
          if (hpRatio < threshold && player.hp < maxHp) {
            if (st.cooldownTicksRemaining == 0) return 0;
            gap = math.min(gap, st.cooldownTicksRemaining - 1);
          }
        } else if (target != null &&
            player.distanceTo(target) <=
                (skill.range ?? player.stats.attackRange)) {
          if (skill.targetType == SkillTarget.area) {
            final nearby = _aliveEnemies
                .where((e) => e.distanceTo(target) <= skill.radius)
                .length;
            if (nearby >= skill.minEnemies) {
              if (st.cooldownTicksRemaining == 0) return 0;
              gap = math.min(gap, st.cooldownTicksRemaining - 1);
            }
          } else {
            if (st.cooldownTicksRemaining == 0) return 0;
            gap = math.min(gap, st.cooldownTicksRemaining - 1);
          }
        }
      }
    }

    final mechanics = config.difficulty.mechanics;
    final mechanicsActive = mechanics.isEnabledFor(cycleRank);
    final playerWalking = target != null && !playerInRange;
    for (final enemy in _enemies) {
      if (!enemy.isAlive) continue;
      if (mechanicsActive) {
        if (enemy.isElite && enemy.eliteSpecialCooldownTicks == 0) return 0;
        if (enemy.elementalWardTicks > 0) {
          gap = math.min(gap, enemy.elementalWardTicks - 1);
        }
        if (enemy.isBoss) {
          if (enemy.isDailyBoss) {
            if (enemy.bossAoECooldownTicks == 0 &&
                enemy.distanceTo(player) <= mechanics.dailyBlazingSurgeRadius) {
              return 0;
            }
          } else if (enemy.isWeeklyBoss) {
            if (enemy.bossAoECooldownTicks == 0 &&
                enemy.distanceTo(player) <= mechanics.weeklyCataclysmRadius) {
              return 0;
            }
            if (enemy.lifeSiphonCooldownTicks == 0 &&
                enemy.distanceTo(player) <= enemy.stats.attackRange) {
              return 0;
            }
          } else {
            if (enemy.bossAoECooldownTicks == 0 &&
                enemy.distanceTo(player) <= mechanics.bossAoeRadius) {
              return 0;
            }
          }
        }
      }
      if (!enemy.aggroed) {
        final distAggro = math.max(
          0.0,
          player.distanceTo(enemy) - enemy.detectionRange,
        );
        if (distAggro <= 0) return 0;
        if (playerWalking) {
          final pStep = player.stats.moveSpeed * CombatSimulation.tickSeconds;
          if (pStep > 0) {
            final tAggro = (distAggro / pStep).floor();
            gap = math.min(gap, math.max(0, tAggro - 1));
          }
        }
        continue;
      }

      if (enemy.distanceTo(player) <= enemy.stats.attackRange) {
        if (enemy.cooldownTicks == 0) return 0;
        gap = math.min(gap, enemy.cooldownTicks - 1);
      } else {
        final distHit = math.max(
          0.0,
          enemy.distanceTo(player) - enemy.stats.attackRange,
        );
        final closing =
            (enemy.stats.moveSpeed +
                (playerWalking ? player.stats.moveSpeed : 0.0)) *
            CombatSimulation.tickSeconds;
        if (closing > 0) {
          final tHit = (distHit / closing).floor();
          gap = math.min(gap, math.max(0, math.min(12, tHit - 1)));
        }
      }
    }

    return math.max(0, gap);
  }

  ({bool arrived, int ticksUsed}) walkTowardExit({
    required GridPoint exitCell,
    required int maxTicks,
  }) {
    final grid = _grid;
    if (grid == null || player.follower.currentCell == exitCell) {
      return (arrived: true, ticksUsed: 0);
    }
    final path = pathfinder.findPath(
      grid,
      player.follower.currentCell,
      exitCell,
    );
    if (path == null || path.isEmpty) {
      return (arrived: false, ticksUsed: 0);
    }
    var dist = 0.0;
    var px = player.x;
    var py = player.y;
    for (var i = 0; i < path.length; i++) {
      final wp = path[i];
      if (i == 0 && wp == player.follower.currentCell) continue;
      final wx = wp.x + 0.5;
      final wy = wp.y + 0.5;
      dist += math.sqrt((wx - px) * (wx - px) + (wy - py) * (wy - py));
      px = wx;
      py = wy;
    }
    final step = player.stats.moveSpeed * CombatSimulation.tickSeconds;
    final neededTicks = step <= 0 ? maxTicks : (dist / step).ceil();
    final dt = math.min(maxTicks, math.max(0, neededTicks));

    reviveCooldownTicks = math.max(0, reviveCooldownTicks - dt);
    player.invulnerableTicks = math.max(0, player.invulnerableTicks - dt);
    if (player.cooldownTicks > 0) {
      player.cooldownTicks = math.max(0, player.cooldownTicks - dt);
    }
    for (final id in _skillStates.keys.toList()) {
      final st = _skillStates[id]!;
      if (st.cooldownTicksRemaining > 0) {
        _skillStates[id] = st.copyWith(
          cooldownTicksRemaining: math.max(0, st.cooldownTicksRemaining - dt),
        );
      }
    }

    player.follower.setPath(path);
    player.follower.advance(step * dt);
    if (dt >= neededTicks) {
      player.follower.resetTo(exitCell);
      return (arrived: true, ticksUsed: dt);
    }
    return (arrived: false, ticksUsed: dt);
  }

  Iterable<Combatant> get _aliveEnemies => _enemies.where((e) => e.isAlive);

  void _updatePlayer(List<_DefeatedEnemyRecord> defeated) {
    if (player.cooldownTicks > 0) player.cooldownTicks--;
    final target = targetSelector.select(
      seeker: player,
      candidates: _aliveEnemies,
    );
    player.targetId = target?.id;

    if (_tryCastSkill(target, defeated)) return;
    if (target == null) return;
    if (player.distanceTo(target) <= player.stats.attackRange) {
      if (player.cooldownTicks == 0) {
        player.cooldownTicks = _intervalTicks(player.stats.attackSpeed);
        _strike(player, target, defeated: defeated);
        if (character.activeResonanceClassId == 'gunslinger') {
          _triggerGunslingerPiercingBeam(player, target, defeated);
        }
      }
      return;
    }
    _chase(player, target);
  }

  void _updateAllies(List<_DefeatedEnemyRecord> defeated) {
    _allies.removeWhere((ally) {
      if (!ally.isAlive) return true;
      if (ally.lifetimeTicks > 0) {
        ally.lifetimeTicks--;
        if (ally.lifetimeTicks <= 0) return true;
      }
      return false;
    });

    for (final ally in List<Combatant>.of(_allies)) {
      if (!ally.isAlive || playerStatus != PlayerStatus.alive) continue;
      if (ally.cooldownTicks > 0) ally.cooldownTicks--;
      final target = targetSelector.select(
        seeker: ally,
        candidates: _aliveEnemies,
      );
      ally.targetId = target?.id;
      if (target == null) continue;
      if (ally.distanceTo(target) <= ally.stats.attackRange) {
        if (ally.cooldownTicks == 0) {
          ally.cooldownTicks = _intervalTicks(ally.stats.attackSpeed);
          _strike(ally, target, defeated: defeated);
        }
      } else {
        _chase(ally, target);
      }
    }
  }

  void _updateEnemy(Combatant enemy, List<_DefeatedEnemyRecord> defeated) {
    if (enemy.cooldownTicks > 0) enemy.cooldownTicks--;
    if (!enemy.isAlive) {
      enemy.aiState = MonsterAiState.dead;
      return;
    }

    // Status efek Weapon Resonance pada musuh
    if (enemy.shadowMarkTicks > 0) {
      enemy.shadowMarkTicks--;
      enemy.isShadowMarked = enemy.shadowMarkTicks > 0;
    }
    if (enemy.shockTicks > 0) {
      enemy.shockTicks--;
      enemy.isShocked = enemy.shockTicks > 0;
    }
    if (enemy.freezeTicks > 0) {
      enemy.freezeTicks--;
      return; // Chronomancer Freeze: musuh tidak bergerak/menyerang
    }

    if (enemy.aiState == MonsterAiState.returning) {
      _returnToSpawn(enemy);
      return;
    }

    final mechanics = config.difficulty.mechanics;
    final mechanicsActive = mechanics.isEnabledFor(cycleRank);

    if (mechanicsActive) {
      if (enemy.eliteSpecialCooldownTicks > 0) {
        enemy.eliteSpecialCooldownTicks--;
      }
      if (enemy.bossAoECooldownTicks > 0) {
        enemy.bossAoECooldownTicks--;
      }
      if (enemy.lifeSiphonCooldownTicks > 0) {
        enemy.lifeSiphonCooldownTicks--;
      }
      if (enemy.elementalWardTicks > 0) {
        enemy.elementalWardTicks--;
      }

      // Berserk / Enrage check (Elite / Boss).
      if ((enemy.isElite || enemy.isBoss) && !enemy.isEnraged) {
        final threshold = enemy.isDailyBoss
            ? mechanics.dailyEnragedRushHpThreshold
            : mechanics.berserkHpThreshold;
        if (enemy.hp <= (enemy.stats.maxHp * threshold)) {
          enemy.isEnraged = true;
        }
      }
    }

    if (!enemy.aggroed) {
      if (!player.isAlive || playerStatus != PlayerStatus.alive) return;
      if (enemy.distanceTo(player) > enemy.detectionRange) return;
      enemy.aggroed = true;
      enemy.aiState = MonsterAiState.chase;
    }

    final outOfLeash =
        enemy.leashRange > 0 &&
        (enemy.distanceToSpawn > enemy.leashRange ||
            enemy.distanceTo(player) > enemy.leashRange);
    if (!player.isAlive || playerStatus != PlayerStatus.alive || outOfLeash) {
      _startReturning(enemy);
      return;
    }

    enemy.targetId = player.id;

    if (mechanicsActive && enemy.isBoss) {
      if (enemy.isDailyBoss) {
        // Daily Boss: Elemental Ward
        if (!enemy.hasTriggeredWard &&
            enemy.hp <=
                (enemy.stats.maxHp * mechanics.dailyElementalWardHpThreshold)) {
          _triggerDailyElementalWard(enemy);
        }
        // Daily Boss: Blazing Surge AoE
        if (player.isAlive &&
            playerStatus == PlayerStatus.alive &&
            enemy.bossAoECooldownTicks == 0 &&
            enemy.distanceTo(player) <= mechanics.dailyBlazingSurgeRadius) {
          _triggerDailyBlazingSurge(enemy, defeated);
          return;
        }
      } else if (enemy.isWeeklyBoss) {
        // Weekly Boss: Summon Elite Guards
        if (!enemy.hasSummonedMinions &&
            enemy.hp <=
                (enemy.stats.maxHp * mechanics.weeklySummonHpThreshold)) {
          _triggerWeeklySummonMinions(enemy);
        }
        // Weekly Boss: Final Stand
        if (!enemy.isFinalStand &&
            enemy.hp <=
                (enemy.stats.maxHp * mechanics.weeklyFinalStandHpThreshold)) {
          _triggerWeeklyFinalStand(enemy);
        }
        // Weekly Boss: Cataclysm AoE
        if (player.isAlive &&
            playerStatus == PlayerStatus.alive &&
            enemy.bossAoECooldownTicks == 0 &&
            enemy.distanceTo(player) <= mechanics.weeklyCataclysmRadius) {
          _triggerWeeklyCataclysm(enemy, defeated);
          return;
        }
        // Weekly Boss: Life Siphon
        if (player.isAlive &&
            playerStatus == PlayerStatus.alive &&
            enemy.lifeSiphonCooldownTicks == 0 &&
            enemy.distanceTo(player) <= enemy.stats.attackRange) {
          _triggerWeeklyLifeSiphon(enemy, defeated);
          return;
        }
      } else {
        // Standard Dungeon Boss: Summon Minions
        if (!enemy.hasSummonedMinions &&
            enemy.hp <= (enemy.stats.maxHp * mechanics.bossSummonHpThreshold)) {
          _triggerBossSummonMinions(enemy);
        }

        // Standard Dungeon Boss: Ground Slam / Shockwave AoE
        if (player.isAlive &&
            playerStatus == PlayerStatus.alive &&
            enemy.bossAoECooldownTicks == 0 &&
            enemy.distanceTo(player) <= mechanics.bossAoeRadius) {
          _triggerBossGroundSlam(enemy, defeated);
          return;
        }
      }
    }

    if (enemy.distanceTo(player) <= enemy.stats.attackRange) {
      enemy.aiState = MonsterAiState.attack;
      if (enemy.cooldownTicks == 0) {
        var speedMultiplier = 1.0;
        var multiplier = 1.0;
        if (enemy.isEnraged && mechanicsActive) {
          if (enemy.isDailyBoss) {
            speedMultiplier = mechanics.dailyEnragedRushSpeedMultiplier;
            multiplier *= mechanics.dailyEnragedRushAtkMultiplier;
          } else if (enemy.isWeeklyBoss && enemy.isFinalStand) {
            speedMultiplier = mechanics.weeklyFinalStandSpeedMultiplier;
            multiplier *= mechanics.weeklyFinalStandAtkMultiplier;
          } else {
            speedMultiplier = mechanics.berserkSpeedMultiplier;
            multiplier *= mechanics.berserkAtkMultiplier;
          }
        }
        final baseTicks = _intervalTicks(enemy.stats.attackSpeed);
        enemy.cooldownTicks = math.max(
          1,
          (baseTicks / speedMultiplier).round(),
        );

        if (enemy.isElite &&
            mechanicsActive &&
            enemy.eliteSpecialCooldownTicks == 0) {
          enemy.eliteSpecialCooldownTicks =
              (mechanics.eliteHeavyStrikeCooldownSeconds *
                      CombatSimulation.ticksPerSecond)
                  .round();
          multiplier *= mechanics.eliteHeavyStrikeMultiplier;
        }

        _strike(enemy, player, multiplier: multiplier, defeated: defeated);
      }
      return;
    }

    enemy.aiState = MonsterAiState.chase;
    if (!_chase(enemy, player)) {
      _startReturning(enemy);
    }
  }

  void _triggerDailyElementalWard(Combatant boss) {
    boss.hasTriggeredWard = true;
    final mechanics = config.difficulty.mechanics;
    boss.elementalWardTicks =
        (mechanics.dailyElementalWardDurationSeconds *
                CombatSimulation.ticksPerSecond)
            .round();
    final shieldAmount = (boss.stats.maxHp * 0.10).round();
    boss.addShield(shieldAmount, max: shieldAmount);
  }

  void _triggerDailyBlazingSurge(
    Combatant boss,
    List<_DefeatedEnemyRecord> defeated,
  ) {
    final mechanics = config.difficulty.mechanics;
    boss.bossAoECooldownTicks =
        (mechanics.dailyBlazingSurgeCooldownSeconds *
                CombatSimulation.ticksPerSecond)
            .round();
    boss.cooldownTicks = math.max(
      boss.cooldownTicks,
      _intervalTicks(boss.stats.attackSpeed),
    );
    final multiplier =
        mechanics.dailyBlazingSurgeMultiplier *
        (boss.isEnraged ? mechanics.dailyEnragedRushAtkMultiplier : 1.0);
    _strike(
      boss,
      player,
      multiplier: multiplier,
      skillId: 'blazing_surge',
      defeated: defeated,
    );
  }

  void _triggerWeeklySummonMinions(Combatant boss) {
    boss.hasSummonedMinions = true;
    final mechanics = config.difficulty.mechanics;
    final bossDef = _definitions[boss.id];
    final count = mechanics.weeklySummonCount;
    final minionDef = _resolveMinionDef(boss, bossDef, isElite: true);
    final cells = _findMinionCells(boss, count);

    for (final cell in cells) {
      final minionId = '${boss.id}__guard_${_spawnCounter++}';
      final minion = Combatant(
        id: minionId,
        team: Team.enemy,
        stats: minionDef.stats,
        cell: cell,
        definitionId: minionDef.id,
        detectionRange: minionDef.detectionRange,
        leashRange: minionDef.leashRange,
        isElite: true,
        isBoss: false,
      );
      minion.aggroed = true;
      minion.targetId = player.id;
      minion.aiState = MonsterAiState.chase;
      _enemies.add(minion);
      _definitions[minionId] = minionDef;
    }
  }

  void _triggerWeeklyFinalStand(Combatant boss) {
    boss.isFinalStand = true;
    boss.isEnraged = true;
    final shieldAmount = (boss.stats.maxHp * 0.05).round();
    boss.addShield(shieldAmount, max: shieldAmount);
  }

  void _triggerWeeklyCataclysm(
    Combatant boss,
    List<_DefeatedEnemyRecord> defeated,
  ) {
    final mechanics = config.difficulty.mechanics;
    boss.bossAoECooldownTicks =
        (mechanics.weeklyCataclysmCooldownSeconds *
                CombatSimulation.ticksPerSecond)
            .round();
    boss.cooldownTicks = math.max(
      boss.cooldownTicks,
      _intervalTicks(boss.stats.attackSpeed),
    );
    final multiplier =
        mechanics.weeklyCataclysmMultiplier *
        (boss.isFinalStand
            ? mechanics.weeklyFinalStandAtkMultiplier
            : (boss.isEnraged ? mechanics.berserkAtkMultiplier : 1.0));
    _strike(
      boss,
      player,
      multiplier: multiplier,
      skillId: 'cataclysm',
      defeated: defeated,
    );
  }

  void _triggerWeeklyLifeSiphon(
    Combatant boss,
    List<_DefeatedEnemyRecord> defeated,
  ) {
    final mechanics = config.difficulty.mechanics;
    boss.lifeSiphonCooldownTicks =
        (mechanics.weeklyLifeSiphonCooldownSeconds *
                CombatSimulation.ticksPerSecond)
            .round();
    boss.cooldownTicks = math.max(
      boss.cooldownTicks,
      _intervalTicks(boss.stats.attackSpeed),
    );
    final multiplier =
        mechanics.weeklyLifeSiphonMultiplier *
        (boss.isFinalStand
            ? mechanics.weeklyFinalStandAtkMultiplier
            : (boss.isEnraged ? mechanics.berserkAtkMultiplier : 1.0));
    final prevPlayerHp = player.hp;
    _strike(
      boss,
      player,
      multiplier: multiplier,
      skillId: 'life_siphon',
      defeated: defeated,
    );
    final dealt = math.max(0, prevPlayerHp - player.hp);
    if (dealt > 0 && boss.isAlive) {
      final healAmount = (dealt * mechanics.weeklyLifeSiphonHealRatio).round();
      boss.heal(healAmount);
    }
  }

  void _triggerBossGroundSlam(
    Combatant boss,
    List<_DefeatedEnemyRecord> defeated,
  ) {
    final mechanics = config.difficulty.mechanics;
    boss.bossAoECooldownTicks =
        (mechanics.bossAoeCooldownSeconds * CombatSimulation.ticksPerSecond)
            .round();
    boss.cooldownTicks = math.max(
      boss.cooldownTicks,
      _intervalTicks(boss.stats.attackSpeed),
    );
    final multiplier =
        mechanics.bossAoeMultiplier *
        (boss.isEnraged ? mechanics.berserkAtkMultiplier : 1.0);
    _strike(
      boss,
      player,
      multiplier: multiplier,
      skillId: 'ground_slam',
      defeated: defeated,
    );
  }

  void _triggerBossSummonMinions(Combatant boss) {
    boss.hasSummonedMinions = true;
    final shieldAmount = (boss.stats.maxHp * 0.08).round();
    boss.addShield(shieldAmount, max: shieldAmount);
    final mechanics = config.difficulty.mechanics;
    final bossDef = _definitions[boss.id];
    final count = mechanics.bossSummonCount;
    final minionDef = _resolveMinionDef(boss, bossDef, isElite: false);
    final cells = _findMinionCells(boss, count);

    for (final cell in cells) {
      final minionId = '${boss.id}__guard_${_spawnCounter++}';
      final minion = Combatant(
        id: minionId,
        team: Team.enemy,
        stats: minionDef.stats,
        cell: cell,
        definitionId: minionDef.id,
        detectionRange: minionDef.detectionRange,
        leashRange: minionDef.leashRange,
        isElite: false,
        isBoss: false,
      );
      minion.aggroed = true;
      minion.targetId = player.id;
      minion.aiState = MonsterAiState.chase;
      _enemies.add(minion);
      _definitions[minionId] = minionDef;
    }
  }

  List<GridPoint> _findMinionCells(Combatant boss, int count) {
    const offsets = [
      (-1, 0),
      (1, 0),
      (0, -1),
      (0, 1),
      (-1, -1),
      (1, -1),
      (-1, 1),
      (1, 1),
      (-2, 0),
      (2, 0),
      (0, -2),
      (0, 2),
    ];
    final bx = boss.follower.currentCell.x;
    final by = boss.follower.currentCell.y;
    final valid = <GridPoint>[];
    final g = _grid;
    for (final (dx, dy) in offsets) {
      final nx = bx + dx;
      final ny = by + dy;
      if (g != null && g.inBounds(nx, ny) && g.isWalkable(nx, ny)) {
        valid.add(GridPoint(nx, ny));
        if (valid.length >= count) break;
      }
    }
    if (valid.isEmpty) {
      valid.add(boss.follower.currentCell);
    }
    return valid;
  }

  EnemyDefinition _resolveMinionDef(
    Combatant boss,
    EnemyDefinition? bossDef, {
    bool isElite = false,
  }) {
    final hpRatio = isElite ? 0.06 : 0.04;
    final atkRatio = isElite ? 0.10 : 0.06;
    final defRatio = isElite ? 0.05 : 0.0;

    if (bossDef != null) {
      return EnemyDefinition(
        id: '${bossDef.id}_guard',
        name: isElite ? '${bossDef.name} Elite Guard' : '${bossDef.name} Guard',
        level: bossDef.level,
        stats: CombatStats(
          maxHp: math.max(10, (bossDef.stats.maxHp * hpRatio).round()),
          atk: math.max(1, (bossDef.stats.atk * atkRatio).round()),
          def: (bossDef.stats.def * defRatio).round(),
          attackSpeed: bossDef.stats.attackSpeed,
          moveSpeed: bossDef.stats.moveSpeed,
          attackRange: bossDef.stats.attackRange,
        ),
        detectionRange: bossDef.detectionRange,
        leashRange: bossDef.leashRange,
        isElite: isElite,
        isBoss: false,
        expReward: 0,
        goldReward: 0,
        spriteRef: bossDef.spriteRef,
        spriteTint: bossDef.spriteTint,
      );
    }

    return EnemyDefinition(
      id: '${boss.id}_guard',
      name: isElite ? 'Boss Elite Guard' : 'Boss Guard',
      level: 1,
      stats: CombatStats(
        maxHp: math.max(
          10,
          (boss.stats.maxHp * (isElite ? 0.25 : 0.15)).round(),
        ),
        atk: math.max(1, (boss.stats.atk * (isElite ? 0.25 : 0.20)).round()),
        def: (boss.stats.def * (isElite ? 0.25 : 0.20)).round(),
        attackSpeed: boss.stats.attackSpeed,
        moveSpeed: boss.stats.moveSpeed,
        attackRange: boss.stats.attackRange,
      ),
      detectionRange: boss.detectionRange,
      leashRange: boss.leashRange,
      isElite: isElite,
      isBoss: false,
    );
  }

  bool _tryCastSkill(Combatant? target, List<_DefeatedEnemyRecord> defeated) {
    if (playerStatus != PlayerStatus.alive || !player.isAlive) return false;
    if (!autoSkillEnabled || _skills.isEmpty) return false;
    final skill = skillSelector.select(
      skills: _skills,
      isReady: (s) {
        final state = _skillStates[s.id];
        return state != null && state.isReady && state.level >= 1;
      },
      caster: player,
      target: target,
      enemies: _aliveEnemies,
    );
    if (skill == null) return false;
    _castSkill(skill, target, defeated);
    return true;
  }

  void _castSkill(
    SkillDefinition skill,
    Combatant? target,
    List<_DefeatedEnemyRecord> defeated,
  ) {
    final state = _skillStates[skill.id];
    if (state == null || !state.isReady || state.level < 1) return;
    final affinityBonus = _skillAffinities[skill.id] ?? 0.0;

    if (skill.effect == SkillEffectType.healing) {
      if (player.hp >= player.stats.maxHp) return;
      _skillStates[skill.id] = state.triggerCooldown(
        _skillCooldownTicks(skill),
      );
      _onSkillCastResonanceCheck();
      final effectiveHealPercent =
          (skill.healPercentAt(state.level) * (1.0 + affinityBonus)).clamp(
            0.0,
            1.0,
          );
      player.heal((player.stats.maxHp * effectiveHealPercent).round());
      return;
    }

    if (skill.effect != SkillEffectType.damage) return;
    if (target == null || !target.isAlive || target.team == player.team) {
      return;
    }
    final range = skill.range ?? player.stats.attackRange;
    if (player.distanceTo(target) > range) return;

    _skillStates[skill.id] = state.triggerCooldown(_skillCooldownTicks(skill));
    _onSkillCastResonanceCheck();

    final victims = skill.targetType == SkillTarget.area
        ? _aliveEnemies
              .where((e) => e.distanceTo(target) <= skill.radius)
              .toList()
        : [target];
    final multiplier =
        skill.damageMultiplierAt(state.level) * (1.0 + affinityBonus);
    final damageType = skill.damageType ?? SkillDamageType.physical;
    for (final victim in victims) {
      if (!player.isAlive || playerStatus != PlayerStatus.alive) break;
      if (!victim.isAlive) continue;
      _strike(
        player,
        victim,
        multiplier: multiplier,
        damageType: damageType,
        skillId: skill.id,
        defeated: defeated,
      );
    }
  }

  void _strike(
    Combatant attacker,
    Combatant target, {
    double multiplier = 1.0,
    SkillDamageType damageType = SkillDamageType.physical,
    String? skillId,
    List<_DefeatedEnemyRecord>? defeated,
  }) {
    if (playerStatus != PlayerStatus.alive ||
        !attacker.isAlive ||
        !target.isAlive) {
      return;
    }
    if (target.invulnerableTicks > 0) return;

    var defenderDef = target.stats.def;
    var effectiveDamageType = damageType;

    // REC-05: Voidblade Shadow Mark mengabaikan 50% DEF musuh
    final isVoidbladeTrueDamage =
        attacker.team == Team.player &&
        character.activeResonanceClassId == 'voidblade' &&
        (target.isShadowMarked || target.shadowMarkTicks > 0);
    if (isVoidbladeTrueDamage) {
      defenderDef = (defenderDef * 0.5).round();
    }

    final result = damageCalculator.roll(
      attacker: attacker.stats,
      defenderDef: defenderDef,
      random: random,
      multiplier: multiplier,
      damageType: effectiveDamageType,
    );
    var finalDamage = result.amount;

    // Stormcaller: Target dengan status Shock menerima +15% damage
    if (target.isShocked || target.shockTicks > 0) {
      finalDamage = (finalDamage * 1.15).round();
    }

    // Voidblade: Serangan kritikal memberi tanda Shadow Mark
    if (attacker.team == Team.player &&
        character.activeResonanceClassId == 'voidblade' &&
        result.isCrit) {
      target.shadowMarkTicks = (6.0 * CombatSimulation.ticksPerSecond).round();
      target.isShadowMarked = true;
    }

    final mechanics = config.difficulty.mechanics;
    final mechanicsActive = mechanics.isEnabledFor(cycleRank);
    if (mechanicsActive) {
      if (target.isElite && !target.isDailyBoss && !target.isWeeklyBoss) {
        if (target.hp > (target.stats.maxHp * mechanics.stoneskinHpThreshold)) {
          final reduced =
              (finalDamage * (1.0 - mechanics.stoneskinDamageReduction))
                  .round();
          finalDamage = math.max(1, reduced);
        }
      } else if (target.isDailyBoss && target.elementalWardTicks > 0) {
        final reduced =
            (finalDamage * (1.0 - mechanics.dailyElementalWardReduction))
                .round();
        finalDamage = math.max(1, reduced);
      } else if (target.isWeeklyBoss && target.isFinalStand) {
        final reduced =
            (finalDamage * (1.0 - mechanics.weeklyFinalStandDamageReduction))
                .round();
        finalDamage = math.max(1, reduced);
      }
    }
    final unabsorbedDamage = target.absorbDamage(finalDamage);
    target.hp = math.max(0, target.hp - unabsorbedDamage);

    // REC-01: Serangan valid memicu aggro musuh terlepas dari jangkauan deteksi
    if (finalDamage > 0 &&
        target.isAlive &&
        target.team == Team.enemy &&
        !target.aggroed &&
        attacker.isAlive) {
      target.aggroed = true;
      target.targetId = attacker.id;
      target.aiState = MonsterAiState.chase;
    }

    // Lifesteal (Basic Attack) & Spell Vamp (Skill Damage)
    if (finalDamage > 0 && attacker.isAlive) {
      if (skillId == null && attacker.stats.lifesteal > 0) {
        final healAmount = (finalDamage * attacker.stats.lifesteal).round();
        if (healAmount > 0) {
          attacker.heal(healAmount);
        }
      } else if (skillId != null && attacker.stats.spellVamp > 0) {
        final healAmount = (finalDamage * attacker.stats.spellVamp).round();
        if (healAmount > 0) {
          attacker.heal(healAmount);
        }
      }
    }

    // Stormcaller: Chain lightning & Shock
    if (attacker.team == Team.player &&
        character.activeResonanceClassId == 'stormcaller' &&
        skillId != 'chain_lightning') {
      target.shockTicks = (4.0 * CombatSimulation.ticksPerSecond).round();
      target.isShocked = true;
      final chainCandidates =
          _aliveEnemies
              .where(
                (e) => !identical(e, target) && target.distanceTo(e) <= 3.0,
              )
              .toList()
            ..sort(
              (a, b) => target.distanceTo(a).compareTo(target.distanceTo(b)),
            );
      for (final extra in chainCandidates.take(2)) {
        extra.shockTicks = (4.0 * CombatSimulation.ticksPerSecond).round();
        extra.isShocked = true;
        _strike(
          attacker,
          extra,
          multiplier: 0.8,
          damageType: SkillDamageType.magic,
          skillId: 'chain_lightning',
          defeated: defeated,
        );
      }
    }

    // REC-06/07: Paladin Holy Nova retaliation saat menerima damage (CD 5.0s, Heal 3% Max HP)
    if (identical(target, player) &&
        character.activeResonanceClassId == 'paladin' &&
        _paladinHolyNovaCooldownTicks == 0 &&
        finalDamage > 0) {
      _paladinHolyNovaCooldownTicks = (5.0 * CombatSimulation.ticksPerSecond)
          .round();
      final healAmount = math.max(1, (player.stats.maxHp * 0.03).round());
      player.heal(healAmount);
      final inRange = _aliveEnemies
          .where((e) => player.distanceTo(e) <= 2.0)
          .toList();
      for (final enemy in inRange) {
        _strike(
          player,
          enemy,
          multiplier: 1.0,
          damageType: SkillDamageType.magic,
          skillId: 'holy_nova_retaliation',
          defeated: defeated,
        );
      }
    }

    if (!target.isAlive) {
      if (identical(target, player)) {
        _onPlayerDefeated();
      } else {
        target.aiState = MonsterAiState.dead;
        target.aggroed = false;
        target.targetId = null;
        target.plannedGoal = null;
        final def = _definitions[target.id];
        if (def != null && _processedDeaths.add(target.id)) {
          defeated?.add(_DefeatedEnemyRecord(target.id, def));
        }

        // Necromancer: Memanggil Shadow Minion saat musuh gugur
        if (character.activeResonanceClassId == 'necromancer') {
          _spawnNecromancerMinion(target.follower.currentCell);
        }
      }
    }
  }

  void _onPlayerDefeated() {
    for (final enemy in _enemies) {
      if (!enemy.isAlive) continue;
      enemy.aggroed = false;
      enemy.targetId = null;
      enemy.plannedGoal = null;
      enemy.aiState = enemy.isAtSpawn
          ? MonsterAiState.idle
          : MonsterAiState.returning;
    }
    if (reviveCooldownTicks == 0) {
      playerStatus = PlayerStatus.downed;
      _downedTicksLeft = math.max(
        1,
        _secondsToTicks(config.revive.delaySeconds),
      );
    } else {
      playerStatus = PlayerStatus.runEnded;
    }
  }

  void _tickDowned() {
    _downedTicksLeft--;
    if (_downedTicksLeft > 0) return;

    player.hp = math.max(
      1,
      (player.stats.maxHp * config.revive.hpPercent).round(),
    );
    player.invulnerableTicks = _secondsToTicks(
      config.revive.invulnerabilitySeconds,
    );
    player.cooldownTicks = 0;
    player.targetId = null;
    player.plannedGoal = null;
    reviveCooldownTicks = _secondsToTicks(config.revive.cooldownSeconds);
    playerStatus = PlayerStatus.alive;
  }

  bool _chase(Combatant mover, Combatant target) {
    final grid = _grid;
    if (grid == null) return false;
    final cachedGoal = mover.plannedGoal;
    final cacheValid =
        cachedGoal != null &&
        grid.isWalkable(cachedGoal.x, cachedGoal.y) &&
        mover.follower.isMoving &&
        (cachedGoal == target.follower.currentCell ||
            AttackPositionFinder.isCellInAttackRange(
              cachedGoal,
              target,
              mover.stats.attackRange,
            ));
    if (!cacheValid) {
      final path = attackPositionFinder.findPath(
        grid: grid,
        pathfinder: pathfinder,
        attacker: mover,
        target: target,
      );
      if (path == null) return false;
      mover.plannedGoal = path.last;
      if (path.length == 1 && mover.follower.currentCell == path.last) {
        mover.follower.walkToCenterOf(path.last);
      } else {
        mover.follower.setPath(path);
      }
    }
    mover.follower.advance(
      mover.stats.moveSpeed * CombatSimulation.tickSeconds,
    );
    return true;
  }

  void _startReturning(Combatant enemy) {
    enemy.aggroed = false;
    enemy.targetId = null;
    enemy.plannedGoal = null;
    enemy.aiState = enemy.isAtSpawn
        ? MonsterAiState.idle
        : MonsterAiState.returning;
    if (enemy.aiState == MonsterAiState.returning) {
      _returnToSpawn(enemy);
    }
  }

  void _returnToSpawn(Combatant enemy) {
    if (enemy.isAtSpawn) {
      enemy.aiState = MonsterAiState.idle;
      enemy.plannedGoal = null;
      return;
    }
    final grid = _grid;
    if (grid == null) return;
    if (enemy.plannedGoal != enemy.spawnCell || !enemy.follower.isMoving) {
      enemy.plannedGoal = enemy.spawnCell;
      final from = enemy.follower.currentCell;
      if (from == enemy.spawnCell) {
        enemy.follower.walkToCenterOf(enemy.spawnCell);
      } else {
        final path = pathfinder.findPath(grid, from, enemy.spawnCell);
        if (path == null) return;
        enemy.follower.setPath(path);
      }
    }
    enemy.follower.advance(
      enemy.stats.moveSpeed * CombatSimulation.tickSeconds,
    );
    if (enemy.isAtSpawn) {
      enemy.aiState = MonsterAiState.idle;
      enemy.plannedGoal = null;
    }
  }

  int _skillCooldownTicks(SkillDefinition skill) {
    final haste = math.min(
      EquipmentStats.maxSkillHaste,
      math.max(0.0, player.stats.skillHaste),
    );
    final seconds = skill.cooldownSeconds * (1 - haste);
    return SkillRuntimeState.secondsToTicks(seconds);
  }

  int _secondsToTicks(double seconds) =>
      math.max(0, (seconds * CombatSimulation.ticksPerSecond).round());

  int _intervalTicks(double attackSpeed) =>
      math.max(1, (CombatSimulation.ticksPerSecond / attackSpeed).round());

  void _triggerGunslingerPiercingBeam(
    Combatant attacker,
    Combatant primaryTarget,
    List<_DefeatedEnemyRecord> defeated,
  ) {
    final px = attacker.x;
    final py = attacker.y;
    final tx = primaryTarget.x;
    final ty = primaryTarget.y;
    final vx = tx - px;
    final vy = ty - py;
    final distTarget = math.sqrt(vx * vx + vy * vy);
    if (distTarget < 1e-4) return;
    final ux = vx / distTarget;
    final uy = vy / distTarget;
    final maxDist = attacker.stats.attackRange + 1.0;

    for (final enemy in _aliveEnemies) {
      if (identical(enemy, primaryTarget)) continue;
      final ex = enemy.x;
      final ey = enemy.y;
      final wx = ex - px;
      final wy = ey - py;
      final proj = wx * ux + wy * uy;
      if (proj > 0 && proj <= maxDist) {
        final perp2 = (wx * wx + wy * wy) - (proj * proj);
        if (perp2 <= 0.6 * 0.6) {
          _strike(
            attacker,
            enemy,
            multiplier: 1.0,
            skillId: 'piercing_beam',
            damageType: SkillDamageType.physical,
            defeated: defeated,
          );
        }
      }
    }
  }

  void _spawnNecromancerMinion(GridPoint cell) {
    if (_allies.length >= 2) return;
    final minionId = 'shadow_minion_${_spawnCounter++}';
    final minionStats = CombatStats(
      maxHp: math.max(1, (player.stats.maxHp * 0.5).round()),
      atk: math.max(1, (player.stats.atk * 0.5).round()),
      def: (player.stats.def * 0.5).round(),
      attackSpeed: player.stats.attackSpeed,
      moveSpeed: player.stats.moveSpeed,
      attackRange: player.stats.attackRange,
    );
    final minion = Combatant(
      id: minionId,
      team: Team.player,
      stats: minionStats,
      cell: cell,
    )..lifetimeTicks = (6.0 * CombatSimulation.ticksPerSecond).round();
    _allies.add(minion);
  }

  void _onSkillCastResonanceCheck() {
    if (character.activeResonanceClassId == 'chronomancer') {
      _chronomancerSkillCasts++;
      if (_chronomancerSkillCasts % 4 == 0) {
        for (final enemy in _aliveEnemies) {
          if (!enemy.isBoss) {
            enemy.freezeTicks = (2.0 * CombatSimulation.ticksPerSecond).round();
          }
        }
      }
    }
  }
}
