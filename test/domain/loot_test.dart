import 'dart:math';

import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loot_table.dart';
import 'package:echoes_of_aether/domain/services/loot_service.dart';
import 'package:flutter_test/flutter_test.dart';

const gel = ItemDefinition(
  id: 'gel',
  name: 'Gel',
  category: ItemCategory.material,
  maxStack: 10,
);
const potion = ItemDefinition(
  id: 'potion',
  name: 'Potion',
  category: ItemCategory.consumable,
);
const sigil = ItemDefinition(
  id: 'sigil',
  name: 'Sigil',
  category: ItemCategory.questItem,
  maxStack: 1,
);
const charm = ItemDefinition(
  id: 'charm',
  name: 'Charm',
  category: ItemCategory.equipment,
  rarity: ItemRarity.rare,
  equipment: EquipmentData(
    slot: EquipmentSlot.accessory,
    baseStats: EquipmentStats(hp: 20),
  ),
);

void main() {
  const service = LootService();

  group('LootService', () {
    test('chance 1.0 selalu drop dengan jumlah dalam rentang', () {
      const table = LootTable(
        id: 't',
        entries: [
          LootEntry(itemId: 'gel', chance: 1.0, minQuantity: 2, maxQuantity: 4),
        ],
      );
      final random = Random(5);
      for (var i = 0; i < 200; i++) {
        final drops = service.roll(table, random);
        expect(drops, hasLength(1));
        expect(drops.single.quantity, inInclusiveRange(2, 4));
      }
    });

    test('jumlah tetap jika min sama dengan max', () {
      const table = LootTable(
        id: 't',
        entries: [
          LootEntry(itemId: 'gel', chance: 1.0, minQuantity: 3, maxQuantity: 3),
        ],
      );
      expect(service.roll(table, Random(1)).single.quantity, 3);
    });

    test('peluang drop mendekati nilai chance', () {
      const table = LootTable(
        id: 't',
        entries: [LootEntry(itemId: 'gel', chance: 0.5)],
      );
      final random = Random(123);
      var hits = 0;
      for (var i = 0; i < 4000; i++) {
        hits += service.roll(table, random).length;
      }
      expect(hits / 4000, inInclusiveRange(0.45, 0.55));
    });

    test('seed sama menghasilkan drop yang sama', () {
      const table = LootTable(
        id: 't',
        entries: [
          LootEntry(itemId: 'gel', chance: 0.5, minQuantity: 1, maxQuantity: 5),
          LootEntry(itemId: 'potion', chance: 0.3),
        ],
      );
      List<String> run() {
        final random = Random(99);
        return [
          for (var i = 0; i < 100; i++)
            service
                .roll(table, random)
                .map((d) => '${d.itemId}x${d.quantity}')
                .join(','),
        ];
      }

      expect(run(), run());
    });

    test('tabel kosong tidak menghasilkan drop', () {
      const table = LootTable(id: 't', entries: []);
      expect(service.roll(table, Random(1)), isEmpty);
    });
  });

  group('Inventory', () {
    Inventory make() => Inventory(definitions: {'gel': gel, 'potion': potion});

    test('menumpuk item yang sama', () {
      final inv = make();
      inv.add('gel', 3);
      inv.add('gel', 4);
      expect(inv.quantityOf('gel'), 7);
    });

    test('batas stack: kelebihan dilaporkan sebagai overflow', () {
      final inv = make();
      final r = inv.add('gel', 15);
      expect(r.added, 10);
      expect(r.overflow, 5);
      expect(inv.quantityOf('gel'), 10);
      final again = inv.add('gel', 1);
      expect(again.added, 0);
      expect(again.overflow, 1);
    });

    test('remove hanya berhasil jika jumlah cukup', () {
      final inv = make()..add('gel', 5);
      expect(inv.remove('gel', 6), isFalse);
      expect(inv.quantityOf('gel'), 5);
      expect(inv.remove('gel', 5), isTrue);
      expect(inv.quantityOf('gel'), 0);
      expect(inv.snapshot(), isEmpty);
    });

    test('item tidak dikenal menghasilkan error', () {
      expect(() => make().add('hantu', 1), throwsArgumentError);
    });

    test('snapshot terurut berdasarkan id', () {
      final inv = make()
        ..add('potion', 1)
        ..add('gel', 2);
      expect(inv.snapshot().map((e) => e.definition.id), ['gel', 'potion']);
    });

    test(
      'jumlah nol atau negatif diabaikan saat add dan remove negatif ditolak',
      () {
        final inv = make()..add('gel', 4);
        expect(inv.add('gel', 0).added, 0);
        expect(inv.add('gel', -3).added, 0);
        expect(inv.remove('gel', -1), isFalse);
        expect(inv.quantityOf('gel'), 4);
      },
    );

    test('item non-stackable (maxStack 1) menolak duplikasi stack', () {
      final inv = Inventory(definitions: {'sigil': sigil});
      final first = inv.add('sigil', 1);
      final second = inv.add('sigil', 2);
      expect([first.added, first.overflow], [1, 0]);
      expect([second.added, second.overflow], [0, 2]);
      expect(inv.quantityOf('sigil'), 1);
    });

    test('kapasitas slot stack dan tas equipment membatasi isi tas', () {
      final inv = Inventory(
        definitions: {'gel': gel, 'potion': potion, 'charm': charm},
        maxStackSlots: 1,
        maxEquipmentCapacity: 1,
      );
      expect(inv.add('gel', 2).added, 2);
      // Slot stack penuh: item jenis baru overflow, item lama tetap bertambah.
      final blocked = inv.add('potion', 3);
      expect([blocked.added, blocked.overflow], [0, 3]);
      expect(inv.add('gel', 3).added, 3);

      const eq1 = EquipmentInstance(
        id: 'eq_1',
        definitionId: 'charm',
        slot: EquipmentSlot.accessory,
        rarity: ItemRarity.rare,
        rolledStats: EquipmentStats(hp: 20),
      );
      const eq2 = EquipmentInstance(
        id: 'eq_2',
        definitionId: 'charm',
        slot: EquipmentSlot.accessory,
        rarity: ItemRarity.rare,
        rolledStats: EquipmentStats(hp: 22),
      );
      expect(inv.addEquipment(eq1), isTrue);
      expect(inv.hasEquipmentSpace, isFalse);
      expect(inv.addEquipment(eq2), isFalse);
      expect(inv.equipmentCount, 1);

      expect(inv.removeEquipment('eq_1'), isTrue);
      expect(inv.hasEquipmentSpace, isTrue);
      expect(inv.addEquipment(eq2), isTrue);
    });

    test(
      'snapshot & restore memulihkan isi dan mencegah tabrakan id equipment',
      () {
        final source = Inventory(definitions: {'gel': gel, 'charm': charm});
        source.add('gel', 6);
        final eqId = source.nextEquipmentId();
        source.addEquipment(
          EquipmentInstance(
            id: eqId,
            definitionId: 'charm',
            slot: EquipmentSlot.accessory,
            rarity: ItemRarity.rare,
            rolledStats: const EquipmentStats(hp: 20),
          ),
        );

        final snapshot = source.toSnapshot();
        final restored = Inventory(definitions: {'gel': gel, 'charm': charm})
          ..restore(snapshot);

        expect(restored.quantityOf('gel'), 6);
        expect(restored.equipmentSnapshot().single.id, eqId);
        expect(restored.nextEquipmentId(), isNot(eqId));
      },
    );
  });
}
