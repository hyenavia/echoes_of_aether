import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/features/dungeon/equipment_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/inventory_overlay.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('InventoryOverlay mendukung filter kategori dan rarity', (
    tester,
  ) async {
    final matDef = const ItemDefinition(
      id: 'slime_gel',
      name: 'Slime Gel',
      category: ItemCategory.material,
      rarity: ItemRarity.common,
      sellValue: 5,
    );
    final potionDef = const ItemDefinition(
      id: 'small_potion',
      name: 'Small Potion',
      category: ItemCategory.consumable,
      rarity: ItemRarity.uncommon,
    );
    final entries = ValueNotifier<List<InventoryEntry>>([
      InventoryEntry(matDef, 4),
      InventoryEntry(potionDef, 2),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventoryOverlay(entries: entries, onClose: () {}),
        ),
      ),
    );

    expect(find.text('Slime Gel'), findsOneWidget);
    expect(find.text('Small Potion'), findsOneWidget);

    final consumableChip = find.widgetWithText(ChoiceChip, 'Consumable');
    await tester.ensureVisible(consumableChip);
    await tester.pumpAndSettle();
    await tester.tap(consumableChip);
    await tester.pumpAndSettle();

    expect(find.text('Slime Gel'), findsNothing);
    expect(find.text('Small Potion'), findsOneWidget);

    final semuaChip = find.widgetWithText(ChoiceChip, 'Semua');
    await tester.ensureVisible(semuaChip);
    await tester.pumpAndSettle();
    await tester.tap(semuaChip);
    final commonChip = find.widgetWithText(ChoiceChip, 'Common');
    await tester.ensureVisible(commonChip);
    await tester.pumpAndSettle();
    await tester.tap(commonChip);
    await tester.pumpAndSettle();

    expect(find.text('Slime Gel'), findsOneWidget);
    expect(find.text('Small Potion'), findsNothing);
  });

  testWidgets('EquipmentOverlay mendukung filter kategori dan rarity', (
    tester,
  ) async {
    final swordDef = const ItemDefinition(
      id: 'rusty_sword',
      name: 'Rusty Sword',
      category: ItemCategory.equipment,
      rarity: ItemRarity.common,
    );
    final armorDef = const ItemDefinition(
      id: 'aether_mail',
      name: 'Aether Mail',
      category: ItemCategory.equipment,
      rarity: ItemRarity.epic,
    );
    final helmDef = const ItemDefinition(
      id: 'iron_helm',
      name: 'Iron Helm',
      category: ItemCategory.equipment,
      rarity: ItemRarity.uncommon,
    );
    final snapshot = ValueNotifier<EquipmentSnapshot>(
      EquipmentSnapshot(
        stats: const CombatStats(maxHp: 100, atk: 10, def: 5),
        equipped: const {},
        bag: const [
          EquipmentInstance(
            id: 'eq_1',
            definitionId: 'rusty_sword',
            slot: EquipmentSlot.weapon,
            rarity: ItemRarity.common,
            rolledStats: EquipmentStats(atk: 5),
          ),
          EquipmentInstance(
            id: 'eq_2',
            definitionId: 'aether_mail',
            slot: EquipmentSlot.body,
            rarity: ItemRarity.epic,
            rolledStats: EquipmentStats(def: 12),
          ),
          EquipmentInstance(
            id: 'eq_3',
            definitionId: 'iron_helm',
            slot: EquipmentSlot.head,
            rarity: ItemRarity.uncommon,
            rolledStats: EquipmentStats(hp: 40),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EquipmentOverlay(
            snapshot: snapshot,
            items: {
              'rusty_sword': swordDef,
              'aether_mail': armorDef,
              'iron_helm': helmDef,
            },
            onEquip: (_) {},
            onUnequip: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('Rusty Sword'), findsOneWidget);
    expect(find.text('Aether Mail'), findsOneWidget);
    expect(find.text('Iron Helm'), findsOneWidget);

    // Filter Badan
    final badanChip = find.widgetWithText(ChoiceChip, 'Badan');
    await tester.ensureVisible(badanChip);
    await tester.pumpAndSettle();
    await tester.tap(badanChip);
    await tester.pumpAndSettle();

    expect(find.text('Rusty Sword'), findsNothing);
    expect(find.text('Iron Helm'), findsNothing);
    expect(find.text('Aether Mail'), findsOneWidget);

    // Filter Kepala
    final kepalaChip = find.widgetWithText(ChoiceChip, 'Kepala');
    await tester.ensureVisible(kepalaChip);
    await tester.pumpAndSettle();
    await tester.tap(kepalaChip);
    await tester.pumpAndSettle();

    expect(find.text('Rusty Sword'), findsNothing);
    expect(find.text('Aether Mail'), findsNothing);
    expect(find.text('Iron Helm'), findsOneWidget);

    final semuaChip = find.widgetWithText(ChoiceChip, 'Semua');
    await tester.ensureVisible(semuaChip);
    await tester.pumpAndSettle();
    await tester.tap(semuaChip);
    final commonChip = find.widgetWithText(ChoiceChip, 'Common');
    await tester.ensureVisible(commonChip);
    await tester.pumpAndSettle();
    await tester.tap(commonChip);
    await tester.pumpAndSettle();

    expect(find.text('Rusty Sword'), findsOneWidget);
    expect(find.text('Aether Mail'), findsNothing);
    expect(find.text('Iron Helm'), findsNothing);
  });
}
