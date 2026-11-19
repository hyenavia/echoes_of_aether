import 'dart:math';

import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/blacksmith_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/features/dungeon/blacksmith_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/equipment_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const progression = ProgressionConfig(
    maxLevel: 10,
    expBase: 100,
    expGrowth: 2.0,
    baseStats: CombatStats(maxHp: 100, atk: 10, def: 5),
    perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
  );

  const swordDef = ItemDefinition(
    id: 'iron_sword',
    name: 'Iron Sword',
    category: ItemCategory.equipment,
    rarity: ItemRarity.rare,
    equipment: EquipmentData(
      slot: EquipmentSlot.weapon,
      weaponType: 'sword',
      baseStats: EquipmentStats(atk: 25, critRate: 0.05),
    ),
  );

  const matGel = ItemDefinition(
    id: 'slime_gel',
    name: 'Slime Gel',
    category: ItemCategory.material,
    maxStack: 999,
  );

  final items = <String, ItemDefinition>{
    swordDef.id: swordDef,
    matGel.id: matGel,
  };

  EquipmentInstance makeEquipment(
    String id,
    ItemDefinition def, {
    int lvl = 0,
  }) {
    final factory = EquipmentFactory(const EquipmentConfig(rollVariance: 0.0));
    final base = factory.create(
      instanceId: id,
      definition: def,
      random: Random(1),
    );
    return base.copyWith(enhancementLevel: lvl);
  }

  Widget createSubject({
    required InventoryViews views,
    required BlacksmithEnhanceResult Function(String) onEnhance,
    required BlacksmithReforgeResult Function(String) onReforge,
    VoidCallback? onClose,
    String? initialId,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BlacksmithOverlay(
          snapshot: views.equipment,
          items: items,
          inventoryEntries: views.stacks,
          characterSnapshot: views.characterView,
          initialSelectedInstanceId: initialId,
          onEnhanceEquipment: onEnhance,
          onReforgeEquipment: onReforge,
          onClose: onClose ?? () {},
        ),
      ),
    );
  }

  testWidgets(
    'BlacksmithOverlay displays header, gold, equipment and mode selector',
    (tester) async {
      final inv = Inventory(definitions: items);
      final char = PlayerCharacter(config: progression);
      char.addGold(50000);

      final sword = makeEquipment('eq_sword', swordDef, lvl: 0);
      inv.addEquipment(sword);
      inv.add('slime_gel', 10);

      final views = InventoryViews(inventory: inv, character: char);

      await tester.pumpWidget(
        createSubject(
          views: views,
          onEnhance: (_) => const BlacksmithEnhanceResult(
            status: BlacksmithEnhanceStatus.success,
          ),
          onReforge: (_) => const BlacksmithReforgeResult(
            status: BlacksmithReforgeStatus.success,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pandai Besi'), findsOneWidget);
      expect(find.textContaining('Gold 50K'), findsOneWidget);
      expect(find.text('Tempa (+1..+10)'), findsOneWidget);
      expect(find.text('Reforge Sub-stat'), findsOneWidget);
      expect(find.text('Iron Sword'), findsNWidgets(2));
      expect(find.text('Tempa (+1)'), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping Tempa calls onEnhanceEquipment and displays success message',
    (tester) async {
      final inv = Inventory(definitions: items);
      final char = PlayerCharacter(config: progression);
      char.addGold(50000);

      final sword = makeEquipment('eq_sword', swordDef, lvl: 0);
      inv.addEquipment(sword);
      inv.add('slime_gel', 10);

      final views = InventoryViews(inventory: inv, character: char);
      var enhanceCalledWith = '';

      await tester.pumpWidget(
        createSubject(
          views: views,
          onEnhance: (id) {
            enhanceCalledWith = id;
            return BlacksmithEnhanceResult(
              status: BlacksmithEnhanceStatus.success,
              updatedInstance: sword.copyWith(enhancementLevel: 1),
              goldSpent: 5000,
            );
          },
          onReforge: (_) => const BlacksmithReforgeResult(
            status: BlacksmithReforgeStatus.success,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // PrimaryButton uses FilledButton under the hood
      final primaryBtn = find.text('Tempa (+1)');
      expect(primaryBtn, findsOneWidget);

      await tester.tap(primaryBtn);
      await tester.pumpAndSettle();

      expect(enhanceCalledWith, 'eq_sword');
      expect(
        find.textContaining('Iron Sword berhasil ditempa ke +1'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Switching to Reforge Sub-stat tab displays reforge cost and triggers onReforgeEquipment',
    (tester) async {
      final inv = Inventory(definitions: items);
      final char = PlayerCharacter(config: progression);
      char.addGold(100000);

      final sword = makeEquipment('eq_sword', swordDef, lvl: 2);
      inv.addEquipment(sword);

      final views = InventoryViews(inventory: inv, character: char);
      var reforgeCalledWith = '';

      await tester.pumpWidget(
        createSubject(
          views: views,
          onEnhance: (_) => const BlacksmithEnhanceResult(
            status: BlacksmithEnhanceStatus.success,
          ),
          onReforge: (id) {
            reforgeCalledWith = id;
            return BlacksmithReforgeResult(
              status: BlacksmithReforgeStatus.success,
              updatedInstance: sword,
              goldSpent: 50000,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Tap Reforge mode tab
      await tester.tap(find.text('Reforge Sub-stat'));
      await tester.pumpAndSettle();

      expect(find.text('Biaya: 50K Gold'), findsOneWidget);
      expect(find.text('Reforge Sub-stat (50K G)'), findsOneWidget);

      await tester.tap(find.text('Reforge Sub-stat (50K G)'));
      await tester.pumpAndSettle();

      expect(reforgeCalledWith, 'eq_sword');
      expect(
        find.textContaining('Sub-stat Iron Sword berhasil di-reforge'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'TownHubView quick access Tempa opens BlacksmithOverlay in bag tab',
    (tester) async {
      final inv = Inventory(definitions: items);
      final char = PlayerCharacter(config: progression);
      char.addGold(50000);

      final sword = makeEquipment('eq_sword', swordDef, lvl: 0);
      inv.addEquipment(sword);

      final views = InventoryViews(inventory: inv, character: char);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TownHubView(
              character: char,
              views: views,
              items: items,
              dungeonProgress: const DungeonProgressSnapshot(),
              dungeonDefinition: null,
              onEnterDungeon: () {},
              onEquip: (_) {},
              onUnequip: (_) {},
              onChooseSpecialization: (_) {},
              onEnhanceEquipment: (_) => const BlacksmithEnhanceResult(
                status: BlacksmithEnhanceStatus.success,
              ),
              onReforgeEquipment: (_) => const BlacksmithReforgeResult(
                status: BlacksmithReforgeStatus.success,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_access_blacksmith')), findsNothing);

      await tester.tap(find.text('Bag'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tempa'));
      await tester.pumpAndSettle();

      expect(find.text('Pandai Besi'), findsOneWidget);
      expect(find.text('Tempa (+1..+10)'), findsOneWidget);
      expect(find.text('Reforge Sub-stat'), findsOneWidget);
    },
  );

  testWidgets(
    'EquipmentOverlay triggers onOpenBlacksmith when tapping forge icon',
    (tester) async {
      final inv = Inventory(definitions: items);
      final char = PlayerCharacter(config: progression);
      final sword = makeEquipment('eq_sword', swordDef, lvl: 0);
      inv.addEquipment(sword);

      final views = InventoryViews(inventory: inv, character: char);
      var openedId = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EquipmentOverlay(
              snapshot: views.equipment,
              items: items,
              onEquip: (_) {},
              onUnequip: (_) {},
              onOpenBlacksmith: (id) => openedId = id,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final forgeBtn = find.byTooltip('Tempa di Pandai Besi');
      await tester.scrollUntilVisible(
        forgeBtn,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(forgeBtn, findsOneWidget);

      await tester.tap(forgeBtn);
      await tester.pumpAndSettle();

      expect(openedId, 'eq_sword');
    },
  );
}
