import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/attack_position_finder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pathfinder = AStarPathfinder();
  const finder = AttackPositionFinder();

  Combatant makeUnit({
    required String id,
    required Team team,
    required GridPoint cell,
    double attackRange = 1.5,
  }) => Combatant(
    id: id,
    team: team,
    stats: CombatStats(
      maxHp: 100,
      atk: 15,
      def: 0,
      attackSpeed: 1,
      moveSpeed: 4,
      attackRange: attackRange,
    ),
    cell: cell,
  );

  group('AttackPositionFinder', () {
    test('penyerang jarak jauh memilih sel terdekat dalam attackRange', () {
      final grid = NavigationGrid.open(columns: 12, rows: 3);
      final attacker = makeUnit(
        id: 'player',
        team: Team.player,
        cell: const GridPoint(1, 1),
        attackRange: 3.0,
      );
      final target = makeUnit(
        id: 'enemy',
        team: Team.enemy,
        cell: const GridPoint(9, 1),
      );

      final path = finder.findPath(
        grid: grid,
        pathfinder: pathfinder,
        attacker: attacker,
        target: target,
      );

      expect(path, isNotNull);
      expect(path!.last, const GridPoint(6, 1));
    });

    test('menghindari sel dinding dan memilih posisi serang tercepat', () {
      final grid = NavigationGrid.fromAscii([
        '##########',
        '#....#...#',
        '#....#...#',
        '#........#',
        '##########',
      ]);
      final attacker = makeUnit(
        id: 'player',
        team: Team.player,
        cell: const GridPoint(1, 1),
        attackRange: 2.0,
      );
      final target = makeUnit(
        id: 'enemy',
        team: Team.enemy,
        cell: const GridPoint(7, 1),
      );

      final path = finder.findPath(
        grid: grid,
        pathfinder: pathfinder,
        attacker: attacker,
        target: target,
      );

      expect(path, isNotNull);
      for (final point in path!) {
        expect(grid.isWalkable(point.x, point.y), isTrue);
      }
      expect(
        AttackPositionFinder.isCellInAttackRange(path.last, target, 2.0),
        isTrue,
      );
    });

    test('mengembalikan null jika seluruh sel serangan terisolasi dinding', () {
      final grid = NavigationGrid.fromAscii([
        '#######',
        '#..#..#',
        '#..#..#',
        '#######',
      ]);
      final attacker = makeUnit(
        id: 'player',
        team: Team.player,
        cell: const GridPoint(1, 1),
        attackRange: 1.5,
      );
      final target = makeUnit(
        id: 'enemy',
        team: Team.enemy,
        cell: const GridPoint(5, 2),
      );

      final path = finder.findPath(
        grid: grid,
        pathfinder: pathfinder,
        attacker: attacker,
        target: target,
      );

      expect(path, isNull);
    });

    test('CombatSimulation: unit ranged menyerang di batas jangkauan tanpa menembus dinding', () {
      final grid = NavigationGrid.fromAscii([
        '###########',
        '#....#....#',
        '#.........#',
        '###########',
      ]);
      final player = makeUnit(
        id: 'player',
        team: Team.player,
        cell: const GridPoint(1, 1),
        attackRange: 3.0,
      );
      final sim = CombatSimulation(
        grid: grid,
        pathfinder: pathfinder,
        player: player,
        seed: 1,
      );
      const dummyDef = EnemyDefinition(
        id: 'dummy',
        name: 'Dummy',
        level: 1,
        detectionRange: 0,
        stats: CombatStats(maxHp: 50, atk: 1, def: 0),
      );
      final enemy = sim.spawnEnemy(dummyDef, const GridPoint(9, 1));

      var attacked = false;
      for (var i = 0; i < 60 && !attacked; i++) {
        sim.tick();
        final cell = player.follower.currentCell;
        expect(grid.isWalkable(cell.x, cell.y), isTrue);
        if (sim.drainEvents().whereType<AttackEvent>().isNotEmpty) {
          attacked = true;
        }
      }

      expect(attacked, isTrue);
      expect(enemy.hp, lessThan(50));
      // Player berhenti di jarak tembak (~2-3 tile dari target), tidak menempel.
      expect(player.distanceTo(enemy), greaterThan(1.5));
      expect(player.distanceTo(enemy), lessThanOrEqualTo(3.0));
    });
  });
}
