import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:echoes_of_aether/data/database/app_database.dart'
    hide ClockState;
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/clock_state.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:flutter_test/flutter_test.dart';

GameConfig _v6MigrationConfig() {
  const layout = <String>['#####', '#...#', '#####'];
  return GameConfig(
    monsters: const {},
    revive: const ReviveConfig(),
    progression: const ProgressionConfig(
      maxLevel: null,
      expCurve: ExpCurveConfig.polynomial(),
      baseStats: CombatStats(
        maxHp: 100,
        atk: 12,
        def: 2,
        attackSpeed: 1.5,
        critRate: 0.1,
        critDamage: 1.5,
        moveSpeed: 4.0,
        attackRange: 1.5,
      ),
      perLevel: LevelGrowth(hp: 15, atk: 2, def: 0.5),
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
    },
  );
}

class _SchemaUser extends QueryExecutorUser {
  _SchemaUser(this.schemaVersion);

  @override
  final int schemaVersion;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

Future<void> _seedLegacyDatabase({
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
        "INSERT INTO game_settings (key, value) VALUES ('audio.bgm_volume', '0.7');",
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
          'last_saved_at_ms INTEGER NOT NULL);',
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
          "INSERT INTO players VALUES ('default_player', 18, 250, 9000, 180, 'vanguard', "
          "'{\"maxHp\":355,\"atk\":46,\"def\":10}', 3, 1700000000000);",
        );
        raw.execute(
          "INSERT INTO skill_progresses VALUES ('default_player', 'power_strike', 3, 1, 0);",
        );
        raw.execute(
          "INSERT INTO inventory_entries VALUES ('default_player', 'slime_gel', 42);",
        );
        raw.execute(
          "INSERT INTO equipment_instances VALUES ('default_player', 'eq_1', 'rusty_sword', 'weapon', 'common', "
          "'{\"atk\":5}', 0);",
        );
        raw.execute(
          "INSERT INTO equipped_items VALUES ('default_player', 'weapon', 'eq_1');",
        );
        if (version >= 3) {
          raw.execute(
            "INSERT INTO dungeon_progresses VALUES ('default_player', 'forgotten_forest', 'r1', 0, 0, 2, 1, '{}');",
          );
        } else {
          raw.execute(
            "INSERT INTO dungeon_progresses VALUES ('default_player', 'forgotten_forest', 'r1', 0, 0, 2, '{}');",
          );
        }
        raw.execute(
          "INSERT INTO game_sessions VALUES ('default_player', 'default_player', 1700000000000, 1700000000000, 1700000000000, 1, '{}');",
        );
        raw.execute(
          "INSERT INTO claimed_rewards VALUES ('default_player', 'ascension:run_1', 1700000000000);",
        );
      }

      if (version >= 3) {
        final highestCol = version >= 4
            ? 'highest_ascension_rank INTEGER NOT NULL DEFAULT 0, '
            : '';
        raw.execute(
          'CREATE TABLE cycle_progresses ('
          'player_id TEXT NOT NULL PRIMARY KEY REFERENCES players (id) ON DELETE CASCADE, '
          'ascension_rank INTEGER NOT NULL DEFAULT 0, '
          '$highestCol'
          'last_normal_dungeon_id TEXT NULL, '
          'updated_at_ms INTEGER NOT NULL);',
        );
        if (version >= 4) {
          raw.execute(
            "INSERT INTO cycle_progresses VALUES ('default_player', 1, 2, 'forgotten_forest', 1700000000000);",
          );
        } else {
          raw.execute(
            "INSERT INTO cycle_progresses VALUES ('default_player', 1, 'forgotten_forest', 1700000000000);",
          );
        }
      }

      if (version >= 5) {
        raw.execute(
          'CREATE TABLE shop_purchases ('
          'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
          'entry_id TEXT NOT NULL, '
          'purchased_count INTEGER NOT NULL DEFAULT 0, '
          'PRIMARY KEY (player_id, entry_id));',
        );
        raw.execute(
          "INSERT INTO shop_purchases VALUES ('default_player', 'shop_rusty_sword', 2);",
        );
      }

      raw.execute('PRAGMA user_version = $version;');
    },
  );
  await seedDb.ensureOpen(_SchemaUser(version));
  await seedDb.close();
}

void main() {
  group('Database v6 Migration', () {
    test(
      'instalasi baru membuat schemaVersion 6 dan seluruh tabel v6',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.initialize();

        expect(db.schemaVersion, 8);
        final tables = await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get();
        final names = tables.map((r) => r.read<String>('name')).toSet();
        expect(
          names,
          containsAll(['clock_states', 'currencies', 'periodic_quest_states']),
        );

        final repo = DriftPlayerSaveRepository(
          db: db,
          config: _v6MigrationConfig(),
        );
        expect(await repo.loadClockState(), const ClockState());
      },
    );

    for (final oldVersion in [1, 2, 3, 4, 5]) {
      test(
        'migrasi v$oldVersion -> v6 mempertahankan data nyata dan membuat tabel baru',
        () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'eoa_v${oldVersion}_v6_',
          );
          addTearDown(() => tempDir.delete(recursive: true));
          final dbFile = File('${tempDir.path}/test.sqlite');

          await _seedLegacyDatabase(dbFile: dbFile, version: oldVersion);

          final db = AppDatabase(NativeDatabase(dbFile));
          addTearDown(db.close);
          await db.initialize();

          final tables = await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'table'",
              )
              .get();
          final names = tables.map((r) => r.read<String>('name')).toSet();
          expect(
            names,
            containsAll([
              'clock_states',
              'currencies',
              'periodic_quest_states',
            ]),
          );

          final repo = DriftPlayerSaveRepository(
            db: db,
            config: _v6MigrationConfig(),
          );
          final settings = await repo.loadSettings();
          expect(settings.bgmVolume, closeTo(0.7, 0.001));

          // Default bila baris ClockStates belum ada.
          expect(await repo.loadClockState(), const ClockState());

          final snapshot = await repo.loadSnapshot();
          if (oldVersion == 1) {
            expect(snapshot, isNull);
          } else {
            expect(snapshot, isNotNull);
            expect(snapshot!.character.progress.level, 18);
            expect(snapshot.character.progress.gold, 9000);
            expect(snapshot.inventory.stacks['slime_gel'], 42);
            expect(
              snapshot.character.equipped[EquipmentSlot.weapon]?.id,
              'eq_1',
            );
            expect(snapshot.claimedEventIds, contains('ascension:run_1'));
            expect(snapshot.clockState, const ClockState());

            if (oldVersion >= 3) {
              expect(snapshot.cycleProgress.ascensionRank, 1);
            }
            if (oldVersion >= 4) {
              expect(snapshot.cycleProgress.highestAscensionRank, 2);
            }
            if (oldVersion >= 5) {
              expect(snapshot.shopPurchases['shop_rusty_sword'], 2);
            }
          }

          // Pastikan tabel baru dapat ditulis setelah migrasi jika ada player.
          if (oldVersion >= 2) {
            await repo.saveClockState(
              const ClockState(
                lastSeenAtMs: 1_700_100_000_000,
                forwardJumpCount: 1,
                maxForwardJumpMs: 200_000,
              ),
            );
            expect(
              await repo.loadClockState(),
              const ClockState(
                lastSeenAtMs: 1_700_100_000_000,
                forwardJumpCount: 1,
                maxForwardJumpMs: 200_000,
              ),
            );
          }
        },
      );
    }
  });
}
