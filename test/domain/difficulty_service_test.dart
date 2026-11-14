import 'dart:math' as math;

import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/difficulty_config.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loot_table.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/loot_service.dart';
import 'package:flutter_test/flutter_test.dart';

DungeonDefinition _makeDungeon(double scale) => DungeonDefinition(
  id: 'd_$scale',
  name: 'D $scale',
  biome: 'test',
  startRoomId: 'r1',
  roomOrder: const ['r1'],
  difficultyScale: scale,
  rooms: const {
    'r1': RoomDefinition(
      id: 'r1',
      dungeonId: 'd',
      name: 'R1',
      type: RoomType.normal,
      mapRef: 'm',
      layout: ['#####', '#...#', '#####'],
      entryPosition: GridPoint(1, 1),
      exitPosition: GridPoint(3, 1),
      spawns: [],
      completionCondition: RoomCompletionCondition(
        type: RoomCompletionConditionType.defeatRequiredEnemies,
      ),
    ),
  },
);

void main() {
  const service = DifficultyService();

  group('DifficultyService — profile & formula', () {
    test('Forgotten Forest (scale 1.0, rank 0) tepat identik', () {
      final profile = service.profileFor(_makeDungeon(1.0), 0);
      expect(profile.isIdentity, isTrue);
      expect(profile.multiplier, 1.0);
      expect(profile.hpMultiplier, 1.0);
      expect(profile.atkMultiplier, 1.0);
      expect(profile.defMultiplier, 1.0);
      expect(profile.rewardMultiplier, 1.0);
      expect(profile.rareDropChanceMultiplier, 1.0);
      expect(profile.equipmentRollBonus, 0.0);

      const stats = CombatStats(maxHp: 45, atk: 8, def: 2);
      final scaledStats = service.scaleMonsterStats(stats, profile);
      expect(scaledStats.maxHp, 45);
      expect(scaledStats.atk, 8);
      expect(scaledStats.def, 2);
      expect(service.scaleExp(15, profile), 15);
      expect(service.scaleGold(6, profile), 6);
    });

    test('kombinasi scale dan cycleRank menghitung eksponen dengan akurat', () {
      final p1 = service.profileFor(_makeDungeon(1.5), 0);
      expect(p1.multiplier, closeTo(1.5, 1e-9));
      expect(p1.hpMultiplier, closeTo(1.5, 1e-9));
      expect(p1.atkMultiplier, closeTo(1.5, 1e-9));
      expect(p1.defMultiplier, closeTo(math.pow(1.5, 0.9), 1e-9));
      expect(p1.rewardMultiplier, closeTo(math.pow(1.5, 0.85), 1e-9));
      expect(p1.rareDropChanceMultiplier, 1.0);
      expect(p1.equipmentRollBonus, 0.0);

      // Rank 1: C(1) = 1.4 -> M = 1.5 * 1.4 = 2.1
      final p2 = service.profileFor(_makeDungeon(1.5), 1);
      expect(p2.multiplier, closeTo(2.1, 1e-9));
      expect(p2.defMultiplier, closeTo(math.pow(2.1, 0.9), 1e-9));
      expect(p2.rewardMultiplier, closeTo(math.pow(2.1, 0.85), 1e-9));
      expect(p2.rareDropChanceMultiplier, closeTo(1.1, 1e-9));
      expect(p2.equipmentRollBonus, closeTo(0.02, 1e-9));

      // Rank 5: C(5) = 1 + 0.4 * 5 = 3.0 -> M = 2.0 * 3.0 = 6.0
      final p3 = service.profileFor(_makeDungeon(2.0), 5);
      expect(p3.multiplier, closeTo(6.0, 1e-9));
      expect(p3.rareDropChanceMultiplier, closeTo(1.5, 1e-9));
      expect(p3.equipmentRollBonus, closeTo(0.10, 1e-9));
    });

    test(
      'clamp drop scaling, rank negatif, serta rank ekstrem 1000..100000',
      () {
        // Rank negatif diamankan menjadi rank 0.
        final pNeg = service.profileFor(_makeDungeon(2.0), -5);
        expect(pNeg.multiplier, closeTo(2.0, 1e-9));
        expect(pNeg.rareDropChanceMultiplier, 1.0);
        expect(pNeg.equipmentRollBonus, 0.0);

        // Rank tinggi tidak NaN, Infinity, atau overflow; di-clamp oleh maxMultiplier & batas drop.
        for (final rank in [10, 50, 1000, 1000000000]) {
          final p = service.profileFor(_makeDungeon(10.0), rank);
          expect(p.multiplier.isFinite, isTrue);
          expect(p.hpMultiplier.isFinite, isTrue);
          expect(p.atkMultiplier.isFinite, isTrue);
          expect(p.defMultiplier.isFinite, isTrue);
          expect(p.rewardMultiplier.isFinite, isTrue);
          expect(p.multiplier, lessThanOrEqualTo(1e9));
          expect(p.hpMultiplier, lessThanOrEqualTo(1e9));
          expect(p.rareDropChanceMultiplier, lessThanOrEqualTo(3.0));
          expect(p.equipmentRollBonus, lessThanOrEqualTo(0.5));

          final scaled = service.scaleMonsterStats(
            const CombatStats(maxHp: 1000000, atk: 50000, def: 10000),
            p,
          );
          expect(scaled.maxHp, greaterThan(0));
          expect(
            scaled.maxHp,
            lessThanOrEqualTo(DifficultyService.kMaxScaledValue),
          );
          expect(scaled.atk, greaterThan(0));
          expect(service.scaleExp(1000, p), greaterThan(0));
          expect(
            service.scaleGold(1000, p),
            lessThanOrEqualTo(DifficultyService.kMaxScaledValue),
          );
        }

        final pCapDrop = service.profileFor(_makeDungeon(1.0), 100);
        expect(pCapDrop.rareDropChanceMultiplier, 3.0);
        expect(pCapDrop.equipmentRollBonus, 0.5);

        // Uji clamp ke maxMultiplier kustom kecil.
        const smallMaxService = DifficultyService(
          DifficultyConfig(maxMultiplier: 100.0),
        );
        final pSmall = smallMaxService.profileFor(_makeDungeon(10.0), 500);
        expect(pSmall.multiplier, 100.0);
        expect(pSmall.hpMultiplier, lessThanOrEqualTo(100.0));
      },
    );

    test(
      'pembulatan reward EXP/Gold: minimum 1 jika base > 0, 0 jika base <= 0',
      () {
        const tinyProfile = DifficultyProfile(rewardMultiplier: 0.1);
        expect(service.scaleExp(0, tinyProfile), 0);
        expect(service.scaleExp(-10, tinyProfile), 0);
        expect(service.scaleExp(1, tinyProfile), 1);
        expect(service.scaleGold(2, tinyProfile), 1);

        const doubleReward = DifficultyProfile(rewardMultiplier: 1.85);
        expect(service.scaleExp(10, doubleReward), 19);
        expect(service.scaleGold(7, doubleReward), 13);
      },
    );

    test('cycleStatExponents menskalakan baseScale dan cycleFactor secara terpisah', () {
      const splitService = DifficultyService(
        DifficultyConfig(
          cycleStatExponents: StatExponentsConfig(
            hp: 0.25,
            atk: 0.2,
            def: 0.18,
          ),
        ),
      );

      // Rank 0 identik dengan M8: cycleFactor == 1.0, hanya statExponents berlaku.
      final p0 = splitService.profileFor(_makeDungeon(2.0), 0);
      expect(p0.multiplier, closeTo(2.0, 1e-9));
      expect(p0.hpMultiplier, closeTo(2.0, 1e-9));
      expect(p0.atkMultiplier, closeTo(2.0, 1e-9));
      expect(p0.defMultiplier, closeTo(math.pow(2.0, 0.9), 1e-9));
      expect(p0.rewardMultiplier, closeTo(math.pow(2.0, 0.85), 1e-9));

      // Rank 5 (C=3.0) pada scale 2.0 -> total multiplier 6.0, stat monster pakai cycleStatExponents.
      final p5 = splitService.profileFor(_makeDungeon(2.0), 5);
      expect(p5.multiplier, closeTo(6.0, 1e-9));
      expect(p5.hpMultiplier, closeTo(2.0 * math.pow(3.0, 0.25), 1e-9));
      expect(p5.atkMultiplier, closeTo(2.0 * math.pow(3.0, 0.2), 1e-9));
      expect(
        p5.defMultiplier,
        closeTo(math.pow(2.0, 0.9) * math.pow(3.0, 0.18), 1e-9),
      );
      expect(p5.rewardMultiplier, closeTo(math.pow(6.0, 0.85), 1e-9));

      // Rank ekstrem tetap finite dan ter-clamp.
      final pExtreme = splitService.profileFor(_makeDungeon(10.0), 1000000);
      expect(pExtreme.hpMultiplier.isFinite, isTrue);
      expect(pExtreme.hpMultiplier, lessThanOrEqualTo(1e9));
      expect(pExtreme.atkMultiplier, lessThanOrEqualTo(1e9));
      expect(pExtreme.defMultiplier, lessThanOrEqualTo(1e9));
    });
  });

  group(
    'LootService & EquipmentFactory — scaling rare drop dan roll bonus',
    () {
      test(
        'rareDropChanceMultiplier hanya menaikkan item rarity rare ke atas',
        () {
          const items = {
            'potion': ItemDefinition(
              id: 'potion',
              name: 'Potion',
              category: ItemCategory.consumable,
              rarity: ItemRarity.common,
            ),
            'epic_sword': ItemDefinition(
              id: 'epic_sword',
              name: 'Epic Sword',
              category: ItemCategory.equipment,
              rarity: ItemRarity.epic,
              equipment: EquipmentData(
                slot: EquipmentSlot.weapon,
                baseStats: EquipmentStats(atk: 10),
              ),
            ),
          };
          const table = LootTable(
            id: 't1',
            entries: [
              LootEntry(itemId: 'potion', chance: 0.3),
              LootEntry(itemId: 'epic_sword', chance: 0.3),
            ],
          );
          const loot = LootService();

          var commonBase = 0;
          var commonScaled = 0;
          var rareBase = 0;
          var rareScaled = 0;
          for (var i = 0; i < 400; i++) {
            final d0 = loot.roll(table, math.Random(i), items: items);
            final d3 = loot.roll(
              table,
              math.Random(i),
              items: items,
              rareDropChanceMultiplier: 3.0,
            );
            if (d0.any((e) => e.itemId == 'potion')) commonBase++;
            if (d3.any((e) => e.itemId == 'potion')) commonScaled++;
            if (d0.any((e) => e.itemId == 'epic_sword')) rareBase++;
            if (d3.any((e) => e.itemId == 'epic_sword')) rareScaled++;
          }

          expect(commonScaled, commonBase);
          expect(rareScaled, greaterThan(rareBase * 2));
        },
      );

      test('equipmentRollBonus meningkatkan roll secara deterministik untuk seed sama', () {
        const factory = EquipmentFactory(EquipmentConfig(rollVariance: 0.15));
        const item = ItemDefinition(
          id: 'iron_sword',
          name: 'Iron Sword',
          category: ItemCategory.equipment,
          rarity: ItemRarity.rare,
          equipment: EquipmentData(
            slot: EquipmentSlot.weapon,
            baseStats: EquipmentStats(atk: 20, hp: 40),
          ),
        );

        final eqBase = factory.create(
          instanceId: 'eq1',
          definition: item,
          random: math.Random(42),
        );
        final eqBonus = factory.create(
          instanceId: 'eq1',
          definition: item,
          random: math.Random(42),
          rollBonus: 0.25,
        );

        expect(
          eqBonus.rolledStats.atk,
          closeTo(eqBase.rolledStats.atk + 5.0, 1e-9),
        );
        expect(
          eqBonus.rolledStats.hp,
          closeTo(eqBase.rolledStats.hp + 10.0, 1e-9),
        );
      });
    },
  );
}
