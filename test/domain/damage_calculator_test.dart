import 'dart:math';

import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/damage_calculator.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DamageFormula.subtractive (regresi formula lama)', () {
    const calc = DamageCalculator(formula: DamageFormula.subtractive);

    test('damage dasar = ATK - DEF', () {
      expect(calc.baseDamage(12, 2), 10);
    });

    test('damage minimal 1 walau DEF lebih besar dari ATK', () {
      expect(calc.baseDamage(3, 50), 1);
    });

    test('critRate 1.0 selalu critical dan memakai pengali', () {
      const stats = CombatStats(
        maxHp: 1,
        atk: 12,
        def: 0,
        critRate: 1.0,
        critDamage: 2.0,
      );
      final r = calc.roll(attacker: stats, defenderDef: 2, random: Random(1));
      expect(r.isCrit, isTrue);
      expect(r.amount, 20); // (12-2) * 2.0
    });

    test('critRate 0 tidak pernah critical', () {
      const stats = CombatStats(maxHp: 1, atk: 12, def: 0, critRate: 0);
      final random = Random(1);
      for (var i = 0; i < 100; i++) {
        final r = calc.roll(attacker: stats, defenderDef: 2, random: random);
        expect(r.isCrit, isFalse);
        expect(r.amount, 10);
      }
    });

    test('seed sama menghasilkan urutan hasil yang sama', () {
      const stats = CombatStats(maxHp: 1, atk: 12, def: 0, critRate: 0.5);
      List<bool> run() {
        final random = Random(42);
        return List.generate(
          30,
          (_) =>
              calc.roll(attacker: stats, defenderDef: 0, random: random).isCrit,
        );
      }

      expect(run(), run());
    });

    test('physical vs magic damage path dan magicDefenseFactor', () {
      const defaultCalc = DamageCalculator(formula: DamageFormula.subtractive);
      expect(defaultCalc.physicalDamage(20, 6), 14);
      expect(defaultCalc.magicDamage(20, 6), 14);
      expect(
        defaultCalc.baseDamage(20, 6, damageType: SkillDamageType.magic),
        14,
      );

      const splitDefCalc = DamageCalculator(
        magicDefenseFactor: 0.5,
        formula: DamageFormula.subtractive,
      );
      expect(splitDefCalc.physicalDamage(20, 6), 14);
      expect(splitDefCalc.magicDamage(20, 6), 17); // 20 - round(6 * 0.5)

      const stats = CombatStats(maxHp: 100, atk: 20, def: 0, critRate: 0);
      final magicRoll = splitDefCalc.roll(
        attacker: stats,
        defenderDef: 6,
        random: Random(1),
        multiplier: 1.5,
        damageType: SkillDamageType.magic,
      );
      expect(magicRoll.damageType, SkillDamageType.magic);
      expect(magicRoll.isCrit, isFalse);
      expect(magicRoll.amount, 27); // (20 * 1.5) - 3
    });

    test(
      'crit dan skill multiplier masing-masing diterapkan tepat satu kali',
      () {
        const stats = CombatStats(
          maxHp: 100,
          atk: 20,
          def: 0,
          critRate: 1.0,
          critDamage: 2.0,
        );
        final r = calc.roll(
          attacker: stats,
          defenderDef: 5,
          random: Random(1),
          multiplier: 1.5,
          damageType: SkillDamageType.physical,
        );
        expect(r.isCrit, isTrue);
        expect(r.damageType, SkillDamageType.physical);
        // (round(20 * 1.5) - 5) * 2.0 = 25 * 2 = 50 (bukan 2.25x atau 4x)
        expect(r.amount, 50);
      },
    );
  });

  group('DamageFormula.ratio (GDD Addendum §6, TDD Addendum §3.1)', () {
    const calc = DamageCalculator();

    test('default constructor menggunakan formula ratio', () {
      expect(calc.formula, DamageFormula.ratio);
    });

    test('tabel nilai spesifikasi: (12,1)->11, (5,2)->4, (70,16)->57, (70,100)->29, (300,2000)->39', () {
      expect(calc.physicalDamage(12, 1), 11);
      expect(calc.physicalDamage(5, 2), 4);
      expect(calc.physicalDamage(70, 16), 57);
      expect(calc.physicalDamage(70, 100), 29);
      expect(calc.physicalDamage(300, 2000), 39);
    });

    test('penjelasan pembulatan (5,2) -> 4', () {
      // 5 * 5 / (5 + 2) = 25 / 7 = 3.571428...
      // Menggunakan round(), desimal >= 0.5 dibulatkan ke atas menjadi 4.
      expect(calc.physicalDamage(5, 2), 4);
    });

    test('penjelasan pembulatan (70,16) -> 57', () {
      // 70 * 70 / (70 + 16) = 4900 / 86 = 56.9767...
      // round(56.9767...) = 57
      expect(calc.physicalDamage(70, 16), 57);
    });

    test('monotonisitas: ATK naik tidak pernah menurunkan damage', () {
      const fixedDef = 15;
      for (var atk = 1; atk < 200; atk++) {
        final d1 = calc.physicalDamage(atk, fixedDef);
        final d2 = calc.physicalDamage(atk + 1, fixedDef);
        expect(
          d2,
          greaterThanOrEqualTo(d1),
          reason: 'ATK $atk -> ${atk + 1} with DEF $fixedDef',
        );
      }
    });

    test('monotonisitas: DEF naik tidak pernah menaikkan damage', () {
      const fixedAtk = 50;
      for (var def = 0; def < 200; def++) {
        final d1 = calc.physicalDamage(fixedAtk, def);
        final d2 = calc.physicalDamage(fixedAtk, def + 1);
        expect(
          d2,
          lessThanOrEqualTo(d1),
          reason: 'DEF $def -> ${def + 1} with ATK $fixedAtk',
        );
      }
    });

    test('batas bawah: damage tidak pernah < 1 walau DEF ekstrem', () {
      expect(calc.physicalDamage(1, 1000000), 1);
      expect(calc.physicalDamage(1, 999999999), 1);
    });

    test('penjaga ATK <= 0 tidak menghasilkan NaN atau Infinity', () {
      expect(calc.physicalDamage(0, 10), 1);
      expect(calc.physicalDamage(-10, 10), 1);
      expect(calc.physicalDamage(0, 0), 1);
      expect(calc.physicalDamage(-5, 0), 1);
      expect(calc.magicDamage(0, 10), 1);
      expect(calc.magicDamage(-10, 10), 1);
    });

    test('DEF negatif diperlakukan sebagai 0 (tidak menambah damage di luar batas ATK)', () {
      // safeDef = max(0, def) -> jika def = -10, safeDef = 0
      // 20 * 20 / (20 + 0) = 20
      expect(calc.physicalDamage(20, -10), 20);
    });

    test('nilai sangat besar (1e9) tidak overflow atau menghasilkan NaN', () {
      // 1e9 * 1e9 / (1e9 + 1e9) = 1e9 * 0.5 = 500_000_000
      expect(calc.physicalDamage(1000000000, 1000000000), 500000000);
      expect(calc.physicalDamage(1000000000, 0), 1000000000);
    });

    test('clamp ke batas teknis kMaxDamage', () {
      expect(calc.physicalDamage(3000000000, 0), DamageCalculator.kMaxDamage);
    });

    test('magic damage memakai DEF efektif magicDefenseFactor', () {
      // ATK 20, DEF 6, factor 0.5 -> effectiveDef = round(6 * 0.5) = 3
      // 20 * 20 / (20 + 3) = 400 / 23 = 17.391... -> round = 17
      const splitCalc = DamageCalculator(magicDefenseFactor: 0.5);
      expect(splitCalc.magicDamage(20, 6), 17);

      // Bandingkan dengan physicalDamage: 20 * 20 / (20 + 6) = 400 / 26 = 15.38... -> round = 15
      expect(splitCalc.physicalDamage(20, 6), 15);
    });

    test('crit dan skill multiplier diterapkan di atas base damage rasio', () {
      const stats = CombatStats(
        maxHp: 100,
        atk: 20,
        def: 0,
        critRate: 1.0,
        critDamage: 2.0,
      );
      // multiplier 1.5 -> scaledAtk = round(20 * 1.5) = 30
      // defenderDef = 5 -> base = round(30 * 30 / (30 + 5)) = round(900 / 35) = round(25.714...) = 26
      // critDamage 2.0 -> amount = round(26 * 2.0) = 52
      final r = calc.roll(
        attacker: stats,
        defenderDef: 5,
        random: Random(1),
        multiplier: 1.5,
        damageType: SkillDamageType.physical,
      );
      expect(r.isCrit, isTrue);
      expect(r.damageType, SkillDamageType.physical);
      expect(r.amount, 52);
    });
  });

  group('Paritas Jalur Online & Offline (Damage Calculator Wiring)', () {
    test('CombatSimulation dan OfflineDungeonRunner menggunakan rumus dan hasil identik', () {
      const damageCalc = DamageCalculator();
      const heroStats = CombatStats(
        maxHp: 100,
        atk: 12,
        def: 2,
        attackSpeed: 1.0,
        critRate: 0.0,
        moveSpeed: 4.0,
        attackRange: 1.5,
      );
      const enemyDef = EnemyDefinition(
        id: 'test_mob',
        name: 'Test Mob',
        level: 1,
        detectionRange: 10,
        stats: CombatStats(
          maxHp: 100,
          atk: 6,
          def: 1,
          attackSpeed: 1.0,
          moveSpeed: 2.0,
          attackRange: 1.0,
        ),
      );

      // 1) Online jalur CombatSimulation
      final onlineSim = CombatSimulation(
        grid: NavigationGrid.open(columns: 5, rows: 5),
        pathfinder: const AStarPathfinder(),
        player: Combatant(
          id: 'player',
          team: Team.player,
          stats: heroStats,
          cell: const GridPoint(1, 1),
        ),
        damageCalculator: damageCalc,
        seed: 42,
      );
      onlineSim.spawnEnemy(enemyDef, const GridPoint(2, 1));
      onlineSim.tick();
      final onlineHits = onlineSim
          .drainEvents()
          .whereType<AttackEvent>()
          .toList();
      expect(onlineHits, isNotEmpty);
      final onlineDamage = onlineHits.first.damage;

      // 2) Offline runner
      const offlineRunner = OfflineDungeonRunner(damageCalculator: damageCalc);
      expect(offlineRunner.damageCalculator.formula, damageCalc.formula);
      expect(onlineSim.damageCalculator.formula, damageCalc.formula);

      // Hero ATK 12 vs Enemy DEF 1:
      // 12 * 12 / (12 + 1) = 144 / 13 = 11.0769... -> round = 11
      expect(onlineDamage, 11);
      expect(
        damageCalc.physicalDamage(heroStats.atk, enemyDef.stats.def),
        onlineDamage,
      );
      expect(
        offlineRunner.damageCalculator.physicalDamage(
          heroStats.atk,
          enemyDef.stats.def,
        ),
        onlineDamage,
      );
    });
  });
}
