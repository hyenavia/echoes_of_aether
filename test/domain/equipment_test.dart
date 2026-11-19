import 'dart:math';

import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/equipment_loadout.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/equipment_service.dart';
import 'package:flutter_test/flutter_test.dart';

const sword = ItemDefinition(
  id: 'sword',
  name: 'Sword',
  category: ItemCategory.equipment,
  rarity: ItemRarity.uncommon,
  equipment: EquipmentData(
    slot: EquipmentSlot.weapon,
    weaponType: 'sword',
    baseStats: EquipmentStats(atk: 10, critRate: 0.04),
  ),
);
const cap = ItemDefinition(
  id: 'cap',
  name: 'Cap',
  category: ItemCategory.equipment,
  equipment: EquipmentData(
    slot: EquipmentSlot.head,
    baseStats: EquipmentStats(def: 2, hp: 10),
  ),
);
const gel = ItemDefinition(
  id: 'gel',
  name: 'Gel',
  category: ItemCategory.material,
);

const progression = ProgressionConfig(
  maxLevel: 5,
  expBase: 100,
  expGrowth: 2.0,
  baseStats: CombatStats(
    maxHp: 100,
    atk: 10,
    def: 2,
    attackSpeed: 1.5,
    critRate: 0.1,
    critDamage: 1.5,
    moveSpeed: 4,
    attackRange: 1.5,
  ),
  perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
);

EquipmentInstance make(String id, ItemDefinition def, {Random? random}) =>
    const EquipmentFactory(EquipmentConfig(rollVariance: 0))
        .create(instanceId: id, definition: def, random: random ?? Random(1));

void main() {
  group('EquipmentStats', () {
    test('penjumlahan per stat', () {
      const a = EquipmentStats(atk: 4, hp: 10);
      const b = EquipmentStats(atk: 1.5, critRate: 0.02);
      final c = a + b;
      expect(c.atk, 5.5);
      expect(c.hp, 10);
      expect(c.critRate, 0.02);
    });

    test('roll berada dalam rentang variance dan stat nol tetap nol', () {
      const base = EquipmentStats(atk: 10, critRate: 0.04);
      final random = Random(7);
      for (var i = 0; i < 500; i++) {
        final r = base.roll(random, 0.2);
        expect(r.atk, inInclusiveRange(8.0, 12.0));
        expect(r.critRate, inInclusiveRange(0.032, 0.048));
        expect(r.hp, 0);
        expect(r.def, 0);
      }
    });

    test('roll dengan seed sama menghasilkan nilai sama', () {
      const base = EquipmentStats(atk: 10, def: 3, hp: 20);
      final a = base.roll(Random(42), 0.15);
      final b = base.roll(Random(42), 0.15);
      expect([a.atk, a.def, a.hp], [b.atk, b.def, b.hp]);
    });

    test('variance 0 menghasilkan nilai dasar', () {
      const base = EquipmentStats(atk: 10);
      expect(base.roll(Random(1), 0).atk, 10);
    });

    test('applyTo membulatkan total dan membatasi crit rate maksimum 1', () {
      const base = CombatStats(
        maxHp: 100,
        atk: 10,
        def: 2,
        critRate: 0.95,
        critDamage: 1.5,
        attackSpeed: 1.0,
        moveSpeed: 4,
        attackRange: 1.5,
      );
      const bonus = EquipmentStats(
        hp: 10.4,
        atk: 3.6,
        def: 1.2,
        critRate: 0.2,
        critDamage: 0.1,
      );
      final s = bonus.applyTo(base);
      expect(s.maxHp, 110);
      expect(s.atk, 14);
      expect(s.def, 3);
      expect(s.critRate, 1.0);
      expect(s.critDamage, closeTo(1.6, 1e-9));
    });
  });

  group('EquipmentFactory', () {
    test('membuat instance dengan slot, rarity, dan stat hasil roll', () {
      final inst = const EquipmentFactory(EquipmentConfig(rollVariance: 0.15))
          .create(instanceId: 'eq_1', definition: sword, random: Random(3));
      expect(inst.id, 'eq_1');
      expect(inst.definitionId, 'sword');
      expect(inst.slot, EquipmentSlot.weapon);
      expect(inst.rarity, ItemRarity.uncommon);
      expect(inst.rolledStats.atk, inInclusiveRange(8.5, 11.5));
      expect(inst.enhancementLevel, 0);
    });

    test('dua instance dari definisi sama bisa memiliki stat berbeda', () {
      const factory = EquipmentFactory(EquipmentConfig(rollVariance: 0.3));
      final random = Random(11);
      final a = factory.create(
        instanceId: 'a',
        definition: sword,
        random: random,
      );
      final b = factory.create(
        instanceId: 'b',
        definition: sword,
        random: random,
      );
      expect(a.rolledStats.atk, isNot(b.rolledStats.atk));
    });

    test('item non-equipment ditolak', () {
      expect(
        () =>
            const EquipmentFactory(EquipmentConfig())
                .create(instanceId: 'x', definition: gel, random: Random(1)),
        throwsArgumentError,
      );
    });
  });

  group('EquipmentLoadout', () {
    test('equip mengembalikan instance lama dan menaikkan revision', () {
      final loadout = EquipmentLoadout();
      final a = make('a', sword);
      final b = make('b', sword);
      expect(loadout.equip(a), isNull);
      expect(loadout.revision, 1);
      expect(loadout.equip(b), a);
      expect(loadout.instanceIn(EquipmentSlot.weapon), b);
      expect(loadout.revision, 2);
    });

    test('unequip slot kosong tidak mengubah revision', () {
      final loadout = EquipmentLoadout();
      expect(loadout.unequip(EquipmentSlot.head), isNull);
      expect(loadout.revision, 0);
    });

    test('totalBonus menjumlahkan semua equipment terpasang', () {
      final loadout = EquipmentLoadout()
        ..equip(make('a', sword))
        ..equip(make('b', cap));
      final total = loadout.totalBonus;
      expect(total.atk, 10);
      expect(total.def, 2);
      expect(total.hp, 10);
      expect(total.critRate, 0.04);
    });
  });

  group('Inventory + EquipmentService', () {
    Inventory newInventory() =>
        Inventory(definitions: {'sword': sword, 'cap': cap, 'gel': gel});

    test('add() menolak equipment', () {
      expect(() => newInventory().add('sword', 1), throwsArgumentError);
    });

    test('id equipment unik dan tas mempertahankan urutan masuk', () {
      final inv = newInventory();
      final a = make(inv.nextEquipmentId(), sword);
      final b = make(inv.nextEquipmentId(), cap);
      inv
        ..addEquipment(a)
        ..addEquipment(b);
      expect(a.id, isNot(b.id));
      expect(inv.equipmentSnapshot().map((e) => e.id), [a.id, b.id]);
    });

    test('equip memindahkan dari tas ke loadout', () {
      final inv = newInventory();
      final loadout = EquipmentLoadout();
      final svc = EquipmentService(inventory: inv, loadout: loadout);
      final a = make(inv.nextEquipmentId(), sword);
      inv.addEquipment(a);

      expect(svc.equip(a.id), isTrue);
      expect(inv.equipmentSnapshot(), isEmpty);
      expect(loadout.instanceIn(EquipmentSlot.weapon), a);
    });

    test('equip pada slot terisi menukar: yang lama kembali ke tas', () {
      final inv = newInventory();
      final loadout = EquipmentLoadout();
      final svc = EquipmentService(inventory: inv, loadout: loadout);
      final a = make(inv.nextEquipmentId(), sword);
      final b = make(inv.nextEquipmentId(), sword);
      inv
        ..addEquipment(a)
        ..addEquipment(b);

      svc.equip(a.id);
      svc.equip(b.id);
      expect(loadout.instanceIn(EquipmentSlot.weapon), b);
      expect(inv.equipmentSnapshot().map((e) => e.id), [a.id]);
    });

    test(
      'unequip mengembalikan ke tas; id tidak dikenal/slot kosong gagal',
      () {
        final inv = newInventory();
        final loadout = EquipmentLoadout();
        final svc = EquipmentService(inventory: inv, loadout: loadout);
        final a = make(inv.nextEquipmentId(), cap);
        inv.addEquipment(a);
        svc.equip(a.id);

        expect(svc.unequip(EquipmentSlot.head), isTrue);
        expect(inv.equipmentSnapshot().single.id, a.id);
        expect(svc.unequip(EquipmentSlot.head), isFalse);
        expect(svc.equip('tidak_ada'), isFalse);
      },
    );

    test('equip menolak instance dengan slot tidak cocok definisi dan swap tetap aman saat tas penuh', () {
      final fullBag = Inventory(
        definitions: {'sword': sword, 'cap': cap, 'gel': gel},
        maxEquipmentCapacity: 1,
      );
      final loadout = EquipmentLoadout();
      final svc = EquipmentService(inventory: fullBag, loadout: loadout);

      final w1 = make(fullBag.nextEquipmentId(), sword);
      fullBag.addEquipment(w1);
      expect(svc.equip(w1.id), isTrue);

      // Isi tas penuh (kapasitas 1) oleh w2: swap tetap sukses (delta 0),
      // tetapi unequip saat tas penuh ditolak agar item tidak hilang.
      final w2 = make(fullBag.nextEquipmentId(), sword);
      fullBag.addEquipment(w2);
      expect(svc.equip(w2.id), isTrue);
      expect(loadout.instanceIn(EquipmentSlot.weapon), w2);
      expect(fullBag.equipmentSnapshot().single.id, w1.id);
      expect(svc.unequip(EquipmentSlot.weapon), isFalse);
      expect(loadout.instanceIn(EquipmentSlot.weapon), w2);

      // Slot mismatch (definisi cap=head, tetapi instance berslot weapon) ditolak.
      final corruptedBag = Inventory(definitions: {'cap': cap});
      final mismatch = const EquipmentInstance(
        id: 'eq_bad',
        definitionId: 'cap',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.common,
        rolledStats: EquipmentStats(atk: 5),
      );
      corruptedBag.addEquipment(mismatch);
      final badSvc = EquipmentService(
        inventory: corruptedBag,
        loadout: EquipmentLoadout(),
      );
      expect(badSvc.equip('eq_bad'), isFalse);
      expect(corruptedBag.equipmentSnapshot(), hasLength(1));
    });

    test('toggleFavorite mengubah status isFavorite pada tas dan loadout terpasang', () {
      final inv = Inventory(definitions: {'sword': sword, 'cap': cap});
      final loadout = EquipmentLoadout();
      final svc = EquipmentService(inventory: inv, loadout: loadout);

      final w1 = make('w1', sword);
      final c1 = make('c1', cap);
      inv.addEquipment(w1);
      inv.addEquipment(c1);

      // Pasang w1 ke loadout
      expect(svc.equip('w1'), isTrue);
      expect(loadout.instanceIn(EquipmentSlot.weapon)?.isFavorite, isFalse);
      expect(inv.equipmentById('c1')?.isFavorite, isFalse);

      // Toggle favorit pada item di tas (c1)
      expect(svc.toggleFavorite('c1'), isTrue);
      expect(inv.equipmentById('c1')?.isFavorite, isTrue);

      // Toggle lagi membalikkan ke false
      expect(svc.toggleFavorite('c1'), isTrue);
      expect(inv.equipmentById('c1')?.isFavorite, isFalse);

      // Toggle favorit pada item terpasang (w1)
      expect(svc.toggleFavorite('w1'), isTrue);
      expect(loadout.instanceIn(EquipmentSlot.weapon)?.isFavorite, isTrue);

      // Toggle lagi membalikkan ke false
      expect(svc.toggleFavorite('w1'), isTrue);
      expect(loadout.instanceIn(EquipmentSlot.weapon)?.isFavorite, isFalse);

      // Id tidak ada mengembalikan false
      expect(svc.toggleFavorite('unknown_id'), isFalse);
    });
  });

  group('PlayerCharacter + equipment', () {
    test(
      'stat akhir = stat level + bonus equipment, dan diperbarui saat ganti',
      () {
        final character = PlayerCharacter(config: progression);
        expect(character.stats.atk, 10);
        expect(character.stats.maxHp, 100);

        character.loadout.equip(make('a', sword)); // atk 10, crit 0.04
        character.loadout.equip(make('b', cap)); // def 2, hp 10
        expect(character.stats.atk, 20);
        expect(character.stats.def, 4);
        expect(character.stats.maxHp, 110);
        expect(character.stats.critRate, closeTo(0.14, 1e-9));

        character.loadout.unequip(EquipmentSlot.weapon);
        expect(character.stats.atk, 10);
      },
    );

    test('bonus equipment tetap berlaku setelah naik level', () {
      final character = PlayerCharacter(config: progression)
        ..loadout.equip(make('a', sword));
      character.receiveReward(exp: 100); // level 2: atk dasar 12
      expect(character.level, 2);
      expect(character.stats.atk, 22);
    });
  });
}
