import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/shop_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig({ShopCatalog? shopOverride}) {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  return GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
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
    shop:
        shopOverride ?? const ShopConfigParser().parse(_readAsset('shop.json')),
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

void main() {
  group('M10 Stage 1 — Shop Config, Validator & Schema v5', () {
    test('assets/data/shop.json valid, tidak memuat consumable, dan lolos GameConfigValidator', () {
      final config = _loadRealConfig();
      expect(
        () => const GameConfigValidator().validate(config),
        returnsNormally,
      );
      expect(config.shop.entries, hasLength(14));
      expect(config.shop.sell.maxSellRatio, 0.4);
      expect(config.shop.sell.confirmMinRarity, ItemRarity.rare);
      expect(config.shop.sell.equippedSellable, isFalse);

      // Pastikan small_potion (consumable) belum masuk shop.
      expect(
        config.shop.entries.any((e) => e.itemId == 'small_potion'),
        isFalse,
      );

      // Cek requirement baseline Rare (min_level), Epic (min_level + dungeon_cleared), Legendary (min_ascension_rank).
      final ranger = config.shop.byId('shop_ranger_blade')!;
      expect(ranger.requirements, [const MinLevelRequirement(10)]);

      final aetherBlade = config.shop.byId('shop_aether_blade')!;
      expect(aetherBlade.requirements, [
        const MinLevelRequirement(20),
        const DungeonClearedRequirement('ancient_crypt'),
      ]);

      final heart = config.shop.byId('shop_heart_of_aether')!;
      expect(heart.purchaseLimit, 1);
      expect(heart.requirements, [const MinAscensionRankRequirement(1)]);
    });

    test('ShopConfigParser & GameConfigValidator menolak kasus invalid', () {
      const parser = ShopConfigParser();
      const validator = GameConfigValidator();
      final base = _loadRealConfig();

      // 1) Duplicate entry id di parser.
      expect(
        () => parser.parse('''
        {
          "entries": [
            {"id": "dup", "item_id": "rusty_sword", "price": 12},
            {"id": "dup", "item_id": "leather_cap", "price": 12}
          ]
        }
        '''),
        throwsA(isA<ConfigException>()),
      );

      // 2) Item tidak ada.
      expect(
        () => validator.validate(
          _loadRealConfig(
            shopOverride: ShopCatalog(
              entries: const [
                ShopEntry(id: 'missing', itemId: 'no_such_item', price: 20),
              ],
            ),
          ),
        ),
        throwsA(isA<ConfigException>()),
      );

      // 3) Consumable (small_potion) ditolak sebelum berfungsi di game.
      expect(
        () => validator.validate(
          _loadRealConfig(
            shopOverride: ShopCatalog(
              entries: const [
                ShopEntry(id: 'pot', itemId: 'small_potion', price: 15),
              ],
            ),
          ),
        ),
        throwsA(isA<ConfigException>()),
      );

      // 4) Harga tidak monoton antar rarity (Uncommon 15 <= Common 16).
      expect(
        () => validator.validate(
          _loadRealConfig(
            shopOverride: ShopCatalog(
              entries: const [
                ShopEntry(id: 'c1', itemId: 'copper_ring', price: 16),
                ShopEntry(id: 'u1', itemId: 'hunters_bow', price: 15),
              ],
            ),
          ),
        ),
        throwsA(isA<ConfigException>()),
      );

      // 5) sell_value melebihi max_sell_ratio * price (ranger_blade sell_value=40 > 0.4 * 90 = 36).
      expect(
        () => validator.validate(
          _loadRealConfig(
            shopOverride: ShopCatalog(
              entries: const [
                ShopEntry(id: 'r1', itemId: 'ranger_blade', price: 90),
              ],
            ),
          ),
        ),
        throwsA(isA<ConfigException>()),
      );

      // 6) Requirement dungeon_cleared merujuk dungeon tidak dikenal.
      expect(
        () => validator.validate(
          _loadRealConfig(
            shopOverride: ShopCatalog(
              entries: const [
                ShopEntry(
                  id: 'e1',
                  itemId: 'aether_blade',
                  price: 1500,
                  requirements: [DungeonClearedRequirement('unknown_dungeon')],
                ),
              ],
            ),
          ),
        ),
        throwsA(isA<ConfigException>()),
      );

      expect(base.shop.entries, isNotEmpty);
    });

    test('instalasi baru v5 membuat tabel shop_purchases dengan PK dan CHECK constraint', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      expect(db.schemaVersion, 12);
      await db.initialize();

      final cols = await db
          .customSelect("PRAGMA table_info('shop_purchases')")
          .get();
      expect(
        cols.map((r) => r.data['name']),
        containsAll(['player_id', 'entry_id', 'purchased_count']),
      );

      await db
          .into(db.players)
          .insert(
            PlayersCompanion.insert(
              id: 'player_1',
              level: 10,
              currentExp: 0,
              gold: 1000,
              baseStatsJson: '{}',
              lastSavedAtMs: 1000,
            ),
          );
      await db
          .into(db.shopPurchases)
          .insert(
            ShopPurchasesCompanion.insert(
              playerId: 'player_1',
              entryId: 'shop_heart_of_aether',
              purchasedCount: const Value(1),
            ),
          );

      final rows = await db.select(db.shopPurchases).get();
      expect(rows, hasLength(1));
      expect(rows.single.entryId, 'shop_heart_of_aether');
      expect(rows.single.purchasedCount, 1);

      // CHECK (purchased_count >= 0) harus menolak nilai negatif.
      await expectLater(
        () => db
            .into(db.shopPurchases)
            .insert(
              ShopPurchasesCompanion.insert(
                playerId: 'player_1',
                entryId: 'shop_bad',
                purchasedCount: const Value(-1),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('migrasi v3 -> v5 menjaga data nyata, mengisi highest_ascension_rank, dan membuat shop_purchases', () async {
      final tempDir = Directory.systemTemp.createTempSync('echoes_v3_to_v5_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final dbFile = File('${tempDir.path}/legacy_v3.sqlite');

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
            'instance_id TEXT NOT NULL PRIMARY KEY, '
            'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
            'definition_id TEXT NOT NULL, '
            'slot TEXT NOT NULL, '
            'rarity TEXT NOT NULL, '
            'rolled_stats_json TEXT NOT NULL);',
          );
          raw.execute(
            'CREATE TABLE equipped_items ('
            'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
            'slot TEXT NOT NULL, '
            'instance_id TEXT NOT NULL REFERENCES equipment_instances (instance_id) ON DELETE CASCADE, '
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
            'cleared_in_cycle_rank INTEGER NOT NULL DEFAULT -1, '
            'reward_state_json TEXT NOT NULL, '
            'updated_at_ms INTEGER NOT NULL, '
            'PRIMARY KEY (player_id, dungeon_id));',
          );
          raw.execute(
            'CREATE TABLE cycle_progresses ('
            'player_id TEXT NOT NULL PRIMARY KEY REFERENCES players (id) ON DELETE CASCADE, '
            'ascension_rank INTEGER NOT NULL DEFAULT 0, '
            'last_normal_dungeon_id TEXT NULL, '
            'updated_at_ms INTEGER NOT NULL);',
          );
          raw.execute(
            'CREATE TABLE game_sessions ('
            'id TEXT NOT NULL PRIMARY KEY, '
            'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
            'last_active_at_ms INTEGER NOT NULL, '
            'last_saved_at_ms INTEGER NOT NULL, '
            'last_offline_claim_at_ms INTEGER NOT NULL, '
            'auto_skill_enabled INTEGER NOT NULL DEFAULT 1, '
            'active_session_json TEXT NULL, '
            'offline_activity_json TEXT NULL);',
          );
          raw.execute(
            'CREATE TABLE claimed_rewards ('
            'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
            'event_id TEXT NOT NULL, '
            'claimed_at_ms INTEGER NOT NULL, '
            'PRIMARY KEY (player_id, event_id));',
          );
          raw.execute(
            "INSERT INTO players VALUES ('player_1', 44, 120, 5000, 200, 'ranger', '{}', 0, 1000);",
          );
          raw.execute(
            "INSERT INTO cycle_progresses VALUES ('player_1', 1, 'forgotten_forest', 1000);",
          );
          raw.execute(
            "INSERT INTO dungeon_progresses VALUES ('player_1', 'aether_sanctum', 'as_heart', 4, 4, 2, 0, '{}', 1000);",
          );
          raw.execute('PRAGMA user_version = 3;');
        },
      );
      await seedDb.ensureOpen(_DummySchemaUser(3));
      await seedDb.close();

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);
      await db.initialize();

      final player = await (db.select(
        db.players,
      )..where((t) => t.id.equals('player_1'))).getSingle();
      expect(player.level, 44);
      expect(player.gold, 5000);

      final cycle = await (db.select(
        db.cycleProgresses,
      )..where((t) => t.playerId.equals('player_1'))).getSingle();
      expect(cycle.ascensionRank, 1);
      expect(cycle.highestAscensionRank, 1);
      expect(cycle.lastNormalDungeonId, 'forgotten_forest');

      await db
          .into(db.shopPurchases)
          .insert(
            ShopPurchasesCompanion.insert(
              playerId: 'player_1',
              entryId: 'shop_ranger_blade',
              purchasedCount: const Value(2),
            ),
          );
      final purchases = await db.select(db.shopPurchases).get();
      expect(purchases, hasLength(1));
      expect(purchases.single.purchasedCount, 2);
    });
  });
}
