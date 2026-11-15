import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:flutter_test/flutter_test.dart';

GameConfig _migrationTestConfig() {
  const layout = <String>['#####', '#...#', '#####'];
  return GameConfig(
    monsters: const {},
    revive: const ReviveConfig(),
    progression: const ProgressionConfig(
      maxLevel: 30,
      expBase: 50,
      expGrowth: 1.5,
      baseStats: CombatStats(
        maxHp: 120,
        atk: 15,
        def: 3,
        attackSpeed: 1.5,
        critRate: 0.1,
        critDamage: 1.5,
        moveSpeed: 4.0,
        attackRange: 1.5,
      ),
      perLevel: LevelGrowth(hp: 20, atk: 3, def: 1),
    ),
    items: const {
      'slime_gel': ItemDefinition(
        id: 'slime_gel',
        name: 'Slime Gel',
        category: ItemCategory.material,
        maxStack: 999,
      ),
      'rusty_sword': ItemDefinition(
        id: 'rusty_sword',
        name: 'Rusty Sword',
        category: ItemCategory.equipment,
        rarity: ItemRarity.common,
        equipment: EquipmentData(
          slot: EquipmentSlot.weapon,
          weaponType: 'sword',
          baseStats: EquipmentStats(atk: 5),
        ),
      ),
    },
    lootTables: const {},
    skills: const {
      'power_strike': SkillDefinition(
        id: 'power_strike',
        name: 'Power Strike',
        type: SkillType.active,
        maxLevel: 5,
        cooldownSeconds: 4.0,
      ),
    },
    specializations: const SpecializationConfig(
      definitions: {
        'vanguard': SpecializationDefinition(
          id: 'vanguard',
          name: 'Vanguard',
          bonus: EquipmentStats(hp: 20, atk: 4, def: 3),
        ),
      },
    ),
    dungeons: {
      'forgotten_forest': const DungeonDefinition(
        id: 'forgotten_forest',
        name: 'Forgotten Forest',
        biome: 'forest',
        kind: DungeonKind.normal,
        order: 1,
        recommendedLevel: 1,
        startRoomId: 'r1',
        roomOrder: ['r1'],
        completionReward: DungeonCompletionReward(
          expReward: 20,
          goldReward: 10,
        ),
        rooms: {
          'r1': RoomDefinition(
            id: 'r1',
            dungeonId: 'forgotten_forest',
            name: 'Entrance',
            type: RoomType.normal,
            mapRef: 'r1',
            layout: layout,
            entryPosition: GridPoint(1, 1),
            exitPosition: GridPoint(3, 1),
            completionCondition: RoomCompletionCondition(
              type: RoomCompletionConditionType.reachExit,
            ),
            spawns: [],
          ),
        },
      ),
      'ancient_crypt': const DungeonDefinition(
        id: 'ancient_crypt',
        name: 'Ancient Crypt',
        biome: 'crypt',
        kind: DungeonKind.normal,
        order: 2,
        recommendedLevel: 8,
        unlockRequiresDungeonId: 'forgotten_forest',
        startRoomId: 'c1',
        roomOrder: ['c1'],
        completionReward: DungeonCompletionReward(
          expReward: 50,
          goldReward: 30,
        ),
        rooms: {
          'c1': RoomDefinition(
            id: 'c1',
            dungeonId: 'ancient_crypt',
            name: 'Crypt Gate',
            type: RoomType.normal,
            mapRef: 'c1',
            layout: layout,
            entryPosition: GridPoint(1, 1),
            exitPosition: GridPoint(3, 1),
            completionCondition: RoomCompletionCondition(
              type: RoomCompletionConditionType.reachExit,
            ),
            spawns: [],
          ),
        },
      ),
      'ascension_forest': const DungeonDefinition(
        id: 'ascension_forest',
        name: 'Ascension: Forgotten Forest',
        biome: 'forest',
        kind: DungeonKind.ascension,
        order: 3,
        recommendedLevel: 25,
        unlockRequiresDungeonId: 'ancient_crypt',
        baseDungeonId: 'forgotten_forest',
        startRoomId: 'a1',
        roomOrder: ['a1'],
        rooms: {
          'a1': RoomDefinition(
            id: 'a1',
            dungeonId: 'ascension_forest',
            name: 'Trial Arena',
            type: RoomType.boss,
            mapRef: 'a1',
            layout: layout,
            entryPosition: GridPoint(1, 1),
            exitPosition: GridPoint(3, 1),
            completionCondition: RoomCompletionCondition(
              type: RoomCompletionConditionType.defeatBoss,
            ),
            spawns: [],
          ),
        },
      ),
    },
  );
}

void main() {
  group('AppDatabase v3 schema & migration', () {
    test('onCreate v3 membuat cycle_progresses, kolom cleared_in_cycle_rank default -1, dan CHECK ascension_rank', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, 8);
      await db.initialize();

      final dpCols = await db
          .customSelect("PRAGMA table_info('dungeon_progresses')")
          .get();
      expect(
        dpCols.map((r) => r.data['name']),
        contains('cleared_in_cycle_rank'),
      );

      final cpCols = await db
          .customSelect("PRAGMA table_info('cycle_progresses')")
          .get();
      expect(
        cpCols.map((r) => r.data['name']),
        containsAll([
          'player_id',
          'ascension_rank',
          'highest_ascension_rank',
          'last_normal_dungeon_id',
          'updated_at_ms',
        ]),
      );

      await db
          .into(db.players)
          .insert(
            PlayersCompanion.insert(
              id: 'p1',
              level: 1,
              currentExp: 0,
              gold: 0,
              baseStatsJson: '{}',
              lastSavedAtMs: 1000,
            ),
          );
      await db
          .into(db.dungeonProgresses)
          .insert(
            DungeonProgressesCompanion.insert(
              playerId: 'p1',
              dungeonId: 'forgotten_forest',
              currentRoomId: 'r1',
              currentRoomIndex: 0,
              highestClearedRoomIndex: -1,
              clearsCount: 0,
            ),
          );
      final insertedDp = await db.select(db.dungeonProgresses).getSingle();
      expect(insertedDp.clearedInCycleRank, -1);

      await expectLater(
        () => db
            .into(db.cycleProgresses)
            .insert(
              CycleProgressesCompanion.insert(
                playerId: 'p1',
                ascensionRank: const Value(-1),
                updatedAtMs: 1000,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('migrasi v2 ke v3 menjaga seluruh data pemain tanpa loss dan mengisi cleared_in_cycle_rank', () async {
      final tempDir = Directory.systemTemp.createTempSync('echoes_v2_to_v3_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final dbFile = File('${tempDir.path}/legacy_v2.sqlite');

      final seedDb = NativeDatabase(
        dbFile,
        setup: (raw) {
          raw.execute('PRAGMA foreign_keys = ON;');
          raw.execute(
            'CREATE TABLE game_settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);',
          );
          raw.execute(
            'CREATE TABLE players ('
            'id TEXT NOT NULL PRIMARY KEY, '
            'level INTEGER NOT NULL, '
            'current_exp INTEGER NOT NULL, '
            'gold INTEGER NOT NULL, '
            'current_hp INTEGER NULL, '
            'active_specialization_id TEXT NULL, '
            'base_stats_json TEXT NOT NULL, '
            'equipment_counter INTEGER NOT NULL DEFAULT 0, '
            'last_saved_at_ms INTEGER NOT NULL, '
            'CHECK (level >= 1), CHECK (current_exp >= 0), CHECK (gold >= 0));',
          );
          raw.execute(
            'CREATE TABLE skill_progresses ('
            'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
            'skill_id TEXT NOT NULL, '
            'skill_level INTEGER NOT NULL, '
            'unlocked INTEGER NOT NULL, '
            'cooldown_ticks_remaining INTEGER NOT NULL DEFAULT 0, '
            'PRIMARY KEY (player_id, skill_id));',
          );
          raw.execute(
            'CREATE TABLE inventory_entries ('
            'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
            'item_id TEXT NOT NULL, '
            'quantity INTEGER NOT NULL, '
            'PRIMARY KEY (player_id, item_id));',
          );
          raw.execute(
            'CREATE TABLE equipment_instances ('
            'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
            'instance_id TEXT NOT NULL, '
            'definition_id TEXT NOT NULL, '
            'slot TEXT NOT NULL, '
            'rarity TEXT NOT NULL, '
            'rolled_stats_json TEXT NOT NULL, '
            'enhancement_level INTEGER NOT NULL DEFAULT 0, '
            'PRIMARY KEY (player_id, instance_id));',
          );
          raw.execute(
            'CREATE TABLE equipped_items ('
            'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
            'slot TEXT NOT NULL, '
            'equipment_instance_id TEXT NOT NULL, '
            'PRIMARY KEY (player_id, slot));',
          );
          raw.execute(
            'CREATE TABLE dungeon_progresses ('
            'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
            'dungeon_id TEXT NOT NULL, '
            'current_room_id TEXT NOT NULL, '
            'current_room_index INTEGER NOT NULL, '
            'highest_cleared_room_index INTEGER NOT NULL, '
            'clears_count INTEGER NOT NULL, '
            "reward_state_json TEXT NOT NULL DEFAULT '{}', "
            'PRIMARY KEY (player_id, dungeon_id));',
          );
          raw.execute(
            'CREATE TABLE game_sessions ('
            'id TEXT NOT NULL PRIMARY KEY, '
            'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
            'last_active_at_ms INTEGER NOT NULL, '
            'last_saved_at_ms INTEGER NOT NULL, '
            'last_offline_claim_at_ms INTEGER NOT NULL, '
            'auto_skill_enabled INTEGER NOT NULL, '
            "session_data_json TEXT NOT NULL DEFAULT '{}');",
          );
          raw.execute(
            'CREATE TABLE claimed_rewards ('
            'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
            'event_id TEXT NOT NULL, '
            'claimed_at_ms INTEGER NOT NULL, '
            'PRIMARY KEY (player_id, event_id));',
          );

          // Seed realistic v2 save state
          raw.execute(
            "INSERT INTO game_settings (key, value) VALUES ('auto_skill', 'true');",
          );
          raw.execute(
            "INSERT INTO players (id, level, current_exp, gold, current_hp, active_specialization_id, base_stats_json, equipment_counter, last_saved_at_ms) "
            "VALUES ('default_player', 7, 120, 450, 85, 'vanguard', '{}', 3, 50000);",
          );
          raw.execute(
            "INSERT INTO skill_progresses (player_id, skill_id, skill_level, unlocked, cooldown_ticks_remaining) "
            "VALUES ('default_player', 'power_strike', 2, 1, 0);",
          );
          raw.execute(
            "INSERT INTO inventory_entries (player_id, item_id, quantity) "
            "VALUES ('default_player', 'slime_gel', 9);",
          );
          raw.execute(
            "INSERT INTO equipment_instances (player_id, instance_id, definition_id, slot, rarity, rolled_stats_json, enhancement_level) "
            "VALUES ('default_player', 'eq_1', 'rusty_sword', 'weapon', 'common', '{\"atk\":6}', 1);",
          );
          raw.execute(
            "INSERT INTO equipped_items (player_id, slot, equipment_instance_id) "
            "VALUES ('default_player', 'weapon', 'eq_1');",
          );
          raw.execute(
            "INSERT INTO dungeon_progresses (player_id, dungeon_id, current_room_id, current_room_index, highest_cleared_room_index, clears_count, reward_state_json) "
            "VALUES ('default_player', 'forgotten_forest', 'r1', 0, 0, 3, '{}');",
          );
          raw.execute(
            "INSERT INTO dungeon_progresses (player_id, dungeon_id, current_room_id, current_room_index, highest_cleared_room_index, clears_count, reward_state_json) "
            "VALUES ('default_player', 'ancient_crypt', 'c1', 0, -1, 0, '{}');",
          );
          raw.execute(
            "INSERT INTO game_sessions (id, player_id, last_active_at_ms, last_saved_at_ms, last_offline_claim_at_ms, auto_skill_enabled, session_data_json) "
            "VALUES ('default_player', 'default_player', 50000, 50000, 50000, 0, '{}');",
          );
          raw.execute(
            "INSERT INTO claimed_rewards (player_id, event_id, claimed_at_ms) "
            "VALUES ('default_player', 'dungeon_clear:old_run', 40000);",
          );
          raw.execute('PRAGMA user_version = 2;');
        },
      );
      final v2Conn = DatabaseConnection(seedDb);
      await v2Conn.ensureOpen(_DummySchemaUser(2));
      await v2Conn.close();

      // Buka dengan AppDatabase v3
      final upgraded = AppDatabase(NativeDatabase(dbFile));
      addTearDown(upgraded.close);
      await upgraded.initialize();

      final config = _migrationTestConfig();
      final repo = DriftPlayerSaveRepository(db: upgraded, config: config);
      final loaded = await repo.loadSnapshot();
      expect(loaded, isNotNull);

      // Zero data loss across all player state
      expect(loaded!.character.progress.level, 7);
      expect(loaded.character.progress.currentExp, 120);
      expect(loaded.character.progress.gold, 450);
      expect(loaded.character.currentHp, 85);
      expect(loaded.character.specializationId, 'vanguard');
      expect(loaded.character.skillLevels['power_strike'], 2);
      expect(loaded.inventory.stacks['slime_gel'], 9);
      expect(loaded.inventory.equipmentCounter, 3);
      expect(loaded.character.equipped[EquipmentSlot.weapon]?.id, 'eq_1');
      expect(
        loaded.character.equipped[EquipmentSlot.weapon]?.rolledStats.atk,
        6,
      );
      expect(loaded.session.autoSkillEnabled, isFalse);
      expect(loaded.claimedEventIds, contains('dungeon_clear:old_run'));

      // CycleProgress default dan migrasi cleared_in_cycle_rank tepat
      expect(loaded.cycleProgress.ascensionRank, 0);
      expect(loaded.cycleProgress.lastNormalDungeonId, isNull);
      expect(loaded.dungeonProgresses['forgotten_forest']?.clearsCount, 3);
      expect(
        loaded.dungeonProgresses['forgotten_forest']?.clearedInCycleRank,
        0,
      );
      expect(loaded.dungeonProgresses['ancient_crypt']?.clearsCount, 0);
      expect(loaded.dungeonProgresses['ancient_crypt']?.clearedInCycleRank, -1);
      expect(loaded.isClearedInCurrentCycle('forgotten_forest'), isTrue);
      expect(loaded.isClearedInCurrentCycle('ancient_crypt'), isFalse);

      final settings = await upgraded.select(upgraded.gameSettings).get();
      expect(settings.single.value, 'true');
    });

    test('migrasi v1 langsung ke v3 berhasil tanpa duplikasi kolom dan menjaga game_settings', () async {
      final tempDir = Directory.systemTemp.createTempSync('echoes_v1_to_v3_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final dbFile = File('${tempDir.path}/legacy_v1.sqlite');

      final seedDb = NativeDatabase(
        dbFile,
        setup: (raw) {
          raw.execute(
            'CREATE TABLE game_settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);',
          );
          raw.execute(
            "INSERT INTO game_settings (key, value) VALUES ('music_volume', '0.5');",
          );
          raw.execute('PRAGMA user_version = 1;');
        },
      );
      final v1Conn = DatabaseConnection(seedDb);
      await v1Conn.ensureOpen(_DummySchemaUser(1));
      await v1Conn.close();

      final upgraded = AppDatabase(NativeDatabase(dbFile));
      addTearDown(upgraded.close);
      await upgraded.initialize();

      final settings = await upgraded.select(upgraded.gameSettings).get();
      expect(settings.single.value, '0.5');

      final repo = DriftPlayerSaveRepository(
        db: upgraded,
        config: _migrationTestConfig(),
      );
      expect(await repo.loadSnapshot(), isNull);
    });

    test('DriftPlayerSaveRepository v3 menyimpan & mensanitasi CycleProgress, clearedInCycleRank, dan OfflineSummary.cycleRank', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      final warnings = <String>[];
      final repo = DriftPlayerSaveRepository(
        db: db,
        config: _migrationTestConfig(),
        onRecoveryWarning: warnings.add,
      );

      const snapshot = PlayerSaveSnapshot(
        character: PlayerCharacterSnapshot(
          progress: PlayerProgress(level: 12, gold: 300),
        ),
        inventory: InventorySnapshot(),
        cycleProgress: CycleProgress(
          ascensionRank: 2,
          lastNormalDungeonId: 'ancient_crypt',
        ),
        dungeon: DungeonProgressSnapshot(
          currentDungeonId: 'ancient_crypt',
          currentRoomId: 'c1',
          currentRoomIndex: 0,
          highestClearedRoomIndex: 0,
          clearsCount: 4,
          clearedInCycleRank: 2,
        ),
        dungeonProgresses: {
          'forgotten_forest': DungeonProgressSnapshot(
            currentDungeonId: 'forgotten_forest',
            currentRoomId: 'r1',
            clearsCount: 5,
            clearedInCycleRank: 1,
          ),
          'ancient_crypt': DungeonProgressSnapshot(
            currentDungeonId: 'ancient_crypt',
            currentRoomId: 'c1',
            clearsCount: 4,
            clearedInCycleRank: 2,
          ),
        },
        session: GameSessionSnapshot(lastSavedAtMs: 20000),
        offlineActivity: OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.completed,
          selectedDungeonId: 'ancient_crypt',
          pendingSummary: OfflineSummarySnapshot(
            eventId: 'offline:10000:20000',
            mode: OfflineActivityMode.autoFarming,
            finalState: OfflineActivityState.completed,
            effectiveElapsedMs: 10000,
            runsAttempted: 1,
            runsCompleted: 1,
            cycleRank: 2,
            generatedAtMs: 20000,
          ),
        ),
      );

      await repo.saveSnapshot(snapshot);
      final loaded = await repo.loadSnapshot();
      expect(loaded, isNotNull);
      expect(loaded!.cycleProgress.ascensionRank, 2);
      expect(loaded.cycleProgress.lastNormalDungeonId, 'ancient_crypt');
      expect(loaded.dungeon.currentDungeonId, 'ancient_crypt');
      expect(loaded.isClearedInCurrentCycle('ancient_crypt'), isTrue);
      expect(loaded.isClearedInCurrentCycle('forgotten_forest'), isFalse);
      expect(loaded.offlineActivity.pendingSummary?.cycleRank, 2);

      // Bila lastNormalDungeonId menunjuk dungeon ascension, saat load harus disanitasi menjadi null.
      await db
          .update(db.cycleProgresses)
          .write(
            const CycleProgressesCompanion(
              lastNormalDungeonId: Value('ascension_forest'),
            ),
          );
      final sanitized = await repo.loadSnapshot();
      expect(sanitized!.cycleProgress.lastNormalDungeonId, isNull);
      expect(warnings.any((w) => w.contains('lastNormalDungeonId')), isTrue);
    });
  });
}

class _DummySchemaUser extends QueryExecutorUser {
  _DummySchemaUser(this.schemaVersion);

  @override
  final int schemaVersion;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
