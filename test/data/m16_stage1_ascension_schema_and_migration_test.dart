import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/models/boss_events_config_parser.dart';
import 'package:echoes_of_aether/data/models/boss_spire_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/event_shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/gacha_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/infinite_spire_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/infinite_spire.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/save_snapshot_codec.dart';
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
    bossSpire: const BossSpireConfigParser().parse(
      _readAsset('boss_spire.json'),
    ),
    shop: const ShopConfigParser().parse(_readAsset('shop.json')),
    eventShop: const EventShopConfigParser().parse(
      _readAsset('event_shop.json'),
    ),
    gacha: const GachaConfigParser().parse(_readAsset('gacha_banners.json')),
    heroAscension: parser.parseHeroAscension(settings),
    infiniteSpire: const InfiniteSpireConfigParser().parse(
      _readAsset('infinite_spire.json'),
    ),
  );
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

void main() {
  late GameConfig realConfig;

  setUpAll(() {
    realConfig = _loadRealConfig();
  });

  group('M16 Stage 1 — Configuration JSON & Validation', () {
    test(
      'game_config.json memiliki max_level = 90 dan hero_ascension lengkap',
      () {
        expect(realConfig.progression.maxLevel, 90);

        final asc = realConfig.heroAscension;
        expect(asc.maxPhase, 6);
        expect(asc.phases, hasLength(7));

        // Phase 0: 1-20
        final a0 = asc.phase(0)!;
        expect(a0.levelCap, 20);
        expect(a0.cost.gold, 0);
        expect(a0.cost.items, isEmpty);
        expect(a0.statBoost.hp, 0);

        // Phase 1: 20-40
        final a1 = asc.phase(1)!;
        expect(a1.levelCap, 40);
        expect(a1.cost.gold, 500);
        expect(a1.cost.items['boss_remnant'], 3);
        expect(a1.statBoost.hp, 50);
        expect(a1.statBoost.atk, 8);
        expect(a1.statBoost.def, 3);

        // Phase 2: 40-50
        final a2 = asc.phase(2)!;
        expect(a2.levelCap, 50);
        expect(a2.cost.gold, 1500);
        expect(a2.cost.items['boss_remnant'], 4);
        expect(a2.cost.items['aether_scrap'], 10);
        expect(a2.statBoost.critRate, 0.02);

        // Phase 6: 80-90
        final a6 = asc.phase(6)!;
        expect(a6.levelCap, 90);
        expect(a6.cost.gold, 15000);
        expect(a6.cost.items['void_essence'], 5);
        expect(a6.cost.items['aether_scrap'], 50);
        expect(a6.cost.currencies['aether_shard'], 100);
        expect(a6.statBoost.hp, 300);
        expect(a6.statBoost.atk, 35);
        expect(a6.statBoost.def, 15);
        expect(a6.hasGoldenAura, isTrue);
      },
    );

    test('infinite_spire.json terurai lengkap 100 lantai dan valid', () {
      final spire = realConfig.infiniteSpire;
      expect(spire, isNotNull);
      expect(spire!.totalFloors, 100);
      expect(spire.floors, hasLength(100));

      final f1 = spire.floor(1)!;
      expect(f1.floor, 1);
      expect(f1.recommendedLevel, 20);
      expect(f1.isBossFloor, isFalse);
      expect(f1.reward.exp, greaterThan(0));
      expect(f1.reward.currencies['aether_shard'], 5);

      final f10 = spire.floor(10)!;
      expect(f10.floor, 10);
      expect(f10.isBossFloor, isTrue);
      expect(f10.bossId, 'corrupted_guardian');
      expect(f10.reward.currencies['soul_prism'], 1);

      final f100 = spire.floor(100)!;
      expect(f100.floor, 100);
      expect(f100.recommendedLevel, 90);
      expect(f100.isBossFloor, isTrue);
      expect(f100.bossId, 'aether_sovereign');
    });

    test(
      'GameConfigValidator memvalidasi seluruh konfigurasi M16 tanpa error',
      () {
        expect(
          () => const GameConfigValidator().validate(realConfig),
          returnsNormally,
        );
      },
    );
  });

  group('M16 Stage 1 — Drift Schema v11 & Fresh DB Initialization', () {
    test('Database baru terinisialisasi dengan schemaVersion 11 dan tabel infinite_spire_progress', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      expect(db.schemaVersion, 11);

      final versionRow = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(versionRow.read<int>('user_version'), 11);

      // Verifikasi tabel infinite_spire_progress ada
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final tableNames = tables.map((r) => r.read<String>('name')).toSet();
      expect(tableNames, contains('infinite_spire_progress'));

      // Verifikasi kolom ascension_phase di tabel players
      final playerColumns = await db
          .customSelect("PRAGMA table_info('players')")
          .get();
      final columnNames = playerColumns
          .map((r) => r.read<String>('name'))
          .toSet();
      expect(columnNames, contains('ascension_phase'));
    });
  });

  group(
    'M16 Stage 1 — Migration v10 -> v11 Smart Conversion & Legacy Protection',
    () {
      test('Migrasi v10 -> v11 mengonversi level pemain lama ke fase Ascension, clamping Lv > 90, dan hadiah kompensasi', () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'echoes_mig_v10_to_v11_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final dbFile = File('${tempDir.path}/legacy_v10.sqlite');

        // 1. Buat SQLite database v10 manual dengan data nyata
        final rawDb = NativeDatabase(
          dbFile,
          setup: (raw) {
            raw.execute('PRAGMA foreign_keys = ON;');
            raw.execute('PRAGMA user_version = 10;');
            raw.execute('''
            CREATE TABLE players (
              id TEXT NOT NULL PRIMARY KEY,
              level INTEGER NOT NULL,
              current_exp INTEGER NOT NULL,
              gold INTEGER NOT NULL,
              current_hp INTEGER,
              active_specialization_id TEXT,
              base_stats_json TEXT NOT NULL,
              equipment_counter INTEGER NOT NULL DEFAULT 0,
              last_saved_at_ms INTEGER NOT NULL
            );
          ''');
            raw.execute('''
            CREATE TABLE cycle_progresses (
              player_id TEXT NOT NULL PRIMARY KEY,
              ascension_rank INTEGER NOT NULL DEFAULT 0,
              highest_ascension_rank INTEGER NOT NULL DEFAULT 0,
              last_normal_dungeon_id TEXT,
              updated_at_ms INTEGER NOT NULL
            );
          ''');
            raw.execute('''
            CREATE TABLE currencies (
              player_id TEXT NOT NULL,
              currency_id TEXT NOT NULL,
              amount INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (player_id, currency_id)
            );
          ''');
            raw.execute('''
            CREATE TABLE gacha_pity_states (
              banner_type TEXT NOT NULL PRIMARY KEY,
              pull_count INTEGER NOT NULL DEFAULT 0,
              is_guaranteed INTEGER NOT NULL DEFAULT 0
            );
          ''');
            raw.execute('''
            CREATE TABLE unlocked_specializations (
              specialization_id TEXT NOT NULL PRIMARY KEY,
              unlocked_at_ms INTEGER NOT NULL
            );
          ''');

            // Masukkan 6 data pemain lama berbeda level:
            // p_beginner: Lv 15 (A0)
            raw.execute('''
            INSERT INTO players VALUES ('p_beginner', 15, 100, 1000, 100, 'vanguard', '{}', 0, 1000000);
          ''');
            // p_adept: Lv 35 (A1)
            raw.execute('''
            INSERT INTO players VALUES ('p_adept', 35, 200, 5000, 200, 'arcanist', '{}', 0, 1000000);
          ''');
            // p_veteran: Lv 65 (A4)
            raw.execute('''
            INSERT INTO players VALUES ('p_veteran', 65, 300, 15000, 300, 'ranger', '{}', 0, 1000000);
          ''');
            // p_master: Lv 85 (A6)
            raw.execute('''
            INSERT INTO players VALUES ('p_master', 85, 400, 30000, 400, 'vanguard', '{}', 0, 1000000);
          ''');
            // p_overleveled: Lv 98 (harus diclamp ke 90, grant A6, kompensasi 8 level = 40.000 gold + 160 shard + 0 soul prism)
            raw.execute('''
            INSERT INTO players VALUES ('p_overleveled', 98, 500, 10000, 500, 'vanguard', '{}', 0, 1000000);
          ''');
            // p_super_overleveled: Lv 110 (harus diclamp ke 90, grant A6, kompensasi 20 level = 100.000 gold + 400 shard + 2 soul prism)
            raw.execute('''
            INSERT INTO players VALUES ('p_super_overleveled', 110, 600, 20000, 600, 'vanguard', '{}', 0, 1000000);
          ''');

            // Masukkan cycle_progresses dengan rank > 5
            raw.execute('''
            INSERT INTO cycle_progresses VALUES ('p_master', 8, 12, 'ancient_crypt', 1000000);
          ''');

            // Masukkan gacha pity & spec
            raw.execute('''
            INSERT INTO gacha_pity_states VALUES ('class', 30, 1);
          ''');
            raw.execute('''
            INSERT INTO unlocked_specializations VALUES ('vanguard', 0), ('voidblade', 1000);
          ''');
          },
        );
        await rawDb.ensureOpen(_SchemaUser(10));
        await rawDb.close();

        // 2. Sekarang buka kembali dengan AppDatabase resmi untuk memicu onUpgrade v10 -> v11
        final migratedDb = AppDatabase(NativeDatabase(dbFile));
        addTearDown(migratedDb.close);
        await migratedDb.initialize();

        expect(migratedDb.schemaVersion, 11);

        // Verifikasi p_beginner (Lv 15 -> A0)
        final rowBeginner = await (migratedDb.select(
          migratedDb.players,
        )..where((t) => t.id.equals('p_beginner'))).getSingle();
        expect(rowBeginner.level, 15);
        expect(rowBeginner.ascensionPhase, 0);
        expect(rowBeginner.gold, 1000);

        // Verifikasi p_adept (Lv 35 -> A1)
        final rowAdept = await (migratedDb.select(
          migratedDb.players,
        )..where((t) => t.id.equals('p_adept'))).getSingle();
        expect(rowAdept.level, 35);
        expect(rowAdept.ascensionPhase, 1);

        // Verifikasi p_veteran (Lv 65 -> A4)
        final rowVeteran = await (migratedDb.select(
          migratedDb.players,
        )..where((t) => t.id.equals('p_veteran'))).getSingle();
        expect(rowVeteran.level, 65);
        expect(rowVeteran.ascensionPhase, 4);

        // Verifikasi p_master (Lv 85 -> A6)
        final rowMaster = await (migratedDb.select(
          migratedDb.players,
        )..where((t) => t.id.equals('p_master'))).getSingle();
        expect(rowMaster.level, 85);
        expect(rowMaster.ascensionPhase, 6);

        // Verifikasi p_overleveled: Level clamped ke 90, A6, Gold bertambah 40.000 (10k -> 50k), Shard 160
        final rowOver = await (migratedDb.select(
          migratedDb.players,
        )..where((t) => t.id.equals('p_overleveled'))).getSingle();
        expect(rowOver.level, 90);
        expect(rowOver.ascensionPhase, 6);
        expect(rowOver.gold, 50000);

        final shardRow =
            await (migratedDb.select(migratedDb.currencies)..where(
                  (t) =>
                      t.playerId.equals('p_overleveled') &
                      t.currencyId.equals('aether_shard'),
                ))
                .getSingle();
        expect(shardRow.amount, 160);

        // Verifikasi p_super_overleveled: Level clamped ke 90, Gold bertambah 100.000 (20k -> 120k), Shard 400, Prism 2
        final rowSuper = await (migratedDb.select(
          migratedDb.players,
        )..where((t) => t.id.equals('p_super_overleveled'))).getSingle();
        expect(rowSuper.level, 90);
        expect(rowSuper.ascensionPhase, 6);
        expect(rowSuper.gold, 120000);

        final superShard =
            await (migratedDb.select(migratedDb.currencies)..where(
                  (t) =>
                      t.playerId.equals('p_super_overleveled') &
                      t.currencyId.equals('aether_shard'),
                ))
                .getSingle();
        expect(superShard.amount, 400);

        final superPrism =
            await (migratedDb.select(migratedDb.currencies)..where(
                  (t) =>
                      t.playerId.equals('p_super_overleveled') &
                      t.currencyId.equals('soul_prism'),
                ))
                .getSingle();
        expect(superPrism.amount, 2);

        // Verifikasi cycle_rank di-clamp ke 5
        final cycleRow = await (migratedDb.select(
          migratedDb.cycleProgresses,
        )..where((t) => t.playerId.equals('p_master'))).getSingle();
        expect(cycleRow.ascensionRank, 5);
        expect(cycleRow.highestAscensionRank, 5);

        // Verifikasi data gacha & specialization tetap utuh
        final pityRow = await (migratedDb.select(
          migratedDb.gachaPityStates,
        )..where((t) => t.bannerType.equals('class'))).getSingle();
        expect(pityRow.pullCount, 30);
        expect(pityRow.isGuaranteed, isTrue);

        final specRows = await migratedDb
            .select(migratedDb.unlockedSpecializations)
            .get();
        final specIds = specRows.map((r) => r.specializationId).toSet();
        expect(specIds, containsAll(['vanguard', 'voidblade']));
      });
    },
  );

  group('M16 Stage 1 — Repository & SaveSnapshotCodec Persistence', () {
    test('DriftPlayerSaveRepository membaca dan menyimpan ascensionPhase dan infiniteSpireProgress', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      final repo = DriftPlayerSaveRepository(db: db, config: realConfig);

      final snapshot = PlayerSaveSnapshot(
        playerId: 'default_player',
        character: const PlayerCharacterSnapshot(
          progress: PlayerProgress(
            level: 50,
            currentExp: 500,
            gold: 25000,
            ascensionPhase: 2,
          ),
          specializationId: 'vanguard',
        ),
        inventory: const InventorySnapshot(),
        infiniteSpireProgress: const InfiniteSpireProgressSnapshot(
          highestFloorCleared: 15,
          claimedFloorRewards: {1, 2, 5, 10},
        ),
      );

      await repo.replaceSnapshot(snapshot, restoredAtMs: 1234567890);

      final loaded = await repo.loadSnapshot();
      expect(loaded, isNotNull);
      expect(loaded!.character.progress.level, 50);
      expect(loaded.character.progress.ascensionPhase, 2);
      expect(loaded.infiniteSpireProgress.highestFloorCleared, 15);
      expect(loaded.infiniteSpireProgress.claimedFloorRewards, {1, 2, 5, 10});
      expect(loaded.infiniteSpireProgress.isFloorCleared(10), isTrue);
      expect(loaded.infiniteSpireProgress.isFloorCleared(16), isFalse);
      expect(loaded.infiniteSpireProgress.isRewardClaimed(10), isTrue);
      expect(loaded.infiniteSpireProgress.isRewardClaimed(11), isFalse);
    });

    test('SaveSnapshotCodec encode dan decode roundtrip secara kanonis untuk data M16', () {
      const codec = SaveSnapshotCodec();

      final snapshot = PlayerSaveSnapshot(
        playerId: 'default_player',
        character: const PlayerCharacterSnapshot(
          progress: PlayerProgress(
            level: 70,
            currentExp: 1200,
            gold: 50000,
            ascensionPhase: 4,
          ),
          specializationId: 'ranger',
        ),
        inventory: const InventorySnapshot(),
        infiniteSpireProgress: const InfiniteSpireProgressSnapshot(
          highestFloorCleared: 30,
          claimedFloorRewards: {10, 20, 30},
        ),
      );

      final jsonCanonical = codec.encodeToCanonicalJson(snapshot);
      expect(jsonCanonical, contains('"ascensionPhase":4'));
      expect(jsonCanonical, contains('"infiniteSpireProgress"'));

      final decoded = codec.decodeFromCanonicalJson(
        jsonCanonical,
        config: realConfig,
      );
      expect(decoded.character.progress.level, 70);
      expect(decoded.character.progress.ascensionPhase, 4);
      expect(decoded.infiniteSpireProgress.highestFloorCleared, 30);
      expect(decoded.infiniteSpireProgress.claimedFloorRewards, {10, 20, 30});

      // Encode ulang kanonis harus identik
      final reEncoded = codec.encodeToCanonicalJson(decoded);
      expect(reEncoded, equals(jsonCanonical));
    });
  });
}
