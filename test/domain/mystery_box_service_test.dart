import 'dart:math' as math;

import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/mystery_box.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/mystery_box_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const progression = ProgressionConfig(
    maxLevel: 30,
    baseStats: CombatStats(maxHp: 100, atk: 10, def: 5),
    perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
  );

  const testItems = <String, ItemDefinition>{
    'sword_c': ItemDefinition(
      id: 'sword_c',
      name: 'Common Sword',
      category: ItemCategory.equipment,
      rarity: ItemRarity.common,
      sellValue: 10,
      equipment: EquipmentData(
        slot: EquipmentSlot.weapon,
        baseStats: EquipmentStats(atk: 5),
      ),
    ),
    'helm_u': ItemDefinition(
      id: 'helm_u',
      name: 'Uncommon Helm',
      category: ItemCategory.equipment,
      rarity: ItemRarity.uncommon,
      sellValue: 25,
      equipment: EquipmentData(
        slot: EquipmentSlot.head,
        baseStats: EquipmentStats(hp: 20, def: 3),
      ),
    ),
    'armor_r': ItemDefinition(
      id: 'armor_r',
      name: 'Rare Armor',
      category: ItemCategory.equipment,
      rarity: ItemRarity.rare,
      sellValue: 80,
      equipment: EquipmentData(
        slot: EquipmentSlot.body,
        baseStats: EquipmentStats(hp: 60, def: 10),
      ),
    ),
    'blade_e': ItemDefinition(
      id: 'blade_e',
      name: 'Epic Blade',
      category: ItemCategory.equipment,
      rarity: ItemRarity.epic,
      sellValue: 200,
      equipment: EquipmentData(
        slot: EquipmentSlot.weapon,
        baseStats: EquipmentStats(atk: 30, critRate: 0.05),
      ),
    ),
    'ring_l': ItemDefinition(
      id: 'ring_l',
      name: 'Legendary Ring',
      category: ItemCategory.equipment,
      rarity: ItemRarity.legendary,
      sellValue: 500,
      equipment: EquipmentData(
        slot: EquipmentSlot.accessory,
        baseStats: EquipmentStats(atk: 25, critRate: 0.1, critDamage: 0.2),
      ),
    ),
    'event_item': ItemDefinition(
      id: 'event_item',
      name: 'Event Only Blade',
      category: ItemCategory.equipment,
      rarity: ItemRarity.legendary,
      sellable: false, // Non-sellable event item
      equipment: EquipmentData(
        slot: EquipmentSlot.weapon,
        baseStats: EquipmentStats(atk: 50),
      ),
    ),
  };

  group('MysteryBoxDefinition', () {
    test('tier defaults memiliki biaya, level, dan bobot yang valid', () {
      final novice = MysteryBoxDefinition.defaults[MysteryBoxTier.novice]!;
      expect(novice.goldCost, 25000);
      expect(novice.minLevel, 1);
      expect(novice.totalWeight, 100);

      final warrior = MysteryBoxDefinition.defaults[MysteryBoxTier.warrior]!;
      expect(warrior.goldCost, 100000);
      expect(warrior.minLevel, 10);
      expect(warrior.totalWeight, 100);

      final aether = MysteryBoxDefinition.defaults[MysteryBoxTier.aether]!;
      expect(aether.goldCost, 500000);
      expect(aether.minLevel, 20);
      expect(aether.totalWeight, 100);
    });

    test('describeProbabilities menghasilkan teks ringkasan yang rapi', () {
      final novice = MysteryBoxDefinition.defaults[MysteryBoxTier.novice]!;
      expect(
        novice.describeProbabilities(),
        'Common 55% • Uncommon 38% • Rare 7%',
      );
    });

    test('rollRarity menghasilkan rarity sesuai bobot', () {
      final aether = MysteryBoxDefinition.defaults[MysteryBoxTier.aether]!;
      final counts = <ItemRarity, int>{};
      final rng = math.Random(123);
      for (var i = 0; i < 1000; i++) {
        final r = aether.rollRarity(rng);
        counts[r] = (counts[r] ?? 0) + 1;
      }
      expect(counts[ItemRarity.rare], isNotNull);
      expect(counts[ItemRarity.epic], isNotNull);
      expect(counts[ItemRarity.legendary], isNotNull);
    });
  });

  group('MysteryBoxService', () {
    late MysteryBoxService service;
    late PlayerCharacter character;
    late Inventory inventory;

    setUp(() {
      service = const MysteryBoxService(
        items: testItems,
        equipmentFactory: EquipmentFactory(EquipmentConfig(rollVariance: 0.1)),
      );
      character = PlayerCharacter(
        config: progression,
        progress: const PlayerProgress(
          level: 25,
          gold: 10000000,
        ), // 10 Juta Gold
      );
      inventory = Inventory(definitions: testItems, maxEquipmentCapacity: 20);
    });

    test(
      'openBox 1x sukses memotong gold dan menambahkan equipment ke tas',
      () {
        final initialGold = character.gold;
        final result = service.openBox(
          character: character,
          inventory: inventory,
          tier: MysteryBoxTier.novice,
          count: 1,
          random: math.Random(42),
        );

        expect(result.isSuccess, isTrue);
        expect(result.status, MysteryBoxOpenStatus.success);
        expect(result.count, 1);
        expect(result.itemsObtained.length, 1);
        expect(result.goldSpent, 25000);
        expect(result.remainingGold, initialGold - 25000);
        expect(character.gold, initialGold - 25000);
        expect(inventory.equipmentCount, 1);

        final item = result.itemsObtained.first;
        expect(inventory.equipmentById(item.id), isNotNull);
        // Item event yang tidak sellable tidak boleh pernah keluar
        expect(item.definitionId, isNot('event_item'));
      },
    );

    test('openBox 5x multi-open sukses memotong total gold dan menambah 5 equipment', () {
      final initialGold = character.gold;
      final result = service.openBox(
        character: character,
        inventory: inventory,
        tier: MysteryBoxTier.warrior,
        count: 5,
        random: math.Random(42),
      );

      expect(result.isSuccess, isTrue);
      expect(result.count, 5);
      expect(result.itemsObtained.length, 5);
      expect(result.goldSpent, 500000); // 100k * 5
      expect(result.remainingGold, initialGold - 500000);
      expect(inventory.equipmentCount, 5);
    });

    test('openBox gagal jika level karakter belum mencukupi (underLevel)', () {
      final lowLevelChar = PlayerCharacter(
        config: progression,
        progress: const PlayerProgress(
          level: 5,
          gold: 5000000,
        ), // Lv 5, butuh Lv 20 untuk Aether
      );

      final result = service.openBox(
        character: lowLevelChar,
        inventory: inventory,
        tier: MysteryBoxTier.aether,
        count: 1,
        random: math.Random(42),
      );

      expect(result.isSuccess, isFalse);
      expect(result.status, MysteryBoxOpenStatus.underLevel);
      expect(result.itemsObtained, isEmpty);
      expect(lowLevelChar.gold, 5000000);
      expect(inventory.equipmentCount, 0);
    });

    test('openBox gagal jika gold tidak mencukupi (insufficientGold)', () {
      final poorChar = PlayerCharacter(
        config: progression,
        progress: const PlayerProgress(
          level: 25,
          gold: 10000,
        ), // Butuh 25k untuk Novice
      );

      final result = service.openBox(
        character: poorChar,
        inventory: inventory,
        tier: MysteryBoxTier.novice,
        count: 1,
        random: math.Random(42),
      );

      expect(result.isSuccess, isFalse);
      expect(result.status, MysteryBoxOpenStatus.insufficientGold);
      expect(poorChar.gold, 10000);
      expect(inventory.equipmentCount, 0);
    });

    test(
      'openBox gagal jika kapasitas tas equipment tidak cukup (inventoryFull)',
      () {
        final smallInv = Inventory(
          definitions: testItems,
          maxEquipmentCapacity: 2,
        );

        // Coba buka 5 box saat sisa slot hanya 2
        final result = service.openBox(
          character: character,
          inventory: smallInv,
          tier: MysteryBoxTier.novice,
          count: 5,
          random: math.Random(42),
        );

        expect(result.isSuccess, isFalse);
        expect(result.status, MysteryBoxOpenStatus.inventoryFull);
        expect(character.gold, 10000000);
        expect(smallInv.equipmentCount, 0);
      },
    );
  });
}
