import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
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
      maxLevel: 100,
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
      'forest_herb': ItemDefinition(
        id: 'forest_herb',
        name: 'Forest Herb',
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
      'leather_armor': ItemDefinition(
        id: 'leather_armor',
        name: 'Leather Armor',
        category: ItemCategory.equipment,
        rarity: ItemRarity.rare,
        equipment: EquipmentData(
          slot: EquipmentSlot.body,
          baseStats: EquipmentStats(def: 8, hp: 30),
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
        startRoomId: 'c1',
        roomOrder: ['c1'],
        completionReward: DungeonCompletionReward(
          expReward: 60,
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
    },
  );
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

Future<void> _createLegacyDatabase({
  required File dbFile,
  required int version,
}) async {
  final seedDb = NativeDatabase(
    dbFile,
    setup: (raw) {
      raw.execute('PRAGMA foreign_keys = ON;');
      raw.execute(
        'CREATE TABLE game_settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);',
      );
      raw.execute(
        "INSERT INTO game_settings (key, value) VALUES ('music_volume', '0.5');",
      );
      raw.execute(
        "INSERT INTO game_settings (key, value) VALUES ('auto_skill', 'true');",
      );

      if (version >= 2) {
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
        final clearedCol = version >= 3
            ? 'cleared_in_cycle_rank INTEGER NOT NULL DEFAULT -1, '
            : '';
        raw.execute(
          'CREATE TABLE dungeon_progresses ('
          'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
          'dungeon_id TEXT NOT NULL, '
          'current_room_id TEXT NOT NULL, '
          'current_room_index INTEGER NOT NULL, '
          'highest_cleared_room_index INTEGER NOT NULL, '
          'clears_count INTEGER NOT NULL, '
          '$clearedCol'
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

        raw.execute(
          "INSERT INTO players (id, level, current_exp, gold, current_hp, active_specialization_id, base_stats_json, equipment_counter, last_saved_at_ms) "
          "VALUES ('default_player', 18, 240, 12500, 180, 'vanguard', '{}', 5, 90000);",
        );
        raw.execute(
          "INSERT INTO skill_progresses (player_id, skill_id, skill_level, unlocked, cooldown_ticks_remaining) "
          "VALUES ('default_player', 'power_strike', 3, 1, 2);",
        );
        raw.execute(
          "INSERT INTO inventory_entries (player_id, item_id, quantity) "
          "VALUES ('default_player', 'slime_gel', 14);",
        );
        raw.execute(
          "INSERT INTO inventory_entries (player_id, item_id, quantity) "
          "VALUES ('default_player', 'forest_herb', 6);",
        );
        raw.execute(
          "INSERT INTO equipment_instances (player_id, instance_id, definition_id, slot, rarity, rolled_stats_json, enhancement_level) "
          "VALUES ('default_player', 'eq_1', 'rusty_sword', 'weapon', 'common', '{\"atk\":7}', 2);",
        );
        raw.execute(
          "INSERT INTO equipment_instances (player_id, instance_id, definition_id, slot, rarity, rolled_stats_json, enhancement_level) "
          "VALUES ('default_player', 'eq_2', 'leather_armor', 'body', 'rare', '{\"def\":10,\"hp\":35}', 1);",
        );
        raw.execute(
          "INSERT INTO equipped_items (player_id, slot, equipment_instance_id) "
          "VALUES ('default_player', 'weapon', 'eq_1');",
        );

        if (version == 2) {
          raw.execute(
            "INSERT INTO dungeon_progresses (player_id, dungeon_id, current_room_id, current_room_index, highest_cleared_room_index, clears_count, reward_state_json) "
            "VALUES ('default_player', 'forgotten_forest', 'r1', 0, 0, 4, '{}');",
          );
          raw.execute(
            "INSERT INTO dungeon_progresses (player_id, dungeon_id, current_room_id, current_room_index, highest_cleared_room_index, clears_count, reward_state_json) "
            "VALUES ('default_player', 'ancient_crypt', 'c1', 0, -1, 0, '{}');",
          );
        } else {
          raw.execute(
            "INSERT INTO dungeon_progresses (player_id, dungeon_id, current_room_id, current_room_index, highest_cleared_room_index, clears_count, cleared_in_cycle_rank, reward_state_json) "
            "VALUES ('default_player', 'forgotten_forest', 'r1', 0, 0, 4, 1, '{}');",
          );
          raw.execute(
            "INSERT INTO dungeon_progresses (player_id, dungeon_id, current_room_id, current_room_index, highest_cleared_room_index, clears_count, cleared_in_cycle_rank, reward_state_json) "
            "VALUES ('default_player', 'ancient_crypt', 'c1', 0, -1, 0, -1, '{}');",
          );
        }

        raw.execute(
          "INSERT INTO game_sessions (id, player_id, last_active_at_ms, last_saved_at_ms, last_offline_claim_at_ms, auto_skill_enabled, session_data_json) "
          "VALUES ('default_player', 'default_player', 90000, 90000, 85000, 1, '{}');",
        );
        raw.execute(
          "INSERT INTO claimed_rewards (player_id, event_id, claimed_at_ms) "
          "VALUES ('default_player', 'dungeon_clear:legacy_run', 80000);",
        );
      }

      if (version == 3) {
        raw.execute(
          'CREATE TABLE cycle_progresses ('
          'player_id TEXT NOT NULL PRIMARY KEY REFERENCES players (id) ON DELETE CASCADE, '
          'ascension_rank INTEGER NOT NULL DEFAULT 0, '
          'last_normal_dungeon_id TEXT NULL, '
          'updated_at_ms INTEGER NOT NULL);',
        );
        raw.execute(
          "INSERT INTO cycle_progresses (player_id, ascension_rank, last_normal_dungeon_id, updated_at_ms) "
          "VALUES ('default_player', 3, 'ancient_crypt', 90000);",
        );
      } else if (version == 4) {
        raw.execute(
          'CREATE TABLE cycle_progresses ('
          'player_id TEXT NOT NULL PRIMARY KEY REFERENCES players (id) ON DELETE CASCADE, '
          'ascension_rank INTEGER NOT NULL DEFAULT 0, '
          'highest_ascension_rank INTEGER NOT NULL DEFAULT 0, '
          'last_normal_dungeon_id TEXT NULL, '
          'updated_at_ms INTEGER NOT NULL, '
          'CHECK (ascension_rank >= 0), '
          'CHECK (highest_ascension_rank >= 0));',
        );
        // Simulasi pemain yang sudah pernah sampai Rank 4 lalu pakai Rank Switcher ke Rank 1.
        raw.execute(
          "INSERT INTO cycle_progresses (player_id, ascension_rank, highest_ascension_rank, last_normal_dungeon_id, updated_at_ms) "
          "VALUES ('default_player', 1, 4, 'ancient_crypt', 90000);",
        );
      }

      raw.execute('PRAGMA user_version = $version;');
    },
  );
  final conn = DatabaseConnection(seedDb);
  await conn.ensureOpen(_DummySchemaUser(version));
  await conn.close();
}

void main() {
  group('Database Migration v1/v2/v3/v4 -> current (v5) with real data', () {
    test('v1 -> v5: menjaga game_settings, membuat seluruh tabel baru, dan user_version = 5', () async {
      final tempDir = Directory.systemTemp.createTempSync('echoes_mig_v1_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final dbFile = File('${tempDir.path}/v1.sqlite');

      await _createLegacyDatabase(dbFile: dbFile, version: 1);

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);
      await db.initialize();

      final userVersionRow = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(userVersionRow.data['user_version'], db.schemaVersion);

      final settings = await db.select(db.gameSettings).get();
      expect(
        {for (final s in settings) s.key: s.value},
        {'music_volume': '0.5', 'auto_skill': 'true'},
      );

      final repo = DriftPlayerSaveRepository(
        db: db,
        config: _migrationTestConfig(),
      );
      expect(await repo.loadSnapshot(), isNull);
      expect(await repo.loadShopPurchases(), isEmpty);
    });

    test('v2 -> v5: menjaga player, inventory, equipment, dungeon & backfill default v3-v5', () async {
      final tempDir = Directory.systemTemp.createTempSync('echoes_mig_v2_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final dbFile = File('${tempDir.path}/v2.sqlite');

      await _createLegacyDatabase(dbFile: dbFile, version: 2);

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);
      await db.initialize();

      final userVersionRow = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(userVersionRow.data['user_version'], db.schemaVersion);

      final repo = DriftPlayerSaveRepository(
        db: db,
        config: _migrationTestConfig(),
      );
      final loaded = await repo.loadSnapshot();
      expect(loaded, isNotNull);

      expect(loaded!.character.progress.level, 18);
      expect(loaded.character.progress.currentExp, 240);
      expect(loaded.character.progress.gold, 12500);
      expect(loaded.character.currentHp, 180);
      expect(loaded.character.specializationId, 'vanguard');
      expect(loaded.character.skillLevels['power_strike'], 3);
      expect(loaded.inventory.stacks['slime_gel'], 14);
      expect(loaded.inventory.stacks['forest_herb'], 6);
      expect(loaded.inventory.equipmentCounter, 5);
      expect(loaded.character.equipped[EquipmentSlot.weapon]?.id, 'eq_1');
      expect(
        loaded.character.equipped[EquipmentSlot.weapon]?.rolledStats.atk,
        7,
      );
      expect(loaded.inventory.equipment.map((e) => e.id), contains('eq_2'));

      expect(loaded.dungeonProgresses['forgotten_forest']?.clearsCount, 4);
      expect(
        loaded.dungeonProgresses['forgotten_forest']?.clearedInCycleRank,
        0,
      );
      expect(loaded.dungeonProgresses['ancient_crypt']?.clearsCount, 0);
      expect(loaded.dungeonProgresses['ancient_crypt']?.clearedInCycleRank, -1);

      expect(loaded.cycleProgress.ascensionRank, 0);
      expect(loaded.cycleProgress.highestAscensionRank, 0);
      expect(loaded.cycleProgress.lastNormalDungeonId, isNull);
      expect(await repo.loadShopPurchases(), isEmpty);
    });

    test('v3 -> v5: menjaga seluruh data, backfill highest_ascension_rank = ascension_rank, dan membuat shop_purchases', () async {
      final tempDir = Directory.systemTemp.createTempSync('echoes_mig_v3_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final dbFile = File('${tempDir.path}/v3.sqlite');

      await _createLegacyDatabase(dbFile: dbFile, version: 3);

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);
      await db.initialize();

      final userVersionRow = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(userVersionRow.data['user_version'], db.schemaVersion);

      final repo = DriftPlayerSaveRepository(
        db: db,
        config: _migrationTestConfig(),
      );
      final loaded = await repo.loadSnapshot();
      expect(loaded, isNotNull);

      expect(loaded!.character.progress.level, 18);
      expect(loaded.character.progress.currentExp, 240);
      expect(loaded.character.progress.gold, 12500);
      expect(loaded.inventory.stacks['slime_gel'], 14);
      expect(loaded.inventory.stacks['forest_herb'], 6);
      expect(loaded.character.equipped[EquipmentSlot.weapon]?.id, 'eq_1');
      expect(loaded.inventory.equipment.map((e) => e.id), contains('eq_2'));
      expect(loaded.dungeonProgresses['forgotten_forest']?.clearsCount, 4);
      expect(
        loaded.dungeonProgresses['forgotten_forest']?.clearedInCycleRank,
        1,
      );

      expect(loaded.cycleProgress.ascensionRank, 3);
      expect(loaded.cycleProgress.highestAscensionRank, 3);
      expect(loaded.cycleProgress.lastNormalDungeonId, 'ancient_crypt');
      expect(await repo.loadShopPurchases(), isEmpty);
    });

    test('v4 -> v5: menjaga data nyata termasuk highest_ascension_rank terpisah dan menyiapkan shop_purchases', () async {
      final tempDir = Directory.systemTemp.createTempSync('echoes_mig_v4_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final dbFile = File('${tempDir.path}/v4.sqlite');

      await _createLegacyDatabase(dbFile: dbFile, version: 4);

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);
      await db.initialize();

      final userVersionRow = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(userVersionRow.data['user_version'], db.schemaVersion);

      final repo = DriftPlayerSaveRepository(
        db: db,
        config: _migrationTestConfig(),
      );
      final loaded = await repo.loadSnapshot();
      expect(loaded, isNotNull);

      // Verifikasi seluruh data v4 tetap utuh
      expect(loaded!.character.progress.level, 18);
      expect(loaded.character.progress.currentExp, 240);
      expect(loaded.character.progress.gold, 12500);
      expect(loaded.character.currentHp, 180);
      expect(loaded.character.specializationId, 'vanguard');
      expect(loaded.character.skillLevels['power_strike'], 3);
      expect(loaded.inventory.stacks['slime_gel'], 14);
      expect(loaded.inventory.stacks['forest_herb'], 6);
      expect(loaded.inventory.equipmentCounter, 5);
      expect(loaded.character.equipped[EquipmentSlot.weapon]?.id, 'eq_1');
      expect(loaded.inventory.equipment.map((e) => e.id), contains('eq_2'));
      expect(loaded.dungeonProgresses['forgotten_forest']?.clearsCount, 4);
      expect(
        loaded.dungeonProgresses['forgotten_forest']?.clearedInCycleRank,
        1,
      );
      expect(loaded.dungeonProgresses['ancient_crypt']?.clearsCount, 0);
      expect(loaded.dungeonProgresses['ancient_crypt']?.clearedInCycleRank, -1);

      // highest_ascension_rank (4) tidak boleh tertimpa ascension_rank (1)
      expect(loaded.cycleProgress.ascensionRank, 1);
      expect(loaded.cycleProgress.highestAscensionRank, 4);
      expect(loaded.cycleProgress.lastNormalDungeonId, 'ancient_crypt');

      // shop_purchases default kosong setelah migrasi v4 -> v5 dan siap dipakai transaksi shop
      expect(await repo.loadShopPurchases(), isEmpty);

      await repo.saveShopTransaction(
        progress: const PlayerProgress(level: 18, currentExp: 240, gold: 10000),
        inventory: loaded.inventory,
        equipped: loaded.character.equipped,
        shopPurchases: const {'shop_rusty_sword': 1},
        actionId: 'v4_to_v5_shop_tx',
        updatedAtMs: 91000,
      );

      final reloaded = await repo.loadSnapshot();
      expect(reloaded, isNotNull);
      expect(reloaded!.character.progress.gold, 10000);
      expect(reloaded.cycleProgress.highestAscensionRank, 4);
      expect(reloaded.shopPurchases, {'shop_rusty_sword': 1});
      expect(await repo.loadShopPurchases(), {'shop_rusty_sword': 1});
    });
  });
}
