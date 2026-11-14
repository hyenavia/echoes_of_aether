import '../entities/grid_point.dart';
import 'astar_pathfinder.dart';
import 'navigation_grid.dart';
import 'path_follower.dart';

/// Pergerakan otomatis sementara untuk Milestone 2: berpatroli antar waypoint
/// menggunakan A*. Di Milestone 3 waypoint digantikan oleh target musuh dari
/// targeting system, sedangkan pathfinding dan path follower tetap dipakai.
class PatrolMover {
  PatrolMover({
    required this.grid,
    required this.pathfinder,
    required List<GridPoint> waypoints,
    required GridPoint start,
    required this.speedTilesPerSecond,
  }) : waypoints = List.unmodifiable(waypoints),
       _follower = PathFollower(start);

  final NavigationGrid grid;
  final AStarPathfinder pathfinder;
  final List<GridPoint> waypoints;
  final double speedTilesPerSecond;

  final PathFollower _follower;
  int _nextWaypoint = 0;

  /// Posisi dalam satuan tile (pusat sel = cx + 0.5).
  double get x => _follower.x;
  double get y => _follower.y;

  void update(double dt) {
    if (dt <= 0) return;
    if (!_follower.isMoving) _planNext();
    _follower.advance(speedTilesPerSecond * dt);
  }

  void _planNext() {
    // Coba setiap waypoint paling banyak satu kali; lewati yang tidak terjangkau.
    for (var i = 0; i < waypoints.length; i++) {
      final target = waypoints[_nextWaypoint];
      _nextWaypoint = (_nextWaypoint + 1) % waypoints.length;
      final from = _follower.currentCell;
      if (target == from) continue;
      final path = pathfinder.findPath(grid, from, target);
      if (path != null) {
        _follower.setPath(path);
        return;
      }
    }
  }
}
