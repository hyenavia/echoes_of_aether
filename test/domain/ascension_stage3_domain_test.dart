import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/ascension_service.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/dungeon_progression_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_reward_settlement_service.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/equipment_service.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig({CombatStats? baseStatsOverride}) {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  final baseProg = parser.parseProgression(settings);
  final progression = baseStatsOverride == null
      ? baseProg
      : ProgressionConfig(
          maxLevel: baseProg.maxLevel,
          expCurve: baseProg.expCurve,
          baseStats: baseStatsOverride,
          perLevel: baseProg.perLevel,
        );
  final config = GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: progression,
    equipment: parser.parseEquipment(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(
      _readAsset('dungeons.json'),
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
  );
  const GameConfigValidator().validate(config);
  return config;
}

void main() {
  late GameConfig config;

  setUpAll(() {
    config = _loadRealConfig();
  });

  group('M9 Stage 3 — Domain, Idempotensi & Death Loop', () {
    test('penyelesaian Ascension end-to-end (headless): rank +1, reset siklus, reward 1x, state pemain & lifetime clear utuh, serta aman dari klaim ganda pasca restart', () async {
      final heroConfig = _loadRealConfig(
        baseStatsOverride: const CombatStats(
          maxHp: 50000,
          atk: 25000,
          def: 10000,
          attackSpeed: 5.0,
          moveSpeed: 10.0,
          attackRange: 6.0,
        ),
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      const startMs = 1000000;
      final repo = DriftPlayerSaveRepository(db: db, config: heroConfig);
      final coordinator = GameSessionCoordinator(
        repository: repo,
        config: heroConfig,
        nowMs: () => startMs,
      );

      final char = PlayerCharacter(
        config: heroConfig.progression,
        progress: const PlayerProgress(level: 50, currentExp: 120, gold: 500),
        skillCatalog: heroConfig.skills,
        specializationConfig: heroConfig.specializations,
        initialSpecializationId: 'vanguard',
        skillLevels: const {'power_strike': 2},
      );
      final inv = Inventory(definitions: heroConfig.items);
      inv.add('small_potion', 3);
      final eqFactory = EquipmentFactory(heroConfig.equipment);
      final equippedWeapon = eqFactory.create(
        instanceId: 'eq_stage3_1',
        definition: heroConfig.items['rusty_sword']!,
        random: math.Random(1),
      );
      inv.addEquipment(equippedWeapon);
      EquipmentService(
        inventory: inv,
        loadout: char.loadout,
      ).equip(equippedWeapon.id);

      final initialProgresses = <String, DungeonProgressSnapshot>{
        'forgotten_forest': const DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          clearsCount: 4,
          clearedInCycleRank: 0,
          highestClearedRoomIndex: 4,
        ),
        'crystal_cavern': const DungeonProgressSnapshot(
          currentDungeonId: 'crystal_cavern',
          clearsCount: 2,
          clearedInCycleRank: 0,
          highestClearedRoomIndex: 4,
        ),
        'ancient_crypt': const DungeonProgressSnapshot(
          currentDungeonId: 'ancient_crypt',
          clearsCount: 1,
          clearedInCycleRank: 0,
          highestClearedRoomIndex: 4,
        ),
        'ashen_wasteland': const DungeonProgressSnapshot(
          currentDungeonId: 'ashen_wasteland',
          clearsCount: 1,
          clearedInCycleRank: 0,
          highestClearedRoomIndex: 4,
        ),
        'aether_sanctum': const DungeonProgressSnapshot(
          currentDungeonId: 'aether_sanctum',
          clearsCount: 1,
          clearedInCycleRank: 0,
          highestClearedRoomIndex: 4,
        ),
      };
      const initialCycle = CycleProgress(
        ascensionRank: 0,
        lastNormalDungeonId: 'aether_sanctum',
      );

      final processor = RewardProcessor(
        character: char,
        inventory: inv,
        items: heroConfig.items,
        lootTables: heroConfig.lootTables,
        equipmentFactory: eqFactory,
      );

      final tracker = EncounterTracker(monsterCatalog: heroConfig.monsters);
      final diffService = DifficultyService(heroConfig.difficulty);
      final manager = DungeonManager(
        dungeons: heroConfig.dungeons,
        encounterTracker: tracker,
        difficultyService: diffService,
      );
      const settlementService = DungeonRewardSettlementService();
      const progression = DungeonProgressionService();
      const ascensionService = AscensionService(
        progressionService: progression,
      );

      DungeonEndedEvent? completedEvent;
      manager.addListener((event) {
        if (event is DungeonEndedEvent &&
            event.finalStatus == DungeonSessionStatus.completed) {
          completedEvent = event;
        }
      });

      final runSession = manager.startDungeon(
        'ascension_sanctum',
        runId: 'asc_e2e_run_1',
        cycleRank: initialCycle.ascensionRank,
      );
      expect(runSession.cycleRank, 0);

      // Jalankan 5 room Ascension hingga tamat.
      final simRandom = math.Random(17);
      for (var roomStep = 0; roomStep < 5; roomStep++) {
        final room = manager.activeRoom!;
        final grid = manager.activeGrid!;
        final player = Combatant(
          id: 'player',
          team: Team.player,
          stats: char.stats,
          cell: room.entryPosition,
        );
        final sim = CombatSimulation(
          grid: grid,
          pathfinder: const AStarPathfinder(),
          player: player,
          reviveConfig: heroConfig.revive,
          damageCalculator: heroConfig.damage.createCalculator(),
          seed: 42 + roomStep,
        );
        tracker.onRoomLoaded(sim, grid: grid);
        manager.activateRoom();
        tracker.onRoomActivated(sim, grid: grid);

        for (var tick = 0; tick < 600; tick++) {
          sim.tick();
          for (final ev in sim.drainEvents()) {
            if (ev is EnemyDefeatedEvent) {
              processor.processEnemyDefeated(
                eventId: 'enemy:${runSession.runId}:${ev.tick}:${ev.enemyId}',
                definition: ev.definition,
                random: simRandom,
                difficultyProfile: manager.activeDifficultyProfile,
                difficultyService: diffService,
              );
              tracker.onEnemyDefeated(ev.enemyId, simulation: sim, grid: grid);
            }
          }
          if (manager.session?.roomLifecycle == RoomLifecycleState.active &&
              manager
                  .evaluateCurrentRoom(playerCell: player.follower.currentCell)
                  .exitUnlocked &&
              room.completionCondition.requiresExit) {
            sim.setExitNavigation(room.exitPosition);
          }
          manager.updatePlayerCell(player.follower.currentCell);
          manager.tryCompleteActiveRoom(
            playerCell: player.follower.currentCell,
          );
          if (manager.session?.roomLifecycle == RoomLifecycleState.completed ||
              manager.session?.status == DungeonSessionStatus.completed) {
            break;
          }
        }

        if (roomStep < 4) {
          expect(manager.session?.roomLifecycle, RoomLifecycleState.completed);
          expect(manager.transitionToNextRoom(), true);
        }
      }

      expect(completedEvent, isNotNull);
      expect(completedEvent!.finalStatus, DungeonSessionStatus.completed);

      final settled = settlementService.settleDungeonCompleted(
        event: completedEvent!,
        config: heroConfig,
        rewardProcessor: processor,
        random: simRandom,
        dungeonManager: manager,
        difficultyProfile: manager.activeDifficultyProfile,
        difficultyService: diffService,
      );
      expect(settled.validCompletion, true);
      expect(settled.granted, isNotNull);
      expect(settled.granted!.alreadyClaimed, false);
      expect(settled.granted!.expGranted, greaterThan(0));
      expect(settled.granted!.goldGranted, greaterThan(0));

      final goldAfterFirstClear = char.gold;
      final expAfterFirstClear = char.currentExp;
      final levelAfterFirstClear = char.level;

      final ascMap = <String, DungeonProgressSnapshot>{
        ...initialProgresses,
        'ascension_sanctum': const DungeonProgressSnapshot(
          currentDungeonId: 'ascension_sanctum',
          clearsCount: 1,
          clearedInCycleRank: -1,
          highestClearedRoomIndex: 4,
        ),
      };
      final ascResult = ascensionService.complete(
        runId: runSession.runId,
        dungeons: heroConfig.dungeons.values,
        cycleProgress: initialCycle,
        dungeonProgresses: ascMap,
        rewardProcessor: processor,
        claimedEventIds: processor.claimedEventIds,
      );

      expect(ascResult.alreadyCompleted, false);
      expect(ascResult.rankIncremented, true);
      expect(ascResult.previousRank, 0);
      expect(ascResult.newRank, 1);
      expect(ascResult.cycleProgress.ascensionRank, 1);
      expect(ascResult.cycleProgress.lastNormalDungeonId, 'forgotten_forest');

      // Status clear siklus di-reset ke -1, tetapi lifetime clearsCount tetap utuh.
      expect(ascResult.dungeonProgresses['forgotten_forest']!.clearsCount, 4);
      expect(
        ascResult.dungeonProgresses['forgotten_forest']!.clearedInCycleRank,
        -1,
      );
      expect(ascResult.dungeonProgresses['aether_sanctum']!.clearsCount, 1);
      expect(
        ascResult.dungeonProgresses['aether_sanctum']!.clearedInCycleRank,
        -1,
      );
      expect(ascResult.dungeonProgresses['ascension_sanctum']!.clearsCount, 1);
      expect(
        progression.isUnlocked(
          heroConfig.dungeons['forgotten_forest']!,
          ascResult.cycleProgress,
          ascResult.dungeonProgresses,
          allDungeons: heroConfig.dungeons.values,
        ),
        true,
      );
      expect(
        progression.isUnlocked(
          heroConfig.dungeons['crystal_cavern']!,
          ascResult.cycleProgress,
          ascResult.dungeonProgresses,
          allDungeons: heroConfig.dungeons.values,
        ),
        false,
      );
      expect(
        ascensionService.canEnterAscension(
          dungeons: heroConfig.dungeons.values,
          cycleProgress: ascResult.cycleProgress,
          dungeonProgresses: ascResult.dungeonProgresses,
        ),
        false,
      );

      // Simpan seluruh state pasca-penyelesaian.
      final potionsAfterFirstClear = inv.quantityOf('small_potion');
      await coordinator.saveFromRuntime(
        character: char,
        inventory: inv,
        dungeon: ascResult.dungeonProgresses['ascension_sanctum']!,
        dungeonProgresses: ascResult.dungeonProgresses,
        cycleProgress: ascResult.cycleProgress,
        rewardProcessor: processor,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: startMs,
        activeDungeonSession: manager.toActiveSessionSnapshot(),
      );

      // Simulasikan tutup & buka ulang aplikasi tepat saat/setelah penyelesaian.
      final reopenedCoord = GameSessionCoordinator(
        repository: DriftPlayerSaveRepository(db: db, config: heroConfig),
        config: heroConfig,
        nowMs: () => startMs + 5000,
      );
      final reloaded = await reopenedCoord.loadAndProcessOffline();
      expect(reloaded.cycleProgress.ascensionRank, 1);
      expect(reloaded.cycleProgress.lastNormalDungeonId, 'forgotten_forest');
      expect(reloaded.hasRecoverableDungeonSession, false);
      expect(reloaded.character.specializationId, 'vanguard');
      expect(reloaded.character.skillLevel('power_strike'), 2);
      expect(
        reloaded.character.loadout.instanceIn(equippedWeapon.slot)?.id,
        equippedWeapon.id,
      );
      expect(
        reloaded.inventory.quantityOf('small_potion'),
        potionsAfterFirstClear,
      );
      expect(reloaded.character.gold, goldAfterFirstClear);
      expect(reloaded.character.level, levelAfterFirstClear);
      expect(reloaded.character.currentExp, expAfterFirstClear);
      expect(
        reloaded.claimedEventIds.contains('ascension:${runSession.runId}'),
        true,
      );
      expect(
        reloaded.claimedEventIds.contains('dungeon_clear:${runSession.runId}'),
        true,
      );

      // Percobaan ulang penyelesaian dengan runId sama pasca-restart tidak menaikkan rank maupun memberi reward ulang.
      final replayAsc = ascensionService.complete(
        runId: runSession.runId,
        dungeons: heroConfig.dungeons.values,
        cycleProgress: reloaded.cycleProgress,
        dungeonProgresses: reloaded.dungeonProgresses,
        rewardProcessor: reloaded.rewardProcessor,
        claimedEventIds: reloaded.claimedEventIds,
      );
      expect(replayAsc.alreadyCompleted, true);
      expect(replayAsc.rankIncremented, false);
      expect(replayAsc.newRank, 1);

      final replayReward = settlementService.settleDungeonCompleted(
        event: completedEvent!,
        config: heroConfig,
        rewardProcessor: reloaded.rewardProcessor,
        random: simRandom,
      );
      expect(replayReward.granted?.alreadyClaimed, true);
      expect(reloaded.character.gold, goldAfterFirstClear);
      expect(reloaded.character.currentExp, expAfterFirstClear);
    });

    test('crash sebelum settlement pada final room Ascension (status roomCompleted) tidak menaikkan rank dan kembali aman ke Town', () {
      final tracker = EncounterTracker(monsterCatalog: config.monsters);
      final manager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: tracker,
      );
      const crashSnapshot = ActiveDungeonSessionSnapshot(
        runId: 'asc_crash_final_room',
        dungeonId: 'ascension_sanctum',
        currentRoomId: 'as_sovereign_throne',
        currentRoomIndex: 4,
        status: DungeonSessionStatus.roomCompleted,
        clearedRoomIds: {
          'as_outer_sanctum',
          'as_arcane_bridge',
          'as_warden_chamber',
          'as_void_corridor',
          'as_sovereign_throne',
        },
        cycleRank: 0,
      );
      final restored = manager.restoreSession(crashSnapshot);
      expect(restored, isNull);
    });

    test('alur respawn pasca-kalah di Ascension vs Normal dan penghitung kekalahan beruntun + persistensi', () async {
      const progression = DungeonProgressionService();
      const cycle = CycleProgress(
        ascensionRank: 1,
        lastNormalDungeonId: 'ancient_crypt',
      );
      final progresses = <String, DungeonProgressSnapshot>{
        'forgotten_forest': const DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          clearsCount: 2,
          clearedInCycleRank: 1,
        ),
        'crystal_cavern': const DungeonProgressSnapshot(
          currentDungeonId: 'crystal_cavern',
          clearsCount: 1,
          clearedInCycleRank: 1,
        ),
        'ancient_crypt': const DungeonProgressSnapshot(
          currentDungeonId: 'ancient_crypt',
          clearsCount: 1,
          clearedInCycleRank: 1,
        ),
      };

      // Kalah di Ascension kembali ke dungeon normal terakhir (ancient_crypt).
      expect(
        progression.resolveRespawnDungeonId(
          dungeons: config.dungeons.values,
          cycle: cycle,
          progresses: progresses,
          exitedDungeonId: 'ascension_sanctum',
        ),
        'ancient_crypt',
      );

      // Kalah di Normal dungeon kembali ke dungeon itu sendiri.
      expect(
        progression.resolveRespawnDungeonId(
          dungeons: config.dungeons.values,
          cycle: cycle,
          progresses: progresses,
          exitedDungeonId: 'crystal_cavern',
        ),
        'crystal_cavern',
      );

      // Death loop counter: increment, threshold 3, reset pada victory.
      var streaks = const <String, int>{};
      streaks = progression.recordDungeonDefeat(streaks, 'ancient_crypt');
      streaks = progression.recordDungeonDefeat(streaks, 'ancient_crypt');
      expect(streaks['ancient_crypt'], 2);
      expect(
        progression.evaluateDeathLoop(
          dungeons: config.dungeons.values,
          cycle: cycle,
          progresses: progresses,
          consecutiveDefeats: streaks,
          suggestAfter: config.farming.deathLoopSuggestAfter,
          selectedDungeonId: 'ancient_crypt',
        ),
        isNull,
      );

      streaks = progression.recordDungeonDefeat(streaks, 'ancient_crypt');
      expect(streaks['ancient_crypt'], 3);
      final suggestion = progression.evaluateDeathLoop(
        dungeons: config.dungeons.values,
        cycle: cycle,
        progresses: progresses,
        consecutiveDefeats: streaks,
        suggestAfter: config.farming.deathLoopSuggestAfter,
        selectedDungeonId: 'ancient_crypt',
      );
      expect(suggestion, isNotNull);
      expect(suggestion!.failedDungeon.id, 'ancient_crypt');
      expect(suggestion.consecutiveDefeats, 3);
      expect(suggestion.suggestedDungeon?.id, 'crystal_cavern');

      // Kalah 3x di Dungeon 1 tidak melempar error (suggestedDungeon null).
      var d1Streaks = const <String, int>{};
      for (var i = 0; i < 3; i++) {
        d1Streaks = progression.recordDungeonDefeat(
          d1Streaks,
          'forgotten_forest',
        );
      }
      final d1Suggestion = progression.evaluateDeathLoop(
        dungeons: config.dungeons.values,
        cycle: cycle,
        progresses: progresses,
        consecutiveDefeats: d1Streaks,
        suggestAfter: 3,
        selectedDungeonId: 'forgotten_forest',
      );
      expect(d1Suggestion, isNotNull);
      expect(d1Suggestion!.suggestedDungeon, isNull);

      // Simpan dan muat ulang lewat DriftPlayerSaveRepository.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();
      final repo = DriftPlayerSaveRepository(db: db, config: config);
      final char = PlayerCharacter(config: config.progression);
      final inv = Inventory(definitions: config.items);
      final coord = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => 500000,
      );
      await coord.saveFromRuntime(
        character: char,
        inventory: inv,
        dungeon: progresses['ancient_crypt']!,
        dungeonProgresses: progresses,
        cycleProgress: cycle,
        rewardProcessor: RewardProcessor(
          character: char,
          inventory: inv,
          items: config.items,
          lootTables: config.lootTables,
          equipmentFactory: EquipmentFactory(config.equipment),
        ),
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: 500000,
        consecutiveDefeats: streaks,
        lastFailedDungeonId: 'ancient_crypt',
      );

      final reloaded = await GameSessionCoordinator(
        repository: DriftPlayerSaveRepository(db: db, config: config),
        config: config,
        nowMs: () => 500100,
      ).loadAndProcessOffline();
      expect(reloaded.session.consecutiveDefeats['ancient_crypt'], 3);
      expect(reloaded.session.lastFailedDungeonId, 'ancient_crypt');

      // Menang di ancient_crypt mereset penghitung kekalahan untuk ancient_crypt.
      final afterWin = progression.recordDungeonVictory(
        reloaded.session.consecutiveDefeats,
        'ancient_crypt',
      );
      expect(afterWin.containsKey('ancient_crypt'), false);
      expect(
        progression.evaluateDeathLoop(
          dungeons: config.dungeons.values,
          cycle: cycle,
          progresses: progresses,
          consecutiveDefeats: afterWin,
          suggestAfter: config.farming.deathLoopSuggestAfter,
          selectedDungeonId: 'ancient_crypt',
        ),
        isNull,
      );
    });

    test('Offline Auto Farming tetap memakai stopOnDefeat dan tidak mengubah ascensionRank', () {
      const offlineService = OfflineProgressionService();
      final char = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 1),
      );
      final inv = Inventory(definitions: config.items);
      const startMs = 1000000;
      final nowMs = startMs + const Duration(hours: 2).inMilliseconds;
      const cycle = CycleProgress(
        ascensionRank: 2,
        lastNormalDungeonId: 'aether_sanctum',
      );
      final result = offlineService.process(
        character: char,
        inventory: inv,
        config: config,
        session: const GameSessionSnapshot(lastSavedAtMs: startMs),
        nowMs: nowMs,
        offlineActivity: OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.configured,
          selectedDungeonId: 'aether_sanctum',
          lastCheckpointAtMs: startMs,
          failurePolicy: OfflineFailurePolicy.stopOnDefeat,
        ),
        dungeonProgress: const DungeonProgressSnapshot(
          currentDungeonId: 'aether_sanctum',
          clearsCount: 1,
          clearedInCycleRank: 2,
        ),
        dungeonProgresses: const {
          'aether_sanctum': DungeonProgressSnapshot(
            currentDungeonId: 'aether_sanctum',
            clearsCount: 1,
            clearedInCycleRank: 2,
          ),
        },
        cycleProgress: cycle,
      );

      expect(result.stopReason, OfflineDungeonStopReason.playerDefeated);
      expect(
        result.updatedOfflineActivity?.failurePolicy,
        OfflineFailurePolicy.stopOnDefeat,
      );
      expect(cycle.ascensionRank, 2);
    });
  });
}
