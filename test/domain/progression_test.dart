import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/domain/services/progression_service.dart';
import 'package:flutter_test/flutter_test.dart';

const config = ProgressionConfig(
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

void main() {
  const service = ProgressionService(config);

  group('ProgressionConfig', () {
    test('kebutuhan EXP naik sesuai growth', () {
      expect(config.expToNext(1), 100);
      expect(config.expToNext(2), 200);
      expect(config.expToNext(3), 400);
    });

    test('stat level 1 sama dengan base stat', () {
      final s = config.statsAt(1);
      expect([s.maxHp, s.atk, s.def], [100, 10, 2]);
    });

    test('stat naik per level; stat lain tidak berubah', () {
      final s = config.statsAt(3);
      expect([s.maxHp, s.atk, s.def], [120, 14, 4]);
      expect(s.attackSpeed, 1.5);
      expect(s.critRate, 0.1);
      expect(s.moveSpeed, 4);
    });
  });

  group('ProgressionService', () {
    test('EXP di bawah ambang tidak menaikkan level', () {
      final r = service.grant(const PlayerProgress(), exp: 40);
      expect(r.progress.level, 1);
      expect(r.progress.currentExp, 40);
      expect(r.levelsGained, 0);
    });

    test('naik level dengan sisa EXP terbawa', () {
      final r = service.grant(const PlayerProgress(), exp: 130);
      expect(r.progress.level, 2);
      expect(r.progress.currentExp, 30);
      expect(r.levelsGained, 1);
    });

    test('bisa naik beberapa level sekaligus', () {
      final r = service.grant(const PlayerProgress(), exp: 350);
      expect(r.progress.level, 3); // 100 + 200 = 300, sisa 50
      expect(r.progress.currentExp, 50);
      expect(r.levelsGained, 2);
    });

    test('level maksimum: EXP tidak terkumpul lagi', () {
      final r = service.grant(const PlayerProgress(level: 4), exp: 100000);
      expect(r.progress.level, 5);
      expect(r.progress.currentExp, 0);
      expect(r.levelsGained, 1);
    });

    test('gold bertambah dan nilai negatif diabaikan', () {
      var p = service.grant(const PlayerProgress(), gold: 5).progress;
      p = service.grant(p, exp: -50, gold: -3).progress;
      expect(p.gold, 5);
      expect(p.currentExp, 0);
    });

    test('spendGold memvalidasi saldo dan menolak nilai negatif', () {
      const start = PlayerProgress(level: 2, currentExp: 10, gold: 50);
      expect(service.spendGold(start, -10), isNull);
      expect(service.spendGold(start, 51), isNull);
      expect(service.spendGold(start, 0), same(start));

      final spent = service.spendGold(start, 35);
      expect(spent, isNotNull);
      expect(spent!.gold, 15);
      expect(spent.level, 2);
      expect(spent.currentExp, 10);
    });
  });

  group('PlayerCharacter', () {
    test('stat mengikuti level dan expToNext 0 di level maksimum', () {
      final c = PlayerCharacter(config: config);
      expect(c.stats.maxHp, 100);
      expect(c.receiveReward(exp: 300, gold: 9), 2);
      expect(c.level, 3);
      expect(c.gold, 9);
      expect(c.stats.maxHp, 120);

      c.receiveReward(exp: 1000000);
      expect(c.isMaxLevel, isTrue);
      expect(c.expToNext, 0);
    });

    test('canAfford dan spendGold menjaga invariant gold >= 0', () {
      final c = PlayerCharacter(config: config);
      c.receiveReward(gold: 40);
      expect(c.canAfford(40), isTrue);
      expect(c.canAfford(41), isFalse);
      expect(c.canAfford(-5), isFalse);

      expect(c.spendGold(-5), isFalse);
      expect(c.spendGold(41), isFalse);
      expect(c.gold, 40);

      expect(c.spendGold(25), isTrue);
      expect(c.gold, 15);
      expect(c.spendGold(15), isTrue);
      expect(c.gold, 0);
    });
  });

  group('EnemyDefinition.tier', () {
    const baseStats = CombatStats(maxHp: 50, atk: 5, def: 1);

    test('membedakan tier normal, elite, dan boss', () {
      const normal = EnemyDefinition(
        id: 'n',
        name: 'N',
        level: 1,
        stats: baseStats,
      );
      const elite = EnemyDefinition(
        id: 'e',
        name: 'E',
        level: 3,
        stats: baseStats,
        isElite: true,
      );
      const boss = EnemyDefinition(
        id: 'b',
        name: 'B',
        level: 5,
        stats: baseStats,
        isBoss: true,
      );

      expect(normal.tier, EnemyTier.normal);
      expect(elite.tier, EnemyTier.elite);
      expect(boss.tier, EnemyTier.boss);
    });
  });

  group('Combatant.applyStats', () {
    Combatant make() => Combatant(
      id: 'p',
      team: Team.player,
      stats: config.statsAt(1),
      cell: const GridPoint(0, 0),
    );

    test('max HP naik: HP bertambah sebesar selisih, bukan penuh', () {
      final c = make()..hp = 60;
      c.applyStats(config.statsAt(4)); // max HP 130
      expect(c.stats.maxHp, 130);
      expect(c.hp, 90);
    });

    test('combatant yang sudah Downed tidak dihidupkan oleh applyStats', () {
      final c = make()..hp = 0;
      c.applyStats(config.statsAt(4));
      expect(c.hp, 0);
    });
  });

  test('simulasi mengeluarkan EnemyDefeatedEvent dengan reward', () {
    const slime = EnemyDefinition(
      id: 'slime',
      name: 'Slime',
      level: 1,
      detectionRange: 10,
      expReward: 10,
      goldReward: 3,
      stats: CombatStats(
        maxHp: 22,
        atk: 1,
        def: 1,
        attackSpeed: 1,
        moveSpeed: 2,
        attackRange: 1.0,
      ),
    );
    final player = Combatant(
      id: 'player',
      team: Team.player,
      stats: const CombatStats(
        maxHp: 500,
        atk: 11,
        def: 0,
        attackSpeed: 1,
        moveSpeed: 4,
        attackRange: 1.5,
      ),
      cell: const GridPoint(1, 1),
    );
    final sim = CombatSimulation(
      grid: NavigationGrid.open(columns: 7, rows: 3),
      pathfinder: const AStarPathfinder(),
      player: player,
      seed: 1,
    );
    final enemy = sim.spawnEnemy(slime, const GridPoint(5, 1));

    final events = <CombatEvent>[];
    for (var i = 0; i < 400 && enemy.isAlive; i++) {
      sim.tick();
      events.addAll(sim.drainEvents());
    }

    final defeated = events.whereType<EnemyDefeatedEvent>().single;
    expect(defeated.enemyId, enemy.id);
    expect(defeated.definition.expReward, 10);
    expect(defeated.definition.goldReward, 3);
  });
}
