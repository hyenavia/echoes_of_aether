import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/mystery_box.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/shop_config.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/mystery_box_service.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:echoes_of_aether/features/dungeon/shop_overlay.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const progression = ProgressionConfig(
    maxLevel: 30,
    baseStats: CombatStats(maxHp: 100, atk: 10, def: 5),
    perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
  );

  const testSword = ItemDefinition(
    id: 'iron_sword',
    name: 'Iron Sword',
    category: ItemCategory.equipment,
    rarity: ItemRarity.rare,
    equipment: EquipmentData(
      slot: EquipmentSlot.weapon,
      baseStats: EquipmentStats(atk: 20),
    ),
  );

  final items = <String, ItemDefinition>{testSword.id: testSword};
  final catalog = ShopCatalog();
  const factory = EquipmentFactory(EquipmentConfig());

  Widget createSubject({
    required int playerLevel,
    required int playerGold,
    required Future<MysteryBoxOpenResult> Function(MysteryBoxTier, int)?
    onOpenMysteryBox,
  }) {
    final inv = Inventory(definitions: items);
    final char = PlayerCharacter(config: progression);
    final views = InventoryViews(inventory: inv, character: char);
    final shopService = ShopService(
      catalog: catalog,
      items: items,
      equipmentFactory: factory,
    );

    return MaterialApp(
      home: Scaffold(
        body: ShopOverlay(
          catalog: catalog,
          items: items,
          dungeons: const {},
          shopService: shopService,
          playerContext: ShopPlayerContext(playerLevel: playerLevel),
          playerGold: playerGold,
          views: views,
          onBuy: (_) async => const ShopBuyNotFound(entryId: 'none'),
          onSellEquipment: (_) async =>
              const ShopSellNotFound(targetId: 'none'),
          onSellMaterialBulk: (_, _) async =>
              const ShopSellNotFound(targetId: 'none'),
          onOpenMysteryBox: onOpenMysteryBox,
          onClose: () {},
        ),
      ),
    );
  }

  testWidgets(
    'ShopOverlay menampilkan tab Peti Misteri jika callback onOpenMysteryBox disediakan',
    (tester) async {
      await tester.pumpWidget(
        createSubject(
          playerLevel: 25,
          playerGold: 1000000,
          onOpenMysteryBox: (_, _) async =>
              const MysteryBoxOpenResult(status: MysteryBoxOpenStatus.success),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Beli'), findsOneWidget);
      expect(find.text('Jual'), findsOneWidget);
      expect(find.text('Peti Misteri'), findsOneWidget);
    },
  );

  testWidgets(
    'Beralih ke tab Peti Misteri menampilkan 3 jenis peti dan rincian peluangnya',
    (tester) async {
      await tester.pumpWidget(
        createSubject(
          playerLevel: 25,
          playerGold: 1000000,
          onOpenMysteryBox: (_, _) async =>
              const MysteryBoxOpenResult(status: MysteryBoxOpenStatus.success),
        ),
      );
      await tester.pumpAndSettle();

      // Tap tab Peti Misteri
      await tester.tap(find.text('Peti Misteri'));
      await tester.pumpAndSettle();

      expect(find.text('Peti Petualang'), findsOneWidget);
      expect(find.text('Peti Prajurit Kuno'), findsOneWidget);
      expect(find.text('Peti Aether Kerajaan'), findsOneWidget);

      expect(find.text('Syarat: Lv. 1+'), findsOneWidget);
      expect(find.text('Syarat: Lv. 10+'), findsOneWidget);
      expect(find.text('Syarat: Lv. 20+'), findsOneWidget);

      expect(
        find.byKey(const Key('mystery_box_open_1_novice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mystery_box_open_5_novice')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Mengetuk Buka 1x memanggil callback onOpenMysteryBox dan menampilkan reveal dialog',
    (tester) async {
      MysteryBoxTier? openedTier;
      int? openedCount;

      final rolledItem = EquipmentInstance(
        id: 'eq_1',
        definitionId: 'iron_sword',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.rare,
        rolledStats: const EquipmentStats(atk: 25),
      );

      await tester.pumpWidget(
        createSubject(
          playerLevel: 25,
          playerGold: 1000000,
          onOpenMysteryBox: (tier, count) async {
            openedTier = tier;
            openedCount = count;
            return MysteryBoxOpenResult(
              status: MysteryBoxOpenStatus.success,
              tier: tier,
              count: count,
              itemsObtained: [rolledItem],
              goldSpent: 25000,
              remainingGold: 975000,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Peti Misteri'));
      await tester.pumpAndSettle();

      final open1NoviceBtn = find.byKey(const Key('mystery_box_open_1_novice'));
      await tester.tap(open1NoviceBtn);
      await tester.pumpAndSettle();

      expect(openedTier, MysteryBoxTier.novice);
      expect(openedCount, 1);

      // Dialog hasil pembukaan
      expect(find.text('Hasil Peti Misteri'), findsOneWidget);
      expect(find.text('Iron Sword'), findsOneWidget);
      expect(find.text('Simpan ke Tas'), findsOneWidget);

      await tester.tap(find.text('Simpan ke Tas'));
      await tester.pumpAndSettle();

      expect(find.text('Hasil Peti Misteri'), findsNothing);
    },
  );

  testWidgets(
    'Tombol Buka dinonaktifkan bila gold tidak mencukupi atau level belum cukup',
    (tester) async {
      await tester.pumpWidget(
        createSubject(
          playerLevel: 5, // Kurang dari 10 & 20
          playerGold: 5000, // Kurang dari 25k
          onOpenMysteryBox: (_, _) async =>
              const MysteryBoxOpenResult(status: MysteryBoxOpenStatus.success),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Peti Misteri'));
      await tester.pumpAndSettle();

      // Novice (butuh 25k, punya 5k) -> disabled
      final novice1Btn = tester.widget<OutlinedButton>(
        find.byKey(const Key('mystery_box_open_1_novice')),
      );
      expect(novice1Btn.onPressed, isNull);

      // Warrior (butuh Lv 10, punya Lv 5) -> disabled
      final warrior1Btn = tester.widget<OutlinedButton>(
        find.byKey(const Key('mystery_box_open_1_warrior')),
      );
      expect(warrior1Btn.onPressed, isNull);
    },
  );
}
