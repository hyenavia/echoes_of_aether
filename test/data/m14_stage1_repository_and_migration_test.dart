import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:echoes_of_aether/data/database/app_database.dart'
    hide ClockState, CloudSyncState, GameSettings, PeriodicQuestState;
import 'package:echoes_of_aether/data/models/boss_events_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/event_shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_cloud_sync_state_repository.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/data/repositories/in_memory_cloud_save_repository.dart';
import 'package:echoes_of_aether/data/repositories/local_backup_service.dart';
import 'package:echoes_of_aether/domain/entities/clock_state.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/event_shop_purchase.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/game_settings.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/periodic_quest_state.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/save_metrics.dart';
import 'package:echoes_of_aether/domain/repositories/cloud_save_repository.dart';
import 'package:echoes_of_aether/domain/services/game_clock.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
  const parser = GameConfigParser();
  const dungeonParser = DungeonConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  final dungeonsJson = _readAsset('dungeons.json');
  return GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    time: parser.parseTime(settings),
    claimedRewards: parser.parseClaimedRewards(settings),
    currencies: parser.parseCurrencies(settings),
    notifications: parser.parseNotifications(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    cloud: parser.parseCloud(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: dungeonParser.parse(
      dungeonsJson,
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
    mapLayouts: dungeonParser.parseMaps(dungeonsJson),
    bossEvents: const BossEventsConfigParser().parse(
      _readAsset('boss_events.json'),
    ),
    shop: const ShopConfigParser().parse(_readAsset('shop.json')),
    eventShop: const EventShopConfigParser().parse(
      _readAsset('event_shop.json'),
    ),
  );
}

class _FixedGameClock implements GameClock {
  const _FixedGameClock(this._nowMs);
  final int _nowMs;

  @override
  int get nowMs => _nowMs;
}

class _SchemaUser extends QueryExecutorUser {
  _SchemaUser(this.version);
  final int version;

  @override
  int get schemaVersion => version;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

Future<void> _seedLegacyDatabase(File dbFile, int version) async {
  final seedDb = NativeDatabase(
    dbFile,
    setup: (raw) {
      raw.execute('PRAGMA foreign_keys = ON;');
      raw.execute(
        'CREATE TABLE game_settings ('
        'key TEXT NOT NULL PRIMARY KEY, '
        'value TEXT NOT NULL);',
      );
      raw.execute(
        "INSERT INTO game_settings VALUES ('audio.bgm_enabled', 'false');",
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
          'skill_level INTEGER NOT NULL DEFAULT 1, '
          'unlocked INTEGER NOT NULL DEFAULT 1, '
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
          'player_id TEXT NOT NULL, '
          'slot TEXT NOT NULL, '
          'equipment_instance_id TEXT NOT NULL, '
          'PRIMARY KEY (player_id, slot), '
          'FOREIGN KEY (player_id, equipment_instance_id) '
          'REFERENCES equipment_instances (player_id, instance_id) ON DELETE CASCADE);',
        );
        final clearedCycleCol = version >= 3
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
          '$clearedCycleCol'
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
          "INSERT INTO players VALUES ('default_player', 20, 450, 3200, 180, 'vanguard', '{}', 7, 1700000000000);",
        );
        raw.execute(
          "INSERT INTO inventory_entries VALUES ('default_player', 'slime_gel', 14);",
        );
        raw.execute(
          'INSERT INTO dungeon_progresses VALUES ('
          "'default_player', 'forgotten_forest', 'forest_entrance', 0, 4, 2"
          '${version >= 3 ? ', 0' : ''}'
          ", '{}');",
        );
        raw.execute(
          "INSERT INTO game_sessions VALUES ('default_player', 'default_player', 1700000000000, 1700000000000, 1700000000000, 1, '{}');",
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
        raw.execute(
          'INSERT INTO cycle_progresses VALUES ('
          "'default_player', 1${version >= 4 ? ', 2' : ''}, 'forgotten_forest', 1700000000000);",
        );
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
          "INSERT INTO shop_purchases VALUES ('default_player', 'shop_rusty_sword', 1);",
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
          "INSERT INTO currencies VALUES ('default_player', 'aether_shard', 75);",
        );
        raw.execute(
          "INSERT INTO periodic_quest_states VALUES ('default_player', 'daily_boss', '2026-04-01', 1700000005000);",
        );
      }

      if (version >= 7) {
        raw.execute(
          'CREATE TABLE event_shop_purchases ('
          'player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE, '
          'entry_id TEXT NOT NULL, '
          'period_key TEXT NOT NULL, '
          'purchased_count INTEGER NOT NULL DEFAULT 0, '
          'PRIMARY KEY (player_id, entry_id, period_key));',
        );
        raw.execute(
          "INSERT INTO event_shop_purchases VALUES ('default_player', 'evt_dawn_blade', '2026-W14', 1);",
        );
      }

      raw.execute('PRAGMA user_version = $version;');
    },
  );
  await seedDb.ensureOpen(_SchemaUser(version));
  await seedDb.close();
}

EquipmentInstance _makeSword(String id, {double atk = 15, double hpPct = 0}) =>
    EquipmentInstance(
      id: id,
      definitionId: 'rusty_sword',
      slot: EquipmentSlot.weapon,
      rarity: ItemRarity.rare,
      rolledStats: EquipmentStats(atk: atk, hpPct: hpPct),
    );

void main() {
  late GameConfig config;

  setUpAll(() {
    config = _loadRealConfig();
  });

  group('DriftPlayerSaveRepository.replaceSnapshot', () {
    test('menghapus baris lama yang tidak ada di snapshot, menjaga GameSettings, mengosongkan sesi aktif, menyetel jangkar offline & pause, dan merge ClockState max', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: const _FixedGameClock(8000000),
      );

      await repo.saveSettings(
        const GameSettingsData(
          bgmEnabled: false,
          sfxEnabled: false,
          bgmVolume: 0.25,
          notifyAutoFarmingFull: false,
        ),
      );

      final dungeonIds = config.dungeons.keys.toList()..sort();
      final primaryDungeonId = dungeonIds.first;
      final extraDungeonId = dungeonIds.last;
      final shopId1 = config.shop.entries[0].id;
      final shopId2 = config.shop.entries[1].id;
      final evtId1 = config.eventShop!.pool[0].id;

      final oldLocal = PlayerSaveSnapshot(
        character: PlayerCharacterSnapshot(
          progress: const PlayerProgress(
            level: 30,
            currentExp: 900,
            gold: 9999,
          ),
          specializationId: 'vanguard',
          equipped: {EquipmentSlot.weapon: _makeSword('old_equipped_eq')},
        ),
        inventory: InventorySnapshot(
          stacks: const {'slime_gel': 50, 'goblin_ear': 33},
          equipment: [_makeSword('old_sold_eq_1'), _makeSword('old_sold_eq_2')],
          equipmentCounter: 99,
        ),
        dungeon: DungeonProgressSnapshot(
          currentDungeonId: primaryDungeonId,
          currentRoomId:
              config.dungeons[primaryDungeonId]!.rooms.values.first.id,
          clearsCount: 10,
        ),
        dungeonProgresses: {
          primaryDungeonId: DungeonProgressSnapshot(
            currentDungeonId: primaryDungeonId,
            currentRoomId:
                config.dungeons[primaryDungeonId]!.rooms.values.first.id,
            clearsCount: 10,
          ),
          extraDungeonId: DungeonProgressSnapshot(
            currentDungeonId: extraDungeonId,
            currentRoomId:
                config.dungeons[extraDungeonId]!.rooms.values.first.id,
            clearsCount: 7,
          ),
        },
        session: const GameSessionSnapshot(
          lastActiveAtMs: 7000000,
          lastSavedAtMs: 7000000,
          lastOfflineClaimAtMs: 7000000,
        ),
        claimedEventIds: {
          'shop:$shopId1',
          'shop:$shopId2',
          'offline_kill:old_run:e1',
        },
        activeDungeonSession: ActiveDungeonSessionSnapshot(
          runId: 'old_active_run',
          dungeonId: primaryDungeonId,
          currentRoomId:
              config.dungeons[primaryDungeonId]!.rooms.values.first.id,
          currentRoomIndex: 0,
          status: DungeonSessionStatus.inProgress,
        ),
        offlineActivity: OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.interrupted,
          selectedDungeonId: primaryDungeonId,
          activeRunId: 'old_offline_run',
          lastCheckpointAtMs: 7100000,
        ),
        shopPurchases: {shopId1: 1, shopId2: 1},
        eventShopPurchases: [
          EventShopPurchaseRecord(
            entryId: evtId1,
            periodKey: '2026-W10',
            purchasedCount: 1,
          ),
        ],
        currencies: const {'aether_shard': 200},
        clockState: const ClockState(
          lastSeenAtMs: 9500000,
          forwardJumpCount: 0,
          maxForwardJumpMs: 0,
        ),
        periodicQuestStates: const [
          PeriodicQuestState(
            questId: 'daily_boss',
            periodKey: '2026-04-10',
            completedAtMs: 7000000,
          ),
        ],
      );
      await repo.saveSnapshot(oldLocal);

      // Snapshot cloud hanya punya progres berbeda (tanpa goblin_ear, old_sold_eq_*,
      // extraDungeonId, shopId2, eventShopPurchases, maupun daily_boss 2026-04-10).
      final restoredInput = PlayerSaveSnapshot(
        character: PlayerCharacterSnapshot(
          progress: const PlayerProgress(
            level: 18,
            currentExp: 120,
            gold: 1500,
          ),
          specializationId: 'arcanist',
          equipped: {
            EquipmentSlot.weapon: _makeSword('cloud_eq_1', hpPct: 0.12),
          },
        ),
        inventory: const InventorySnapshot(
          stacks: {'slime_gel': 4},
          equipment: [],
          equipmentCounter: 12,
        ),
        dungeon: DungeonProgressSnapshot(
          currentDungeonId: primaryDungeonId,
          currentRoomId:
              config.dungeons[primaryDungeonId]!.rooms.values.first.id,
          clearsCount: 3,
        ),
        dungeonProgresses: {
          primaryDungeonId: DungeonProgressSnapshot(
            currentDungeonId: primaryDungeonId,
            currentRoomId:
                config.dungeons[primaryDungeonId]!.rooms.values.first.id,
            clearsCount: 3,
          ),
        },
        session: const GameSessionSnapshot(
          lastActiveAtMs: 1111111,
          lastSavedAtMs: 1111111,
          lastOfflineClaimAtMs: 1111111,
          autoSkillEnabled: false,
        ),
        claimedEventIds: {'shop:$shopId1'},
        activeDungeonSession: ActiveDungeonSessionSnapshot(
          runId: 'should_be_cleared',
          dungeonId: primaryDungeonId,
          currentRoomId:
              config.dungeons[primaryDungeonId]!.rooms.values.first.id,
          currentRoomIndex: 0,
          status: DungeonSessionStatus.inProgress,
        ),
        offlineActivity: OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.pending,
          selectedDungeonId: primaryDungeonId,
        ),
        shopPurchases: {shopId1: 1},
        currencies: const {'aether_shard': 45},
        clockState: const ClockState(
          lastSeenAtMs: 4200000,
          forwardJumpCount: 2,
          maxForwardJumpMs: 3600000,
        ),
      );

      const restoredAtMs = 8000000;
      await repo.replaceSnapshot(restoredInput, restoredAtMs: restoredAtMs);

      final loaded = (await repo.loadSnapshot())!;
      expect(loaded.character.progress.level, 18);
      expect(loaded.character.progress.gold, 1500);
      expect(loaded.character.specializationId, 'arcanist');
      expect(loaded.inventory.stacks, {'slime_gel': 4});
      expect(loaded.inventory.equipment, isEmpty);
      expect(loaded.character.equipped[EquipmentSlot.weapon]!.id, 'cloud_eq_1');

      // Data lama yang tidak ada di snapshot cloud benar-benar terhapus.
      expect(loaded.dungeonProgresses.containsKey(extraDungeonId), false);
      expect(loaded.shopPurchases.containsKey(shopId2), false);
      expect(loaded.eventShopPurchases, isEmpty);
      expect(loaded.periodicQuestStates, isEmpty);
      expect(loaded.claimedEventIds, {'shop:$shopId1'});

      // Sesi dungeon aktif dikosongkan dan mode offline dipause.
      expect(loaded.activeDungeonSession, isNull);
      expect(loaded.offlineActivity.mode, OfflineActivityMode.pauseProgression);
      expect(loaded.offlineActivity.state, OfflineActivityState.inactive);

      // Jangkar offline disetel tepat ke restoredAtMs dan tidak memicu kredit lama.
      expect(loaded.session.lastOfflineClaimAtMs, restoredAtMs);
      expect(loaded.session.lastSavedAtMs, restoredAtMs);
      expect(loaded.session.lastActiveAtMs, restoredAtMs);

      final offlineWindow =
          const OfflineTimeCalculator(maxOfflineDuration: Duration(hours: 8))
              .calculate(
                session: loaded.session,
                activity: loaded.offlineActivity,
                nowMs: restoredAtMs,
              );
      expect(offlineWindow.effectiveElapsed, Duration.zero);

      // ClockState.lastSeenAtMs mengambil max(restored 4.2M, local 9.5M) = 9.5M.
      expect(loaded.clockState.lastSeenAtMs, 9500000);
      expect(loaded.clockState.forwardJumpCount, 2);

      // GameSettings tetap utuh.
      final settings = await repo.loadSettings();
      expect(settings.bgmEnabled, false);
      expect(settings.sfxEnabled, false);
      expect(settings.bgmVolume, 0.25);
      expect(settings.notifyAutoFarmingFull, false);
    });

    test('kegagalan di tengah transaksi replaceSnapshot tidak mengubah data lokal apa pun', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: const _FixedGameClock(5000000),
      );

      final dungeonId = config.dungeons.keys.first;
      final roomId = config.dungeons[dungeonId]!.rooms.values.first.id;
      await repo.saveSnapshot(
        PlayerSaveSnapshot(
          character: PlayerCharacterSnapshot(
            progress: const PlayerProgress(level: 15, gold: 4321),
            equipped: {EquipmentSlot.weapon: _makeSword('original_sword')},
          ),
          inventory: InventorySnapshot(
            stacks: const {'slime_gel': 22},
            equipment: [_makeSword('original_bag_item')],
            equipmentCounter: 5,
          ),
          dungeon: DungeonProgressSnapshot(
            currentDungeonId: dungeonId,
            currentRoomId: roomId,
            clearsCount: 8,
          ),
          currencies: const {'aether_shard': 99},
        ),
      );

      final replacement = PlayerSaveSnapshot(
        character: const PlayerCharacterSnapshot(
          progress: PlayerProgress(level: 1, gold: 0),
        ),
        inventory: const InventorySnapshot(),
        dungeon: DungeonProgressSnapshot(
          currentDungeonId: dungeonId,
          currentRoomId: roomId,
        ),
      );

      await expectLater(
        () => repo.replaceSnapshot(
          replacement,
          restoredAtMs: 6000000,
          beforeCommitHook: () => throw StateError('Simulated crash mid-tx'),
        ),
        throwsStateError,
      );

      final afterRollback = (await repo.loadSnapshot())!;
      expect(afterRollback.character.progress.level, 15);
      expect(afterRollback.character.progress.gold, 4321);
      expect(
        afterRollback.character.equipped[EquipmentSlot.weapon]!.id,
        'original_sword',
      );
      expect(afterRollback.inventory.equipment.single.id, 'original_bag_item');
      expect(afterRollback.inventory.stacks['slime_gel'], 22);
      expect(afterRollback.currencies['aether_shard'], 99);
    });
  });

  group('DriftCloudSyncStateRepository, LocalBackupService & Migrasi v1..v7 -> v8', () {
    test('deviceId dibuat acak memakai Random.secure dan bertahan permanen di CloudSyncStates', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final syncRepo = DriftCloudSyncStateRepository(
        db: db,
        secureRandom: math.Random(42),
      );

      final created = await syncRepo.getOrCreateState();
      expect(created.deviceId, isNotEmpty);
      expect(created.deviceId.length, 36);
      expect(created.lastSyncedRevision, 0);

      await syncRepo.markSynced(
        revision: 3,
        blobSha256: 'a' * 64,
        syncedAtMs: 123456789,
      );
      final afterSync = await syncRepo.getOrCreateState();
      expect(afterSync.deviceId, created.deviceId);
      expect(afterSync.lastSyncedRevision, 3);
      expect(afterSync.lastSyncedBlobSha256, 'a' * 64);
      expect(afterSync.lastSyncAtMs, 123456789);
      expect(afterSync.lastRejectCode, isNull);

      await syncRepo.markRejected(
        code: 'permission-denied',
        rejectedAtMs: 200000000,
      );
      final afterReject = await syncRepo.getOrCreateState();
      expect(afterReject.lastRejectCode, 'permission-denied');
      expect(afterReject.lastRejectAtMs, 200000000);

      await syncRepo.updateServerOffset(
        offsetMs: -450000,
        measuredAtMs: 200000100,
      );
      final afterOffset = await syncRepo.getOrCreateState();
      expect(afterOffset.serverOffsetMs, -450000);
      expect(afterOffset.serverOffsetAtMs, 200000100);
    });

    test('LocalBackupService hanya mempertahankan 3 cadangan terbaru dan bisa dibongkar kembali', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final backups = LocalBackupService(db: db);
      final dungeonId = config.dungeons.keys.first;
      final roomId = config.dungeons[dungeonId]!.rooms.values.first.id;

      for (var i = 1; i <= 5; i++) {
        await backups.saveBackup(
          PlayerSaveSnapshot(
            character: PlayerCharacterSnapshot(
              progress: PlayerProgress(level: i * 10, gold: i * 100),
            ),
            inventory: const InventorySnapshot(),
            dungeon: DungeonProgressSnapshot(
              currentDungeonId: dungeonId,
              currentRoomId: roomId,
            ),
          ),
          reason: 'pre_restore_$i',
          createdAtMs: 1000000 + i * 1000,
        );
      }

      final stored = await backups.listBackups();
      expect(stored, hasLength(3));
      expect(stored.map((b) => b.reason), [
        'pre_restore_5',
        'pre_restore_4',
        'pre_restore_3',
      ]);

      final restored = backups.restoreFromRecord(stored.first, config: config);
      expect(restored.character.progress.level, 50);
      expect(restored.character.progress.gold, 500);
    });

    test('instalasi baru membuat schemaVersion 8 dengan CloudSyncStates dan LocalSaveBackups', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      expect(db.schemaVersion, 8);
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      expect(
        tables.map((r) => r.read<String>('name')),
        containsAll(['cloud_sync_states', 'local_save_backups']),
      );
    });

    for (final oldVersion in [1, 2, 3, 4, 5, 6, 7]) {
      test(
        'migrasi v$oldVersion -> v8 mempertahankan data nyata dan membuat tabel CloudSyncStates & LocalSaveBackups',
        () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'eoa_m14_v${oldVersion}_test_',
          );
          addTearDown(() async {
            if (await tempDir.exists()) {
              await tempDir.delete(recursive: true);
            }
          });
          final dbFile = File('${tempDir.path}/echoes_v$oldVersion.sqlite');
          await _seedLegacyDatabase(dbFile, oldVersion);

          final migratedDb = AppDatabase(NativeDatabase(dbFile));
          addTearDown(migratedDb.close);
          await migratedDb.initialize();

          expect(migratedDb.schemaVersion, 8);

          final versionRow = await migratedDb
              .customSelect('PRAGMA user_version')
              .getSingle();
          expect(versionRow.read<int>('user_version'), 8);

          final repo = DriftPlayerSaveRepository(
            db: migratedDb,
            config: config,
          );
          final settings = await repo.loadSettings();
          expect(settings.bgmEnabled, false);

          if (oldVersion >= 2) {
            final snap = (await repo.loadSnapshot())!;
            expect(snap.character.progress.level, 20);
            expect(snap.character.progress.gold, 3200);
            expect(snap.inventory.stacks['slime_gel'], 14);
            expect(snap.dungeon.clearsCount, 2);
          }
          if (oldVersion >= 6) {
            final snap = (await repo.loadSnapshot())!;
            expect(snap.currencies['aether_shard'], 75);
            expect(snap.periodicQuestStates, hasLength(1));
          }
          if (oldVersion >= 7) {
            final snap = (await repo.loadSnapshot())!;
            expect(snap.eventShopPurchases, hasLength(1));
            expect(snap.eventShopPurchases.single.entryId, 'evt_dawn_blade');
          }

          // Tabel v8 baru siap digunakan segera setelah migrasi.
          final syncStateRepo = DriftCloudSyncStateRepository(db: migratedDb);
          final state = await syncStateRepo.getOrCreateState();
          expect(state.deviceId, isNotEmpty);
          expect(state.lastSyncedRevision, 0);

          final backupSvc = LocalBackupService(
            db: migratedDb,
            clock: const _FixedGameClock(1700000100000),
          );
          final backup = await backupSvc.saveBackup(
            PlayerSaveSnapshot(
              character: const PlayerCharacterSnapshot(
                progress: PlayerProgress(level: 20, gold: 3200),
              ),
              inventory: const InventorySnapshot(),
              dungeon: DungeonProgressSnapshot(
                currentDungeonId: config.dungeons.keys.first,
                currentRoomId:
                    config.dungeons.values.first.rooms.values.first.id,
              ),
            ),
            reason: 'post_migration_test',
          );
          expect(backup.schemaVersion, 8);
        },
      );
    }
  });

  group('InMemoryCloudSaveRepository', () {
    const metrics = SaveMetrics(
      level: 10,
      gold: 500,
      shards: 20,
      highestAscensionRank: 1,
      lifetimeClears: 3,
      dailyQuestDone: 1,
      weeklyQuestDone: 0,
      eventPurchasesLifetime: 0,
      equipmentCount: 2,
      blobBytes: 4,
      blobSha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      schemaVersion: 8,
      codecVersion: 1,
    );

    test('menyimpan dua slot bergantian (r % 2), mendeteksi konflik, dan mensimulasikan penolakan/jaringan putus', () async {
      var now = 1000000;
      final cloud = InMemoryCloudSaveRepository(serverNowMs: () => now);

      expect(
        await cloud.latestMeta(),
        isA<CloudSuccess<CloudSaveMeta?>>().having(
          (s) => s.value,
          'value',
          isNull,
        ),
      );

      // Revisi 1 -> slot 1
      final up1 = await cloud.upload(
        CloudSaveUploadRequest(
          expectedBaseRevision: 0,
          newRevision: 1,
          deviceId: 'dev_1',
          appVersion: '1.0.0+1',
          metrics: metrics,
          blob: Uint8List.fromList([1, 2, 3, 4]),
        ),
      );
      expect(up1, isA<CloudSuccess<CloudSaveMeta>>());
      expect(cloud.slotData(1)!.meta.revision, 1);
      expect(cloud.slotData(0), isNull);

      // Revisi 2 -> slot 0, slot 1 tetap menyimpan revisi 1
      now += 60000;
      final up2 = await cloud.upload(
        CloudSaveUploadRequest(
          expectedBaseRevision: 1,
          newRevision: 2,
          deviceId: 'dev_1',
          appVersion: '1.0.0+1',
          metrics: metrics,
          blob: Uint8List.fromList([5, 6, 7, 8]),
        ),
      );
      expect(up2, isA<CloudSuccess<CloudSaveMeta>>());
      expect(cloud.slotData(0)!.meta.revision, 2);
      expect(cloud.slotData(1)!.meta.revision, 1);

      // Konflik revisi saat expectedBaseRevision basi (1 vs terkini 2)
      final staleUpload = await cloud.upload(
        CloudSaveUploadRequest(
          expectedBaseRevision: 1,
          newRevision: 2,
          deviceId: 'dev_2',
          appVersion: '1.0.0+1',
          metrics: metrics,
          blob: Uint8List.fromList([9, 9, 9, 9]),
        ),
      );
      expect(
        staleUpload,
        isA<CloudRejected<CloudSaveMeta>>()
            .having((r) => r.isConflict, 'isConflict', true)
            .having((r) => r.currentRevision, 'currentRevision', 2),
      );

      // Simulasi jaringan putus
      cloud
        ..nextFault = CloudFaultMode.networkError
        ..oneShotFault = true;
      expect(
        await cloud.download(),
        isA<CloudNetworkError<CloudSaveDownload?>>(),
      );

      // Operasi berikutnya kembali sukses setelah oneShotFault reset
      final dl = await cloud.download();
      expect(
        dl,
        isA<CloudSuccess<CloudSaveDownload?>>().having(
          (s) => s.value!.meta.revision,
          'rev',
          2,
        ),
      );

      // Simulasi penolakan server (rules rejection)
      cloud
        ..nextFault = CloudFaultMode.rejected
        ..nextRejectCode = 'metric_regression';
      final rejected = await cloud.upload(
        CloudSaveUploadRequest(
          expectedBaseRevision: 2,
          newRevision: 3,
          deviceId: 'dev_1',
          appVersion: '1.0.0+1',
          metrics: metrics,
          blob: Uint8List.fromList([1, 1, 1, 1]),
        ),
      );
      expect(
        rejected,
        isA<CloudRejected<CloudSaveMeta>>().having(
          (r) => r.code,
          'code',
          'metric_regression',
        ),
      );
    });
  });
}
