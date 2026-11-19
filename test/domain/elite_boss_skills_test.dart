import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/damage_calculator.dart';
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

Combatant _makePlayer({int hp = 1000, int atk = 50, int def = 10}) {
  return Combatant(
    id: 'player',
    team: Team.player,
    cell: const GridPoint(1, 1),
    stats: CombatStats(
      maxHp: hp,
      atk: atk,
      def: def,
      attackSpeed: 1.0,
      attackRange: 1.5,
      moveSpeed: 4.0,
    ),
  );
}

EnemyDefinition _makeEliteDef({int hp = 400, int atk = 30, int def = 5}) {
  return EnemyDefinition(
    id: 'elite_orc',
    name: 'Orc Brute',
    level: 5,
    isElite: true,
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

EnemyDefinition _makeBossDef({int hp = 1000, int atk = 40, int def = 8}) {
  return EnemyDefinition(
    id: 'boss_dragon',
    name: 'Ancient Dragon',
    level: 10,
    isBoss: true,
    detectionRange: 10.0,
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
  group('Elite and Boss Skills (Stage 2 & 3)', () {
    test('Stoneskin: absorbs 15% damage when Elite HP > 50%, breaks when HP <= 50%', () {
      final grid = _openGrid();
      final player = _makePlayer(atk: 100);
      final eliteDef = _makeEliteDef(hp: 400, def: 0);

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
        cycleRank: 1, // Ascension active
        damageCalculator: const DamageCalculator(
          formula: DamageFormula.subtractive,
        ),
      );

      final elite = sim.spawnEnemy(eliteDef, const GridPoint(1, 2));
      expect(elite.hp, 400);

      // Player strikes elite while HP = 400 (> 50% of 400 = 200).
      // Base damage = 100 - 0 = 100.
      // Stoneskin reduces damage by 15%: 100 * 0.85 = 85.
      sim.tick();
      final events = sim.drainEvents().whereType<AttackEvent>().toList();
      expect(events.isNotEmpty, isTrue);
      final firstHit = events.firstWhere((e) => e.targetId == elite.id);
      expect(firstHit.damage, 85); // 15% reduction!
      expect(elite.hp, 315);

      // Now set elite HP <= 200 (broken shield threshold).
      elite.hp = 180;
      player.cooldownTicks = 0;
      sim.tick();
      final secondEvents = sim.drainEvents().whereType<AttackEvent>().toList();
      final secondHit = secondEvents.firstWhere((e) => e.targetId == elite.id);
      expect(secondHit.damage, 100); // Full damage! Stoneskin broken!
    });

    test('Stoneskin: does not activate at Rank 0 (minAscensionRank = 1)', () {
      final grid = _openGrid();
      final player = _makePlayer(atk: 100);
      final eliteDef = _makeEliteDef(hp: 400, def: 0);

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
        cycleRank: 0, // Rank 0 (untouched baseline)
        damageCalculator: const DamageCalculator(
          formula: DamageFormula.subtractive,
        ),
      );

      final elite = sim.spawnEnemy(eliteDef, const GridPoint(1, 2));
      sim.tick();
      final events = sim.drainEvents().whereType<AttackEvent>().toList();
      final hit = events.firstWhere((e) => e.targetId == elite.id);
      expect(hit.damage, 100); // Full damage at rank 0!
    });

    test('Berserk: triggers when Elite or Boss HP <= 35%, boosting ATK and attack speed', () {
      final grid = _openGrid();
      final player = _makePlayer(hp: 2000, def: 0);
      final eliteDef = _makeEliteDef(hp: 400, atk: 40, def: 0);

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
        cycleRank: 1,
        damageCalculator: const DamageCalculator(
          formula: DamageFormula.subtractive,
        ),
      );

      final elite = sim.spawnEnemy(eliteDef, const GridPoint(1, 2));
      elite.hp = 140; // 140 / 400 = 35%
      expect(elite.isEnraged, isFalse);

      sim.tick();
      expect(elite.isEnraged, isTrue);

      final specialEvents = sim
          .drainEvents()
          .whereType<EnemySpecialEvent>()
          .toList();
      expect(
        specialEvents.any((e) => e.specialType == EnemySpecialType.berserk),
        isTrue,
      );
    });

    test('Elite Heavy Strike: fires on ready cooldown for 1.6x damage', () {
      final grid = _openGrid();
      final player = _makePlayer(hp: 2000, def: 0);
      final eliteDef = _makeEliteDef(hp: 1000, atk: 50, def: 0);

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
        cycleRank: 1,
        damageCalculator: const DamageCalculator(
          formula: DamageFormula.subtractive,
        ),
      );

      final elite = sim.spawnEnemy(eliteDef, const GridPoint(1, 2));
      elite.eliteSpecialCooldownTicks = 0; // ready
      elite.cooldownTicks = 0;

      // Strike player!
      sim.tick();
      final events = sim.drainEvents().whereType<AttackEvent>().toList();
      final enemyHit = events.firstWhere((e) => e.attackerId == elite.id);
      // Base atk = 50. Multiplier 1.20 = 60 damage.
      expect(enemyHit.damage, 60);
      expect(enemyHit.skillId, 'heavy_strike');
      expect(elite.eliteSpecialCooldownTicks, greaterThan(0));
    });

    test('Boss Ground Slam AoE: triggers periodic shockwave when player is within radius', () {
      final grid = _openGrid();
      final player = _makePlayer(hp: 2000, def: 0);
      final bossDef = _makeBossDef(hp: 2000, atk: 50, def: 0);

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
        cycleRank: 1,
        damageCalculator: const DamageCalculator(
          formula: DamageFormula.subtractive,
        ),
      );

      final boss = sim.spawnEnemy(bossDef, const GridPoint(1, 2));
      boss.bossAoECooldownTicks = 0; // ready for slam
      boss.aggroed = true;

      sim.tick();
      final specialEvents = sim
          .drainEvents()
          .whereType<EnemySpecialEvent>()
          .toList();
      expect(
        specialEvents.any((e) => e.specialType == EnemySpecialType.groundSlam),
        isTrue,
      );
      expect(boss.bossAoECooldownTicks, greaterThan(0));
    });

    test('Boss Summon Minions: spawns 1 guard at 35% HP threshold', () {
      final grid = _openGrid();
      final player = _makePlayer(hp: 2000, def: 0);
      final bossDef = _makeBossDef(hp: 1000, atk: 50, def: 0);

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
        cycleRank: 1,
        damageCalculator: const DamageCalculator(
          formula: DamageFormula.subtractive,
        ),
      );

      final boss = sim.spawnEnemy(bossDef, const GridPoint(5, 5));
      boss.aggroed = true;
      expect(sim.enemies.length, 1);
      expect(boss.hasSummonedMinions, isFalse);

      // Drop boss HP to 350 (35%)
      boss.hp = 350;
      sim.tick();

      expect(boss.hasSummonedMinions, isTrue);
      expect(boss.shield, 80); // 8% max HP shield
      // Boss + 1 guard = 2 enemies
      expect(sim.enemies.length, 2);
      final guards = sim.enemies.where((e) => e.id.contains('guard')).toList();
      expect(guards.length, 1);
      for (final guard in guards) {
        expect(guard.isAlive, isTrue);
        expect(guard.aggroed, isTrue);
      }

      // Does not re-summon on next tick
      sim.tick();
      expect(sim.enemies.length, 2);
    });

    test(
      'Daily Boss: Elemental Ward triggers at 60% HP and absorbs 30% damage',
      () {
        final grid = _openGrid();
        final player = _makePlayer(atk: 100);
        final dailyDef = EnemyDefinition(
          id: 'daily_ash_tyrant',
          name: 'Ash Tyrant',
          level: 10,
          isBoss: true,
          stats: const CombatStats(
            maxHp: 1000,
            atk: 30,
            def: 0,
            attackSpeed: 1.0,
            attackRange: 1.5,
            moveSpeed: 3.0,
          ),
        );

        final sim = CombatSimulation(
          grid: grid,
          pathfinder: const AStarPathfinder(),
          player: player,
          cycleRank: 1,
          damageCalculator: const DamageCalculator(
            formula: DamageFormula.subtractive,
          ),
        );

        final boss = sim.spawnEnemy(dailyDef, const GridPoint(1, 2));
        boss.aggroed = true;
        expect(boss.isDailyBoss, isTrue);

        // Drop boss HP to 600 (60%)
        boss.hp = 600;
        sim.tick();

        expect(boss.hasTriggeredWard, isTrue);
        expect(boss.shield, 100); // 10% max HP shield
        expect(boss.elementalWardTicks, greaterThan(0));

        final events = sim
            .drainEvents()
            .whereType<EnemySpecialEvent>()
            .toList();
        expect(
          events.any((e) => e.specialType == EnemySpecialType.elementalWard),
          isTrue,
        );

        // Player strikes boss while ward is active: 100 damage * (1 - 0.30) = 70 damage
        boss.cooldownTicks = 999;
        player.cooldownTicks = 0;
        sim.tick();
        final attacks = sim.drainEvents().whereType<AttackEvent>().toList();
        final playerAtk = attacks.firstWhere((e) => e.attackerId == player.id);
        expect(playerAtk.damage, 70);
      },
    );

    test('Daily Boss: Blazing Surge AoE triggers with 1.25x multiplier', () {
      final grid = _openGrid();
      final player = _makePlayer(hp: 2000, def: 0);
      final dailyDef = EnemyDefinition(
        id: 'daily_prism_warden',
        name: 'Prism Warden',
        level: 10,
        isBoss: true,
        stats: const CombatStats(
          maxHp: 1000,
          atk: 40,
          def: 0,
          attackSpeed: 1.0,
          attackRange: 1.5,
          moveSpeed: 3.0,
        ),
      );

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
        cycleRank: 1,
        damageCalculator: const DamageCalculator(
          formula: DamageFormula.subtractive,
        ),
      );

      final boss = sim.spawnEnemy(dailyDef, const GridPoint(1, 2));
      boss.aggroed = true;
      boss.bossAoECooldownTicks = 0;

      sim.tick();

      final events = sim.drainEvents();
      final specialEvents = events.whereType<EnemySpecialEvent>().toList();
      expect(
        specialEvents.any(
          (e) => e.specialType == EnemySpecialType.blazingSurge,
        ),
        isTrue,
      );
      final attackEvents = events.whereType<AttackEvent>().toList();
      final surgeAtk = attackEvents.firstWhere(
        (e) => e.skillId == 'blazing_surge',
      );
      // 40 atk * 1.25 multiplier = 50 damage
      expect(surgeAtk.damage, 50);
      expect(boss.bossAoECooldownTicks, greaterThan(0));
    });

    test('Weekly Boss: Life Siphon deals 1.35x dmg and heals boss by 30% of damage dealt', () {
      final grid = _openGrid();
      final player = _makePlayer(hp: 2000, def: 0);
      final weeklyDef = EnemyDefinition(
        id: 'weekly_crimson_sovereign',
        name: 'Crimson Sovereign',
        level: 10,
        isBoss: true,
        stats: const CombatStats(
          maxHp: 1000,
          atk: 100,
          def: 0,
          attackSpeed: 1.0,
          attackRange: 1.5,
          moveSpeed: 3.0,
        ),
      );

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
        cycleRank: 1,
        damageCalculator: const DamageCalculator(
          formula: DamageFormula.subtractive,
        ),
      );

      final boss = sim.spawnEnemy(weeklyDef, const GridPoint(1, 2));
      boss.aggroed = true;
      boss.hp = 500; // Damaged boss
      boss.lifeSiphonCooldownTicks = 0;
      player.cooldownTicks = 999;

      sim.tick();

      final events = sim.drainEvents();
      final special = events.whereType<EnemySpecialEvent>().toList();
      expect(
        special.any((e) => e.specialType == EnemySpecialType.lifeSiphon),
        isTrue,
      );

      final attacks = events.whereType<AttackEvent>().toList();
      final siphonAtk = attacks.firstWhere((e) => e.skillId == 'life_siphon');
      // 100 atk * 1.35 = 135 damage
      expect(siphonAtk.damage, 135);

      // Boss heals for 30% of 135 = 41 HP
      expect(boss.hp, 500 + 41);
      final heals = events.whereType<HealEvent>().toList();
      expect(
        heals.any((h) => h.skillId == 'life_siphon' && h.amount == 41),
        isTrue,
      );
    });

    test('Weekly Boss: Cataclysm AoE triggers with 1.30x multiplier and 3.5 radius', () {
      final grid = _openGrid();
      final player = _makePlayer(hp: 2000, def: 0);
      final weeklyDef = EnemyDefinition(
        id: 'weekly_solar_archon',
        name: 'Solar Archon',
        level: 10,
        isBoss: true,
        stats: const CombatStats(
          maxHp: 1000,
          atk: 50,
          def: 0,
          attackSpeed: 1.0,
          attackRange: 1.5,
          moveSpeed: 3.0,
        ),
      );

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
        cycleRank: 1,
        damageCalculator: const DamageCalculator(
          formula: DamageFormula.subtractive,
        ),
      );

      final boss = sim.spawnEnemy(weeklyDef, const GridPoint(1, 4));
      boss.aggroed = true;
      boss.bossAoECooldownTicks = 0;

      sim.tick();

      final events = sim.drainEvents();
      final specialEvents = events.whereType<EnemySpecialEvent>().toList();
      expect(
        specialEvents.any((e) => e.specialType == EnemySpecialType.cataclysm),
        isTrue,
      );
      final attackEvents = events.whereType<AttackEvent>().toList();
      final cataclysmAtk = attackEvents.firstWhere(
        (e) => e.skillId == 'cataclysm',
      );
      // 50 atk * 1.30 = 65 damage
      expect(cataclysmAtk.damage, 65);
    });

    test('Weekly Boss: summons 2 Elite Guards at 50% HP threshold', () {
      final grid = _openGrid();
      final player = _makePlayer(hp: 2000, def: 0);
      final weeklyDef = EnemyDefinition(
        id: 'weekly_crimson_sovereign',
        name: 'Crimson Sovereign',
        level: 10,
        isBoss: true,
        stats: const CombatStats(
          maxHp: 1000,
          atk: 50,
          def: 0,
          attackSpeed: 1.0,
          attackRange: 1.5,
          moveSpeed: 3.0,
        ),
      );

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
        cycleRank: 1,
        damageCalculator: const DamageCalculator(
          formula: DamageFormula.subtractive,
        ),
      );

      final boss = sim.spawnEnemy(weeklyDef, const GridPoint(5, 5));
      boss.aggroed = true;
      expect(sim.enemies.length, 1);

      // Drop boss HP to 500 (50%)
      boss.hp = 500;
      sim.tick();

      expect(boss.hasSummonedMinions, isTrue);
      // Boss + 2 guards = 3 enemies
      expect(sim.enemies.length, 3);
      final guards = sim.enemies.where((e) => e.id.contains('guard')).toList();
      expect(guards.length, 2);
      for (final guard in guards) {
        expect(guard.isElite, isTrue);
        expect(guard.isAlive, isTrue);
        expect(guard.aggroed, isTrue);
      }
    });

    test('Weekly Boss: Final Stand triggers at 20% HP granting 20% damage reduction', () {
      final grid = _openGrid();
      final player = _makePlayer(atk: 100);
      final weeklyDef = EnemyDefinition(
        id: 'weekly_solar_archon',
        name: 'Solar Archon',
        level: 10,
        isBoss: true,
        stats: const CombatStats(
          maxHp: 1000,
          atk: 50,
          def: 0,
          attackSpeed: 1.0,
          attackRange: 1.5,
          moveSpeed: 3.0,
        ),
      );

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
        cycleRank: 1,
        damageCalculator: const DamageCalculator(
          formula: DamageFormula.subtractive,
        ),
      );

      final boss = sim.spawnEnemy(weeklyDef, const GridPoint(1, 2));
      boss.aggroed = true;

      // Drop boss HP to 200 (20%)
      boss.hp = 200;
      sim.tick();

      expect(boss.isFinalStand, isTrue);
      expect(boss.shield, 50); // 5% max HP shield
      expect(boss.isEnraged, isTrue);

      final events = sim.drainEvents().whereType<EnemySpecialEvent>().toList();
      expect(
        events.any((e) => e.specialType == EnemySpecialType.finalStand),
        isTrue,
      );

      // Player strikes boss while in Final Stand: 100 damage * (1 - 0.20) = 80 damage
      boss.cooldownTicks = 999;
      player.cooldownTicks = 0;
      sim.tick();
      final attacks = sim.drainEvents().whereType<AttackEvent>().toList();
      final playerAtk = attacks.firstWhere((e) => e.attackerId == player.id);
      expect(playerAtk.damage, 80);
    });
  });
}
