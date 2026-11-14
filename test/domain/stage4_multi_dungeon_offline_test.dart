import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/difficulty_config.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loot_table.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/dungeon_progression_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

const _layout = <String>[
  '########',
  '#......#',
  '#......#',
  '#......#',
  '########',
];

const _progression = ProgressionConfig(
  maxLevel: 40,
  expBase: 50,
  expGrowth: 1.5,
  baseStats: CombatStats(
    maxHp: 180,
    atk: 25,
    def: 6,
    attackSpeed: 1.8,
    critRate: 0.1,
    critDamage: 1.5,
    moveSpeed: 4.5,
    attackRange: 1.5,
  ),
  perLevel: LevelGrowth(hp: 25, atk: 5, def: 2),
);

DungeonDefinition _makeSimpleDungeon({
  required String id,
  required String name,
  required int order,
  DungeonKind kind = DungeonKind.normal,
  String? unlockRequiresDungeonId,
  String? baseDungeonId,
  int recommendedLevel = 1,
}) {
  final r1 = '${id}_r1';
  final r2 = '${id}_r2';
  return DungeonDefinition(
    id: id,
    name: name,
    biome: 'test',
    kind: kind,
    order: order,
    recommendedLevel: recommendedLevel,
    unlockRequiresDungeonId: unlockRequiresDungeonId,
    baseDungeonId: baseDungeonId,
    difficultyScale: order.toDouble(),
    startRoomId: r1,
    roomOrder: [r1, r2],
    completionReward: const DungeonCompletionReward(
      expReward: 40,
      goldReward: 25,
    ),
    rooms: {
      r1: RoomDefinition(
        id: r1,
        dungeonId: id,
        name: '$name Room 1',
        type: RoomType.normal,
        mapRef: r1,
        layout: _layout,
        entryPosition: const GridPoint(1, 2),
        exitPosition: const GridPoint(6, 2),
        nextRoomIds: [r2],
        completionCondition: const RoomCompletionCondition(
          type: RoomCompletionConditionType.defeatRequiredEnemies,
        ),
        spawns: const [
          RoomSpawnConfig(
            id: 's1',
            monsterId: 'slime',
            position: GridPoint(3, 2),
          ),
        ],
      ),
      r2: RoomDefinition(
        id: r2,
        dungeonId: id,
        name: '$name Boss',
        type: RoomType.boss,
        mapRef: r2,
        layout: _layout,
        entryPosition: const GridPoint(1, 2),
        exitPosition: const GridPoint(6, 2),
        completionCondition: const RoomCompletionCondition(
          type: RoomCompletionConditionType.defeatBoss,
        ),
        spawns: const [
          RoomSpawnConfig(
            id: 'b1',
            monsterId: 'boss',
            position: GridPoint(4, 2),
            isBoss: true,
          ),
        ],
      ),
    },
  );
}

GameConfig _multiDungeonConfig() => GameConfig(
  monsters: const {
    'slime': EnemyDefinition(
      id: 'slime',
      name: 'Slime',
      level: 1,
      expReward: 12,
      goldReward: 6,
      lootTableId: 'slime_loot',
      stats: CombatStats(
        maxHp: 20,
        atk: 4,
        def: 1,
        attackSpeed: 1.0,
        moveSpeed: 2.0,
        attackRange: 1.2,
      ),
    ),
    'boss': EnemyDefinition(
      id: 'boss',
      name: 'Forest Boss',
      level: 3,
      isBoss: true,
      expReward: 40,
      goldReward: 20,
      stats: CombatStats(
        maxHp: 35,
        atk: 6,
        def: 1,
        attackSpeed: 1.0,
        moveSpeed: 2.0,
        attackRange: 1.4,
      ),
    ),
  },
  revive: const ReviveConfig(),
  progression: _progression,
  difficulty: const DifficultyConfig(),
  items: const {
    'slime_gel': ItemDefinition(
      id: 'slime_gel',
      name: 'Slime Gel',
      category: ItemCategory.material,
      maxStack: 999,
    ),
  },
  lootTables: const {
    'slime_loot': LootTable(
      id: 'slime_loot',
      entries: [
        LootEntry(
          itemId: 'slime_gel',
          chance: 1.0,
          minQuantity: 1,
          maxQuantity: 1,
        ),
      ],
    ),
  },
  dungeons: {
    'dungeon_1': _makeSimpleDungeon(
      id: 'dungeon_1',
      name: 'Forest Alpha',
      order: 1,
      recommendedLevel: 1,
    ),
    'dungeon_2': _makeSimpleDungeon(
      id: 'dungeon_2',
      name: 'Cavern Beta',
      order: 2,
      unlockRequiresDungeonId: 'dungeon_1',
      recommendedLevel: 10,
    ),
    'ascension_trial': _makeSimpleDungeon(
      id: 'ascension_trial',
      name: 'Ascension Trial',
      order: 3,
      kind: DungeonKind.ascension,
      unlockRequiresDungeonId: 'dungeon_2',
      baseDungeonId: 'dungeon_1',
      recommendedLevel: 25,
    ),
  },
);

void main() {
  group('M8 Stage 4 — Multi-Dungeon Progression & Offline Rules', () {
    const service = OfflineProgressionService();

    test('DungeonProgressionService membuka berurutan per siklus dan menentukan target default Auto Farming', () {
      final config = _multiDungeonConfig();
      final progression = DungeonProgressionService(config.difficulty);
      final dungeons = config.dungeons.values.toList();

      const rank0 = CycleProgress(ascensionRank: 0);
      final emptyProgress = <String, DungeonProgressSnapshot>{};

      expect(
        progression.isUnlocked(
          config.dungeons['dungeon_1']!,
          rank0,
          emptyProgress,
          allDungeons: dungeons,
        ),
        isTrue,
      );
      expect(
        progression.isUnlocked(
          config.dungeons['dungeon_2']!,
          rank0,
          emptyProgress,
          allDungeons: dungeons,
        ),
        isFalse,
      );
      expect(
        progression.resolveFarmDungeonId(
          dungeons: dungeons,
          cycle: rank0,
          progresses: emptyProgress,
        ),
        isNull,
      );

      // Clear dungeon_1 pada rank 0 -> dungeon_2 terbuka & farm default ke dungeon_1.
      final clearedD1Rank0 = {
        'dungeon_1': const DungeonProgressSnapshot(
          currentDungeonId: 'dungeon_1',
          clearsCount: 2,
          clearedInCycleRank: 0,
        ),
      };
      expect(
        progression.isUnlocked(
          config.dungeons['dungeon_2']!,
          rank0,
          clearedD1Rank0,
          allDungeons: dungeons,
        ),
        isTrue,
      );
      expect(
        progression.resolveFarmDungeonId(
          dungeons: dungeons,
          cycle: rank0,
          progresses: clearedD1Rank0,
        ),
        'dungeon_1',
      );

      // Saat siklus naik ke rank 1: clearsCount 2 dari rank 0 TIDAK menganggap dungeon_1 selesai di rank 1.
      const rank1 = CycleProgress(ascensionRank: 1);
      expect(
        progression.isUnlocked(
          config.dungeons['dungeon_2']!,
          rank1,
          clearedD1Rank0,
          allDungeons: dungeons,
        ),
        isFalse,
      );
      expect(
        progression.resolveFarmDungeonId(
          dungeons: dungeons,
          cycle: rank1,
          progresses: clearedD1Rank0,
        ),
        isNull,
      );

      // Selesaikan dungeon_1 dan dungeon_2 di rank 1 -> default farm memilih dungeon_2 (order tertinggi).
      final clearedBothRank1 = {
        'dungeon_1': const DungeonProgressSnapshot(
          currentDungeonId: 'dungeon_1',
          clearsCount: 3,
          clearedInCycleRank: 1,
        ),
        'dungeon_2': const DungeonProgressSnapshot(
          currentDungeonId: 'dungeon_2',
          clearsCount: 1,
          clearedInCycleRank: 1,
        ),
      };
      expect(
        progression.resolveFarmDungeonId(
          dungeons: dungeons,
          cycle: rank1,
          progresses: clearedBothRank1,
        ),
        'dungeon_2',
      );
    });

    test('Auto Farming menolak dungeon siklus lama maupun ascension, dan berjalan pada dungeon normal siklus aktif', () {
      final config = _multiDungeonConfig();
      const startMs = 1000000;
      final endMs = startMs + const Duration(minutes: 10).inMilliseconds;

      // 1) clearsCount > 0 tapi clearedInCycleRank = 0 pada siklus rank 1 -> ditolak.
      final staleRes = service.process(
        character: PlayerCharacter(config: config.progression),
        inventory: Inventory(definitions: config.items),
        config: config,
        session: const GameSessionSnapshot(lastSavedAtMs: startMs),
        nowMs: endMs,
        cycleProgress: const CycleProgress(ascensionRank: 1),
        offlineActivity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.configured,
          selectedDungeonId: 'dungeon_1',
          simulationSeed: 10,
        ),
        dungeonProgresses: const {
          'dungeon_1': DungeonProgressSnapshot(
            currentDungeonId: 'dungeon_1',
            clearsCount: 3,
            clearedInCycleRank: 0,
          ),
        },
      );
      expect(staleRes.status, OfflineProgressionStatus.noEligibleEncounter);
      expect(staleRes.hasRewards, isFalse);

      // 2) Dungeon bertipe ascension -> selalu ditolak meski clearedInCycleRank == cycleRank.
      final ascRes = service.process(
        character: PlayerCharacter(config: config.progression),
        inventory: Inventory(definitions: config.items),
        config: config,
        session: const GameSessionSnapshot(lastSavedAtMs: startMs),
        nowMs: endMs,
        cycleProgress: const CycleProgress(ascensionRank: 1),
        offlineActivity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.configured,
          selectedDungeonId: 'ascension_trial',
          simulationSeed: 10,
        ),
        dungeonProgresses: const {
          'ascension_trial': DungeonProgressSnapshot(
            currentDungeonId: 'ascension_trial',
            clearsCount: 1,
            clearedInCycleRank: 1,
          ),
        },
      );
      expect(ascRes.status, OfflineProgressionStatus.noEligibleEncounter);
      expect(ascRes.hasRewards, isFalse);

      // 3) dungeon_2 selesai di rank 1 -> Auto Farming berjalan, summary membawa cycleRank: 1.
      final strongChar = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 10),
      );
      final validRes = service.process(
        character: strongChar,
        inventory: Inventory(definitions: config.items),
        config: config,
        session: const GameSessionSnapshot(lastSavedAtMs: startMs),
        nowMs: endMs,
        cycleProgress: const CycleProgress(ascensionRank: 1),
        offlineActivity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.configured,
          selectedDungeonId: 'dungeon_2',
          simulationSeed: 10,
        ),
        dungeonProgresses: const {
          'dungeon_2': DungeonProgressSnapshot(
            currentDungeonId: 'dungeon_2',
            clearsCount: 1,
            clearedInCycleRank: 1,
          ),
        },
      );
      expect(validRes.status, OfflineProgressionStatus.applied);
      expect(validRes.runsCompleted, greaterThan(0));
      expect(validRes.updatedDungeonProgress?.currentDungeonId, 'dungeon_2');
      expect(validRes.updatedDungeonProgress?.clearedInCycleRank, 1);
      expect(validRes.updatedOfflineActivity?.pendingSummary?.cycleRank, 1);
    });

    test('Continue Dungeon pada ascension dungeon memaksa fallback Pause Progression tanpa reward', () {
      final config = _multiDungeonConfig();
      const startMs = 2000000;
      final endMs = startMs + const Duration(minutes: 20).inMilliseconds;

      final res = service.process(
        character: PlayerCharacter(config: config.progression),
        inventory: Inventory(definitions: config.items),
        config: config,
        session: const GameSessionSnapshot(lastSavedAtMs: startMs),
        nowMs: endMs,
        cycleProgress: const CycleProgress(ascensionRank: 1),
        offlineActivity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.continueDungeon,
          state: OfflineActivityState.configured,
          selectedDungeonId: 'ascension_trial',
          activeRunId: 'run_asc_1',
        ),
        activeDungeonSession: const ActiveDungeonSessionSnapshot(
          runId: 'run_asc_1',
          dungeonId: 'ascension_trial',
          currentRoomId: 'ascension_trial_r1',
          currentRoomIndex: 0,
          status: DungeonSessionStatus.inProgress,
        ),
      );

      expect(res.status, OfflineProgressionStatus.noEligibleEncounter);
      expect(res.hasRewards, isFalse);
      expect(
        res.updatedOfflineActivity?.mode,
        OfflineActivityMode.pauseProgression,
      );
      expect(res.updatedOfflineActivity?.state, OfflineActivityState.inactive);
      expect(res.updatedOfflineActivity?.pendingSummary?.cycleRank, 1);
      expect(
        res.updatedOfflineActivity?.pendingSummary?.failureReason,
        isNotNull,
      );

      // Guard langsung pada OfflineDungeonRunner.
      final char = PlayerCharacter(config: config.progression);
      final inv = Inventory(definitions: config.items);
      final outcome = const OfflineDungeonRunner().runBatch(
        OfflineDungeonRunRequest(
          mode: OfflineActivityMode.continueDungeon,
          character: char,
          inventory: inv,
          config: config,
          rewardProcessor: RewardProcessor(
            character: char,
            inventory: inv,
            items: config.items,
            lootTables: config.lootTables,
            equipmentFactory: const EquipmentFactory(EquipmentConfig()),
          ),
          dungeonId: 'ascension_trial',
          dungeonProgress: const DungeonProgressSnapshot(
            currentDungeonId: 'ascension_trial',
          ),
          activeDungeonSession: const ActiveDungeonSessionSnapshot(
            runId: 'run_asc_1',
            dungeonId: 'ascension_trial',
            currentRoomId: 'ascension_trial_r1',
            currentRoomIndex: 0,
            status: DungeonSessionStatus.inProgress,
          ),
          timeWindow: OfflineTimeWindow(
            status: OfflineTimeValidationStatus.valid,
            anchorTimestampMs: startMs,
            nowMs: endMs,
            rawElapsed: const Duration(minutes: 10),
            effectiveElapsed: const Duration(minutes: 10),
            cappedAtMaxDuration: false,
            previouslyProcessedMs: 0,
            remainingBudgetMs: 28800000,
            endTimestampMs: endMs,
            eventId: 'offline:asc:test',
            newLastOfflineClaimAtMs: endMs,
          ),
          simulationSeed: 1,
          cycleRank: 1,
        ),
      );
      expect(outcome.stopReason, OfflineDungeonStopReason.invalidSetup);
      expect(outcome.runsAttempted, 0);
    });

    test('GameSessionCoordinator memulihkan activeDungeonSession & progres dungeon kedua terpisah dari dungeon pertama', () async {
      final config = _multiDungeonConfig();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      var clockMs = 1000000;
      final repo = DriftPlayerSaveRepository(db: db, config: config);
      final coord1 = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => clockMs,
      );

      final boot1 = await coord1.loadAndProcessOffline();
      expect(boot1.isFirstLaunch, isTrue);
      expect(boot1.cycleProgress.lastNormalDungeonId, 'dungeon_1');

      // Simpan dungeon_1 selesai + pemain sedang di dalam dungeon_2 room 2.
      clockMs += 5000;
      const d1Progress = DungeonProgressSnapshot(
        currentDungeonId: 'dungeon_1',
        currentRoomId: 'dungeon_1_r2',
        currentRoomIndex: 1,
        highestClearedRoomIndex: 1,
        clearsCount: 2,
        clearedInCycleRank: 0,
      );
      const d2Progress = DungeonProgressSnapshot(
        currentDungeonId: 'dungeon_2',
        currentRoomId: 'dungeon_2_r2',
        currentRoomIndex: 1,
        highestClearedRoomIndex: 0,
        clearsCount: 0,
        clearedInCycleRank: -1,
      );
      await coord1.saveFromRuntime(
        character: boot1.character,
        inventory: boot1.inventory,
        dungeon: d2Progress,
        dungeonProgresses: {'dungeon_1': d1Progress, 'dungeon_2': d2Progress},
        cycleProgress: const CycleProgress(
          ascensionRank: 0,
          lastNormalDungeonId: 'dungeon_2',
        ),
        rewardProcessor: boot1.rewardProcessor,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: clockMs,
        currentHp: 140,
        activeDungeonSession: const ActiveDungeonSessionSnapshot(
          runId: 'run_d2_active',
          dungeonId: 'dungeon_2',
          currentRoomId: 'dungeon_2_r2',
          currentRoomIndex: 1,
          status: DungeonSessionStatus.inProgress,
          clearedRoomIds: {'dungeon_2_r1'},
        ),
      );

      // Restart coordinator baru.
      clockMs += 60000;
      final coord2 = GameSessionCoordinator(
        repository: DriftPlayerSaveRepository(db: db, config: config),
        config: config,
        nowMs: () => clockMs,
      );
      final boot2 = await coord2.loadAndProcessOffline();

      expect(boot2.hasRecoverableDungeonSession, isTrue);
      expect(boot2.activeDungeonSession?.dungeonId, 'dungeon_2');
      expect(boot2.activeDungeonSession?.currentRoomId, 'dungeon_2_r2');
      expect(boot2.dungeon.currentDungeonId, 'dungeon_2');
      expect(boot2.cycleProgress.lastNormalDungeonId, 'dungeon_2');
      // Progres dungeon_1 tidak tertimpa dungeon_2.
      expect(boot2.dungeonProgresses['dungeon_1']?.clearsCount, 2);
      expect(boot2.dungeonProgresses['dungeon_1']?.clearedInCycleRank, 0);
      expect(boot2.dungeonProgresses['dungeon_2']?.clearsCount, 0);
      expect(boot2.dungeonProgresses['dungeon_2']?.clearedInCycleRank, -1);
    });

    test('Continue Dungeon normal menetapkan clearedInCycleRank sesuai cycleRank dan menambah lifetime clearsCount', () {
      final config = _multiDungeonConfig();
      const startMs = 3000000;
      final endMs = startMs + const Duration(minutes: 10).inMilliseconds;
      final char = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 12),
      );
      final inv = Inventory(definitions: config.items);
      final res = service.process(
        character: char,
        inventory: inv,
        config: config,
        session: const GameSessionSnapshot(lastSavedAtMs: startMs),
        nowMs: endMs,
        cycleProgress: const CycleProgress(ascensionRank: 2),
        offlineActivity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.continueDungeon,
          state: OfflineActivityState.configured,
          selectedDungeonId: 'dungeon_1',
          activeRunId: 'run_d1_r2',
          simulationSeed: 21,
        ),
        activeDungeonSession: const ActiveDungeonSessionSnapshot(
          runId: 'run_d1_r2',
          dungeonId: 'dungeon_1',
          currentRoomId: 'dungeon_1_r2',
          currentRoomIndex: 1,
          status: DungeonSessionStatus.inProgress,
          clearedRoomIds: {'dungeon_1_r1'},
        ),
        dungeonProgresses: const {
          'dungeon_1': DungeonProgressSnapshot(
            currentDungeonId: 'dungeon_1',
            clearsCount: 2,
            clearedInCycleRank: 0,
          ),
        },
      );

      expect(res.status, OfflineProgressionStatus.applied);
      expect(res.runsCompleted, 1);
      expect(res.updatedDungeonProgress?.currentDungeonId, 'dungeon_1');
      expect(res.updatedDungeonProgress?.clearsCount, 3);
      expect(res.updatedDungeonProgress?.clearedInCycleRank, 2);
      expect(res.updatedOfflineActivity?.pendingSummary?.cycleRank, 2);
    });
  });
}
