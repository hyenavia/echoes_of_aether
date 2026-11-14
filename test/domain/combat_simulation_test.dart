import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:flutter_test/flutter_test.dart';

const slime = EnemyDefinition(
  id: 'slime',
  name: 'Slime',
  level: 1,
  detectionRange: 10,
  stats: CombatStats(
    maxHp: 22,
    atk: 4,
    def: 1,
    attackSpeed: 1,
    moveSpeed: 2,
    attackRange: 1.0,
  ),
);

Combatant makePlayer({int hp = 100, double critRate = 0}) => Combatant(
  id: 'player',
  team: Team.player,
  stats: CombatStats(
    maxHp: hp,
    atk: 11,
    def: 0,
    attackSpeed: 1,
    critRate: critRate,
    moveSpeed: 4,
    attackRange: 1.5,
  ),
  cell: const GridPoint(1, 1),
);

CombatSimulation makeSim(
  NavigationGrid grid,
  Combatant player, {
  int seed = 1,
}) => CombatSimulation(
  grid: grid,
  pathfinder: const AStarPathfinder(),
  player: player,
  seed: seed,
);

void main() {
  test('player mengejar dan mengalahkan musuh, dan menerima damage', () {
    final player = makePlayer();
    final sim = makeSim(NavigationGrid.open(columns: 7, rows: 3), player);
    final enemy = sim.spawnEnemy(slime, const GridPoint(5, 1));

    for (var i = 0; i < 400 && enemy.isAlive; i++) {
      sim.tick();
    }

    expect(enemy.isAlive, isFalse);
    expect(player.isAlive, isTrue);
    expect(player.hp, lessThan(100));
    final deaths = sim.drainEvents().whereType<DeathEvent>().toList();
    expect(deaths.single.combatantId, enemy.id);
  });

  test('tanpa musuh, player diam di tempat', () {
    final player = makePlayer();
    final sim = makeSim(NavigationGrid.open(columns: 5, rows: 5), player);
    for (var i = 0; i < 50; i++) {
      sim.tick();
    }
    expect(player.x, closeTo(1.5, 1e-9));
    expect(player.y, closeTo(1.5, 1e-9));
  });

  test('mengalahkan beberapa musuh berurutan', () {
    final player = makePlayer(hp: 500);
    final sim = makeSim(NavigationGrid.open(columns: 9, rows: 5), player);
    sim.spawnEnemy(slime, const GridPoint(7, 1));
    sim.spawnEnemy(slime, const GridPoint(7, 3));
    sim.spawnEnemy(slime, const GridPoint(4, 4));

    for (var i = 0; i < 1500 && sim.aliveEnemies.isNotEmpty; i++) {
      sim.tick();
    }
    expect(sim.aliveEnemies, isEmpty);
    expect(player.isAlive, isTrue);
  });

  test('tidak ada yang menembus dinding saat mengejar', () {
    final grid = NavigationGrid.fromAscii(['.....', '.###.', '.....']);
    final player = Combatant(
      id: 'player',
      team: Team.player,
      stats: makePlayer().stats,
      cell: const GridPoint(0, 1),
    );
    final sim = makeSim(grid, player);
    final enemy = sim.spawnEnemy(slime, const GridPoint(4, 1));

    for (var i = 0; i < 600; i++) {
      sim.tick();
      expect(
        grid.isWalkable(player.x.floor(), player.y.floor()),
        isTrue,
        reason: 'player di dinding pada tick $i',
      );
      expect(
        grid.isWalkable(enemy.x.floor(), enemy.y.floor()),
        isTrue,
        reason: 'musuh di dinding pada tick $i',
      );
    }
  });

  test('seed sama menghasilkan rangkaian event identik', () {
    List<String> run(int seed) {
      final player = makePlayer(critRate: 0.5);
      final sim = makeSim(
        NavigationGrid.open(columns: 7, rows: 3),
        player,
        seed: seed,
      );
      sim.spawnEnemy(slime, const GridPoint(5, 1));
      sim.spawnEnemy(slime, const GridPoint(5, 2));
      final log = <String>[];
      for (var i = 0; i < 300; i++) {
        sim.tick();
        for (final e in sim.drainEvents()) {
          log.add(switch (e) {
            final AttackEvent a =>
              '${a.tick}:${a.attackerId}>${a.targetId}:${a.damage}:${a.isCrit}',
            final DeathEvent d => '${d.tick}:dead:${d.combatantId}',
            final CombatEvent other => '${other.tick}:${other.runtimeType}',
          });
        }
      }
      return log;
    }

    expect(run(7), run(7));
    expect(run(7), isNotEmpty);
  });

  group('Monster Return State', () {
    test('monster kembali ke spawnCell saat target keluar dari leashRange', () {
      const stalker = EnemyDefinition(
        id: 'stalker',
        name: 'Stalker',
        level: 1,
        detectionRange: 6,
        leashRange: 5,
        stats: CombatStats(
          maxHp: 100,
          atk: 2,
          def: 0,
          attackSpeed: 1,
          moveSpeed: 4,
          attackRange: 1.0,
        ),
      );
      final player = makePlayer(hp: 500); // di (1,1)
      final sim = makeSim(NavigationGrid.open(columns: 15, rows: 3), player);
      final enemy = sim.spawnEnemy(stalker, const GridPoint(5, 1));
      expect(enemy.spawnCell, const GridPoint(5, 1));

      // Gerakkan player lebih dekat agar terdeteksi, lalu jauhkan keluar leash.
      player.follower.walkToCenterOf(const GridPoint(4, 1));
      for (var i = 0; i < 20; i++) {
        player.follower.advance(0.2);
        sim.tick();
      }
      expect(enemy.aggroed, isTrue);
      expect(enemy.x, lessThan(5.5)); // sudah bergeser dari spawn

      // Pindahkan player jauh di luar leashRange (14, 1).
      player.follower.setPath([const GridPoint(14, 1)]);
      player.follower.advance(20);
      sim.tick();
      expect(enemy.aiState, MonsterAiState.returning);
      expect(enemy.aggroed, isFalse);
      expect(enemy.targetId, isNull);

      for (
        var i = 0;
        i < 100 && enemy.aiState == MonsterAiState.returning;
        i++
      ) {
        sim.tick();
      }
      expect(enemy.aiState, MonsterAiState.idle);
      expect(enemy.isAtSpawn, isTrue);
    });

    test('monster berhenti menyerang dan kembali ke spawn saat player Downed', () {
      const chaser = EnemyDefinition(
        id: 'chaser',
        name: 'Chaser',
        level: 1,
        detectionRange: 10,
        stats: CombatStats(
          maxHp: 1000,
          atk: 50,
          def: 0,
          attackSpeed: 1,
          moveSpeed: 4,
          attackRange: 1.0,
        ),
      );
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: const CombatStats(
          maxHp: 20,
          atk: 1,
          def: 0,
          attackSpeed: 1,
          moveSpeed: 0.1,
          attackRange: 1.0,
        ),
        cell: const GridPoint(1, 1),
      );
      final sim = makeSim(NavigationGrid.open(columns: 8, rows: 3), player);
      final enemy = sim.spawnEnemy(chaser, const GridPoint(6, 1));

      // Jalankan sampai player Downed setelah monster mengejar ke dekat player.
      for (var i = 0; i < 100 && sim.playerStatus.name == 'alive'; i++) {
        sim.tick();
      }
      expect(sim.playerStatus.name, 'downed');
      expect(enemy.aggroed, isFalse);
      expect(enemy.targetId, isNull);
      expect(enemy.aiState, MonsterAiState.returning);

      // Selama Downed (60 tick), monster kembali ke spawn tanpa menyerang.
      for (var i = 0; i < 50; i++) {
        sim.tick();
      }
      expect(enemy.isAtSpawn, isTrue);
      expect(enemy.aiState, MonsterAiState.idle);
    });
  });
}
