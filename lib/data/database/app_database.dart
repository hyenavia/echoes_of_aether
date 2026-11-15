import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Tabel pengaturan key-value minimal (v1) — tetap dipertahankan di v2.
class GameSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Progres inti karakter pemain (bukan sumber kebenaran derived stats).
class Players extends Table {
  TextColumn get id => text()();
  IntColumn get level => integer()();
  IntColumn get currentExp => integer()();
  IntColumn get gold => integer()();
  IntColumn get currentHp => integer().nullable()();
  TextColumn get activeSpecializationId => text().nullable()();
  TextColumn get baseStatsJson => text()();
  IntColumn get equipmentCounter => integer().withDefault(const Constant(0))();
  IntColumn get lastSavedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (level >= 1)',
    'CHECK (current_exp >= 0)',
    'CHECK (gold >= 0)',
  ];
}

/// Progres level, unlock, dan sisa cooldown tick masing-masing skill.
class SkillProgresses extends Table {
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();
  TextColumn get skillId => text()();
  IntColumn get skillLevel => integer()();
  BoolColumn get unlocked => boolean()();
  IntColumn get cooldownTicksRemaining =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {playerId, skillId};

  @override
  List<String> get customConstraints => [
    'CHECK (skill_level >= 1)',
    'CHECK (cooldown_ticks_remaining >= 0)',
  ];
}

/// Item stackable / quest item di tas pemain.
class InventoryEntries extends Table {
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemId => text()();
  IntColumn get quantity => integer()();

  @override
  Set<Column<Object>> get primaryKey => {playerId, itemId};

  @override
  List<String> get customConstraints => ['CHECK (quantity > 0)'];
}

/// Seluruh instance equipment milik pemain (baik di tas maupun sedang terpasang).
@DataClassName('EquipmentInstanceRow')
class EquipmentInstances extends Table {
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();
  TextColumn get instanceId => text()();
  TextColumn get definitionId => text()();
  TextColumn get slot => text()();
  TextColumn get rarity => text()();
  TextColumn get rolledStatsJson => text()();
  IntColumn get enhancementLevel => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {playerId, instanceId};
}

/// Referensi slot equipment yang sedang dipakai; menunjuk baris di [EquipmentInstances].
class EquippedItems extends Table {
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();
  TextColumn get slot => text()();
  TextColumn get equipmentInstanceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {playerId, slot};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (player_id, equipment_instance_id) '
        'REFERENCES equipment_instances (player_id, instance_id) '
        'ON DELETE CASCADE',
  ];
}

/// Progres dungeon & room terakhir pemain.
class DungeonProgresses extends Table {
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();
  TextColumn get dungeonId => text()();
  TextColumn get currentRoomId => text()();
  IntColumn get currentRoomIndex => integer()();
  IntColumn get highestClearedRoomIndex => integer()();
  IntColumn get clearsCount => integer()();
  IntColumn get clearedInCycleRank =>
      integer().withDefault(const Constant(-1))();
  TextColumn get rewardStateJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {playerId, dungeonId};
}

/// State siklus ascension pemain dan pilihan dungeon normal terakhir (v3/v4).
class CycleProgresses extends Table {
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();
  IntColumn get ascensionRank => integer().withDefault(const Constant(0))();
  IntColumn get highestAscensionRank =>
      integer().withDefault(const Constant(0))();
  TextColumn get lastNormalDungeonId => text().nullable()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {playerId};

  @override
  List<String> get customConstraints => [
    'CHECK (ascension_rank >= 0)',
    'CHECK (highest_ascension_rank >= 0)',
  ];
}

/// Metadata sesi terakhir (recovery, pengaturan auto-skill, dan cursor offline).
class GameSessions extends Table {
  TextColumn get id => text()();
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();
  IntColumn get lastActiveAtMs => integer()();
  IntColumn get lastSavedAtMs => integer()();
  IntColumn get lastOfflineClaimAtMs => integer()();
  BoolColumn get autoSkillEnabled => boolean()();
  TextColumn get sessionDataJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Log idempoten event reward yang sudah diklaim agar tidak pernah double-claim.
class ClaimedRewards extends Table {
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();
  TextColumn get eventId => text()();
  IntColumn get claimedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {playerId, eventId};
}

/// Riwayat jumlah pembelian item shop per pemain (M10 Stage 1, schema v5).
class ShopPurchases extends Table {
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();
  TextColumn get entryId => text()();
  IntColumn get purchasedCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {playerId, entryId};

  @override
  List<String> get customConstraints => ['CHECK (purchased_count >= 0)'];
}

/// State pengaman jam perangkat per pemain (M12 Stage 1, schema v6).
class ClockStates extends Table {
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();
  IntColumn get lastSeenAtMs => integer().withDefault(const Constant(0))();
  IntColumn get forwardJumpCount => integer().withDefault(const Constant(0))();
  IntColumn get maxForwardJumpMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {playerId};
}

/// Saldo mata uang khusus (mis. Aether Shard) per pemain (M12 Stage 1, schema v6).
class Currencies extends Table {
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();
  TextColumn get currencyId => text()();
  IntColumn get amount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {playerId, currencyId};

  @override
  List<String> get customConstraints => ['CHECK (amount >= 0)'];
}

/// Status penyelesaian quest periodik (Daily/Weekly Boss) (M12 Stage 1, schema v6).
class PeriodicQuestStates extends Table {
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();
  TextColumn get questId => text()();
  TextColumn get periodKey => text()();
  IntColumn get completedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {playerId, questId, periodKey};
}

/// Riwayat pembelian Event Shop per periode per pemain (M13 Stage 1, schema v7).
class EventShopPurchases extends Table {
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();
  TextColumn get entryId => text()();
  TextColumn get periodKey => text()();
  IntColumn get purchasedCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {playerId, entryId, periodKey};

  @override
  List<String> get customConstraints => ['CHECK (purchased_count >= 0)'];
}

/// State sinkronisasi Cloud Save per pemain pada perangkat ini (M14 Stage 1, schema v8).
class CloudSyncStates extends Table {
  TextColumn get playerId => text()();
  TextColumn get deviceId => text()();
  IntColumn get lastSyncedRevision =>
      integer().withDefault(const Constant(0))();
  TextColumn get lastSyncedBlobSha256 => text().nullable()();
  IntColumn get lastSyncAtMs => integer().nullable()();
  TextColumn get lastRejectCode => text().nullable()();
  IntColumn get lastRejectAtMs => integer().nullable()();
  IntColumn get serverOffsetMs => integer().nullable()();
  IntColumn get serverOffsetAtMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {playerId};

  @override
  List<String> get customConstraints => ['CHECK (last_synced_revision >= 0)'];
}

/// Cadangan lokal terkompresi sebelum pemulihan dari cloud (M14 Stage 1, schema v8).
/// Hanya maksimal 3 baris terbaru yang dipertahankan oleh [LocalBackupService].
class LocalSaveBackups extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get createdAtMs => integer()();
  TextColumn get reason => text()();
  IntColumn get schemaVersion => integer()();
  TextColumn get blobSha256 => text()();
  BlobColumn get payload => blob().named('blob')();
}

@DriftDatabase(
  tables: [
    GameSettings,
    Players,
    SkillProgresses,
    InventoryEntries,
    EquipmentInstances,
    EquippedItems,
    DungeonProgresses,
    CycleProgresses,
    GameSessions,
    ClaimedRewards,
    ShopPurchases,
    ClockStates,
    Currencies,
    PeriodicQuestStates,
    EventShopPurchases,
    CloudSyncStates,
    LocalSaveBackups,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? _openDefaultConnection());

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await transaction(() async {
        await m.createAll();
        await _createIndexes();
      });
    },
    onUpgrade: (Migrator m, int from, int to) async {
      await transaction(() async {
        if (from < 2) {
          await m.createTable(players);
          await m.createTable(skillProgresses);
          await m.createTable(inventoryEntries);
          await m.createTable(equipmentInstances);
          await m.createTable(equippedItems);
          await m.createTable(dungeonProgresses);
          await m.createTable(gameSessions);
          await m.createTable(claimedRewards);
          await _createIndexes();
        }
        if (from < 3) {
          await m.createTable(cycleProgresses);
          // Kolom cleared_in_cycle_rank otomatis ikut terbuat bila tabel
          // dungeon_progresses baru dibuat di blok from < 2 (upgrade v1 -> v3).
          if (from >= 2) {
            await m.addColumn(
              dungeonProgresses,
              dungeonProgresses.clearedInCycleRank,
            );
          }
          await customStatement(
            'UPDATE dungeon_progresses SET cleared_in_cycle_rank = 0 WHERE clears_count > 0',
          );
        }
        if (from < 4) {
          if (from >= 3) {
            await m.addColumn(
              cycleProgresses,
              cycleProgresses.highestAscensionRank,
            );
          }
          await customStatement(
            'UPDATE cycle_progresses '
            'SET highest_ascension_rank = ascension_rank '
            'WHERE highest_ascension_rank < ascension_rank',
          );
        }
        if (from < 5) {
          await m.createTable(shopPurchases);
        }
        if (from < 6) {
          await m.createTable(clockStates);
          await m.createTable(currencies);
          await m.createTable(periodicQuestStates);
        }
        if (from < 7) {
          await m.createTable(eventShopPurchases);
        }
        if (from < 8) {
          await m.createTable(cloudSyncStates);
          await m.createTable(localSaveBackups);
        }
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_equipment_player_def '
      'ON equipment_instances (player_id, definition_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_inventory_player '
      'ON inventory_entries (player_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_claimed_rewards_time '
      'ON claimed_rewards (player_id, claimed_at_ms)',
    );
  }

  /// Memastikan database dapat dibuka, migration berjalan, dan siap menerima query.
  Future<void> initialize() async {
    await customSelect('SELECT 1').get();
  }

  static QueryExecutor _openDefaultConnection() =>
      driftDatabase(name: 'echoes_of_aether');
}
