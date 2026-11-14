import '../../domain/entities/grid_point.dart';

/// Ruangan uji. Akan digantikan definisi room dari JSON (dungeons.json)
/// pada Milestone 5. `#` = dinding, `.` = lantai.
class TestRoom {
  TestRoom._();

  static const List<String> layout = [
    '####################',
    '#..................#',
    '#..####.....####...#',
    '#..#..........#....#',
    '#..#...####...#....#',
    '#......#..#........#',
    '#..#...#..#...#....#',
    '#..#...##.#...#....#',
    '#..####....####....#',
    '#..................#',
    '####################',
  ];

  static const GridPoint playerStart = GridPoint(1, 1);

  /// Waypoint patroli (dipakai PatrolMover dari Milestone 2).
  static const List<GridPoint> waypoints = [
    GridPoint(1, 1),
    GridPoint(18, 1),
    GridPoint(18, 9),
    GridPoint(9, 5),
    GridPoint(1, 9),
  ];

  /// Gelombang musuh uji: (id monster di monsters.json, sel spawn).
  static const List<(String, GridPoint)> enemySpawns = [
    ('forest_slime', GridPoint(17, 2)),
    ('forest_slime', GridPoint(17, 8)),
    ('forest_goblin', GridPoint(10, 9)),
    ('forest_slime', GridPoint(12, 1)),
  ];
}
