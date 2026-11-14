import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/equipment_service.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter_test/flutter_test.dart';

const gel = ItemDefinition(
  id: 'gel',
  name: 'Gel',
  category: ItemCategory.material,
);
const sword = ItemDefinition(
  id: 'sword',
  name: 'Sword',
  category: ItemCategory.equipment,
  equipment: EquipmentData(
    slot: EquipmentSlot.weapon,
    baseStats: EquipmentStats(atk: 5),
  ),
);

const progression = ProgressionConfig(
  maxLevel: 5,
  expBase: 100,
  expGrowth: 2.0,
  baseStats: CombatStats(maxHp: 100, atk: 10, def: 2),
  perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
);

void main() {
  test('refresh memperbarui daftar stack, tas equipment, dan stat akhir', () {
    final inventory = Inventory(definitions: {'gel': gel, 'sword': sword});
    final character = PlayerCharacter(config: progression);
    final views = InventoryViews(inventory: inventory, character: character);
    final service = EquipmentService(
      inventory: inventory,
      loadout: character.loadout,
    );

    expect(views.stacks.value, isEmpty);
    expect(views.equipment.value.bag, isEmpty);
    expect(views.equipment.value.stats.atk, 10);

    inventory.add('gel', 3);
    final id = inventory.nextEquipmentId();
    inventory.addEquipment(
      EquipmentInstance(
        id: id,
        definitionId: 'sword',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.common,
        rolledStats: const EquipmentStats(atk: 5),
      ),
    );
    views.refresh();
    expect(views.stacks.value.single.quantity, 3);
    expect(views.equipment.value.bag.single.id, id);

    service.equip(id);
    views.refresh();
    expect(views.equipment.value.bag, isEmpty);
    expect(views.equipment.value.equipped[EquipmentSlot.weapon]!.id, id);
    expect(views.equipment.value.stats.atk, 15);
  });
}
