import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/features/dungeon/character_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/equipment_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/inventory_overlay.dart';
import 'package:echoes_of_aether/features/shared/widgets/shared_widgets.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseStats = CombatStats(
    maxHp: 220,
    atk: 35,
    def: 14,
    critRate: 0.10,
    critDamage: 1.60,
    attackSpeed: 1.15,
    moveSpeed: 95,
    attackRange: 48,
  );

  const specKnight = SpecializationDefinition(
    id: 'vanguard',
    name: 'Aether Vanguard dengan Gelar Panjang Pelindung Kerajaan',
    description:
        'Pertahanan tinggi dan ketahanan luar biasa di garis depan dungeon.',
    bonus: EquipmentStats(hp: 40, def: 8),
    attackRange: 52,
    skillAffinities: {'slash': 0.25},
  );

  const skillSlash = SkillDefinition(
    id: 'slash',
    name: 'Aether Slash Berkekuatan Cahaya Kuno',
    type: SkillType.active,
    effect: SkillEffectType.damage,
    targetType: SkillTarget.single,
    cooldownSeconds: 4,
    unlockLevel: 1,
    maxLevel: 3,
    upgradeCost: 50,
    damageMultiplier: 1.8,
  );

  const skillUlt = SkillDefinition(
    id: 'ult',
    name: 'Aether Nova',
    type: SkillType.active,
    effect: SkillEffectType.damage,
    targetType: SkillTarget.area,
    cooldownSeconds: 10,
    unlockLevel: 10,
    maxLevel: 3,
    upgradeCost: 120,
    damageMultiplier: 2.5,
  );

  const skillMax = SkillDefinition(
    id: 'passive',
    name: 'Iron Will',
    type: SkillType.passive,
    effect: SkillEffectType.statModifier,
    cooldownSeconds: 0,
    unlockLevel: 1,
    maxLevel: 3,
    upgradeCost: 40,
  );

  testWidgets(
    'CharacterOverlay menampilkan stat tempur, pilih spesialisasi, upgrade skill, dan teks panjang tanpa overflow',
    (tester) async {
      String? chosenSpec;
      String? upgradedSkill;
      final snapshot = ValueNotifier(
        const CharacterSnapshot(
          level: 5,
          gold: 120,
          stats: baseStats,
          specializationId: null,
          canChooseSpecialization: true,
          specializationUnlockLevel: 3,
          specializations: [specKnight],
          skills: [
            SkillEntry(
              skillSlash,
              unlocked: true,
              level: 1,
              nextUpgradeCost: 50,
              canUpgrade: true,
            ),
            SkillEntry(
              skillMax,
              unlocked: true,
              level: 3,
              nextUpgradeCost: 0,
              canUpgrade: false,
            ),
            SkillEntry(
              skillUlt,
              unlocked: false,
              level: 1,
              nextUpgradeCost: 0,
              canUpgrade: false,
            ),
          ],
          skillNames: {'slash': 'Aether Slash'},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: CharacterOverlay(
                snapshot: snapshot,
                onChooseSpecialization: (id) => chosenSpec = id,
                onUpgradeSkill: (id) => upgradedSkill = id,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Stat Tempur'), findsOneWidget);
      expect(find.textContaining('HP 220'), findsOneWidget);
      expect(find.text('Gold 120'), findsOneWidget);
      expect(find.text('MAX'), findsOneWidget);
      expect(find.text('Terkunci'), findsOneWidget);

      await tester.tap(find.text('Pilih'));
      await tester.pumpAndSettle();
      expect(chosenSpec, 'vanguard');

      final upgradeBtn = find.text('Upgrade (50G)');
      await tester.ensureVisible(upgradeBtn);
      await tester.tap(upgradeBtn);
      await tester.pumpAndSettle();
      expect(upgradedSkill, 'slash');
    },
  );

  testWidgets(
    'EquipmentOverlay menampilkan ItemCard rarity, equip/unequip, dan perbandingan stat saat item tas diketuk',
    (tester) async {
      String? equippedId;
      EquipmentSlot? unequippedSlot;

      final items = <String, ItemDefinition>{
        'iron_sword': const ItemDefinition(
          id: 'iron_sword',
          name: 'Iron Sword',
          category: ItemCategory.equipment,
          rarity: ItemRarity.common,
        ),
        'aether_blade': const ItemDefinition(
          id: 'aether_blade',
          name: 'Aether Blade of Dawn with Very Long Name',
          category: ItemCategory.equipment,
          rarity: ItemRarity.epic,
        ),
        'leather_vest': const ItemDefinition(
          id: 'leather_vest',
          name: 'Leather Vest',
          category: ItemCategory.equipment,
          rarity: ItemRarity.uncommon,
        ),
      };

      const equippedSword = EquipmentInstance(
        id: 'eq_1',
        definitionId: 'iron_sword',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.common,
        rolledStats: EquipmentStats(atk: 10, critRate: 0.02),
      );
      const bagEpicBlade = EquipmentInstance(
        id: 'bag_1',
        definitionId: 'aether_blade',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.epic,
        rolledStats: EquipmentStats(atk: 24, critRate: 0.05),
      );
      const bagArmor = EquipmentInstance(
        id: 'bag_2',
        definitionId: 'leather_vest',
        slot: EquipmentSlot.body,
        rarity: ItemRarity.uncommon,
        rolledStats: EquipmentStats(hp: 30, def: 6),
      );

      final snapshot = ValueNotifier(
        const EquipmentSnapshot(
          equipped: {EquipmentSlot.weapon: equippedSword},
          bag: [bagEpicBlade, bagArmor],
          stats: baseStats,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 680),
              textScaler: TextScaler.linear(1.2),
            ),
            child: Scaffold(
              body: EquipmentOverlay(
                snapshot: snapshot,
                items: items,
                onEquip: (id) => equippedId = id,
                onUnequip: (slot) => unequippedSlot = slot,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ItemCard), findsWidgets);
      expect(find.text('Tas perlengkapan (2)'), findsOneWidget);

      // Unequip senjata terpasang.
      await tester.tap(find.text('Lepas'));
      await tester.pumpAndSettle();
      expect(unequippedSlot, EquipmentSlot.weapon);

      // Ketuk item tas epic untuk memunculkan perbandingan stat.
      final epicText = find.text('Aether Blade of Dawn with Very Long Name');
      await tester.ensureVisible(epicText);
      await tester.tap(epicText);
      await tester.pumpAndSettle();

      expect(find.text('Perbandingan (Senjata)'), findsOneWidget);
      expect(find.text('ATK +14'), findsOneWidget);
      expect(find.text('CRIT +3%'), findsOneWidget);

      final equipCompareBtn = find.text('Pakai Item Ini');
      await tester.ensureVisible(equipCompareBtn);
      await tester.tap(equipCompareBtn);
      await tester.pumpAndSettle();
      expect(equippedId, 'bag_1');
    },
  );

  testWidgets(
    'EquipmentOverlay dan InventoryOverlay menangani daftar kosong dan pengurutan',
    (tester) async {
      final emptyEq = ValueNotifier(
        const EquipmentSnapshot(equipped: {}, bag: [], stats: baseStats),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EquipmentOverlay(
              snapshot: emptyEq,
              items: const {},
              onEquip: (_) {},
              onUnequip: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada equipment.'), findsOneWidget);

      final emptyInv = ValueNotifier<List<InventoryEntry>>([]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryOverlay(entries: emptyInv, onClose: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada item.'), findsOneWidget);

      // Uji pengurutan berdasarkan Rarity di InventoryOverlay.
      emptyInv.value = [
        InventoryEntry(
          const ItemDefinition(
            id: 'mat_c',
            name: 'Zebra Gel',
            category: ItemCategory.material,
            rarity: ItemRarity.common,
          ),
          5,
        ),
        InventoryEntry(
          const ItemDefinition(
            id: 'mat_r',
            name: 'Aether Core',
            category: ItemCategory.material,
            rarity: ItemRarity.rare,
          ),
          1,
        ),
      ];
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Rarity'));
      await tester.pumpAndSettle();

      final rarePos = tester.getTopLeft(find.text('Aether Core')).dy;
      final commonPos = tester.getTopLeft(find.text('Zebra Gel')).dy;
      expect(rarePos, lessThan(commonPos));
    },
  );
}
