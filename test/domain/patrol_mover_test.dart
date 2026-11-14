import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/domain/services/patrol_mover.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PatrolMover', () {
    test('bergerak ke waypoint dengan kecepatan yang benar', () {
      final mover = PatrolMover(
        grid: NavigationGrid.open(columns: 5, rows: 1),
        pathfinder: const AStarPathfinder(),
        waypoints: const [GridPoint(4, 0)],
        start: const GridPoint(0, 0),
        speedTilesPerSecond: 2,
      );
      mover.update(1.0);
      expect(mover.x, closeTo(2.5, 1e-9));
      mover.update(1.0);
      expect(mover.x, closeTo(4.5, 1e-9));
      expect(mover.y, closeTo(0.5, 1e-9));
    });

    test('berganti ke waypoint berikutnya setelah tiba', () {
      final mover = PatrolMover(
        grid: NavigationGrid.open(columns: 5, rows: 1),
        pathfinder: const AStarPathfinder(),
        waypoints: const [GridPoint(4, 0), GridPoint(0, 0)],
        start: const GridPoint(0, 0),
        speedTilesPerSecond: 2,
      );
      mover.update(2.0); // tiba di (4,0)
      expect(mover.x, closeTo(4.5, 1e-9));
      mover.update(2.0); // kembali ke (0,0)
      expect(mover.x, closeTo(0.5, 1e-9));
    });

    test('melewati waypoint yang tidak terjangkau', () {
      final mover = PatrolMover(
        grid: NavigationGrid.fromAscii(['..#.']),
        pathfinder: const AStarPathfinder(),
        waypoints: const [GridPoint(3, 0), GridPoint(1, 0)],
        start: const GridPoint(0, 0),
        speedTilesPerSecond: 1,
      );
      mover.update(1.0);
      expect(mover.x, closeTo(1.5, 1e-9));
    });

    test('tanpa waypoint, posisi tidak berubah', () {
      final mover = PatrolMover(
        grid: NavigationGrid.open(columns: 3, rows: 3),
        pathfinder: const AStarPathfinder(),
        waypoints: const [],
        start: const GridPoint(1, 1),
        speedTilesPerSecond: 3,
      );
      mover.update(1.0);
      expect(mover.x, closeTo(1.5, 1e-9));
      expect(mover.y, closeTo(1.5, 1e-9));
    });

    test('posisi tidak pernah berada di dalam dinding', () {
      final grid = NavigationGrid.fromAscii([
        '.........',
        '.###.###.',
        '.........',
        '.###.###.',
        '.........',
      ]);
      final mover = PatrolMover(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        waypoints: const [
          GridPoint(0, 0),
          GridPoint(8, 4),
          GridPoint(0, 4),
          GridPoint(8, 0),
        ],
        start: const GridPoint(0, 0),
        speedTilesPerSecond: 4,
      );
      for (var i = 0; i < 3000; i++) {
        mover.update(1 / 60);
        expect(
          grid.isWalkable(mover.x.floor(), mover.y.floor()),
          isTrue,
          reason: 'Frame $i: (${mover.x}, ${mover.y}) berada di dinding',
        );
      }
    });
  });
}
