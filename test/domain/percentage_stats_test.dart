import 'dart:math';

import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/equipment_loadout.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/shop_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/damage_calculator.dart';
import 'package:echoes_of_aether/domain/services/derived_stats_calculator.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _progression = ProgressionConfig(
  maxLevel: null,
  expCurve: ExpCurveConfig.polynomial(),
  baseStats: CombatStats(
    maxHp: 100,
    atk: 20,
    def: 10,
    attackSpeed: 1.5,
    critRate: 0.0,
    critDamage: 1.5,
    moveSpeed: 4.0,
    attackRange: 1.5,
  ),
  perLevel: LevelGrowth(hp: 20, atk: 5, def: 2),
);

void main() {
  group('EquipmentStats & DerivedStatsCalculator percentage stats', () {
    test('flat diterapkan dulu, lalu persentase, lalu round satu kali', () {
      const calc = DerivedStatsCalculator(
        pctCaps: EquipmentPctCaps(hpPct: 0.6, atkPct: 0.5, defPct: 0.5),
      );
      const base = CombatStats(maxHp: 100, atk: 20, def: 10);
      // (100 + 25) * 1.15 = 143.75 -> 144
      // (20 + 5) * 1.10 = 27.5 -> 28
      // (10 + 3) * 1.25 = 16.25 -> 16
      final result = calc.calculate(
        baseStats: base,
        equipmentBonus: const EquipmentStats(
          hp: 25,
          atk: 5,
          def: 3,
          hpPct: 0.15,
          atkPct: 0.10,
          defPct: 0.25,
        ),
      );

      expect(result.maxHp, 144);
      expect(result.atk, 28);
      expect(result.def, 16);
    });

    test('akumulasi antar slot bersifat aditif dan dipotong pada pct_caps', () {
      const calc = DerivedStatsCalculator(
        pctCaps: EquipmentPctCaps(hpPct: 0.6, atkPct: 0.5, defPct: 0.5),
      );
      final loadout = EquipmentLoadout()
        ..equip(
          const EquipmentInstance(
            id: 'w1',
            definitionId: 'w',
            slot: EquipmentSlot.weapon,
            rarity: ItemRarity.rare,
            rolledStats: EquipmentStats(atk: 10, atkPct: 0.35),
          ),
        )
        ..equip(
          const EquipmentInstance(
            id: 'a1',
            definitionId: 'a',
            slot: EquipmentSlot.accessory,
            rarity: ItemRarity.rare,
            rolledStats: EquipmentStats(
              atkPct: 0.30,
              hpPct: 0.70,
              defPct: 0.60,
            ),
          ),
        );

      // Total raw atkPct = 0.65 -> capped 0.50; hpPct = 0.70 -> capped 0.60; defPct = 0.60 -> capped 0.50.
      expect(loadout.totalBonus.atkPct, closeTo(0.65, 1e-9));
      final stats = calc.calculate(
        baseStats: const CombatStats(maxHp: 100, atk: 20, def: 10),
        equipmentBonus: loadout.totalBonus,
      );
      expect(stats.maxHp, (100 * 1.60).round()); // 160
      expect(stats.atk, ((20 + 10) * 1.50).round()); // 45
      expect(stats.def, (10 * 1.50).round()); // 15
    });

    test(
      'regresi item non-pct (0%) menghasilkan stat identik seperti sebelumnya',
      () {
        const calcDefault = DerivedStatsCalculator();
        const calcExplicitCaps = DerivedStatsCalculator(
          pctCaps: EquipmentPctCaps(hpPct: 0.6, atkPct: 0.5, defPct: 0.5),
        );
        const base = CombatStats(maxHp: 145, atk: 23, def: 9);
        const flatBonus = EquipmentStats(
          hp: 40.4,
          atk: 11.6,
          def: 4.5,
          critRate: 0.1,
          attackSpeed: 0.25,
        );
        const spec = SpecializationDefinition(
          id: 'guard',
          name: 'Guard',
          bonus: EquipmentStats(hp: 20, atk: 3, def: 2),
        );
        const passive = SkillDefinition(
          id: 'vit',
          name: 'Vit',
          type: SkillType.passive,
          passiveStats: EquipmentStats(hp: 15, def: 1.5),
        );

        final a = calcDefault.calculate(
          baseStats: base,
          equipmentBonus: flatBonus,
          specialization: spec,
          passiveSkills: [passive],
        );
        final b = calcExplicitCaps.calculate(
          baseStats: base,
          equipmentBonus: flatBonus,
          specialization: spec,
          passiveSkills: [passive],
        );

        expect(a.maxHp, b.maxHp);
        expect(a.atk, b.atk);
        expect(a.def, b.def);
        expect(b.maxHp, base.maxHp + (40.4 + 20 + 15).round());
        expect(b.atk, base.atk + (11.6 + 3).round());
        expect(b.def, base.def + (4.5 + 2 + 1.5).round());
      },
    );

    test(
      'nilai persentase negatif atau NaN aman dan diperlakukan sebagai 0%',
      () {
        const calc = DerivedStatsCalculator();
        final result = calc.calculate(
          baseStats: const CombatStats(maxHp: 100, atk: 20, def: 10),
          equipmentBonus: const EquipmentStats(
            hpPct: -0.25,
            atkPct: double.nan,
            defPct: double.negativeInfinity,
          ),
        );
        expect(result.maxHp, 100);
        expect(result.atk, 20);
        expect(result.def, 10);
      },
    );

    test('EquipmentStats.applyTo hanya menerapkan stat flat (TDD §3.4)', () {
      const base = CombatStats(maxHp: 100, atk: 20, def: 10);
      const bonus = EquipmentStats(
        hp: 50,
        atk: 5,
        hpPct: 0.25,
        atkPct: 0.20,
        defPct: 0.15,
      );
      final applied = bonus.applyTo(base);
      expect(applied.maxHp, 150);
      expect(applied.atk, 25);
      expect(applied.def, 10);
    });

    test('EquipmentStats.isEmpty, +, scaled, dan roll mencakup pct stats', () {
      const pctOnly = EquipmentStats(hpPct: 0.1);
      expect(pctOnly.isEmpty, isFalse);

      const b = EquipmentStats(atkPct: 0.2, defPct: 0.05);
      final sum = pctOnly + b;
      expect(sum.hpPct, closeTo(0.1, 1e-9));
      expect(sum.atkPct, closeTo(0.2, 1e-9));
      expect(sum.defPct, closeTo(0.05, 1e-9));

      final scaled = sum.scaled(0.5);
      expect(scaled.hpPct, closeTo(0.05, 1e-9));
      expect(scaled.atkPct, closeTo(0.1, 1e-9));
      expect(scaled.defPct, closeTo(0.025, 1e-9));

      final rolled = sum.roll(Random(7), 0.15, rollBonus: 0.1);
      expect(rolled.hpPct, inInclusiveRange(0.1 * 0.95, 0.1 * 1.25));
      expect(rolled.atkPct, inInclusiveRange(0.2 * 0.95, 0.2 * 1.25));
    });
  });

  group('fixed_stats & sellable behavior', () {
    test('EquipmentFactory melewati roll jika fixed_stats: true', () {
      const fixedDef = ItemDefinition(
        id: 'event_sword',
        name: 'Event Sword',
        category: ItemCategory.equipment,
        rarity: ItemRarity.rare,
        sellable: false,
        equipment: EquipmentData(
          slot: EquipmentSlot.weapon,
          weaponType: 'sword',
          fixedStats: true,
          baseStats: EquipmentStats(atk: 18, atkPct: 0.12, hpPct: 0.08),
        ),
      );
      const factory = EquipmentFactory(EquipmentConfig(rollVariance: 0.15));
      final a = factory.create(
        instanceId: 'eq_a',
        definition: fixedDef,
        random: Random(1),
        rollBonus: 0.25,
      );
      final b = factory.create(
        instanceId: 'eq_b',
        definition: fixedDef,
        random: Random(99),
        rollBonus: 0.0,
      );

      expect(a.rolledStats.atk, 18);
      expect(a.rolledStats.atkPct, 0.12);
      expect(a.rolledStats.hpPct, 0.08);
      expect(b.rolledStats, a.rolledStats);
    });

    test('ShopService menolak penjualan item dengan sellable: false', () {
      const unsellableEquip = ItemDefinition(
        id: 'boss_relic',
        name: 'Boss Relic',
        category: ItemCategory.equipment,
        rarity: ItemRarity.epic,
        sellValue: 500,
        sellable: false,
        equipment: EquipmentData(
          slot: EquipmentSlot.accessory,
          fixedStats: true,
          baseStats: EquipmentStats(hpPct: 0.15),
        ),
      );
      const unsellableMat = ItemDefinition(
        id: 'boss_token',
        name: 'Boss Token',
        category: ItemCategory.material,
        rarity: ItemRarity.rare,
        sellValue: 100,
        sellable: false,
      );
      final items = {
        'boss_relic': unsellableEquip,
        'boss_token': unsellableMat,
      };
      final character = PlayerCharacter(config: _progression);
      final inventory = Inventory(definitions: items)
        ..addEquipment(
          const EquipmentInstance(
            id: 'relic_1',
            definitionId: 'boss_relic',
            slot: EquipmentSlot.accessory,
            rarity: ItemRarity.epic,
            rolledStats: EquipmentStats(hpPct: 0.15),
          ),
        )
        ..add('boss_token', 3);

      final shop = ShopService(
        catalog: const ShopCatalog.empty(),
        items: items,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      final eqRes = shop.sellEquipment(
        instanceId: 'relic_1',
        character: character,
        inventory: inventory,
      );
      expect(eqRes, isA<ShopSellNotSellable>());
      expect(inventory.equipmentById('relic_1'), isNotNull);

      final matRes = shop.sellMaterialBulk(
        itemId: 'boss_token',
        quantity: 1,
        character: character,
        inventory: inventory,
      );
      expect(matRes, isA<ShopSellNotSellable>());
      expect(inventory.quantityOf('boss_token'), 3);

      final batchRes = shop.sellBatch(
        equipmentInstanceIds: ['relic_1'],
        materialQuantities: {'boss_token': 1},
        character: character,
        inventory: inventory,
      );
      expect(batchRes, isA<ShopSellNotSellable>());
      expect(character.gold, 0);
      expect(inventory.equipmentById('relic_1'), isNotNull);
      expect(inventory.quantityOf('boss_token'), 3);
    });
  });

  group('Paritas Online vs Offline dengan percentage stats', () {
    test('CombatSimulation dan OfflineDungeonRunner memakai stat akhir & cap yang sama', () {
      const config = GameConfig(
        monsters: {
          'test_slime': EnemyDefinition(
            id: 'test_slime',
            name: 'Slime',
            level: 1,
            detectionRange: 10,
            stats: CombatStats(
              maxHp: 300,
              atk: 10,
              def: 5,
              attackSpeed: 1.0,
              moveSpeed: 2.0,
              attackRange: 1.0,
            ),
            expReward: 10,
            goldReward: 5,
          ),
        },
        revive: ReviveConfig(),
        progression: _progression,
        items: {
          'pct_sword': ItemDefinition(
            id: 'pct_sword',
            name: 'Pct Sword',
            category: ItemCategory.equipment,
            rarity: ItemRarity.epic,
            equipment: EquipmentData(
              slot: EquipmentSlot.weapon,
              fixedStats: true,
              baseStats: EquipmentStats(atk: 10, atkPct: 0.40, hpPct: 0.20),
            ),
          ),
          'pct_ring': ItemDefinition(
            id: 'pct_ring',
            name: 'Pct Ring',
            category: ItemCategory.equipment,
            rarity: ItemRarity.epic,
            equipment: EquipmentData(
              slot: EquipmentSlot.accessory,
              fixedStats: true,
              baseStats: EquipmentStats(atkPct: 0.25, def: 10, defPct: 0.20),
            ),
          ),
        },
        lootTables: {},
        equipment: EquipmentConfig(
          rollVariance: 0.15,
          pctCaps: EquipmentPctCaps(hpPct: 0.6, atkPct: 0.5, defPct: 0.5),
        ),
        dungeons: {
          'd1': DungeonDefinition(
            id: 'd1',
            name: 'D1',
            biome: 'forest',
            kind: DungeonKind.normal,
            order: 1,
            recommendedLevel: 1,
            startRoomId: 'r1',
            roomOrder: ['r1'],
            completionReward: DungeonCompletionReward(
              expReward: 20,
              goldReward: 10,
            ),
            rooms: {
              'r1': RoomDefinition(
                id: 'r1',
                dungeonId: 'd1',
                name: 'R1',
                type: RoomType.normal,
                mapRef: 'r1',
                layout: ['#####', '#...#', '#####'],
                entryPosition: GridPoint(1, 1),
                exitPosition: GridPoint(3, 1),
                completionCondition: RoomCompletionCondition(
                  type: RoomCompletionConditionType.defeatRequiredEnemies,
                ),
                spawns: [
                  RoomSpawnConfig(
                    id: 'spawn_slime',
                    monsterId: 'test_slime',
                    position: GridPoint(2, 1),
                    quantity: 1,
                  ),
                ],
              ),
            },
          ),
        },
      );

      final loadout = EquipmentLoadout()
        ..equip(
          EquipmentInstance(
            id: 'w1',
            definitionId: 'pct_sword',
            slot: EquipmentSlot.weapon,
            rarity: ItemRarity.epic,
            rolledStats: config.items['pct_sword']!.equipment!.baseStats,
          ),
        )
        ..equip(
          EquipmentInstance(
            id: 'a1',
            definitionId: 'pct_ring',
            slot: EquipmentSlot.accessory,
            rarity: ItemRarity.epic,
            rolledStats: config.items['pct_ring']!.equipment!.baseStats,
          ),
        );

      PlayerCharacter makeHero() => PlayerCharacter(
        config: config.progression,
        loadout: EquipmentLoadout()
          ..equip(loadout.equipped[EquipmentSlot.weapon]!)
          ..equip(loadout.equipped[EquipmentSlot.accessory]!),
        statsCalculator: DerivedStatsCalculator(
          pctCaps: config.equipment.pctCaps,
        ),
      );

      final heroOnline = makeHero();
      // Base Lv1: HP=100, ATK=20, DEF=10
      // + flat(atk 10, def 10) -> (100, 30, 20)
      // * (1 + capped pct: hp 0.20, atk min(0.65, 0.5)=0.50, def 0.20) -> (120, 45, 24)
      expect(heroOnline.stats.maxHp, 120);
      expect(heroOnline.stats.atk, 45);
      expect(heroOnline.stats.def, 24);

      const dmgCalc = DamageCalculator();
      final onlineSim = CombatSimulation(
        grid: NavigationGrid.open(columns: 5, rows: 3),
        pathfinder: const AStarPathfinder(),
        player: Combatant(
          id: 'player',
          team: Team.player,
          stats: heroOnline.stats,
          cell: const GridPoint(1, 1),
        ),
        damageCalculator: dmgCalc,
        seed: 7,
      );
      onlineSim.spawnEnemy(
        config.monsters['test_slime']!,
        const GridPoint(2, 1),
      );
      onlineSim.tick();
      final firstHit = onlineSim.drainEvents().whereType<AttackEvent>().first;
      // 45 ATK vs 5 DEF (ratio): 45*45/(45+5) = 2025/50 = 40.5 -> 41
      expect(firstHit.damage, dmgCalc.physicalDamage(heroOnline.stats.atk, 5));
      expect(firstHit.damage, 41);

      final heroOffline = makeHero();
      expect(heroOffline.stats.atk, heroOnline.stats.atk);
      expect(heroOffline.stats.maxHp, heroOnline.stats.maxHp);
      expect(heroOffline.stats.def, heroOnline.stats.def);

      final inventory = Inventory(definitions: config.items);
      final outcome = OfflineDungeonRunner(damageCalculator: dmgCalc).runBatch(
        OfflineDungeonRunRequest(
          mode: OfflineActivityMode.autoFarming,
          character: heroOffline,
          inventory: inventory,
          config: config,
          rewardProcessor: RewardProcessor(
            character: heroOffline,
            inventory: inventory,
            items: config.items,
            lootTables: config.lootTables,
            equipmentFactory: EquipmentFactory(config.equipment),
          ),
          dungeonId: 'd1',
          dungeonProgress: const DungeonProgressSnapshot(
            currentDungeonId: 'd1',
            clearsCount: 1,
            clearedInCycleRank: 0,
          ),
          timeWindow: const OfflineTimeWindow(
            status: OfflineTimeValidationStatus.valid,
            anchorTimestampMs: 0,
            nowMs: 60000,
            rawElapsed: Duration(minutes: 1),
            effectiveElapsed: Duration(minutes: 1),
            cappedAtMaxDuration: false,
            previouslyProcessedMs: 0,
            remainingBudgetMs: 60000,
            endTimestampMs: 60000,
            eventId: 'offline:0:60000',
            newLastOfflineClaimAtMs: 60000,
          ),
          simulationSeed: 7,
        ),
      );

      expect(outcome.encountersCleared, greaterThan(0));
      expect(outcome.runsCompleted, greaterThan(0));
      final lv = heroOffline.progress.level;
      expect(lv, greaterThan(1));
      expect(heroOffline.stats.maxHp, ((100 + (lv - 1) * 20) * 1.20).round());
      expect(heroOffline.stats.atk, ((20 + (lv - 1) * 5 + 10) * 1.50).round());
      expect(heroOffline.stats.def, ((10 + (lv - 1) * 2 + 10) * 1.20).round());
    });
  });
}
