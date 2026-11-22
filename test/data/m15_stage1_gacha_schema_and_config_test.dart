import 'dart:io';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/models/boss_events_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/event_shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/gacha_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/currency_config.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/gacha_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
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
    shop: const ShopConfigParser().parse(_readAsset('shop.json')),
    eventShop: const EventShopConfigParser().parse(
      _readAsset('event_shop.json'),
    ),
    gacha: const GachaConfigParser().parse(_readAsset('gacha_banners.json')),
  );
}

void main() {
  late GameConfig realConfig;

  setUpAll(() {
    realConfig = _loadRealConfig();
  });

  group('M15 Stage 1 — Gacha Config & Parsers', () {
    test('gacha_banners.json terurai lengkap dan valid', () {
      final gachaJson = File('assets/data/gacha_banners.json')
          .readAsStringSync();
      final gacha = const GachaConfigParser().parse(gachaJson);

      expect(gacha.cycleDays, 21);
      expect(gacha.costPerPull, 30);
      expect(gacha.costPerTenPull, 300);
      expect(gacha.currencyId, kAetherShardCurrencyId);
      expect(gacha.duplicateCurrencyId, kSoulPrismCurrencyId);
      expect(gacha.duplicateGrantedAmount, 1);

      final classBanner = gacha.bannerByType(GachaBannerType.classBanner);
      expect(classBanner, isNotNull);
      expect(classBanner!.hardPity, 40);
      expect(classBanner.baseRate, 0.015);
      expect(classBanner.featuredPool, hasLength(6));
      expect(
        classBanner.featuredPool,
        containsAll([
          'paladin',
          'voidblade',
          'chronomancer',
          'gunslinger',
          'necromancer',
          'stormcaller',
        ]),
      );

      final weaponBanner = gacha.bannerByType(GachaBannerType.weaponBanner);
      expect(weaponBanner, isNotNull);
      expect(weaponBanner!.hardPity, 30);
      expect(weaponBanner.baseRate, 0.02);
      expect(weaponBanner.featuredPool, hasLength(6));
      expect(
        weaponBanner.featuredPool,
        containsAll([
          'dawns_aegis_blade',
          'shadowfang_twinblade',
          'hourglass_of_eternity',
          'aether_railgun',
          'scythe_of_the_harvester',
          'thunderlords_scepter',
        ]),
      );

      expect(gacha.sanctuaryExchange.currencyId, kSoulPrismCurrencyId);
      expect(gacha.sanctuaryExchange.classCost, 3);
      expect(gacha.sanctuaryExchange.weaponCost, 2);
    });

    test('Specializations memuat 3 class Legendary dan 6 class Mythical dengan relasi senjata', () {
      final specs = realConfig.specializations.definitions;
      expect(specs.length, greaterThanOrEqualTo(9));

      // 3 class dasar
      for (final id in ['vanguard', 'arcanist', 'ranger']) {
        expect(specs[id], isNotNull);
        expect(specs[id]!.rarity, ItemRarity.legendary);
      }

      // 6 class mythical gacha
      final mythicalIds = [
        'paladin',
        'voidblade',
        'chronomancer',
        'gunslinger',
        'necromancer',
        'stormcaller',
      ];
      for (final id in mythicalIds) {
        final def = specs[id];
        expect(def, isNotNull);
        expect(def!.rarity, ItemRarity.mythical);
        expect(def.signatureWeaponId, isNotNull);
        expect(realConfig.items.containsKey(def.signatureWeaponId), isTrue);
      }
    });

    test(
      'Items memuat 6 Senjata Mythical dengan Signature Trait dan slot weapon',
      () {
        final weapons = [
          ('dawns_aegis_blade', 'paladin'),
          ('shadowfang_twinblade', 'voidblade'),
          ('hourglass_of_eternity', 'chronomancer'),
          ('aether_railgun', 'gunslinger'),
          ('scythe_of_the_harvester', 'necromancer'),
          ('thunderlords_scepter', 'stormcaller'),
        ];

        for (final (weaponId, expectedClassId) in weapons) {
          final item = realConfig.items[weaponId];
          expect(
            item,
            isNotNull,
            reason: 'Weapon $weaponId harus ada di items.json',
          );
          expect(item!.rarity, ItemRarity.mythical);
          expect(item.category, ItemCategory.equipment);
          expect(item.equipment, isNotNull);
          expect(item.equipment!.slot, EquipmentSlot.weapon);
          expect(item.equipment!.signatureClassId, expectedClassId);
          expect(item.equipment!.resonanceDescription, isNotEmpty);
        }
      },
    );

    test('GameConfigValidator memvalidasi seluruh konfigurasi gacha dan mata uang soul_prism', () {
      expect(
        () => const GameConfigValidator().validate(realConfig),
        returnsNormally,
      );
      expect(realConfig.currencies.containsKey(kSoulPrismCurrencyId), isTrue);
    });
  });

  group(
    'M15 Stage 1 — SaveSnapshotCodec Gacha Pity & Unlocked Specializations',
    () {
      const codec = SaveSnapshotCodec();

      test('Encode dan decode mempertahankan gachaPityStates dan unlockedSpecializations', () {
        const pityClass = GachaPityState(
          bannerType: 'class',
          pullCount: 25,
          isGuaranteed: true,
        );
        const pityWeapon = GachaPityState(
          bannerType: 'weapon',
          pullCount: 12,
          isGuaranteed: false,
        );

        final snapshot = PlayerSaveSnapshot(
          playerId: 'player_gacha_test',
          character: const PlayerCharacterSnapshot(
            progress: PlayerProgress(level: 15, currentExp: 50, gold: 5000),
            specializationId: 'paladin',
          ),
          inventory: const InventorySnapshot(),
          currencies: const {
            kAetherShardCurrencyId: 450,
            kSoulPrismCurrencyId: 2,
          },
          gachaPityStates: const {'class': pityClass, 'weapon': pityWeapon},
          unlockedSpecializations: const {
            'vanguard',
            'arcanist',
            'ranger',
            'paladin',
          },
        );

        final encoded = codec.encodeToCanonicalJson(snapshot);
        final decoded = codec.decodeFromCanonicalJson(
          encoded,
          config: realConfig,
        );

        expect(decoded.gachaPityStates['class']?.pullCount, 25);
        expect(decoded.gachaPityStates['class']?.isGuaranteed, true);
        expect(decoded.gachaPityStates['weapon']?.pullCount, 12);
        expect(decoded.gachaPityStates['weapon']?.isGuaranteed, false);

        expect(
          decoded.unlockedSpecializations,
          containsAll(['vanguard', 'arcanist', 'ranger', 'paladin']),
        );
        expect(decoded.currencies[kSoulPrismCurrencyId], 2);
      });

      test(
        'Decode fallback ke class dasar jika data gacha kosong di save lama',
        () {
          final snapshot = PlayerSaveSnapshot(
            playerId: 'legacy_player',
            character: const PlayerCharacterSnapshot(
              progress: PlayerProgress(level: 5, currentExp: 0, gold: 100),
            ),
            inventory: const InventorySnapshot(),
          );

          final map = codec.encodeToMap(snapshot);
          // Simulasikan save v9 lama tanpa key gacha
          map.remove('gachaPityStates');
          map.remove('unlockedSpecializations');

          final decoded = codec.decodeFromMap(map, config: realConfig);
          expect(decoded.gachaPityStates, isEmpty);
          expect(
            decoded.unlockedSpecializations,
            containsAll(['vanguard', 'arcanist', 'ranger']),
          );
        },
      );
    },
  );

  group('M15 Stage 1 — Drift Database Schema v10 Migration', () {
    test('Database baru terinisialisasi dengan schemaVersion 10 dan default class terbuka', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      expect(db.schemaVersion, 12);

      final versionRow = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(versionRow.read<int>('user_version'), 12);

      // Verifikasi tabel baru ada
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final tableNames = tables.map((r) => r.read<String>('name')).toSet();
      expect(
        tableNames,
        containsAll(['gacha_pity_states', 'unlocked_specializations']),
      );

      // Verifikasi class dasar ter-insert otomatis
      final unlockedRows = await db.select(db.unlockedSpecializations).get();
      final unlockedIds = unlockedRows.map((r) => r.specializationId).toSet();
      expect(unlockedIds, containsAll(['vanguard', 'arcanist', 'ranger']));
    });

    test('DriftPlayerSaveRepository membaca dan menyimpan gachaPityStates serta unlockedSpecializations', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      final repo = DriftPlayerSaveRepository(db: db, config: realConfig);

      const pityClass = GachaPityState(
        bannerType: 'class',
        pullCount: 33,
        isGuaranteed: true,
      );
      final snapshot = PlayerSaveSnapshot(
        playerId: 'default_player',
        character: const PlayerCharacterSnapshot(
          progress: PlayerProgress(level: 20, currentExp: 100, gold: 12000),
          specializationId: 'voidblade',
        ),
        inventory: const InventorySnapshot(),
        currencies: const {
          kAetherShardCurrencyId: 900,
          kSoulPrismCurrencyId: 3,
        },
        gachaPityStates: const {'class': pityClass},
        unlockedSpecializations: const {
          'vanguard',
          'arcanist',
          'ranger',
          'voidblade',
        },
      );

      await repo.replaceSnapshot(snapshot, restoredAtMs: 1234567890);

      final loaded = await repo.loadSnapshot();
      expect(loaded, isNotNull);
      expect(loaded!.gachaPityStates['class']?.pullCount, 33);
      expect(loaded.gachaPityStates['class']?.isGuaranteed, true);
      expect(loaded.unlockedSpecializations, contains('voidblade'));
      expect(loaded.currencies[kSoulPrismCurrencyId], 3);
    });
  });
}
