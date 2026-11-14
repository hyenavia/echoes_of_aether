import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:flutter_test/flutter_test.dart';

/// Memastikan jalur valid: dimulai di start, berakhir di goal, setiap langkah
/// bersebelahan, dan tidak melewati dinding.
void expectValidPath(
  NavigationGrid grid,
  List<GridPoint> path,
  GridPoint start,
  GridPoint goal,
) {
  expect(path.first, start);
  expect(path.last, goal);
  for (final p in path) {
    expect(grid.isWalkable(p.x, p.y), isTrue, reason: '$p adalah dinding');
  }
  for (var i = 1; i < path.length; i++) {
    final dx = (path[i].x - path[i - 1].x).abs();
    final dy = (path[i].y - path[i - 1].y).abs();
    expect(
      dx <= 1 && dy <= 1 && (dx + dy) > 0,
      isTrue,
      reason: 'Langkah ${path[i - 1]} -> ${path[i]} tidak bersebelahan',
    );
  }
}

void main() {
  const pathfinder = AStarPathfinder();

  group('AStarPathfinder', () {
    test('start sama dengan goal mengembalikan satu titik', () {
      final grid = NavigationGrid.open(columns: 5, rows: 5);
      const p = GridPoint(2, 2);
      expect(pathfinder.findPath(grid, p, p), [p]);
    });

    test('jalur lurus pada grid kosong (tanpa diagonal)', () {
      final grid = NavigationGrid.open(columns: 5, rows: 1);
      final path = const AStarPathfinder(allowDiagonal: false)
          .findPath(grid, const GridPoint(0, 0), const GridPoint(4, 0))!;
      expect(path.length, 5);
    });

    test('diagonal menghasilkan jalur terpendek pada grid kosong', () {
      final grid = NavigationGrid.open(columns: 5, rows: 5);
      const start = GridPoint(0, 0);
      const goal = GridPoint(4, 4);
      final diagonal = pathfinder.findPath(grid, start, goal)!;
      final cardinal = const AStarPathfinder(allowDiagonal: false)
          .findPath(grid, start, goal)!;
      expect(diagonal.length, 5); // 4 langkah diagonal
      expect(cardinal.length, 9); // 8 langkah lurus
    });

    test('berputar mengelilingi dinding', () {
      final grid = NavigationGrid.fromAscii([
        '..#..',
        '..#..',
        '..#..',
        '.....',
      ]);
      const start = GridPoint(0, 0);
      const goal = GridPoint(4, 0);
      final path = pathfinder.findPath(grid, start, goal)!;
      expectValidPath(grid, path, start, goal);
    });

    test('mengembalikan null jika tujuan tidak terjangkau', () {
      final grid = NavigationGrid.fromAscii(['..#..', '..#..', '..#..']);
      expect(
        pathfinder.findPath(grid, const GridPoint(0, 0), const GridPoint(4, 0)),
        isNull,
      );
    });

    test('mengembalikan null jika start atau goal adalah dinding', () {
      final grid = NavigationGrid.fromAscii(['.#.']);
      expect(
        pathfinder.findPath(grid, const GridPoint(1, 0), const GridPoint(2, 0)),
        isNull,
      );
      expect(
        pathfinder.findPath(grid, const GridPoint(0, 0), const GridPoint(1, 0)),
        isNull,
      );
    });

    test('mengembalikan null jika titik berada di luar grid', () {
      final grid = NavigationGrid.open(columns: 3, rows: 3);
      expect(
        pathfinder.findPath(grid, const GridPoint(0, 0), const GridPoint(9, 9)),
        isNull,
      );
    });

    test('diagonal tidak boleh memotong sudut dinding', () {
      final grid = NavigationGrid.fromAscii(['.#', '#.']);
      expect(
        pathfinder.findPath(grid, const GridPoint(0, 0), const GridPoint(1, 1)),
        isNull,
      );
    });

    test('hasil deterministik untuk input yang sama', () {
      final grid = NavigationGrid.fromAscii([
        '.......',
        '.###...',
        '.......',
        '...###.',
        '.......',
      ]);
      const start = GridPoint(0, 0);
      const goal = GridPoint(6, 4);
      final a = pathfinder.findPath(grid, start, goal)!;
      final b = pathfinder.findPath(grid, start, goal)!;
      expect(a, b);
      expectValidPath(grid, a, start, goal);
    });
  });

  group('NavigationGrid', () {
    test('fromAscii membaca dinding dan lantai', () {
      final grid = NavigationGrid.fromAscii(['.#', '..']);
      expect(grid.columns, 2);
      expect(grid.rows, 2);
      expect(grid.isWalkable(0, 0), isTrue);
      expect(grid.isWalkable(1, 0), isFalse);
      expect(grid.isWalkable(5, 5), isFalse); // di luar grid
    });

    test('fromAscii menolak baris dengan panjang berbeda', () {
      expect(() => NavigationGrid.fromAscii(['..', '.']), throwsArgumentError);
    });
  });
}
