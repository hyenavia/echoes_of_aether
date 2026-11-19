import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_loadout.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/blacksmith_service.dart';
import 'package:echoes_of_aether/domain/services/offline_equipment_cleanup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scrapDef = ItemDefinition(
    id: BlacksmithService.aetherScrapItemId,
    name: 'Aether Scrap',
    category: ItemCategory.material,
    rarity: ItemRarity.common,
    maxStack: 9999,
  );

  const weaponDef = ItemDefinition(
    id: 'wp_test',
    name: 'Test Sword',
    category: ItemCategory.equipment,
    rarity: ItemRarity.rare,
    equipment: EquipmentData(
      slot: EquipmentSlot.weapon,
      baseStats: EquipmentStats(atk: 10),
    ),
  );

  const armorDef = ItemDefinition(
    id: 'ar_test',
    name: 'Test Armor',
    category: ItemCategory.equipment,
    rarity: ItemRarity.rare,
    equipment: EquipmentData(
      slot: EquipmentSlot.body,
      baseStats: EquipmentStats(def: 10),
    ),
  );

  const config = GameConfig(
    monsters: {},
    revive: ReviveConfig(),
    progression: ProgressionConfig(
      baseStats: CombatStats(maxHp: 100, atk: 10, def: 5),
      perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
    ),
    lootTables: {},
    items: {
      BlacksmithService.aetherScrapItemId: scrapDef,
      'wp_test': weaponDef,
      'ar_test': armorDef,
    },
  );

  EquipmentInstance makeWeapon(
    String id, {
    required double atk,
    ItemRarity rarity = ItemRarity.rare,
    bool isFavorite = false,
  }) => EquipmentInstance(
    id: id,
    definitionId: weaponDef.id,
    slot: EquipmentSlot.weapon,
    rarity: rarity,
    rolledStats: EquipmentStats(atk: atk),
    isFavorite: isFavorite,
  );

  EquipmentInstance makeArmor(
    String id, {
    required double def,
    ItemRarity rarity = ItemRarity.epic,
  }) => EquipmentInstance(
    id: id,
    definitionId: armorDef.id,
    slot: EquipmentSlot.body,
    rarity: rarity,
    rolledStats: EquipmentStats(def: def),
  );

  test('menyisakan top 3 per slot terpisah dan membongkar sisanya menjadi Aether Scrap', () {
    final inv = Inventory(definitions: config.items);
    final loadout = EquipmentLoadout();

    // 5 weapon Rare..Legendary -> top 3 (w5, w4, w3) disisakan, 2 (w2, w1) dibongkar
    inv.addEquipment(makeWeapon('w1', atk: 10));
    inv.addEquipment(makeWeapon('w2', atk: 20));
    inv.addEquipment(makeWeapon('w3', atk: 30, rarity: ItemRarity.epic));
    inv.addEquipment(makeWeapon('w4', atk: 40, rarity: ItemRarity.legendary));
    inv.addEquipment(makeWeapon('w5', atk: 50, rarity: ItemRarity.epic));

    // 4 armor Epic -> top 3 (a4, a3, a2) disisakan, 1 (a1) dibongkar
    inv.addEquipment(makeArmor('a1', def: 5));
    inv.addEquipment(makeArmor('a2', def: 15));
    inv.addEquipment(makeArmor('a3', def: 25));
    inv.addEquipment(makeArmor('a4', def: 35));

    final result = const OfflineEquipmentCleanupService(keepTopPerSlot: 3)
        .cleanupAfterOffline(inventory: inv, loadout: loadout, config: config);

    expect(result.salvagedCount, 3);
    expect(result.keptCount, 6);
    expect(result.scrapGained, greaterThan(0));
    expect(
      inv.quantityOf(BlacksmithService.aetherScrapItemId),
      result.scrapGained,
    );

    final remainingIds = inv.equipmentSnapshot().map((e) => e.id).toSet();
    expect(remainingIds, {'w5', 'w4', 'w3', 'a4', 'a3', 'a2'});
  });

  test(
    'tidak pernah membongkar item favorite, mythical, atau yang sedang dipakai',
    () {
      final inv = Inventory(definitions: config.items);
      final equippedWeapon = makeWeapon('eq_w', atk: 1);
      inv.addEquipment(equippedWeapon);
      final loadout = EquipmentLoadout()..equip(equippedWeapon);

      inv.addEquipment(makeWeapon('fav_w', atk: 2, isFavorite: true));
      inv.addEquipment(
        makeWeapon('myth_w', atk: 3, rarity: ItemRarity.mythical),
      );
      inv.addEquipment(makeWeapon('w1', atk: 10));
      inv.addEquipment(makeWeapon('w2', atk: 20));
      inv.addEquipment(makeWeapon('w3', atk: 30));
      inv.addEquipment(makeWeapon('w4', atk: 40));

      final result = const OfflineEquipmentCleanupService(
        keepTopPerSlot: 3,
      ).cleanupAfterOffline(inventory: inv, loadout: loadout, config: config);

      expect(result.salvagedCount, 1);
      final remainingIds = inv.equipmentSnapshot().map((e) => e.id).toSet();
      expect(
        remainingIds,
        containsAll(['eq_w', 'fav_w', 'myth_w', 'w4', 'w3', 'w2']),
      );
      expect(remainingIds.contains('w1'), isFalse);
    },
  );
}
