import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:flutter_test/flutter_test.dart';

const progression = ProgressionConfig(
  maxLevel: 30,
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

const specs = SpecializationConfig(
  unlockLevel: 5,
  definitions: {
    'vanguard': SpecializationDefinition(
      id: 'vanguard',
      name: 'Vanguard',
      bonus: EquipmentStats(hp: 60, def: 3),
      attackRange: 1.5,
    ),
    'ranger': SpecializationDefinition(
      id: 'ranger',
      name: 'Ranger',
      bonus: EquipmentStats(attackSpeed: 0.4),
      attackRange: 5.0,
    ),
  },
);

const skills = {
  'power_strike': SkillDefinition(
    id: 'power_strike',
    name: 'Power Strike',
    type: SkillType.active,
    unlockLevel: 2,
    cooldownSeconds: 5,
    damageMultiplier: 1.5,
  ),
  'second_wind': SkillDefinition(
    id: 'second_wind',
    name: 'Second Wind',
    type: SkillType.active,
    unlockLevel: 3,
    cooldownSeconds: 25,
    effect: SkillEffectType.healing,
    targetType: SkillTarget.self,
    healPercent: 0.35,
  ),
  'iron_resolve': SkillDefinition(
    id: 'iron_resolve',
    name: 'Iron Resolve',
    type: SkillType.passive,
    unlockLevel: 5,
    specializationId: 'vanguard',
    passiveStats: EquipmentStats(hp: 30, def: 3),
  ),
  'quick_shot': SkillDefinition(
    id: 'quick_shot',
    name: 'Quick Shot',
    type: SkillType.active,
    unlockLevel: 5,
    specializationId: 'ranger',
    cooldownSeconds: 3,
    damageMultiplier: 1.2,
    range: 5,
  ),
};

PlayerCharacter make({int level = 1}) => PlayerCharacter(
  config: progression,
  progress: PlayerProgress(level: level),
  skillCatalog: skills,
  specializationConfig: specs,
);

List<String> ids(List<SkillDefinition> list) => list.map((s) => s.id).toList();

void main() {
  group('skill terbuka berdasarkan level', () {
    test('level 1 belum punya skill; level 2 dan 3 membuka skill umum', () {
      expect(make().unlockedSkills, isEmpty);
      expect(ids(make(level: 2).unlockedSkills), ['power_strike']);
      expect(ids(make(level: 3).unlockedSkills), [
        'power_strike',
        'second_wind',
      ]);
    });

    test('naik level lewat reward membuka skill baru', () {
      final c = make();
      c.receiveReward(exp: 100); // level 2
      expect(ids(c.activeSkills), ['power_strike']);
    });

    test('skill specialization tidak terbuka tanpa memilih specialization', () {
      final c = make(level: 10);
      expect(ids(c.unlockedSkills), ['power_strike', 'second_wind']);
    });
  });

  group('specialization', () {
    test('tidak bisa dipilih sebelum level unlock', () {
      final c = make(level: 4);
      expect(c.canChooseSpecialization, isFalse);
      expect(c.chooseSpecialization('vanguard'), isFalse);
      expect(c.specializationId, isNull);
      expect(c.buildRevision, 0);
    });

    test('bisa dipilih di level unlock dan membuka skill-nya', () {
      final c = make(level: 5);
      expect(c.chooseSpecialization('vanguard'), isTrue);
      expect(c.specialization!.name, 'Vanguard');
      expect(c.buildRevision, 1);
      expect(ids(c.unlockedSkills), [
        'iron_resolve',
        'power_strike',
        'second_wind',
      ]);
      expect(ids(c.activeSkills), ['power_strike', 'second_wind']);
      expect(ids(c.passiveSkills), ['iron_resolve']);
    });

    test('id tidak dikenal atau pilihan yang sama ditolak tanpa perubahan', () {
      final c = make(level: 5);
      expect(c.chooseSpecialization('tidak_ada'), isFalse);
      c.chooseSpecialization('vanguard');
      expect(c.chooseSpecialization('vanguard'), isFalse);
      expect(c.buildRevision, 1);
    });

    test('mengganti specialization (respec) mengganti skill dan stat', () {
      final c = make(level: 5)..chooseSpecialization('vanguard');
      expect(c.chooseSpecialization('ranger'), isTrue);
      expect(c.buildRevision, 2);
      expect(ids(c.unlockedSkills), [
        'power_strike',
        'quick_shot',
        'second_wind',
      ]);
      expect(c.unlockedSkills.any((s) => s.id == 'iron_resolve'), isFalse);
    });
  });

  group('stat akhir', () {
    // Level 5: hp 100+40=140, atk 10+8=18, def 2+4=6.
    test('tanpa specialization = stat level', () {
      final s = make(level: 5).stats;
      expect([s.maxHp, s.atk, s.def], [140, 18, 6]);
      expect(s.attackRange, 1.5);
    });

    test('specialization + skill pasif menambah bonus', () {
      final c = make(level: 5)..chooseSpecialization('vanguard');
      final s = c.stats;
      expect(s.maxHp, 140 + 60 + 30);
      expect(s.def, 6 + 3 + 3);
      expect(s.atk, 18);
    });

    test('specialization ranged mengganti attack range dan menambah ASPD', () {
      final c = make(level: 5)..chooseSpecialization('ranger');
      expect(c.stats.attackRange, 5.0);
      expect(c.stats.attackSpeed, closeTo(1.9, 1e-9));
      expect(c.stats.maxHp, 140); // tanpa bonus HP vanguard
    });

    test('bonus equipment, specialization, dan passive bertumpuk', () {
      final c = make(level: 5)..chooseSpecialization('vanguard');
      c.loadout.equip(
        const EquipmentInstance(
          id: 'eq_1',
          definitionId: 'x',
          slot: EquipmentSlot.head,
          rarity: ItemRarity.common,
          rolledStats: EquipmentStats(hp: 10, def: 2),
        ),
      );
      expect(c.stats.maxHp, 140 + 60 + 30 + 10);
      expect(c.stats.def, 6 + 3 + 3 + 2);
    });
  });

  group('M4 Phase C — Class Specialization & Skill Affinity', () {
    const fullSpecs = SpecializationConfig(
      unlockLevel: 5,
      definitions: {
        'vanguard': SpecializationDefinition(
          id: 'vanguard',
          name: 'Vanguard',
          description: 'Physical & durability',
          bonus: EquipmentStats(hp: 60, def: 3),
          attackRange: 1.5,
          skillAffinities: {'power_strike': 0.2, 'vitality': 0.25},
        ),
        'arcanist': SpecializationDefinition(
          id: 'arcanist',
          name: 'Arcanist',
          description: 'Magic & AoE',
          bonus: EquipmentStats(atk: 6, skillHaste: 0.05),
          attackRange: 4.0,
          skillAffinities: {'aether_burst': 0.25, 'healing_pulse': 0.2},
        ),
        'ranger': SpecializationDefinition(
          id: 'ranger',
          name: 'Ranger',
          description: 'Ranged & precision',
          bonus: EquipmentStats(attackSpeed: 0.4, critRate: 0.05),
          attackRange: 5.0,
          skillAffinities: {'power_strike': 0.1, 'focus': 0.25},
        ),
      },
    );

    const fullSkills = {
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
      'aether_burst': SkillDefinition(
        id: 'aether_burst',
        name: 'Aether Burst',
        type: SkillType.active,
        effect: SkillEffectType.damage,
        damageType: SkillDamageType.magic,
        targetType: SkillTarget.area,
        unlockLevel: 5,
        cooldownSeconds: 7,
        baseValue: 1.3,
        radius: 2.5,
        range: 4.0,
        minEnemies: 2,
      ),
      'healing_pulse': SkillDefinition(
        id: 'healing_pulse',
        name: 'Healing Pulse',
        type: SkillType.active,
        effect: SkillEffectType.healing,
        targetType: SkillTarget.self,
        unlockLevel: 3,
        cooldownSeconds: 25,
        baseValue: 0.30,
        useWhenHpBelow: 0.5,
      ),
      'vitality': SkillDefinition(
        id: 'vitality',
        name: 'Vitality',
        type: SkillType.passive,
        effect: SkillEffectType.statModifier,
        unlockLevel: 4,
        passiveStats: EquipmentStats(hp: 40, def: 4),
      ),
      'focus': SkillDefinition(
        id: 'focus',
        name: 'Focus',
        type: SkillType.passive,
        effect: SkillEffectType.statModifier,
        unlockLevel: 4,
        passiveStats: EquipmentStats(atk: 4, critRate: 0.04),
      ),
    };

    PlayerCharacter makeFull({int level = 5}) => PlayerCharacter(
      config: progression,
      progress: PlayerProgress(level: level),
      skillCatalog: fullSkills,
      specializationConfig: fullSpecs,
    );

    test('Vanguard, Arcanist, dan Ranger menghasilkan derived stats distinct serta menghapus modifier saat ganti/clear', () {
      // Base level 5: hp=140, atk=18, def=6, aspd=1.5, critRate=0.1, range=1.5, haste=0
      // + Passive umum unlocked: Vitality (+40 HP, +4 DEF) & Focus (+4 ATK, +0.04 critRate)
      // Neutral lv 5: hp=180, atk=22, def=10, aspd=1.5, critRate=0.14, range=1.5, haste=0
      final c = makeFull();
      final neutral = c.stats;
      expect([neutral.maxHp, neutral.atk, neutral.def], [180, 22, 10]);
      expect(neutral.critRate, closeTo(0.14, 1e-9));
      expect(neutral.attackRange, 1.5);

      // Vanguard: +60 HP, +3 DEF + Vitality affinity +25% (+10 HP, +1 DEF)
      expect(c.chooseSpecialization('vanguard'), isTrue);
      final vanguard = c.stats;
      expect(vanguard.maxHp, 180 + 60 + 10); // 250
      expect(vanguard.def, 10 + 3 + 1); // 14
      expect(vanguard.atk, 22);
      expect(vanguard.attackRange, 1.5);

      // Switch -> Arcanist: bonus Vanguard & affinity Vitality hilang total,
      // diganti ATK +6, haste +0.05, attackRange 4.0
      expect(c.chooseSpecialization('arcanist'), isTrue);
      final arcanist = c.stats;
      expect(arcanist.maxHp, 180);
      expect(arcanist.def, 10);
      expect(arcanist.atk, 22 + 6); // 28
      expect(arcanist.skillHaste, closeTo(0.05, 1e-9));
      expect(arcanist.attackRange, 4.0);

      // Switch -> Ranger: bonus Arcanist hilang total,
      // diganti ASPD +0.4, critRate +0.05, range 5.0, + Focus affinity +25% (+1 ATK, +0.01 crit)
      expect(c.chooseSpecialization('ranger'), isTrue);
      final ranger = c.stats;
      expect(ranger.maxHp, 180);
      expect(ranger.def, 10);
      expect(ranger.skillHaste, 0);
      expect(ranger.atk, 22 + 1); // 23
      expect(ranger.attackSpeed, closeTo(1.9, 1e-9));
      expect(ranger.critRate, closeTo(0.14 + 0.05 + 0.01, 1e-9)); // 0.20
      expect(ranger.attackRange, 5.0);

      // Switch berulang tidak mengakumulasi modifier.
      expect(c.chooseSpecialization('vanguard'), isTrue);
      expect(c.chooseSpecialization('arcanist'), isTrue);
      expect(c.chooseSpecialization('ranger'), isTrue);
      expect(c.chooseSpecialization('vanguard'), isTrue);
      final vanguardAgain = c.stats;
      expect(vanguardAgain.maxHp, vanguard.maxHp);
      expect(vanguardAgain.def, vanguard.def);
      expect(vanguardAgain.atk, vanguard.atk);
      expect(vanguardAgain.attackRange, vanguard.attackRange);
      expect(vanguardAgain.attackSpeed, vanguard.attackSpeed);

      // Clear specialization memulihkan state tepat ke netral (plus equipment tetap).
      c.loadout.equip(
        const EquipmentInstance(
          id: 'w1',
          definitionId: 'sword',
          slot: EquipmentSlot.weapon,
          rarity: ItemRarity.common,
          rolledStats: EquipmentStats(atk: 5),
        ),
      );
      expect(c.clearSpecialization(), isTrue);
      expect(c.clearSpecialization(), isFalse);
      final cleared = c.stats;
      expect(cleared.maxHp, neutral.maxHp);
      expect(cleared.def, neutral.def);
      expect(cleared.atk, neutral.atk + 5);
      expect(cleared.attackRange, neutral.attackRange);
    });

    test('seluruh 5 skill awal tetap tersedia di semua specialization netral ketika unlocked', () {
      for (final specId in const ['vanguard', 'arcanist', 'ranger']) {
        final c = makeFull()..chooseSpecialization(specId);
        expect(c.unlockedSkills.map((s) => s.id).toSet(), {
          'power_strike',
          'aether_burst',
          'healing_pulse',
          'vitality',
          'focus',
        }, reason: specId);
      }
    });

    test('skill affinity aktif memengaruhi damage & healing di CombatSimulation serta tersinkron saat berganti specialization', () {
      const dummyDef = EnemyDefinition(
        id: 'dummy',
        name: 'Dummy',
        level: 1,
        detectionRange: 0,
        stats: CombatStats(maxHp: 10000, atk: 1, def: 0),
      );
      final c = makeFull();

      // Vanguard: Power Strike base 1.5 * (1 + 0.2) = 1.8x; ATK 22 -> round(22 * 1.8) = 40
      c.chooseSpecialization('vanguard');
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: c.stats,
        cell: const GridPoint(1, 2),
      );
      final sim = CombatSimulation(
        grid: NavigationGrid.open(columns: 10, rows: 5),
        pathfinder: const AStarPathfinder(),
        player: player,
        seed: 99, // pastikan bukan crit pada tick awal jika critRate > 0 (bisa dikontrol lewat stats)
      );
      // Pakai ATK tanpa crit acak untuk determinisme uji multiplier exact
      player.applyStats(
        CombatStats(
          maxHp: c.stats.maxHp,
          atk: c.stats.atk,
          def: c.stats.def,
          attackSpeed: c.stats.attackSpeed,
          critRate: 0,
          attackRange: c.stats.attackRange,
          skillHaste: c.stats.skillHaste,
        ),
      );
      sim.setPlayerSkills([
        fullSkills['power_strike']!,
      ], skillAffinities: c.activeSkillAffinities);
      sim.spawnEnemy(dummyDef, const GridPoint(2, 2));
      sim.tick();
      final vanguardHit = sim.drainEvents().whereType<AttackEvent>().firstWhere(
        (e) => e.attackerId == 'player',
      );
      expect(vanguardHit.skillId, 'power_strike');
      expect(vanguardHit.damage, (22 * 1.8).round()); // 40

      // Ganti ke Arcanist: ATK 28, Aether Burst 1.3 * (1 + 0.25) = 1.625x -> 46 magic dmg
      // dan Healing Pulse 0.30 * (1 + 0.20) = 0.36 maxHp heal
      c.chooseSpecialization('arcanist');
      player.applyStats(
        CombatStats(
          maxHp: c.stats.maxHp,
          atk: c.stats.atk,
          def: c.stats.def,
          attackSpeed: c.stats.attackSpeed,
          critRate: 0,
          attackRange: c.stats.attackRange,
          skillHaste: c.stats.skillHaste,
        ),
      );
      sim.setPlayerSkills([
        fullSkills['aether_burst']!,
        fullSkills['healing_pulse']!,
      ], skillAffinities: c.activeSkillAffinities);
      sim.spawnEnemy(dummyDef, const GridPoint(3, 2));

      // Uji Arcanist AoE magic affinity
      sim.tick();
      final arcanistHits = sim
          .drainEvents()
          .whereType<AttackEvent>()
          .where((e) => e.skillId == 'aether_burst')
          .toList();
      expect(arcanistHits, hasLength(2));
      expect(
        arcanistHits.every(
          (e) =>
              e.damageType == SkillDamageType.magic &&
              e.damage == (28 * 1.625).round(), // 46
        ),
        isTrue,
      );

      // Uji Arcanist Healing Pulse affinity: HP 50/180 -> pulih round(180 * 0.36) = 65
      player.hp = 50;
      sim.tick();
      final heal = sim.drainEvents().whereType<HealEvent>().single;
      expect(heal.skillId, 'healing_pulse');
      expect(heal.amount, (180 * 0.36).round());
    });
  });
}
