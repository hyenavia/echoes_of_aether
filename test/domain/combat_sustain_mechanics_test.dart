import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/damage_calculator.dart';
import 'package:echoes_of_aether/domain/services/derived_stats_calculator.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:flutter_test/flutter_test.dart';

NavigationGrid _openGrid() => NavigationGrid.fromAscii([
  '..........',
  '..........',
  '..........',
  '..........',
  '..........',
  '..........',
  '..........',
  '..........',
  '..........',
  '..........',
]);

Combatant _makePlayer({
  int hp = 1000,
  int atk = 50,
  int def = 10,
  double lifesteal = 0.0,
  double spellVamp = 0.0,
  GridPoint cell = const GridPoint(1, 1),
}) {
  return Combatant(
    id: 'player',
    team: Team.player,
    cell: cell,
    stats: CombatStats(
      maxHp: hp,
      atk: atk,
      def: def,
      attackSpeed: 1.0,
      attackRange: 2.0,
      moveSpeed: 4.0,
      lifesteal: lifesteal,
      spellVamp: spellVamp,
    ),
  );
}

EnemyDefinition _makeDummyEnemy({
  required String id,
  int hp = 500,
  int atk = 50,
  int def = 0,
}) {
  return EnemyDefinition(
    id: id,
    name: 'Dummy',
    level: 1,
    detectionRange: 8.0,
    stats: CombatStats(
      maxHp: hp,
      atk: atk,
      def: def,
      attackSpeed: 1.0,
      attackRange: 1.5,
      moveSpeed: 3.0,
    ),
  );
}

void main() {
  group('Combat Sustain Mechanics — Unit & Simulation Tests', () {
    test('Combatant Shield: addShield, absorbDamage, dan clearShield', () {
      final hero = _makePlayer(hp: 500);
      expect(hero.shield, 0);

      // Tambah shield 100
      hero.addShield(100);
      expect(hero.shield, 100);
      expect(hero.maxShield, 100);

      // Serangan pertama 40 damage: terserap penuh oleh shield
      final unabsorbed1 = hero.absorbDamage(40);
      expect(unabsorbed1, 0);
      expect(hero.shield, 60);
      expect(hero.hp, 500); // HP tetap utuh

      // Serangan kedua 80 damage: menyerap 60 shield tersisa, tembus 20 damage ke HP
      final unabsorbed2 = hero.absorbDamage(80);
      expect(unabsorbed2, 20);
      expect(hero.shield, 0);

      // Terapkan sisa unabsorbed damage ke HP
      hero.hp -= unabsorbed2;
      expect(hero.hp, 480);

      // Clear shield
      hero.addShield(50);
      expect(hero.shield, 50);
      hero.clearShield();
      expect(hero.shield, 0);
    });

    test(
      'CombatSimulation: Shield menyerap damage dan mengemisikan ShieldEvent',
      () {
        final grid = _openGrid();
        final player = _makePlayer(hp: 500, atk: 0, def: 0);
        // Beri shield 100 pada player
        player.addShield(100);

        final sim = CombatSimulation(
          grid: grid,
          pathfinder: const AStarPathfinder(),
          player: player,
          damageCalculator: const DamageCalculator(
            formula: DamageFormula.subtractive,
          ),
          seed: 42,
        );

        sim.spawnEnemy(
          _makeDummyEnemy(id: 'enemy_1', hp: 500, atk: 40, def: 0),
          const GridPoint(1, 2),
        );

        // Jalankan ticks sampai musuh menyerang
        for (var t = 0; t < 10; t++) {
          sim.tick();
          if (player.shield < 100) break;
        }

        final events = sim.drainEvents();
        final shieldEvents = events.whereType<ShieldEvent>().toList();
        expect(shieldEvents, isNotEmpty);
        expect(shieldEvents.first.targetId, 'player');
        expect(shieldEvents.first.absorbedDamage, greaterThan(0));
        expect(player.hp, 500); // HP tetap 500 karena 100% terserap shield
        expect(player.shield, lessThan(100));
      },
    );

    test(
      'CombatSimulation: Lifesteal memulihkan HP attacker pada basic attack',
      () {
        final grid = _openGrid();
        final player = _makePlayer(
          hp: 1000,
          atk: 100,
          def: 0,
          lifesteal: 0.30, // 30% Lifesteal
        );
        // Karakter terluka dulu agar pemulihan HP terlihat
        player.hp = 500;

        final sim = CombatSimulation(
          grid: grid,
          pathfinder: const AStarPathfinder(),
          player: player,
          damageCalculator: const DamageCalculator(
            formula: DamageFormula.subtractive,
          ),
          seed: 101,
        );

        sim.spawnEnemy(
          _makeDummyEnemy(id: 'dummy', hp: 1000, atk: 0, def: 0),
          const GridPoint(1, 2),
        );

        for (var t = 0; t < 10; t++) {
          sim.tick();
          if (player.hp > 500) break;
        }

        final events = sim.drainEvents();
        final lifestealEvents = events
            .whereType<HealEvent>()
            .where((e) => e.skillId == 'lifesteal')
            .toList();

        expect(lifestealEvents, isNotEmpty);
        expect(lifestealEvents.first.targetId, 'player');
        expect(lifestealEvents.first.amount, greaterThan(0));
        expect(player.hp, greaterThan(500));
      },
    );

    test(
      'CombatSimulation: Spell Vamp memulihkan HP attacker pada skill damage',
      () {
        final grid = _openGrid();
        final player = _makePlayer(
          hp: 1000,
          atk: 100,
          def: 0,
          spellVamp: 0.25, // 25% Spell Vamp
        );
        player.hp = 600;

        const meteorSkill = SkillDefinition(
          id: 'meteor_strike',
          name: 'Meteor Strike',
          type: SkillType.active,
          cooldownSeconds: 0.1,
          effect: SkillEffectType.damage,
          damageMultiplier: 1.5,
          targetType: SkillTarget.single,
          range: 3.0,
        );

        final sim = CombatSimulation(
          grid: grid,
          pathfinder: const AStarPathfinder(),
          player: player,
          damageCalculator: const DamageCalculator(
            formula: DamageFormula.subtractive,
          ),
          seed: 102,
        );
        sim.setPlayerSkills(const [meteorSkill]);

        sim.spawnEnemy(
          _makeDummyEnemy(id: 'dummy_mage', hp: 1000, atk: 0, def: 0),
          const GridPoint(1, 2),
        );

        for (var t = 0; t < 10; t++) {
          sim.tick();
          if (player.hp > 600) break;
        }

        final events = sim.drainEvents();
        final spellVampEvents = events
            .whereType<HealEvent>()
            .where((e) => e.skillId == 'spell_vamp')
            .toList();

        expect(spellVampEvents, isNotEmpty);
        expect(spellVampEvents.first.targetId, 'player');
        expect(spellVampEvents.first.amount, greaterThan(0));
        expect(player.hp, greaterThan(600));
      },
    );

    test('EquipmentStats & DerivedStatsCalculator: lifesteal dan spellVamp teragregasi', () {
      const base = CombatStats(maxHp: 100, atk: 10, def: 2);
      const weaponBonus = EquipmentStats(atk: 25, lifesteal: 0.12);
      const ringBonus = EquipmentStats(spellVamp: 0.15);

      final combinedBonus = weaponBonus + ringBonus;
      expect(combinedBonus.lifesteal, 0.12);
      expect(combinedBonus.spellVamp, 0.15);

      final calc = DerivedStatsCalculator();
      final finalStats = calc.calculate(
        baseStats: base,
        equipmentBonus: combinedBonus,
      );

      expect(finalStats.lifesteal, 0.12);
      expect(finalStats.spellVamp, 0.15);
    });

    test('Boss Lifesteal: Boss with lifesteal heals when attacking player with basic attack', () {
      final grid = _openGrid();
      final player = _makePlayer(hp: 2000, atk: 0, def: 0);
      final bossDef = EnemyDefinition(
        id: 'vampiric_boss',
        name: 'Vampiric Boss',
        level: 10,
        isBoss: true,
        stats: const CombatStats(
          maxHp: 1000,
          atk: 100,
          def: 0,
          lifesteal: 0.15,
        ),
      );

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
        damageCalculator: const DamageCalculator(
          formula: DamageFormula.subtractive,
        ),
        seed: 42,
      );

      final boss = sim.spawnEnemy(bossDef, const GridPoint(1, 2));
      boss.hp = 500; // damaged boss
      boss.cooldownTicks = 0;
      player.cooldownTicks = 999;

      sim.tick();

      final events = sim.drainEvents();
      final healEvents = events
          .whereType<HealEvent>()
          .where((e) => e.targetId == boss.id)
          .toList();
      expect(healEvents, isNotEmpty);
      expect(healEvents.first.skillId, 'lifesteal');
      expect(healEvents.first.amount, greaterThan(0));
      expect(boss.hp, 500 + healEvents.first.amount);
    });
  });
}
