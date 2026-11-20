import 'dart:io';

import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_loadout.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/features/shared/assets/item_sprite_registry.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
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
    heroAscension: parser.parseHeroAscension(settings),
  );
}

void main() {
  late GameConfig config;
  const validator = GameConfigValidator();

  setUpAll(() {
    config = _loadRealConfig();
  });

  group('M16 Stage 3 — Dungeon 6 (The Abyssal Rift) Definition & Graph', () {
    test(
      'Dungeon 6 terdaftar dengan atribut kanonikal dan tervalidasi penuh',
      () {
        expect(() => validator.validate(config), returnsNormally);

        final d6 = config.dungeons['abyssal_rift'];
        expect(d6, isNotNull);
        expect(d6!.name, 'The Abyssal Rift');
        expect(d6.biome, 'abyssal_rift');
        expect(d6.kind, DungeonKind.normal);
        expect(d6.order, 6);
        expect(d6.recommendedLevel, 65);
        expect(d6.unlockRequiresDungeonId, 'aether_sanctum');
        expect(d6.difficultyScale, closeTo(4.5, 1e-6));
        expect(d6.startRoomId, 'ar_chasm_entrance');

        final completion = d6.completionReward;
        expect(completion, isNotNull);
        expect(completion!.expReward, 450);
        expect(completion.goldReward, 220);
        expect(completion.lootTableId, 'abyssal_clear_loot');
      },
    );

    test('Struktur 5 Room Abyssal Rift tersusun sekuensial tanpa siklus', () {
      final d6 = config.dungeons['abyssal_rift']!;
      expect(d6.roomOrder, hasLength(5));
      expect(d6.roomOrder, [
        'ar_chasm_entrance',
        'ar_void_corridor',
        'ar_shadow_depths',
        'ar_abyssal_sanctum',
        'ar_abyssal_core',
      ]);

      expect(d6.roomById('ar_chasm_entrance')!.type, RoomType.normal);
      expect(d6.roomById('ar_void_corridor')!.type, RoomType.normal);
      expect(d6.roomById('ar_shadow_depths')!.type, RoomType.normal);
      expect(d6.roomById('ar_abyssal_sanctum')!.type, RoomType.elite);
      expect(d6.roomById('ar_abyssal_core')!.type, RoomType.boss);

      expect(d6.roomById('ar_chasm_entrance')!.nextRoomIds, [
        'ar_void_corridor',
      ]);
      expect(d6.roomById('ar_void_corridor')!.nextRoomIds, [
        'ar_shadow_depths',
      ]);
      expect(d6.roomById('ar_shadow_depths')!.nextRoomIds, [
        'ar_abyssal_sanctum',
      ]);
      expect(d6.roomById('ar_abyssal_sanctum')!.nextRoomIds, [
        'ar_abyssal_core',
      ]);
      expect(d6.roomById('ar_abyssal_core')!.nextRoomIds, isEmpty);
    });
  });

  group('M16 Stage 3 — Monster & Boss Abyssal Rift', () {
    test('Regular monsters (abyssal_crawler, void_weaver) dan elite (shadow_stalker) terdefinisi benar', () {
      final crawler = config.monsters['abyssal_crawler'];
      expect(crawler, isNotNull);
      expect(crawler!.level, 60);
      expect(crawler.isElite, isFalse);
      expect(crawler.isBoss, isFalse);
      expect(crawler.lootTableId, 'abyssal_normal_loot');

      final weaver = config.monsters['void_weaver'];
      expect(weaver, isNotNull);
      expect(weaver!.level, 62);
      expect(weaver.isElite, isFalse);
      expect(weaver.isBoss, isFalse);
      expect(weaver.lootTableId, 'abyssal_normal_loot');

      final stalker = config.monsters['shadow_stalker'];
      expect(stalker, isNotNull);
      expect(stalker!.level, 65);
      expect(stalker.isElite, isTrue);
      expect(stalker.isBoss, isFalse);
      expect(stalker.lootTableId, 'abyssal_elite_loot');
    });

    test('Boss abyssal_archon memiliki base HP 2.800, ATK 35, DEF 10 dan bukan final boss', () {
      final archon = config.monsters['abyssal_archon'];
      expect(archon, isNotNull);
      expect(archon!.name, 'Abyssal Archon');
      expect(archon.level, 68);
      expect(archon.isBoss, isTrue);
      expect(archon.isFinalBoss, isFalse);
      expect(archon.stats.maxHp, 2800);
      expect(archon.stats.atk, 35);
      expect(archon.stats.def, 10);
      expect(archon.lootTableId, 'abyssal_boss_loot');
    });
  });

  group('M16 Stage 3 — Tier 6 Equipment (Abyssal Set)', () {
    test('8 item Tier 6 (4 Epic & 4 Legendary) terdaftar di items.json dengan stat di atas T5', () {
      const epicIds = [
        'abyssal_blade',
        'abyssal_bow',
        'abyssal_staff',
        'abyssal_cowl',
      ];
      for (final id in epicIds) {
        final item = config.items[id];
        expect(item, isNotNull, reason: 'Item $id harus ada.');
        expect(item!.rarity, ItemRarity.epic);
        expect(item.category, ItemCategory.equipment);
        expect(item.equipment, isNotNull);
      }

      const legIds = [
        'void_cleaver',
        'void_carapace',
        'void_crown',
        'abyssal_eye',
      ];
      for (final id in legIds) {
        final item = config.items[id];
        expect(item, isNotNull, reason: 'Item $id harus ada.');
        expect(item!.rarity, ItemRarity.legendary);
        expect(item.category, ItemCategory.equipment);
        expect(item.equipment, isNotNull);
      }

      // Senjata Legendary T6 Void Cleaver (ATK 30) lebih kuat dari T5 Celestial Blade (ATK 21)
      final voidCleaver = config.items['void_cleaver']!;
      final celestialBlade = config.items['celestial_blade']!;
      expect(
        voidCleaver.equipment!.baseStats.atk,
        greaterThan(celestialBlade.equipment!.baseStats.atk),
      );

      // Armor Legendary T6 Void Carapace (DEF 11, HP 110) lebih kuat dari T5 Celestial Plate (DEF 8, HP 80)
      final voidCarapace = config.items['void_carapace']!;
      final celestialPlate = config.items['celestial_plate']!;
      expect(
        voidCarapace.equipment!.baseStats.def,
        greaterThan(celestialPlate.equipment!.baseStats.def),
      );
      expect(
        voidCarapace.equipment!.baseStats.hp,
        greaterThan(celestialPlate.equipment!.baseStats.hp),
      );
    });

    test('Seluruh 8 item T6 memiliki sprite mapping di ItemSpriteRegistry', () {
      const allT6Ids = [
        'abyssal_blade',
        'abyssal_bow',
        'abyssal_staff',
        'abyssal_cowl',
        'void_cleaver',
        'void_carapace',
        'void_crown',
        'abyssal_eye',
      ];
      for (final id in allT6Ids) {
        expect(
          ItemSpriteRegistry.itemSprites.containsKey(id),
          isTrue,
          reason: 'Item $id wajib terdaftar di ItemSpriteRegistry.',
        );
      }
    });
  });

  group('M16 Stage 3 — Loot Tables & Breakthrough Drops', () {
    test('Boss loot & Clear loot menjatuhkan abyssal_remnant 100% dan void_essence 20%', () {
      final bossLoot = config.lootTables['abyssal_boss_loot'];
      expect(bossLoot, isNotNull);
      final remnantEntry = bossLoot!.entries.firstWhere(
        (e) => e.itemId == 'abyssal_remnant',
      );
      expect(remnantEntry.chance, 1.0);
      expect(remnantEntry.minQuantity, greaterThanOrEqualTo(1));

      final essenceEntry = bossLoot.entries.firstWhere(
        (e) => e.itemId == 'void_essence',
      );
      expect(essenceEntry.chance, closeTo(0.20, 1e-6));

      final clearLoot = config.lootTables['abyssal_clear_loot'];
      expect(clearLoot, isNotNull);
      final clearRemnant = clearLoot!.entries.firstWhere(
        (e) => e.itemId == 'abyssal_remnant',
      );
      expect(clearRemnant.chance, 1.0);
      final clearEssence = clearLoot.entries.firstWhere(
        (e) => e.itemId == 'void_essence',
      );
      expect(clearEssence.chance, closeTo(0.20, 1e-6));
    });
  });

  group('M16 Stage 3 — Headless Simulation & Combat Run', () {
    test('Karakter Level 65 dapat menyelesaikan Dungeon 6 dan menerima reward & drop', () {
      const runner = OfflineDungeonRunner();
      final factory = EquipmentFactory(config.equipment);

      EquipmentInstance makeGear(String itemId, String instanceId) {
        final def = config.items[itemId]!;
        return EquipmentInstance(
          id: instanceId,
          definitionId: def.id,
          slot: def.equipment!.slot,
          rarity: def.rarity,
          rolledStats: def.equipment!.baseStats,
        );
      }

      final loadout = EquipmentLoadout();
      loadout.equip(makeGear('void_cleaver', 'inst_w1'));
      loadout.equip(makeGear('void_crown', 'inst_h1'));
      loadout.equip(makeGear('void_carapace', 'inst_b1'));
      loadout.equip(makeGear('abyssal_eye', 'inst_a1'));

      final skillLevels = <String, int>{
        for (final s in config.skills.values)
          if (65 >= s.unlockLevel &&
              (s.specializationId == null || s.specializationId == 'vanguard'))
            s.id: (65 ~/ 7).clamp(1, s.maxLevel),
      };

      final character = PlayerCharacter(
        config: config.progression,
        heroAscensionConfig: config.heroAscension,
        progress: const PlayerProgress(
          level: 65,
          currentExp: 0,
          gold: 50000,
          ascensionPhase: 4,
        ),
        loadout: loadout,
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
        initialSpecializationId: 'vanguard',
        skillLevels: skillLevels,
      );

      final inventory = Inventory(definitions: config.items);
      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: factory,
      );

      final timeWindow = const OfflineTimeCalculator().calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(minutes: 25).inMilliseconds,
      );

      final outcome = runner.runBatch(
        OfflineDungeonRunRequest(
          mode: OfflineActivityMode.continueDungeon,
          character: character,
          inventory: inventory,
          config: config,
          rewardProcessor: rewardProcessor,
          dungeonId: 'abyssal_rift',
          dungeonProgress: const DungeonProgressSnapshot(
            currentDungeonId: 'abyssal_rift',
          ),
          timeWindow: timeWindow,
          simulationSeed: 42,
          activeDungeonSession: ActiveDungeonSessionSnapshot(
            runId: 'stage3_run_abyssal_rift',
            dungeonId: 'abyssal_rift',
            currentRoomId: config.dungeons['abyssal_rift']!.startRoomId,
            currentRoomIndex: 0,
            status: DungeonSessionStatus.inProgress,
          ),
        ),
      );

      expect(
        outcome.stopReason,
        OfflineDungeonStopReason.dungeonCompleted,
        reason:
            'Karakter Lv 65 dengan gear memadai harus bisa menyelesaikan D6.',
      );
      expect(outcome.runsCompleted, 1);
      expect(outcome.runsFailed, 0);
      expect(
        outcome.roomsCleared,
        config.dungeons['abyssal_rift']!.roomOrder.length,
      );

      // Pemain mendapatkan drop abyssal_remnant 100% dari bos
      expect(inventory.quantityOf('abyssal_remnant'), greaterThan(0));
    });
  });
}
