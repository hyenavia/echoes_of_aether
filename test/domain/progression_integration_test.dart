import 'dart:math';

import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loot_table.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/equipment_service.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

const _progression = ProgressionConfig(
  maxLevel: 10,
  expBase: 50,
  expGrowth: 1.5,
  baseStats: CombatStats(
    maxHp: 120,
    atk: 15,
    def: 3,
    attackSpeed: 1.5,
    critRate: 0.1,
    critDamage: 1.5,
    moveSpeed: 4.0,
    attackRange: 1.5,
  ),
  perLevel: LevelGrowth(hp: 20, atk: 3, def: 1),
);

const _skills = {
  'power_strike': SkillDefinition(
    id: 'power_strike',
    name: 'Power Strike',
    type: SkillType.active,
    effect: SkillEffectType.damage,
    damageType: SkillDamageType.physical,
    unlockLevel: 2,
    maxLevel: 5,
    upgradeCost: 25,
    cooldownSeconds: 4,
    baseValue: 1.5,
    valuePerLevel: 0.25,
  ),
  'vitality': SkillDefinition(
    id: 'vitality',
    name: 'Vitality',
    type: SkillType.passive,
    effect: SkillEffectType.statModifier,
    unlockLevel: 3,
    maxLevel: 5,
    upgradeCost: 30,
    passiveStats: EquipmentStats(hp: 30, def: 2),
  ),
};

const _specs = SpecializationConfig(
  unlockLevel: 3,
  definitions: {
    'vanguard': SpecializationDefinition(
      id: 'vanguard',
      name: 'Vanguard',
      bonus: EquipmentStats(hp: 50, def: 3),
      attackRange: 1.5,
      skillAffinities: {'power_strike': 0.2, 'vitality': 0.25},
    ),
  },
);

const _items = {
  'slime_gel': ItemDefinition(
    id: 'slime_gel',
    name: 'Slime Gel',
    category: ItemCategory.material,
    maxStack: 999,
  ),
  'aether_sigil': ItemDefinition(
    id: 'aether_sigil',
    name: 'Aether Sigil',
    category: ItemCategory.questItem,
    rarity: ItemRarity.rare,
    maxStack: 1,
  ),
  'aether_blade': ItemDefinition(
    id: 'aether_blade',
    name: 'Aether Blade',
    category: ItemCategory.equipment,
    rarity: ItemRarity.epic,
    equipment: EquipmentData(
      slot: EquipmentSlot.weapon,
      weaponType: 'sword',
      baseStats: EquipmentStats(atk: 12, critRate: 0.05),
    ),
  ),
};

const _lootTables = {
  'normal_loot': LootTable(
    id: 'normal_loot',
    entries: [
      LootEntry(
        itemId: 'slime_gel',
        chance: 1.0,
        minQuantity: 2,
        maxQuantity: 2,
      ),
    ],
  ),
  'elite_loot': LootTable(
    id: 'elite_loot',
    entries: [
      LootEntry(
        itemId: 'slime_gel',
        chance: 1.0,
        minQuantity: 3,
        maxQuantity: 5,
      ),
    ],
  ),
  'boss_loot': LootTable(
    id: 'boss_loot',
    entries: [
      LootEntry(itemId: 'aether_blade', chance: 1.0),
      LootEntry(itemId: 'aether_sigil', chance: 1.0),
    ],
  ),
  'clear_loot': LootTable(
    id: 'clear_loot',
    entries: [
      LootEntry(
        itemId: 'slime_gel',
        chance: 1.0,
        minQuantity: 4,
        maxQuantity: 4,
      ),
    ],
  ),
};

const _normalMonster = EnemyDefinition(
  id: 'slime',
  name: 'Slime',
  level: 1,
  expReward: 20,
  goldReward: 10,
  lootTableId: 'normal_loot',
  stats: CombatStats(maxHp: 20, atk: 1, def: 0),
);

const _eliteMonster = EnemyDefinition(
  id: 'brute',
  name: 'Brute',
  level: 3,
  isElite: true,
  expReward: 45,
  goldReward: 25,
  lootTableId: 'elite_loot',
  stats: CombatStats(maxHp: 30, atk: 2, def: 0),
);

const _bossMonster = EnemyDefinition(
  id: 'guardian',
  name: 'Guardian',
  level: 5,
  isBoss: true,
  expReward: 120,
  goldReward: 60,
  lootTableId: 'boss_loot',
  stats: CombatStats(maxHp: 45, atk: 3, def: 1),
);

void main() {
  group('M4 Phase E — RPG Progression Integration', () {
    test(
      'alur lengkap: combat normal/elite/boss + dungeon completion -> '
      'EXP/gold/loot -> inventory -> equip -> derived stats -> upgrade skill',
      () {
        final character = PlayerCharacter(
          config: _progression,
          skillCatalog: _skills,
          specializationConfig: _specs,
        );
        final inventory = Inventory(definitions: _items);
        final equipmentService = EquipmentService(
          inventory: inventory,
          loadout: character.loadout,
        );
        final processor = RewardProcessor(
          character: character,
          inventory: inventory,
          items: _items,
          lootTables: _lootTables,
          equipmentFactory: const EquipmentFactory(
            EquipmentConfig(rollVariance: 0.1),
          ),
        );
        final random = Random(42);

        final combatant = Combatant(
          id: 'player',
          team: Team.player,
          stats: character.stats,
          cell: const GridPoint(1, 1),
        );
        final sim = CombatSimulation(
          grid: NavigationGrid.open(columns: 10, rows: 5),
          pathfinder: const AStarPathfinder(),
          player: combatant,
          seed: 7,
        );

        // Spawn normal, elite, lalu boss bertahap; proses event via RewardProcessor.
        final eNormal = sim.spawnEnemy(_normalMonster, const GridPoint(2, 1));
        final eElite = sim.spawnEnemy(_eliteMonster, const GridPoint(3, 1));
        final eBoss = sim.spawnEnemy(_bossMonster, const GridPoint(4, 1));

        for (var i = 0; i < 400 && sim.aliveEnemies.isNotEmpty; i++) {
          sim.tick();
          for (final event
              in sim.drainEvents().whereType<EnemyDefeatedEvent>()) {
            processor.processEnemyDefeated(
              eventId: 'enemy:${event.tick}:${event.enemyId}',
              definition: event.definition,
              random: random,
            );
          }
          combatant.applyStats(character.stats);
        }
        expect(eNormal.isAlive, isFalse);
        expect(eElite.isAlive, isFalse);
        expect(eBoss.isAlive, isFalse);

        // Total EXP dari monster: 20 + 45 + 120 = 185
        // Ambang lv1=50, lv2=75 (sisa 60/113 di lv3)
        expect(character.level, 3);
        expect(character.currentExp, 60);
        expect(character.gold, 95); // 10 + 25 + 60
        expect(inventory.quantityOf('aether_sigil'), 1);
        expect(inventory.equipmentSnapshot(), hasLength(1));

        // Klaim dungeon completion reward
        final clearResult = processor.processDungeonCompletion(
          eventId: 'dungeon_clear:run_1',
          reward: const DungeonCompletionReward(
            expReward: 60,
            goldReward: 50,
            lootTableId: 'clear_loot',
          ),
          random: random,
        );
        expect(clearResult.alreadyClaimed, isFalse);
        expect(character.level, 4); // 60 + 60 = 120 >= 113 -> lv4, sisa 7
        expect(character.currentExp, 7);
        expect(character.gold, 145);

        // Equip weapon epic yang jatuh dari boss -> stats naik otomatis
        final droppedWeapon = inventory.equipmentSnapshot().single;
        expect(droppedWeapon.rarity, ItemRarity.epic);
        final atkBeforeEquip = character.stats.atk;
        expect(equipmentService.equip(droppedWeapon.id), isTrue);
        expect(inventory.equipmentSnapshot(), isEmpty);
        expect(character.stats.atk, greaterThan(atkBeforeEquip));

        // Pilih specialization di level >= 3 dan upgrade skill pakai gold hasil combat
        expect(character.chooseSpecialization('vanguard'), isTrue);
        final powerUpgrade = character.upgradeSkill('power_strike');
        expect(powerUpgrade.succeeded, isTrue);
        expect(powerUpgrade.newLevel, 2);
        expect(character.gold, 145 - 25); // 120

        final passiveUpgrade = character.upgradeSkill('vitality');
        expect(passiveUpgrade.succeeded, isTrue);
        expect(character.gold, 120 - 30); // 90
        expect(character.skillLevel('vitality'), 2);
      },
    );

    test('pencegahan reward ganda: eventId sama diabaikan tanpa side effect RNG/state', () {
      final c1 = PlayerCharacter(config: _progression);
      final inv1 = Inventory(definitions: _items);
      final p1 = RewardProcessor(
        character: c1,
        inventory: inv1,
        items: _items,
        lootTables: _lootTables,
        equipmentFactory: const EquipmentFactory(
          EquipmentConfig(rollVariance: 0.1),
        ),
      );

      final first = p1.processEnemyDefeated(
        eventId: 'enemy:10:enemy_1',
        definition: _bossMonster,
        random: Random(99),
      );
      final duplicate = p1.processEnemyDefeated(
        eventId: 'enemy:10:enemy_1',
        definition: _bossMonster,
        random: Random(99),
      );

      expect(first.alreadyClaimed, isFalse);
      expect(duplicate.alreadyClaimed, isTrue);
      expect(duplicate.expGranted, 0);
      expect(duplicate.goldGranted, 0);
      expect(c1.gold, 60);
      expect(inv1.equipmentSnapshot(), hasLength(1));

      // Dungeon completion juga hanya bisa diklaim sekali per eventId.
      const clear = DungeonCompletionReward(
        expReward: 30,
        goldReward: 20,
        lootTableId: 'clear_loot',
      );
      expect(
        p1
            .processDungeonCompletion(
              eventId: 'clear:1',
              reward: clear,
              random: Random(1),
            )
            .alreadyClaimed,
        isFalse,
      );
      expect(
        p1
            .processDungeonCompletion(
              eventId: 'clear:1',
              reward: clear,
              random: Random(1),
            )
            .alreadyClaimed,
        isTrue,
      );
      expect(c1.gold, 80);
    });

    test('kapasitas tas penuh melaporkan droppedEquipment tanpa crash', () {
      final character = PlayerCharacter(config: _progression);
      final inventory = Inventory(definitions: _items, maxEquipmentCapacity: 0);
      final processor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: _items,
        lootTables: _lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      final result = processor.processEnemyDefeated(
        eventId: 'boss:1',
        definition: _bossMonster,
        random: Random(5),
      );
      expect(result.addedEquipment, isEmpty);
      expect(result.droppedEquipment, hasLength(1));
      expect(inventory.equipmentSnapshot(), isEmpty);
      // Item stackable (quest item) tetap diproses terpisah dari bag equipment.
      expect(result.addedStacks['aether_sigil'], 1);
    });

    test('save snapshot round-trip memulihkan seluruh state progression dan inventory', () {
      final originalChar = PlayerCharacter(
        config: _progression,
        skillCatalog: _skills,
        specializationConfig: _specs,
      )..receiveReward(exp: 150, gold: 80);
      originalChar.chooseSpecialization('vanguard');
      originalChar.upgradeSkill('power_strike');

      final originalInv = Inventory(definitions: _items)..add('slime_gel', 12);
      final eqId = originalInv.nextEquipmentId();
      originalInv.addEquipment(
        EquipmentInstance(
          id: eqId,
          definitionId: 'aether_blade',
          slot: EquipmentSlot.weapon,
          rarity: ItemRarity.epic,
          rolledStats: const EquipmentStats(atk: 12, critRate: 0.05),
        ),
      );
      EquipmentService(
        inventory: originalInv,
        loadout: originalChar.loadout,
      ).equip(eqId);
      final extraId = originalInv.nextEquipmentId();
      originalInv.addEquipment(
        EquipmentInstance(
          id: extraId,
          definitionId: 'aether_blade',
          slot: EquipmentSlot.weapon,
          rarity: ItemRarity.epic,
          rolledStats: const EquipmentStats(atk: 11, critRate: 0.04),
        ),
      );

      final save = PlayerSaveSnapshot(
        character: originalChar.toSnapshot(),
        inventory: originalInv.toSnapshot(),
      );

      // Rekonstruksi ke instance baru (simulasi restart aplikasi / Phase F load).
      final loadedChar = PlayerCharacter(
        config: _progression,
        skillCatalog: _skills,
        specializationConfig: _specs,
      )..restoreSnapshot(save.character);
      final loadedInv = Inventory(definitions: _items)..restore(save.inventory);

      expect(loadedChar.level, originalChar.level);
      expect(loadedChar.currentExp, originalChar.currentExp);
      expect(loadedChar.gold, originalChar.gold);
      expect(loadedChar.specializationId, originalChar.specializationId);
      expect(loadedChar.skillLevel('power_strike'), 2);
      expect(loadedChar.stats.maxHp, originalChar.stats.maxHp);
      expect(loadedChar.stats.atk, originalChar.stats.atk);
      expect(loadedChar.loadout.instanceIn(EquipmentSlot.weapon)?.id, eqId);
      expect(loadedInv.quantityOf('slime_gel'), 12);
      expect(loadedInv.equipmentSnapshot().single.id, extraId);
      expect(loadedInv.nextEquipmentId(), isNot(extraId));
    });
  });
}
