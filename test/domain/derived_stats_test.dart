import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/derived_stats_calculator.dart';
import 'package:echoes_of_aether/domain/services/equipment_service.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:flutter_test/flutter_test.dart';

const _progression = ProgressionConfig(
  maxLevel: 20,
  expBase: 100,
  expGrowth: 1.5,
  baseStats: CombatStats(
    maxHp: 100,
    atk: 10,
    def: 2,
    attackSpeed: 1.0,
    critRate: 0.05,
    critDamage: 1.5,
    moveSpeed: 3.0,
    attackRange: 1.5,
    skillHaste: 0.0,
  ),
  perLevel: LevelGrowth(hp: 15, atk: 3, def: 1),
);

const _specs = SpecializationConfig(
  unlockLevel: 5,
  definitions: {
    'vanguard': SpecializationDefinition(
      id: 'vanguard',
      name: 'Vanguard',
      bonus: EquipmentStats(hp: 60, def: 4, moveSpeed: 0.3),
      attackRange: 1.5,
      skillAffinities: {'vitality': 0.25, 'power_strike': 0.2},
    ),
    'ranger': SpecializationDefinition(
      id: 'ranger',
      name: 'Ranger',
      bonus: EquipmentStats(attackSpeed: 0.5, critRate: 0.1, critDamage: 0.25),
      attackRange: 5.0,
      skillAffinities: {'focus': 0.5},
    ),
  },
);

const _skills = {
  'power_strike': SkillDefinition(
    id: 'power_strike',
    name: 'Power Strike',
    type: SkillType.active,
    effect: SkillEffectType.damage,
    damageType: SkillDamageType.physical,
    unlockLevel: 2,
    cooldownSeconds: 5,
    baseValue: 1.5,
  ),
  'healing_pulse': SkillDefinition(
    id: 'healing_pulse',
    name: 'Healing Pulse',
    type: SkillType.active,
    effect: SkillEffectType.healing,
    targetType: SkillTarget.self,
    unlockLevel: 3,
    cooldownSeconds: 20,
    baseValue: 0.3,
    useWhenHpBelow: 0.5,
  ),
  'vitality': SkillDefinition(
    id: 'vitality',
    name: 'Vitality',
    type: SkillType.passive,
    effect: SkillEffectType.statModifier,
    unlockLevel: 4,
    valuePerLevel: 0.5,
    maxLevel: 5,
    upgradeCost: 50,
    passiveStats: EquipmentStats(hp: 40, def: 4),
  ),
  'focus': SkillDefinition(
    id: 'focus',
    name: 'Focus',
    type: SkillType.passive,
    effect: SkillEffectType.statModifier,
    unlockLevel: 4,
    valuePerLevel: 0.5,
    maxLevel: 5,
    upgradeCost: 50,
    passiveStats: EquipmentStats(atk: 4, critRate: 0.04),
  ),
};

const _ironSword = EquipmentInstance(
  id: 'w_1',
  definitionId: 'iron_sword',
  slot: EquipmentSlot.weapon,
  rarity: ItemRarity.common,
  rolledStats: EquipmentStats(atk: 8, attackSpeed: 0.2),
);

const _aetherBlade = EquipmentInstance(
  id: 'w_2',
  definitionId: 'aether_blade',
  slot: EquipmentSlot.weapon,
  rarity: ItemRarity.rare,
  rolledStats: EquipmentStats(atk: 15, skillHaste: 0.2, attackRange: 0.5),
);

const _swiftBoots = EquipmentInstance(
  id: 'acc_1',
  definitionId: 'swift_boots',
  slot: EquipmentSlot.accessory,
  rarity: ItemRarity.uncommon,
  rolledStats: EquipmentStats(moveSpeed: 1.2, critDamage: 0.15, hp: 20),
);

void main() {
  const calculator = DerivedStatsCalculator();

  group('DerivedStatsCalculator — isolasi & kombinasi seluruh atribut', () {
    test('1. base stats tanpa modifier sama persis dengan base', () {
      final result = calculator.calculate(baseStats: _progression.statsAt(1));
      expect(result.maxHp, 100);
      expect(result.atk, 10);
      expect(result.def, 2);
      expect(result.attackSpeed, 1.0);
      expect(result.critRate, 0.05);
      expect(result.critDamage, 1.5);
      expect(result.moveSpeed, 3.0);
      expect(result.attackRange, 1.5);
      expect(result.skillHaste, 0.0);
    });

    test('2. equipment modifier mencakup seluruh 9 atribut termasuk moveSpeed dan attackRange', () {
      final result = calculator.calculate(
        baseStats: _progression.statsAt(1),
        equipmentBonus: _aetherBlade.rolledStats + _swiftBoots.rolledStats,
      );
      expect(result.maxHp, 120);
      expect(result.atk, 25);
      expect(result.def, 2);
      expect(result.attackSpeed, 1.0);
      expect(result.critRate, 0.05);
      expect(result.critDamage, closeTo(1.65, 1e-9));
      expect(result.moveSpeed, closeTo(4.2, 1e-9));
      expect(result.attackRange, closeTo(2.0, 1e-9));
      expect(result.skillHaste, closeTo(0.2, 1e-9));
    });

    test('3 & 4 & 5. kombinasi Base + Equipment + Specialization + Passive Skill konsisten', () {
      // Base lv5: hp=160, atk=22, def=6, aspd=1.0, crit=0.05, cdmg=1.5, spd=3.0, range=1.5, haste=0
      // Equipment: aetherBlade + swiftBoots => hp+20, atk+15, cdmg+0.15, spd+1.2, range+0.5, haste+0.2
      // Spec ranger: aspd+0.5, crit+0.10, cdmg+0.25, range override 5.0 (+ equip range 0.5 => 5.5)
      // Passive focus lv2 (scale 1.5) * ranger affinity 1.5 = factor 2.25 => atk+9, crit+0.09
      // Passive vitality lv1 (scale 1.0, affinity 0) => hp+40, def+4
      final result = calculator.calculate(
        baseStats: _progression.statsAt(5),
        equipmentBonus: _aetherBlade.rolledStats + _swiftBoots.rolledStats,
        specialization: _specs.definitions['ranger'],
        passiveSkills: [
          _skills['vitality']!,
          _skills['focus']!,
          _skills['power_strike']!,
        ],
        skillLevelOf: (id) => id == 'focus' ? 2 : 1,
      );

      expect(result.maxHp, 160 + 20 + 40); // 220
      expect(result.atk, 22 + 15 + 9); // 46
      expect(result.def, 6 + 4); // 10
      expect(result.attackSpeed, closeTo(1.5, 1e-9));
      expect(result.critRate, closeTo(0.05 + 0.10 + 0.09, 1e-9)); // 0.24
      expect(result.critDamage, closeTo(1.5 + 0.15 + 0.25, 1e-9)); // 1.90
      expect(result.moveSpeed, closeTo(4.2, 1e-9));
      expect(result.attackRange, closeTo(5.5, 1e-9));
      expect(result.skillHaste, closeTo(0.2, 1e-9));
    });
  });

  group(
    'PlayerCharacter — mutasi, recalculation & tanpa duplicate stacking',
    () {
      PlayerCharacter makeChar({int level = 5, int gold = 500}) =>
          PlayerCharacter(
            config: _progression,
            progress: PlayerProgress(level: level, gold: gold),
            skillCatalog: _skills,
            specializationConfig: _specs,
          );

      test(
        '6 & 7. ganti dan lepas equipment memperbarui derived stats tanpa sisa',
        () {
          final inv = Inventory(
            definitions: {
              'iron_sword': const ItemDefinition(
                id: 'iron_sword',
                name: 'Iron Sword',
                category: ItemCategory.equipment,
                equipment: EquipmentData(
                  slot: EquipmentSlot.weapon,
                  baseStats: EquipmentStats(atk: 8, attackSpeed: 0.2),
                ),
              ),
              'aether_blade': const ItemDefinition(
                id: 'aether_blade',
                name: 'Aether Blade',
                category: ItemCategory.equipment,
                equipment: EquipmentData(
                  slot: EquipmentSlot.weapon,
                  baseStats: EquipmentStats(
                    atk: 15,
                    skillHaste: 0.2,
                    attackRange: 0.5,
                  ),
                ),
              ),
            },
          );
          inv
            ..addEquipment(_ironSword)
            ..addEquipment(_aetherBlade);

          final c = makeChar();
          final eqService = EquipmentService(
            inventory: inv,
            loadout: c.loadout,
          );
          final beforeEquip = c.stats;

          // Equip sword pertama
          expect(eqService.equip(_ironSword.id), isTrue);
          expect(c.stats.atk, beforeEquip.atk + 8);
          expect(c.stats.attackSpeed, closeTo(1.2, 1e-9));

          // Ganti ke aether blade: bonus iron sword harus hilang
          expect(eqService.equip(_aetherBlade.id), isTrue);
          expect(c.stats.atk, beforeEquip.atk + 15);
          expect(c.stats.attackSpeed, closeTo(1.0, 1e-9));
          expect(c.stats.attackRange, closeTo(2.0, 1e-9));

          // Unequip weapon: kembali tepat ke stats awal
          expect(eqService.unequip(EquipmentSlot.weapon), isTrue);
          expect(c.stats.atk, beforeEquip.atk);
          expect(c.stats.skillHaste, 0);
          expect(c.stats.attackRange, beforeEquip.attackRange);
        },
      );

      test('8 & 9 & 10. ganti specialization, upgrade passive skill, dan recalculation berulang tanpa stacking', () {
        final c = makeChar();
        c.loadout.equip(_swiftBoots);

        expect(c.chooseSpecialization('vanguard'), isTrue);
        final vanguardSnap = c.stats;
        // Panggil stats berkali-kali -> nilai tetap identik
        for (var i = 0; i < 10; i++) {
          final s = c.stats;
          expect(
            [s.maxHp, s.atk, s.def],
            [vanguardSnap.maxHp, vanguardSnap.atk, vanguardSnap.def],
          );
          expect(s.moveSpeed, closeTo(vanguardSnap.moveSpeed, 1e-9));
        }

        // Ganti ke ranger lalu balik lagi ke vanguard
        expect(c.chooseSpecialization('ranger'), isTrue);
        expect(c.chooseSpecialization('vanguard'), isTrue);
        expect(c.stats.maxHp, vanguardSnap.maxHp);
        expect(c.stats.attackSpeed, vanguardSnap.attackSpeed);
        expect(c.stats.critRate, vanguardSnap.critRate);
        expect(c.stats.attackRange, vanguardSnap.attackRange);

        // Upgrade passive Vitality (Lv1 -> Lv2, value scale 1.0 -> 1.5, plus Vanguard affinity 1.25 => 40 * 1.5 * 1.25 = 75 vs awal 50 => +25 HP)
        final up = c.upgradeSkill('vitality');
        expect(up.succeeded, isTrue);
        expect(c.stats.maxHp, vanguardSnap.maxHp + 25);
        expect(c.stats.def, vanguardSnap.def + 3); // 4 * 1.875 = 7.5 (awal 5.0 -> delta round = +3 vs 6+4+4+5=19 -> 6+4+4+7.5=21.5 -> 22)
      });
    },
  );

  group('Integrasi Combat & Edge Cases', () {
    test('11 & 12. CombatSimulation memakai final stats untuk damage, heal, ASPD, dan haste tanpa aplikasi ganda', () {
      final c = PlayerCharacter(
        config: _progression,
        progress: const PlayerProgress(level: 5),
        skillCatalog: _skills,
        specializationConfig: _specs,
      );
      c.loadout.equip(_aetherBlade); // +15 ATK, +0.2 haste, +0.5 range
      c.chooseSpecialization(
        'ranger',
      ); // +0.5 ASPD, +0.1 crit, +0.25 critDmg, range 5.0 (+0.5 = 5.5)

      final finalStats = c.stats;
      // ATK = 22 (lv5) + 15 (blade) + 6 (focus lv1 4 * 1.5) = 43
      expect(finalStats.atk, 43);
      expect(finalStats.attackSpeed, closeTo(1.5, 1e-9));
      expect(finalStats.skillHaste, closeTo(0.2, 1e-9));
      expect(finalStats.attackRange, closeTo(5.5, 1e-9));

      // Jadikan critRate 0 pada salinan simulasi agar perhitungan deterministik tepat pada ATK final.
      final combatStats = CombatStats(
        maxHp: finalStats.maxHp,
        atk: finalStats.atk,
        def: finalStats.def,
        attackSpeed: finalStats.attackSpeed,
        critRate: 0,
        critDamage: finalStats.critDamage,
        moveSpeed: finalStats.moveSpeed,
        attackRange: finalStats.attackRange,
        skillHaste: finalStats.skillHaste,
      );
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: combatStats,
        cell: const GridPoint(0, 2),
      )..hp = 50; // < 50% untuk memicu Healing Pulse

      final sim =
          CombatSimulation(
            grid: NavigationGrid.open(columns: 10, rows: 5),
            pathfinder: const AStarPathfinder(),
            player: player,
            seed: 1,
          )..setPlayerSkills([
            _skills['healing_pulse']!,
            _skills['power_strike']!,
          ], skillAffinities: c.activeSkillAffinities);

      // Musuh di (5, 2) berjarak tepat 5.0 tile -> masuk range 5.5 Ranger!
      const dummy = EnemyDefinition(
        id: 'dummy',
        name: 'Dummy',
        level: 1,
        detectionRange: 0,
        stats: CombatStats(maxHp: 5000, atk: 1, def: 3),
      );
      sim.spawnEnemy(dummy, const GridPoint(5, 2));

      // Tick 1: Healing Pulse (base maxHp = 200 -> 30% = +60 HP, cooldown 20s * (1 - 0.2) = 16s = 320 tick).
      sim.tick();
      final t1 = sim.drainEvents();
      expect(
        t1.whereType<HealEvent>().single.amount,
        (200 * 0.3).round(),
      ); // 60
      expect(player.hp, 110);
      expect(sim.skillCooldownTicks('healing_pulse'), 320);

      // Tick 2: Power Strike (43 * 1.5 - 3 def = 65 - 3 = 62, tidak ada double bonus ATK)
      sim.tick();
      final t2 = sim.drainEvents().whereType<AttackEvent>().single;
      expect(t2.skillId, 'power_strike');
      expect(t2.damage, 62);

      // Tick 3: Basic Attack memakai finalStats.atk (43 - 3 def = 40) & interval ASPD 1.5 -> round(20/1.5) = 13 tick
      sim.tick();
      final t3 = sim.drainEvents().whereType<AttackEvent>().single;
      expect(t3.skillId, isNull);
      expect(t3.damage, 40);
      expect(player.cooldownTicks, 13);
    });

    test('13. edge cases: modifier negatif, batas atribut, NaN/Infinity, dan level < 1 aman', () {
      const negative = EquipmentStats(
        hp: -999,
        atk: -999,
        def: -999,
        attackSpeed: -99,
        critRate: -5,
        critDamage: -5,
        moveSpeed: -50,
        attackRange: -10,
        skillHaste: -1,
      );
      final floored = calculator.calculate(
        baseStats: _progression.statsAt(0), // level < 1 aman menjadi level 1
        equipmentBonus: negative,
      );
      expect(floored.maxHp, 1);
      expect(floored.atk, 0);
      expect(floored.def, 0);
      expect(floored.attackSpeed, 0.1);
      expect(floored.critRate, 0.0);
      expect(floored.critDamage, 1.0);
      expect(floored.moveSpeed, 0.1);
      expect(floored.attackRange, 0.5);
      expect(floored.skillHaste, 0.0);

      const extreme = EquipmentStats(
        attackSpeed: 999,
        critRate: 5.0,
        moveSpeed: 999,
        attackRange: 999,
        skillHaste: 0.99,
      );
      final capped = calculator.calculate(
        baseStats: _progression.statsAt(1),
        equipmentBonus: extreme,
      );
      expect(capped.attackSpeed, 10.0);
      expect(capped.critRate, 1.0);
      expect(capped.moveSpeed, 20.0);
      expect(capped.attackRange, 20.0);
      expect(capped.skillHaste, EquipmentStats.maxSkillHaste);

      final nanSafe = calculator.clamp(
        const CombatStats(
          maxHp: 0,
          atk: -1,
          def: -1,
          attackSpeed: double.nan,
          critRate: double.infinity,
          critDamage: 0.2,
          moveSpeed: double.negativeInfinity,
          attackRange: 0,
          skillHaste: double.nan,
        ),
      );
      expect(nanSafe.maxHp, 1);
      expect(nanSafe.atk, 0);
      expect(nanSafe.def, 0);
      expect(nanSafe.attackSpeed, 0.1);
      expect(nanSafe.critRate, 0.0);
      expect(nanSafe.critDamage, 1.0);
      expect(nanSafe.moveSpeed, 0.1);
      expect(nanSafe.attackRange, 0.5);
      expect(nanSafe.skillHaste, 0.0);
    });
  });
}
