import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/player_status.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const layout = <String>[
    '#########',
    '#.......#',
    '#.......#',
    '#.......#',
    '#########',
  ];

  const dungeon = DungeonDefinition(
    id: 'forgotten_forest',
    name: 'Forgotten Forest',
    biome: 'forgotten_forest',
    startRoomId: 'forest_entrance',
    roomOrder: ['forest_entrance', 'ancient_path', 'ancient_heart'],
    rooms: {
      'forest_entrance': RoomDefinition(
        id: 'forest_entrance',
        dungeonId: 'forgotten_forest',
        name: 'Forest Entrance',
        type: RoomType.normal,
        mapRef: 'map_1',
        layout: layout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(7, 2),
        spawns: [
          RoomSpawnConfig(
            id: 's1',
            monsterId: 'aether_slime',
            position: GridPoint(4, 2),
          ),
        ],
        completionCondition: RoomCompletionCondition(),
        nextRoomIds: ['ancient_path'],
        reward: RoomRewardConfig(expReward: 15, goldReward: 5),
      ),
      'ancient_path': RoomDefinition(
        id: 'ancient_path',
        dungeonId: 'forgotten_forest',
        name: 'Ancient Path',
        type: RoomType.normal,
        mapRef: 'map_2',
        layout: layout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(7, 2),
        spawns: [
          RoomSpawnConfig(
            id: 's2',
            monsterId: 'aether_slime',
            position: GridPoint(5, 2),
          ),
        ],
        completionCondition: RoomCompletionCondition(),
        nextRoomIds: ['ancient_heart'],
      ),
      'ancient_heart': RoomDefinition(
        id: 'ancient_heart',
        dungeonId: 'forgotten_forest',
        name: 'Ancient Heart',
        type: RoomType.boss,
        mapRef: 'map_3',
        layout: layout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(7, 2),
        spawns: [
          RoomSpawnConfig(
            id: 'b1',
            monsterId: 'aether_slime',
            position: GridPoint(6, 2),
            isBoss: true,
          ),
        ],
        completionCondition: RoomCompletionCondition(
          type: RoomCompletionConditionType.defeatBoss,
        ),
        nextRoomIds: [],
      ),
    },
  );

  const config = GameConfig(
    monsters: {
      'aether_slime': EnemyDefinition(
        id: 'aether_slime',
        name: 'Aether Slime',
        level: 1,
        stats: CombatStats(maxHp: 30, atk: 5, def: 0),
      ),
    },
    revive: ReviveConfig(),
    progression: ProgressionConfig(
      maxLevel: 30,
      expBase: 100,
      expGrowth: 1.4,
      baseStats: CombatStats(maxHp: 120, atk: 20, def: 2),
      perLevel: LevelGrowth(hp: 15, atk: 3, def: 1),
    ),
    items: {},
    lootTables: {},
    dungeonCompletion: DungeonCompletionReward(expReward: 120, goldReward: 50),
    skills: {
      'power_strike': SkillDefinition(
        id: 'power_strike',
        name: 'Power Strike',
        type: SkillType.active,
        effect: SkillEffectType.damage,
        damageType: SkillDamageType.physical,
        unlockLevel: 1,
        cooldownSeconds: 5,
        baseValue: 1.5,
      ),
    },
    dungeons: {'forgotten_forest': dungeon},
  );

  group('Stage 5 — Dungeon Session Persistence & Recovery', () {
    test('session inProgress disimpan ke GameSessions & DungeonProgresses dan dipulihkan ke awal room terakhir', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      var clock = 100000;
      final repo = DriftPlayerSaveRepository(db: db, config: config);
      final coord1 = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => clock,
      );

      final character = PlayerCharacter(
        config: config.progression,
        skillCatalog: config.skills,
      );
      final inventory = Inventory(definitions: config.items);
      final rp = RewardProcessor(
        character: character,
        inventory: inventory,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
        claimedEventIds: {'room_clear:run_active_1:forest_entrance'},
      );

      await coord1.saveFromRuntime(
        character: character,
        inventory: inventory,
        dungeon: const DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          currentRoomId: 'ancient_path',
          currentRoomIndex: 1,
          highestClearedRoomIndex: 0,
          clearsCount: 0,
          rewardState: DungeonRewardStateSnapshot(
            lastRunId: 'run_active_1',
            completionRewardClaimed: false,
            claimedRoomRewardIds: {'forest_entrance'},
          ),
        ),
        rewardProcessor: rp,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: clock,
        currentHp: 85,
        skillCooldownTicks: {'power_strike': 45},
        activeDungeonSession: const ActiveDungeonSessionSnapshot(
          runId: 'run_active_1',
          dungeonId: 'forgotten_forest',
          currentRoomId: 'ancient_path',
          currentRoomIndex: 1,
          status: DungeonSessionStatus.inProgress,
          clearedRoomIds: {'forest_entrance'},
          completionRewardClaimed: false,
          reviveCooldownTicks: 1200,
          playerStatus: PlayerStatus.alive,
        ),
      );

      // Restart langsung pada timestamp yang sama -> tidak ada offline reward.
      final coord2 = GameSessionCoordinator(
        repository: DriftPlayerSaveRepository(db: db, config: config),
        config: config,
        nowMs: () => clock,
      );
      final loaded = await coord2.loadAndProcessOffline();
      expect(loaded.hasRecoverableDungeonSession, isTrue);
      expect(loaded.activeDungeonSession!.runId, 'run_active_1');
      expect(loaded.activeDungeonSession!.reviveCooldownTicks, 1200);
      expect(loaded.recoveredHp, 85);
      expect(loaded.recoveredSkillCooldownTicks['power_strike'], 45);
      expect(
        loaded.claimedEventIds,
        contains('room_clear:run_active_1:forest_entrance'),
      );
      expect(
        loaded.dungeon.rewardState.claimedRoomRewardIds,
        contains('forest_entrance'),
      );

      final manager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: EncounterTracker(monsterCatalog: config.monsters),
      );
      final restored = manager.restoreSession(loaded.activeDungeonSession!);
      expect(restored, isNotNull);
      expect(restored!.runId, 'run_active_1');
      expect(restored.currentRoomId, 'ancient_path');
      expect(restored.clearedRoomIds, {'forest_entrance'});
      expect(manager.activeRoom!.id, 'ancient_path');
      // Posisi awal recovery ada di entryPosition room terakhir, bukan mid-fight.
      expect(manager.activeRoom!.entryPosition, const GridPoint(1, 2));
    });

    test('session roomCompleted dipulihkan langsung ke room berikutnya dan tidak mengulang room selesai', () async {
      final manager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: EncounterTracker(monsterCatalog: config.monsters),
      );

      const snapshot = ActiveDungeonSessionSnapshot(
        runId: 'run_transition_cut',
        dungeonId: 'forgotten_forest',
        currentRoomId: 'forest_entrance',
        currentRoomIndex: 0,
        status: DungeonSessionStatus.roomCompleted,
        clearedRoomIds: {'forest_entrance'},
      );

      final restored = manager.restoreSession(snapshot);
      expect(restored, isNotNull);
      expect(restored!.currentRoomId, 'ancient_path');
      expect(restored.currentRoomIndex, 1);
      expect(restored.clearedRoomIds, {'forest_entrance'});
    });

    test('aplikasi ditutup saat Downed memulihkan HP 30% dan mengonsumsi cooldown revive tanpa revive ganda', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      const now = 200000;
      final repo = DriftPlayerSaveRepository(db: db, config: config);
      final coord = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => now,
      );

      final c = PlayerCharacter(config: config.progression);
      final inv = Inventory(definitions: config.items);
      final rp = RewardProcessor(
        character: c,
        inventory: inv,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      await coord.saveFromRuntime(
        character: c,
        inventory: inv,
        dungeon: const DungeonProgressSnapshot(currentRoomId: 'ancient_path'),
        rewardProcessor: rp,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: now,
        currentHp: 0,
        activeDungeonSession: const ActiveDungeonSessionSnapshot(
          runId: 'run_downed_close',
          dungeonId: 'forgotten_forest',
          currentRoomId: 'ancient_path',
          currentRoomIndex: 1,
          status: DungeonSessionStatus.inProgress,
          reviveCooldownTicks: 0,
          playerStatus: PlayerStatus.downed,
        ),
      );

      final loaded = await coord.loadAndProcessOffline();
      expect(loaded.hasRecoverableDungeonSession, isTrue);
      // 30% dari maxHp 120 = 36, dan cooldown 90 detik * 20 tick = 1800.
      expect(loaded.recoveredHp, 36);
      expect(loaded.activeDungeonSession!.reviveCooldownTicks, 1800);
      expect(loaded.activeDungeonSession!.playerStatus, PlayerStatus.alive);
    });

    test('completed dan failed session tidak dipulihkan ke dungeon melainkan diarahkan ke Town', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      const now = 300000;
      final repo = DriftPlayerSaveRepository(db: db, config: config);
      final coord = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => now,
      );

      final c = PlayerCharacter(config: config.progression);
      final inv = Inventory(definitions: config.items);
      final rp = RewardProcessor(
        character: c,
        inventory: inv,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
        claimedEventIds: {'dungeon_clear:run_done'},
      );

      for (final status in [
        DungeonSessionStatus.completed,
        DungeonSessionStatus.failed,
      ]) {
        await coord.saveFromRuntime(
          character: c,
          inventory: inv,
          dungeon: DungeonProgressSnapshot(
            currentDungeonId: 'forgotten_forest',
            currentRoomId: 'ancient_heart',
            currentRoomIndex: 2,
            highestClearedRoomIndex: status == DungeonSessionStatus.completed
                ? 2
                : 1,
            clearsCount: status == DungeonSessionStatus.completed ? 1 : 0,
          ),
          rewardProcessor: rp,
          autoSkillEnabled: true,
          lastOfflineClaimAtMs: now,
          activeDungeonSession: ActiveDungeonSessionSnapshot(
            runId: 'run_${status.name}',
            dungeonId: 'forgotten_forest',
            currentRoomId: 'ancient_heart',
            currentRoomIndex: 2,
            status: status,
            completionRewardClaimed: status == DungeonSessionStatus.completed,
          ),
        );

        final loaded = await coord.loadAndProcessOffline();
        expect(loaded.hasRecoverableDungeonSession, isFalse);
        expect(loaded.activeDungeonSession!.status, status);
        final manager = DungeonManager(dungeons: config.dungeons);
        expect(manager.restoreSession(loaded.activeDungeonSession!), isNull);
      }
    });

    test('sessionDataJson / rewardStateJson rusak atau merujuk room hilang ditangani aman tanpa crash', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      final warnings = <String>[];
      final repo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        onRecoveryWarning: warnings.add,
      );
      final coord = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => 400000,
      );
      final c = PlayerCharacter(config: config.progression);
      final inv = Inventory(definitions: config.items);
      final rp = RewardProcessor(
        character: c,
        inventory: inv,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      await coord.saveFromRuntime(
        character: c,
        inventory: inv,
        dungeon: const DungeonProgressSnapshot(),
        rewardProcessor: rp,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: 400000,
      );

      // Rusak JSON sessionDataJson & rewardStateJson langsung di SQLite.
      await db.customUpdate(
        "UPDATE game_sessions SET session_data_json = '{corrupt_json' WHERE id = 'default_player'",
        updates: {db.gameSessions},
      );
      await db.customUpdate(
        "UPDATE dungeon_progresses SET reward_state_json = 'not_json'",
        updates: {db.dungeonProgresses},
      );

      final loadedCorrupt = await coord.loadAndProcessOffline();
      expect(loadedCorrupt.loadError, isNull);
      expect(loadedCorrupt.hasRecoverableDungeonSession, isFalse);
      expect(warnings, isNotEmpty);

      // Referensi room yang sudah dihapus dari konfigurasi.
      warnings.clear();
      await db.customUpdate(
        "UPDATE game_sessions SET session_data_json = "
        "'{\"activeDungeonSession\":{\"runId\":\"r1\",\"dungeonId\":\"forgotten_forest\",\"currentRoomId\":\"deleted_room\",\"currentRoomIndex\":0,\"status\":\"inProgress\"}}' "
        "WHERE id = 'default_player'",
        updates: {db.gameSessions},
      );

      final loadedMissingRoom = await coord.loadAndProcessOffline();
      expect(loadedMissingRoom.hasRecoverableDungeonSession, isFalse);
      expect(warnings.any((w) => w.contains('deleted_room')), isTrue);
    });

    test('normalisasi Downed saat boot langsung dipersistensikan ke SQLite bahkan tanpa reward offline', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      const now = 500000;
      final repo = DriftPlayerSaveRepository(db: db, config: config);
      final coord1 = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => now,
      );

      final c = PlayerCharacter(config: config.progression);
      final inv = Inventory(definitions: config.items);
      final rp = RewardProcessor(
        character: c,
        inventory: inv,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      await coord1.saveFromRuntime(
        character: c,
        inventory: inv,
        dungeon: const DungeonProgressSnapshot(currentRoomId: 'ancient_path'),
        rewardProcessor: rp,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: now,
        currentHp: 0,
        activeDungeonSession: const ActiveDungeonSessionSnapshot(
          runId: 'run_downed_persisted',
          dungeonId: 'forgotten_forest',
          currentRoomId: 'ancient_path',
          currentRoomIndex: 1,
          status: DungeonSessionStatus.inProgress,
          reviveCooldownTicks: 0,
          playerStatus: PlayerStatus.downed,
        ),
        offlineActivity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.continueDungeon,
          state: OfflineActivityState.configured,
          selectedDungeonId: 'forgotten_forest',
          activeRunId: 'run_downed_persisted',
        ),
      );

      // Load langsung pada timestamp sama -> offlineResult.hasRewards == false,
      // namun hasil normalisasi Downed tetap langsung tersimpan ke DB.
      final loaded = await coord1.loadAndProcessOffline();
      expect(loaded.offlineResult.hasRewards, isFalse);
      expect(loaded.offlineActivity.mode, OfflineActivityMode.continueDungeon);

      final rawPersisted = await repo.loadSnapshot();
      expect(rawPersisted!.character.currentHp, 36);
      expect(
        rawPersisted.activeDungeonSession!.playerStatus,
        PlayerStatus.alive,
      );
      expect(rawPersisted.activeDungeonSession!.reviveCooldownTicks, 1800);
      expect(rawPersisted.offlineActivity.activeRunId, 'run_downed_persisted');
    });

    test('clock rollback tidak menurunkan high-water mark lastSavedAtMs pada save berikutnya', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      var clock = 1000000;
      final repo = DriftPlayerSaveRepository(db: db, config: config);
      final coord1 = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => clock,
      );

      final c = PlayerCharacter(config: config.progression);
      final inv = Inventory(definitions: config.items);
      final rp = RewardProcessor(
        character: c,
        inventory: inv,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      await coord1.saveFromRuntime(
        character: c,
        inventory: inv,
        dungeon: const DungeonProgressSnapshot(),
        rewardProcessor: rp,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: 1000000,
      );

      // Simulasikan jam perangkat dimundurkan ke masa lalu (300000 < 1000000).
      clock = 300000;
      final coord2 = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => clock,
      );
      final loaded = await coord2.loadAndProcessOffline();
      expect(
        loaded.offlineResult.status,
        OfflineProgressionStatus.invalidClock,
      );
      expect(loaded.session.lastSavedAtMs, 1000000);

      // Save runtime berikutnya pada jam mundur tidak boleh menurunkan lastSavedAtMs.
      await coord2.saveFromRuntime(
        character: loaded.character,
        inventory: loaded.inventory,
        dungeon: loaded.dungeon,
        rewardProcessor: loaded.rewardProcessor,
        autoSkillEnabled: loaded.session.autoSkillEnabled,
        lastOfflineClaimAtMs: loaded.offlineResult.newLastOfflineClaimAtMs,
      );

      final persisted = await repo.loadSnapshot();
      expect(persisted!.session.lastSavedAtMs, 1000000);
      expect(persisted.session.lastOfflineClaimAtMs, 1000000);
    });
  });
}
