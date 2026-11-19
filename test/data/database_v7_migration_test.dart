import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/equipment_loadout.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/domain/services/derived_stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

GameConfig _v7MigrationConfig() {
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
    equipment: const EquipmentConfig(
      rollVariance: 0.15,
      pctCaps: EquipmentPctCaps(hpPct: 0.6, atkPct: 0.5, defPct: 0.5),
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
      'pct_charm': ItemDefinition(
        id: 'pct_charm',
        name: 'Pct Charm',
        category: ItemCategory.equipment,
        rarity: ItemRarity.rare,
        sellable: false,
        equipment: EquipmentData(
          slot: EquipmentSlot.accessory,
          fixedStats: true,
          baseStats: EquipmentStats(hpPct: 0.12, atkPct: 0.15, defPct: 0.08),
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
        // Legacy 9-key equipment stats JSON (tanpa hpPct/atkPct/defPct).
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

      if (version >= 6) {
        raw.execute(
          'CREATE TABLE clock_states ('
          'player_id TEXT NOT NULL PRIMARY KEY REFERENCES players (id) ON DELETE CASCADE, '
          'last_seen_at_ms INTEGER NOT NULL DEFAULT 0, '
          'forward_jump_count INTEGER NOT NULL DEFAULT 0, '
          'max_forward_jump_ms INTEGER NOT NULL DEFAULT 0);',
        );
        raw.execute(
          'CREATE TABLE currencies ('
          'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
          'currency_id TEXT NOT NULL, '
          'amount INTEGER NOT NULL DEFAULT 0, '
          'PRIMARY KEY (player_id, currency_id));',
        );
        raw.execute(
          'CREATE TABLE periodic_quest_states ('
          'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
          'quest_id TEXT NOT NULL, '
          'period_key TEXT NOT NULL, '
          'completed_at_ms INTEGER NOT NULL, '
          'PRIMARY KEY (player_id, quest_id, period_key));',
        );
        raw.execute(
          "INSERT INTO clock_states VALUES ('default_player', 1700000005000, 0, 0);",
        );
        raw.execute(
          "INSERT INTO currencies VALUES ('default_player', 'aether_shard', 120);",
        );
        raw.execute(
          "INSERT INTO periodic_quest_states VALUES ('default_player', 'daily_boss', '2026-04-01', 1700000005000);",
        );
      }

      raw.execute('PRAGMA user_version = $version;');
    },
  );
  await seedDb.ensureOpen(_SchemaUser(version));
  await seedDb.close();
}

void main() {
  group('Database v7 Migration & Percentage Stats Persistence', () {
    test('instalasi baru membuat schemaVersion 7 dan tabel event_shop_purchases dengan PK dan CHECK', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      expect(db.schemaVersion, 10);
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      expect(
        tables.map((r) => r.read<String>('name')),
        contains('event_shop_purchases'),
      );

      final cols = await db
          .customSelect("PRAGMA table_info('event_shop_purchases')")
          .get();
      expect(
        cols.map((r) => r.data['name']),
        containsAll(['player_id', 'entry_id', 'period_key', 'purchased_count']),
      );

      await db
          .into(db.players)
          .insert(
            PlayersCompanion.insert(
              id: 'default_player',
              level: 1,
              currentExp: 0,
              gold: 0,
              baseStatsJson: '{}',
              lastSavedAtMs: 0,
            ),
          );

      await db
          .into(db.eventShopPurchases)
          .insert(
            EventShopPurchasesCompanion.insert(
              playerId: 'default_player',
              entryId: 'event_sword_entry',
              periodKey: '2026-W14',
              purchasedCount: const Value(1),
            ),
          );

      // CHECK constraint purchased_count >= 0.
      await expectLater(
        db
            .into(db.eventShopPurchases)
            .insert(
              EventShopPurchasesCompanion.insert(
                playerId: 'default_player',
                entryId: 'event_bad',
                periodKey: '2026-W14',
                purchasedCount: const Value(-1),
              ),
            ),
        throwsA(anything),
      );

      // Cascade delete saat player dihapus.
      await (db.delete(
        db.players,
      )..where((t) => t.id.equals('default_player'))).go();
      expect(await db.select(db.eventShopPurchases).get(), isEmpty);
    });

    for (final oldVersion in [1, 2, 3, 4, 5, 6]) {
      test(
        'migrasi v$oldVersion -> v7 mempertahankan data nyata dan membuat event_shop_purchases',
        () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'eoa_v${oldVersion}_v7_',
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
          expect(
            tables.map((r) => r.read<String>('name')),
            contains('event_shop_purchases'),
          );

          final repo = DriftPlayerSaveRepository(
            db: db,
            config: _v7MigrationConfig(),
          );
          final settings = await repo.loadSettings();
          expect(settings.bgmVolume, closeTo(0.7, 0.001));

          final snapshot = await repo.loadSnapshot();
          if (oldVersion == 1) {
            expect(snapshot, isNull);
          } else {
            expect(snapshot, isNotNull);
            expect(snapshot!.character.progress.level, 18);
            expect(snapshot.character.progress.gold, 9000);
            expect(snapshot.inventory.stacks['slime_gel'], 42);
            final legacySword =
                snapshot.character.equipped[EquipmentSlot.weapon];
            expect(legacySword?.id, 'eq_1');
            expect(legacySword?.rolledStats.atk, 5);
            // Save lama tanpa hpPct/atkPct/defPct otomatis terbaca 0.0.
            expect(legacySword?.rolledStats.hpPct, 0.0);
            expect(legacySword?.rolledStats.atkPct, 0.0);
            expect(legacySword?.rolledStats.defPct, 0.0);
            expect(snapshot.claimedEventIds, contains('ascension:run_1'));

            if (oldVersion >= 3) {
              expect(snapshot.cycleProgress.ascensionRank, 1);
            }
            if (oldVersion >= 4) {
              expect(snapshot.cycleProgress.highestAscensionRank, 2);
            }
            if (oldVersion >= 5) {
              expect(snapshot.shopPurchases['shop_rusty_sword'], 2);
            }
            if (oldVersion >= 6) {
              expect(snapshot.currencies['aether_shard'], 120);
              expect(
                snapshot.periodicQuestStates.any(
                  (q) =>
                      q.questId == 'daily_boss' &&
                      q.periodKey == '2026-04-01' &&
                      q.completedAtMs == 1700000005000,
                ),
                isTrue,
              );
              expect(snapshot.clockState.lastSeenAtMs, 1700000005000);
            }

            await db
                .into(db.eventShopPurchases)
                .insert(
                  EventShopPurchasesCompanion.insert(
                    playerId: 'default_player',
                    entryId: 'event_charm',
                    periodKey: '2026-W14',
                    purchasedCount: const Value(1),
                  ),
                );
            final inserted = await db.select(db.eventShopPurchases).get();
            expect(inserted, hasLength(1));
            expect(inserted.single.purchasedCount, 1);
          }
        },
      );
    }

    test(
      'persistensi dan pemulihan EquipmentInstance dengan stat persentase',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.initialize();

        final cfg = _v7MigrationConfig();
        final repo = DriftPlayerSaveRepository(db: db, config: cfg);

        const pctCharm = EquipmentInstance(
          id: 'eq_pct_1',
          definitionId: 'pct_charm',
          slot: EquipmentSlot.accessory,
          rarity: ItemRarity.rare,
          rolledStats: EquipmentStats(hpPct: 0.12, atkPct: 0.15, defPct: 0.08),
        );
        const sword = EquipmentInstance(
          id: 'eq_flat_1',
          definitionId: 'rusty_sword',
          slot: EquipmentSlot.weapon,
          rarity: ItemRarity.common,
          rolledStats: EquipmentStats(atk: 5),
        );
        const bagCharm = EquipmentInstance(
          id: 'eq_pct_bag',
          definitionId: 'pct_charm',
          slot: EquipmentSlot.accessory,
          rarity: ItemRarity.rare,
          rolledStats: EquipmentStats(hpPct: 0.05, atkPct: 0.07, defPct: 0.03),
        );

        final loadout = EquipmentLoadout()
          ..equip(sword)
          ..equip(pctCharm);
        final character = PlayerCharacter(
          config: cfg.progression,
          progress: const PlayerProgress(level: 1, gold: 100),
          loadout: loadout,
          statsCalculator: DerivedStatsCalculator(
            pctCaps: cfg.equipment.pctCaps,
          ),
        );
        final inventory = Inventory(definitions: cfg.items)
          ..addEquipment(bagCharm);

        final snapshot = PlayerSaveSnapshot(
          character: character.toSnapshot(),
          inventory: inventory.toSnapshot(),
          dungeon: const DungeonProgressSnapshot(),
          session: const GameSessionSnapshot(
            lastActiveAtMs: 1000,
            lastSavedAtMs: 1000,
            lastOfflineClaimAtMs: 1000,
            autoSkillEnabled: true,
          ),
        );
        await repo.saveSnapshot(snapshot);

        final loaded = await repo.loadSnapshot();
        expect(loaded, isNotNull);
        final restoredCharm =
            loaded!.character.equipped[EquipmentSlot.accessory];
        expect(restoredCharm, isNotNull);
        expect(restoredCharm!.rolledStats.hpPct, closeTo(0.12, 1e-9));
        expect(restoredCharm.rolledStats.atkPct, closeTo(0.15, 1e-9));
        expect(restoredCharm.rolledStats.defPct, closeTo(0.08, 1e-9));

        final restoredBagCharm = loaded.inventory.equipment.singleWhere(
          (e) => e.id == 'eq_pct_bag',
        );
        expect(restoredBagCharm.rolledStats.hpPct, closeTo(0.05, 1e-9));
        expect(restoredBagCharm.rolledStats.atkPct, closeTo(0.07, 1e-9));
        expect(restoredBagCharm.rolledStats.defPct, closeTo(0.03, 1e-9));

        final restoredCharacter = PlayerCharacter(
          config: cfg.progression,
          progress: loaded.character.progress,
          loadout: EquipmentLoadout()
            ..equip(loaded.character.equipped[EquipmentSlot.weapon]!)
            ..equip(restoredCharm),
          statsCalculator: DerivedStatsCalculator(
            pctCaps: cfg.equipment.pctCaps,
          ),
        );
        expect(restoredCharacter.stats.maxHp, character.stats.maxHp);
        expect(restoredCharacter.stats.atk, character.stats.atk);
        expect(restoredCharacter.stats.def, character.stats.def);
      },
    );
  });
}
