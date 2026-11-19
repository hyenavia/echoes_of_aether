import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/services/bag_expansion_service.dart';
import 'package:echoes_of_aether/features/dungeon/equipment_overlay.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseStats = CombatStats(maxHp: 100, atk: 12, def: 2);
  const items = {
    'sword_1': ItemDefinition(
      id: 'sword_1',
      name: 'Iron Sword',
      category: ItemCategory.equipment,
      equipment: EquipmentData(
        slot: EquipmentSlot.weapon,
        weaponType: 'sword',
        baseStats: EquipmentStats(atk: 5),
      ),
    ),
  };

  final testEquipment = EquipmentInstance(
    id: 'eq_1',
    definitionId: 'sword_1',
    slot: EquipmentSlot.weapon,
    rarity: ItemRarity.common,
    rolledStats: const EquipmentStats(atk: 5),
  );

  group('EquipmentOverlay Bag Expansion UI Tests', () {
    testWidgets(
      'Menampilkan kapasitas tas (1 / 100) dan tombol +20 Slot saat belum maxLevel',
      (tester) async {
        final snapshot = ValueNotifier(
          EquipmentSnapshot(
            equipped: const {},
            bag: [testEquipment],
            stats: baseStats,
            maxCapacity: 100,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EquipmentOverlay(
                snapshot: snapshot,
                items: items,
                onEquip: (_) {},
                onUnequip: (_) {},
                bagLevelProvider: () => 0,
                playerGoldProvider: () => 50000,
                onExpandBag: () async => true,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tas perlengkapan (1 / 100)'), findsOneWidget);
        expect(
          find.byKey(const Key('expand_bag_capacity_button')),
          findsOneWidget,
        );
        expect(find.text('+20 Slot'), findsOneWidget);
      },
    );

    testWidgets(
      'Klik tombol +20 Slot membuka dialog konfirmasi dan eksekusi sukses memunculkan SnackBar',
      (tester) async {
        var expandCalled = false;
        var bagLevel = 0;
        final snapshot = ValueNotifier(
          EquipmentSnapshot(
            equipped: const {},
            bag: [testEquipment],
            stats: baseStats,
            maxCapacity: 100,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EquipmentOverlay(
                snapshot: snapshot,
                items: items,
                onEquip: (_) {},
                onUnequip: (_) {},
                bagLevelProvider: () => bagLevel,
                playerGoldProvider: () => 50000,
                onExpandBag: () async {
                  expandCalled = true;
                  bagLevel = 1;
                  snapshot.value = EquipmentSnapshot(
                    equipped: const {},
                    bag: [testEquipment],
                    stats: baseStats,
                    maxCapacity: 120,
                  );
                  return true;
                },
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Ketuk tombol +20 Slot
        await tester.tap(find.byKey(const Key('expand_bag_capacity_button')));
        await tester.pumpAndSettle();

        // Dialog konfirmasi muncul
        expect(find.text('Perluas Kapasitas Tas'), findsOneWidget);
        expect(find.text('0 -> 1 / 10'), findsOneWidget);
        expect(find.text('100 -> 120 slot'), findsOneWidget);
        expect(find.text('10K Gold'), findsOneWidget);
        expect(find.text('50K Gold'), findsOneWidget);

        // Ketuk tombol Perluas
        final confirmBtn = find.byKey(const Key('confirm_expand_bag_button'));
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(expandCalled, isTrue);
        expect(
          find.text('Kapasitas tas berhasil diperluas menjadi 120 slot!'),
          findsOneWidget,
        );
        expect(find.text('Tas perlengkapan (1 / 120)'), findsOneWidget);
      },
    );

    testWidgets(
      'Dialog menonaktifkan tombol Perluas dan memberi peringatan jika Gold tidak cukup',
      (tester) async {
        final snapshot = ValueNotifier(
          EquipmentSnapshot(
            equipped: const {},
            bag: [testEquipment],
            stats: baseStats,
            maxCapacity: 100,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EquipmentOverlay(
                snapshot: snapshot,
                items: items,
                onEquip: (_) {},
                onUnequip: (_) {},
                bagLevelProvider: () => 0,
                playerGoldProvider: () => 5000, // Butuh 10.000
                onExpandBag: () async => true,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('expand_bag_capacity_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Gold tidak mencukupi untuk memperluas tas.'),
          findsOneWidget,
        );
        final confirmBtn = tester.widget<FilledButton>(
          find.byKey(const Key('confirm_expand_bag_button')),
        );
        expect(confirmBtn.onPressed, isNull); // Disabled
      },
    );

    testWidgets(
      'Tombol +20 Slot tidak ditampilkan jika sudah mencapai maxLevel 10',
      (tester) async {
        final snapshot = ValueNotifier(
          EquipmentSnapshot(
            equipped: const {},
            bag: [testEquipment],
            stats: baseStats,
            maxCapacity: 300,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EquipmentOverlay(
                snapshot: snapshot,
                items: items,
                onEquip: (_) {},
                onUnequip: (_) {},
                bagLevelProvider: () => BagExpansionService.maxLevel,
                playerGoldProvider: () => 9999999,
                onExpandBag: () async => true,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tas perlengkapan (1 / 300)'), findsOneWidget);
        expect(
          find.byKey(const Key('expand_bag_capacity_button')),
          findsNothing,
        );
      },
    );
  });
}
