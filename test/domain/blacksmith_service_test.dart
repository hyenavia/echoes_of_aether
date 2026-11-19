import 'dart:math';

import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/equipment_loadout.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/blacksmith_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const commonSword = ItemDefinition(
    id: 'rusty_sword',
    name: 'Rusty Sword',
    category: ItemCategory.equipment,
    rarity: ItemRarity.common,
    equipment: EquipmentData(
      slot: EquipmentSlot.weapon,
      weaponType: 'sword',
      baseStats: EquipmentStats(atk: 10, hp: 50, def: 5, critRate: 0.05),
    ),
  );

  const rareBlade = ItemDefinition(
    id: 'rare_blade',
    name: 'Rare Blade',
    category: ItemCategory.equipment,
    rarity: ItemRarity.rare,
    equipment: EquipmentData(
      slot: EquipmentSlot.weapon,
      weaponType: 'sword',
      baseStats: EquipmentStats(atk: 40, critRate: 0.1, critDamage: 0.2),
    ),
  );

  const epicArmor = ItemDefinition(
    id: 'epic_armor',
    name: 'Epic Armor',
    category: ItemCategory.equipment,
    rarity: ItemRarity.epic,
    equipment: EquipmentData(
      slot: EquipmentSlot.body,
      baseStats: EquipmentStats(hp: 200, def: 30, hpPct: 0.1),
    ),
  );

  const fixedEventSword = ItemDefinition(
    id: 'event_blade',
    name: 'Event Blade',
    category: ItemCategory.equipment,
    rarity: ItemRarity.epic,
    equipment: EquipmentData(
      slot: EquipmentSlot.weapon,
      weaponType: 'sword',
      fixedStats: true,
      baseStats: EquipmentStats(atk: 50, critDamage: 0.25),
    ),
  );

  const matSlimeGel = ItemDefinition(
    id: 'slime_gel',
    name: 'Slime Gel',
    category: ItemCategory.material,
    maxStack: 999,
  );

  const matWolfFang = ItemDefinition(
    id: 'wolf_fang',
    name: 'Wolf Fang',
    category: ItemCategory.material,
    maxStack: 999,
  );

  const matCorruptedBark = ItemDefinition(
    id: 'corrupted_bark',
    name: 'Corrupted Bark',
    category: ItemCategory.material,
    maxStack: 999,
  );

  const matAncientFragment = ItemDefinition(
    id: 'ancient_fragment',
    name: 'Ancient Fragment',
    category: ItemCategory.material,
    maxStack: 999,
  );

  final definitions = <String, ItemDefinition>{
    commonSword.id: commonSword,
    rareBlade.id: rareBlade,
    epicArmor.id: epicArmor,
    fixedEventSword.id: fixedEventSword,
    matSlimeGel.id: matSlimeGel,
    matWolfFang.id: matWolfFang,
    matCorruptedBark.id: matCorruptedBark,
    matAncientFragment.id: matAncientFragment,
  };

  const progression = ProgressionConfig(
    maxLevel: 10,
    expBase: 100,
    expGrowth: 2.0,
    baseStats: CombatStats(
      maxHp: 100,
      atk: 10,
      def: 5,
      attackSpeed: 1.0,
      critRate: 0.05,
      critDamage: 1.5,
      moveSpeed: 3.0,
      attackRange: 1.5,
    ),
    perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
  );

  EquipmentInstance makeEquipment(
    String id,
    ItemDefinition def, {
    int enhancementLevel = 0,
    Random? random,
  }) {
    final factory = EquipmentFactory(const EquipmentConfig(rollVariance: 0.0));
    final base = factory.create(
      instanceId: id,
      definition: def,
      random: random ?? Random(42),
    );
    return base.copyWith(enhancementLevel: enhancementLevel);
  }

  group('EquipmentInstance Enhancement and effectiveStats', () {
    test('effectiveStats returns rolledStats when enhancementLevel is 0', () {
      final item = makeEquipment('eq_1', commonSword, enhancementLevel: 0);
      expect(item.effectiveStats.atk, 10.0);
      expect(item.effectiveStats.hp, 50.0);
      expect(item.effectiveStats.def, 5.0);
      expect(item.effectiveStats.critRate, 0.05);
    });

    test('effectiveStats boosts flat stats by 5% per level, keeping percent stats identical', () {
      final itemLvl1 = makeEquipment('eq_1', commonSword, enhancementLevel: 1);
      expect(itemLvl1.effectiveStats.atk, closeTo(10.5, 0.001));
      expect(itemLvl1.effectiveStats.hp, closeTo(52.5, 0.001));
      expect(itemLvl1.effectiveStats.def, closeTo(5.25, 0.001));
      expect(itemLvl1.effectiveStats.critRate, 0.05);

      final itemLvl10 = makeEquipment(
        'eq_1',
        commonSword,
        enhancementLevel: 10,
      );
      expect(itemLvl10.effectiveStats.atk, closeTo(15.0, 0.001)); // +50%
      expect(itemLvl10.effectiveStats.hp, closeTo(75.0, 0.001)); // +50%
      expect(itemLvl10.effectiveStats.def, closeTo(7.5, 0.001)); // +50%
      expect(itemLvl10.effectiveStats.critRate, 0.05);
    });

    test('effectiveStats preserves lifesteal and spellVamp across enhancement levels', () {
      final item = EquipmentInstance(
        id: 'eq_sustain',
        definitionId: 'sustain_sword',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.epic,
        enhancementLevel: 5,
        rolledStats: const EquipmentStats(
          atk: 100,
          lifesteal: 0.12,
          spellVamp: 0.08,
        ),
      );
      expect(item.effectiveStats.atk, 125.0); // +25%
      expect(item.effectiveStats.lifesteal, 0.12);
      expect(item.effectiveStats.spellVamp, 0.08);
    });

    test('copyWith updates fields while preserving others', () {
      final item = makeEquipment('eq_1', commonSword, enhancementLevel: 2);
      final updated = item.copyWith(enhancementLevel: 3);

      expect(updated.id, item.id);
      expect(updated.definitionId, item.definitionId);
      expect(updated.slot, item.slot);
      expect(updated.rarity, item.rarity);
      expect(updated.enhancementLevel, 3);
      expect(updated.rolledStats, item.rolledStats);
    });
  });

  group('EquipmentLoadout and Character Stats with Enhancement', () {
    test(
      'EquipmentLoadout.totalBonus includes effectiveStats from equipped items',
      () {
        final loadout = EquipmentLoadout();
        final sword0 = makeEquipment('eq_1', commonSword, enhancementLevel: 0);
        loadout.equip(sword0);

        expect(loadout.totalBonus.atk, 10.0);

        final swordPlus2 = sword0.copyWith(
          enhancementLevel: 2,
        ); // +10% -> 11.0 atk
        loadout.equip(swordPlus2);

        expect(loadout.totalBonus.atk, closeTo(11.0, 0.001));
      },
    );

    test('PlayerCharacter.stats reflects enhanced equipment stats', () {
      final loadout = EquipmentLoadout();
      final character = PlayerCharacter(config: progression, loadout: loadout);

      final baseAtkWithoutGear = character.stats.atk; // 10

      final swordPlus10 = makeEquipment(
        'eq_1',
        commonSword,
        enhancementLevel: 10,
      ); // 10 * 1.5 = 15 atk
      loadout.equip(swordPlus10);

      expect(character.stats.atk, baseAtkWithoutGear + 15);
    });
  });

  group('Inventory.updateEquipment', () {
    test('updates existing equipment in-place and returns true', () {
      final inv = Inventory(definitions: definitions);
      final item = makeEquipment('eq_1', commonSword, enhancementLevel: 0);
      inv.addEquipment(item);

      final upgraded = item.copyWith(enhancementLevel: 5);
      final ok = inv.updateEquipment(upgraded);

      expect(ok, isTrue);
      expect(inv.equipmentById('eq_1')?.enhancementLevel, 5);
    });

    test('returns false when equipment id does not exist in inventory', () {
      final inv = Inventory(definitions: definitions);
      final ghost = makeEquipment('ghost', commonSword);

      final ok = inv.updateEquipment(ghost);
      expect(ok, isFalse);
    });
  });

  group('BlacksmithService - Requirements', () {
    const service = BlacksmithService();

    test('getEnhanceRequirement returns valid costs up to level 9 targeting level 10', () {
      final req1 = service.getEnhanceRequirement(0);
      expect(req1?.targetLevel, 1);
      expect(req1?.goldCost, 5000);
      expect(req1?.requiredMaterials['slime_gel'], 3);

      final req10 = service.getEnhanceRequirement(9);
      expect(req10?.targetLevel, 10);
      expect(req10?.goldCost, 4000000);
      expect(req10?.requiredMaterials['ancient_fragment'], 12);
    });

    test('getEnhanceRequirement returns null for max level (10) or invalid negative level', () {
      expect(service.getEnhanceRequirement(10), isNull);
      expect(service.getEnhanceRequirement(11), isNull);
      expect(service.getEnhanceRequirement(-1), isNull);
    });

    test('getReforgeCost returns correct costs for Rare, Epic, Legendary; null for Common, Uncommon', () {
      expect(service.getReforgeCost(ItemRarity.common), isNull);
      expect(service.getReforgeCost(ItemRarity.uncommon), isNull);
      expect(service.getReforgeCost(ItemRarity.rare), 50000);
      expect(service.getReforgeCost(ItemRarity.epic), 150000);
      expect(service.getReforgeCost(ItemRarity.legendary), 500000);
    });
  });

  group('BlacksmithService - Enhance Equipment', () {
    const service = BlacksmithService();

    test(
      'enhances inventory item successfully, deducting gold and materials',
      () {
        final inv = Inventory(definitions: definitions);
        final character = PlayerCharacter(config: progression);
        character.addGold(10000);

        final item = makeEquipment('eq_1', commonSword, enhancementLevel: 0);
        inv.addEquipment(item);
        inv.add('slime_gel', 10);

        final result = service.enhanceEquipment(
          character: character,
          inventory: inv,
          instanceId: 'eq_1',
        );

        expect(result.isSuccess, isTrue);
        expect(result.status, BlacksmithEnhanceStatus.success);
        expect(result.updatedInstance?.enhancementLevel, 1);
        expect(result.goldSpent, 5000);
        expect(result.materialsSpent['slime_gel'], 3);

        expect(character.gold, 5000);
        expect(inv.quantityOf('slime_gel'), 7);
        expect(inv.equipmentById('eq_1')?.enhancementLevel, 1);
      },
    );

    test('enhances equipped item in loadout and updates character stats immediately', () {
      final loadout = EquipmentLoadout();
      final inv = Inventory(definitions: definitions);
      final character = PlayerCharacter(config: progression, loadout: loadout);
      character.addGold(100000);
      inv.add('slime_gel', 20);

      final sword = makeEquipment('eq_1', commonSword, enhancementLevel: 0);
      loadout.equip(sword);

      final initialRevision = loadout.revision;
      final initialAtk = character.stats.atk;

      final result = service.enhanceEquipment(
        character: character,
        inventory: inv,
        instanceId: 'eq_1',
        loadout: loadout,
      );

      expect(result.isSuccess, isTrue);
      expect(result.updatedInstance?.enhancementLevel, 1);
      expect(loadout.instanceIn(EquipmentSlot.weapon)?.enhancementLevel, 1);
      expect(loadout.revision, greaterThan(initialRevision));
      // Base ATK (10) + enhanced weapon ATK (10 * 1.05 = 10.5 rounded -> 11)
      expect(character.stats.atk, greaterThanOrEqualTo(initialAtk));
    });

    test('can enhance sequentially up to level 10', () {
      final inv = Inventory(definitions: definitions);
      final character = PlayerCharacter(config: progression);
      character.addGold(10000000); // 10 million gold

      inv.add('slime_gel', 100);
      inv.add('wolf_fang', 100);
      inv.add('corrupted_bark', 100);
      inv.add('ancient_fragment', 100);

      final item = makeEquipment('eq_1', commonSword, enhancementLevel: 0);
      inv.addEquipment(item);

      for (var target = 1; target <= 10; target++) {
        final res = service.enhanceEquipment(
          character: character,
          inventory: inv,
          instanceId: 'eq_1',
        );
        expect(
          res.isSuccess,
          isTrue,
          reason: 'Target level +$target should succeed',
        );
        expect(res.updatedInstance?.enhancementLevel, target);
      }

      expect(inv.equipmentById('eq_1')?.enhancementLevel, 10);

      // Attempting to enhance further (+11) fails
      final overflowRes = service.enhanceEquipment(
        character: character,
        inventory: inv,
        instanceId: 'eq_1',
      );
      expect(overflowRes.status, BlacksmithEnhanceStatus.maxLevelReached);
      expect(overflowRes.isSuccess, isFalse);
    });

    test(
      'fails with insufficientGold without altering character or inventory',
      () {
        final inv = Inventory(definitions: definitions);
        final character = PlayerCharacter(config: progression);
        character.addGold(1000); // Needs 5000

        final item = makeEquipment('eq_1', commonSword, enhancementLevel: 0);
        inv.addEquipment(item);
        inv.add('slime_gel', 10);

        final res = service.enhanceEquipment(
          character: character,
          inventory: inv,
          instanceId: 'eq_1',
        );

        expect(res.status, BlacksmithEnhanceStatus.insufficientGold);
        expect(character.gold, 1000);
        expect(inv.quantityOf('slime_gel'), 10);
        expect(inv.equipmentById('eq_1')?.enhancementLevel, 0);
      },
    );

    test('fails with insufficientMaterials without deducting gold', () {
      final inv = Inventory(definitions: definitions);
      final character = PlayerCharacter(config: progression);
      character.addGold(10000); // Has enough gold

      final item = makeEquipment('eq_1', commonSword, enhancementLevel: 0);
      inv.addEquipment(item);
      inv.add('slime_gel', 2); // Needs 3

      final res = service.enhanceEquipment(
        character: character,
        inventory: inv,
        instanceId: 'eq_1',
      );

      expect(res.status, BlacksmithEnhanceStatus.insufficientMaterials);
      expect(character.gold, 10000);
      expect(inv.quantityOf('slime_gel'), 2);
      expect(inv.equipmentById('eq_1')?.enhancementLevel, 0);
    });

    test('fails with itemNotFound when instanceId is absent', () {
      final inv = Inventory(definitions: definitions);
      final character = PlayerCharacter(config: progression);
      character.addGold(10000);

      final res = service.enhanceEquipment(
        character: character,
        inventory: inv,
        instanceId: 'nonexistent',
      );

      expect(res.status, BlacksmithEnhanceStatus.itemNotFound);
    });
  });

  group('BlacksmithService - Reforge Equipment', () {
    const service = BlacksmithService(
      equipmentConfig: EquipmentConfig(rollVariance: 0.15),
    );

    test('reforges Rare equipment successfully, rerolling stats and preserving enhancement level', () {
      final inv = Inventory(definitions: definitions);
      final character = PlayerCharacter(config: progression);
      character.addGold(100000);

      final rare = makeEquipment('eq_rare', rareBlade, enhancementLevel: 4);
      inv.addEquipment(rare);

      final res = service.reforgeEquipment(
        character: character,
        inventory: inv,
        instanceId: 'eq_rare',
        random: Random(999),
      );

      expect(res.isSuccess, isTrue);
      expect(res.status, BlacksmithReforgeStatus.success);
      expect(res.goldSpent, 50000);
      expect(character.gold, 50000);

      final updated = res.updatedInstance!;
      expect(updated.id, 'eq_rare');
      expect(updated.definitionId, 'rare_blade');
      expect(
        updated.enhancementLevel,
        4,
      ); // Enhancement level MUST be preserved!
      expect(updated.rolledStats, isNot(equals(rare.rolledStats)));
    });

    test('reforges Epic equipment successfully with 150,000 gold cost', () {
      final inv = Inventory(definitions: definitions);
      final character = PlayerCharacter(config: progression);
      character.addGold(200000);

      final epic = makeEquipment('eq_epic', epicArmor, enhancementLevel: 2);
      inv.addEquipment(epic);

      final res = service.reforgeEquipment(
        character: character,
        inventory: inv,
        instanceId: 'eq_epic',
        random: Random(123),
      );

      expect(res.isSuccess, isTrue);
      expect(res.goldSpent, 150000);
      expect(character.gold, 50000);
      expect(res.updatedInstance?.enhancementLevel, 2);
    });

    test(
      'reforging equipped item in loadout updates loadout instance directly',
      () {
        final loadout = EquipmentLoadout();
        final inv = Inventory(definitions: definitions);
        final character = PlayerCharacter(
          config: progression,
          loadout: loadout,
        );
        character.addGold(100000);

        final rare = makeEquipment('eq_rare', rareBlade, enhancementLevel: 0);
        loadout.equip(rare);

        final res = service.reforgeEquipment(
          character: character,
          inventory: inv,
          instanceId: 'eq_rare',
          loadout: loadout,
          random: Random(777),
        );

        expect(res.isSuccess, isTrue);
        expect(
          loadout.instanceIn(EquipmentSlot.weapon)?.rolledStats,
          res.newStats,
        );
      },
    );

    test('fails on Common / Uncommon gear with ineligibleRarity', () {
      final inv = Inventory(definitions: definitions);
      final character = PlayerCharacter(config: progression);
      character.addGold(100000);

      final common = makeEquipment('eq_common', commonSword);
      inv.addEquipment(common);

      final res = service.reforgeEquipment(
        character: character,
        inventory: inv,
        instanceId: 'eq_common',
      );

      expect(res.status, BlacksmithReforgeStatus.ineligibleRarity);
      expect(res.isSuccess, isFalse);
      expect(character.gold, 100000);
    });

    test('fails on fixedStats gear with fixedStatsNotReforgeable', () {
      final inv = Inventory(definitions: definitions);
      final character = PlayerCharacter(config: progression);
      character.addGold(200000);

      final fixedItem = makeEquipment('eq_fixed', fixedEventSword);
      inv.addEquipment(fixedItem);

      final res = service.reforgeEquipment(
        character: character,
        inventory: inv,
        instanceId: 'eq_fixed',
      );

      expect(res.status, BlacksmithReforgeStatus.fixedStatsNotReforgeable);
      expect(res.isSuccess, isFalse);
      expect(character.gold, 200000);
    });

    test('fails with insufficientGold if character cannot afford reforge', () {
      final inv = Inventory(definitions: definitions);
      final character = PlayerCharacter(config: progression);
      character.addGold(20000); // Needs 50,000 for Rare

      final rare = makeEquipment('eq_rare', rareBlade);
      inv.addEquipment(rare);

      final res = service.reforgeEquipment(
        character: character,
        inventory: inv,
        instanceId: 'eq_rare',
      );

      expect(res.status, BlacksmithReforgeStatus.insufficientGold);
      expect(character.gold, 20000);
    });

    test('fails with itemNotFound if instanceId does not exist', () {
      final inv = Inventory(definitions: definitions);
      final character = PlayerCharacter(config: progression);
      character.addGold(100000);

      final res = service.reforgeEquipment(
        character: character,
        inventory: inv,
        instanceId: 'missing_id',
      );

      expect(res.status, BlacksmithReforgeStatus.itemNotFound);
    });
  });
}
