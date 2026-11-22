import 'dart:math';

import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/equipment_loadout.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/services/blacksmith_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scrapDef = ItemDefinition(
    id: BlacksmithService.aetherScrapItemId,
    name: 'Aether Scrap',
    category: ItemCategory.material,
    rarity: ItemRarity.common,
    maxStack: 999,
  );

  ItemDefinition makeWeaponDef(String id, ItemRarity rarity) => ItemDefinition(
    id: id,
    name: 'Weapon $id',
    category: ItemCategory.equipment,
    rarity: rarity,
    equipment: const EquipmentData(
      slot: EquipmentSlot.weapon,
      weaponType: 'sword',
      baseStats: EquipmentStats(atk: 10),
    ),
  );

  final defs = <String, ItemDefinition>{
    scrapDef.id: scrapDef,
    'wp_common': makeWeaponDef('wp_common', ItemRarity.common),
    'wp_uncommon': makeWeaponDef('wp_uncommon', ItemRarity.uncommon),
    'wp_rare': makeWeaponDef('wp_rare', ItemRarity.rare),
    'wp_epic': makeWeaponDef('wp_epic', ItemRarity.epic),
    'wp_legendary': makeWeaponDef('wp_legendary', ItemRarity.legendary),
    'wp_mythical': makeWeaponDef('wp_mythical', ItemRarity.mythical),
  };

  const factory = EquipmentFactory(EquipmentConfig(rollVariance: 0.0));
  const service = BlacksmithService();

  group('Fase 1 QoL — Auto-Favorite & Smart Bulk Salvage', () {
    test('EquipmentFactory.create auto-favorites legendary and mythical items only', () {
      final rng = Random(42);
      final common = factory.create(
        instanceId: 'c1',
        definition: defs['wp_common']!,
        random: rng,
      );
      final uncommon = factory.create(
        instanceId: 'u1',
        definition: defs['wp_uncommon']!,
        random: rng,
      );
      final rare = factory.create(
        instanceId: 'r1',
        definition: defs['wp_rare']!,
        random: rng,
      );
      final epic = factory.create(
        instanceId: 'e1',
        definition: defs['wp_epic']!,
        random: rng,
      );
      final legendary = factory.create(
        instanceId: 'l1',
        definition: defs['wp_legendary']!,
        random: rng,
      );
      final mythical = factory.create(
        instanceId: 'm1',
        definition: defs['wp_mythical']!,
        random: rng,
      );

      expect(common.isFavorite, isFalse);
      expect(uncommon.isFavorite, isFalse);
      expect(rare.isFavorite, isFalse);
      expect(epic.isFavorite, isFalse);
      expect(legendary.isFavorite, isTrue);
      expect(mythical.isFavorite, isTrue);
    });

    test('salvageEquipmentBulk salvages matching rarities and protects equipped, favorite, enhanced, and mythical', () {
      final rng = Random(7);
      final inv = Inventory(definitions: defs);
      final equipped = factory.create(
        instanceId: 'eq_equipped',
        definition: defs['wp_common']!,
        random: rng,
      );
      final loadout = EquipmentLoadout()..equip(equipped);

      final commonBag = factory.create(
        instanceId: 'eq_common_1',
        definition: defs['wp_common']!,
        random: rng,
      );
      final uncommonBag = factory.create(
        instanceId: 'eq_uncommon_1',
        definition: defs['wp_uncommon']!,
        random: rng,
      );
      final favCommon = factory
          .create(
            instanceId: 'eq_fav_common',
            definition: defs['wp_common']!,
            random: rng,
          )
          .copyWith(isFavorite: true);
      final enhancedUncommon = factory
          .create(
            instanceId: 'eq_enh_uncommon',
            definition: defs['wp_uncommon']!,
            random: rng,
          )
          .copyWith(enhancementLevel: 2);
      final rareBag = factory.create(
        instanceId: 'eq_rare_1',
        definition: defs['wp_rare']!,
        random: rng,
      );
      final legendaryBag = factory.create(
        instanceId: 'eq_leg_1',
        definition: defs['wp_legendary']!,
        random: rng,
      );
      final mythicalBag = factory.create(
        instanceId: 'eq_myth_1',
        definition: defs['wp_mythical']!,
        random: rng,
      );

      for (final eq in [
        equipped,
        commonBag,
        uncommonBag,
        favCommon,
        enhancedUncommon,
        rareBag,
        legendaryBag,
        mythicalBag,
      ]) {
        inv.addEquipment(eq);
      }

      final result = service.salvageEquipmentBulk(
        inventory: inv,
        targetRarities: const {
          ItemRarity.common,
          ItemRarity.uncommon,
          ItemRarity.mythical,
        },
        loadout: loadout,
      );

      // Hanya eq_common_1 (+2) dan eq_uncommon_1 (+5) yang terbongkar.
      expect(result.hasSalvaged, isTrue);
      expect(result.salvagedCount, 2);
      expect(result.aetherScrapGained, 7);
      expect(
        result.salvagedIds,
        unorderedEquals(['eq_common_1', 'eq_uncommon_1']),
      );
      expect(result.skippedCount, 4); // equipped, fav, enhanced, mythical
      expect(result.stoppedByInventoryFull, isFalse);
      expect(inv.quantityOf(BlacksmithService.aetherScrapItemId), 7);

      // Item terlindungi + rare/legendary tetap aman.
      expect(inv.equipmentById('eq_equipped'), isNotNull);
      expect(inv.equipmentById('eq_fav_common'), isNotNull);
      expect(inv.equipmentById('eq_enh_uncommon'), isNotNull);
      expect(inv.equipmentById('eq_rare_1'), isNotNull);
      expect(inv.equipmentById('eq_leg_1'), isNotNull);
      expect(inv.equipmentById('eq_myth_1'), isNotNull);
      expect(inv.equipmentById('eq_common_1'), isNull);
      expect(inv.equipmentById('eq_uncommon_1'), isNull);
    });

    test('salvageEquipmentBulk stops safely without item loss when aether_scrap hits maxStack', () {
      final smallCapDefs = <String, ItemDefinition>{
        ...defs,
        BlacksmithService.aetherScrapItemId: const ItemDefinition(
          id: BlacksmithService.aetherScrapItemId,
          name: 'Aether Scrap',
          category: ItemCategory.material,
          rarity: ItemRarity.common,
          maxStack: 4,
        ),
      };
      final inv = Inventory(definitions: smallCapDefs);
      final rng = Random(9);
      inv.addEquipment(
        factory.create(
          instanceId: 'c1',
          definition: smallCapDefs['wp_common']!,
          random: rng,
        ),
      );
      inv.addEquipment(
        factory.create(
          instanceId: 'c2',
          definition: smallCapDefs['wp_common']!,
          random: rng,
        ),
      );
      inv.addEquipment(
        factory.create(
          instanceId: 'c3',
          definition: smallCapDefs['wp_common']!,
          random: rng,
        ),
      );

      final result = service.salvageEquipmentBulk(
        inventory: inv,
        targetRarities: const {ItemRarity.common},
      );

      // maxStack = 4 hanya muat 2x common (+4 scrap); item ke-3 harus aman.
      expect(result.salvagedCount, 2);
      expect(result.aetherScrapGained, 4);
      expect(result.stoppedByInventoryFull, isTrue);
      expect(result.skippedCount, 1);
      expect(inv.quantityOf(BlacksmithService.aetherScrapItemId), 4);
      expect(inv.equipmentSnapshot().length, 1);
    });
  });
}
