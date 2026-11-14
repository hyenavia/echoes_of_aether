import 'dart:math' as math;

import '../entities/combatant.dart';
import '../entities/grid_point.dart';
import 'astar_pathfinder.dart';
import 'navigation_grid.dart';

/// Memilih sel serangan terdekat yang dapat dicapai dari posisi penyerang
/// tanpa harus berjalan tepat ke pusat sel target.
class AttackPositionFinder {
  const AttackPositionFinder();

  static const int _straightCost = 10;
  static const int _diagonalCost = 14;

  /// Mengembalikan jalur terpendek menuju sel walkable yang berada dalam
  /// jangkauan [attacker.stats.attackRange] terhadap posisi [target] saat ini,
  /// atau `null` jika tidak ada posisi serangan yang dapat dicapai.
  List<GridPoint>? findPath({
    required NavigationGrid grid,
    required AStarPathfinder pathfinder,
    required Combatant attacker,
    required Combatant target,
  }) {
    final start = attacker.follower.currentCell;
    if (!grid.isWalkable(start.x, start.y)) return null;

    final range = attacker.stats.attackRange;
    if (isCellInAttackRange(start, target, range)) {
      return [start];
    }

    final radius = range.ceil();
    final targetCell = target.follower.currentCell;
    final minX = math.max(0, targetCell.x - radius);
    final maxX = math.min(grid.columns - 1, targetCell.x + radius);
    final minY = math.max(0, targetCell.y - radius);
    final maxY = math.min(grid.rows - 1, targetCell.y + radius);

    List<GridPoint>? bestPath;
    int? bestCost;
    double? bestGoalDistToTarget;

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        if (!grid.isWalkable(x, y)) continue;
        final cell = GridPoint(x, y);
        if (!isCellInAttackRange(cell, target, range)) continue;

        final path = pathfinder.findPath(grid, start, cell);
        if (path == null) continue;

        final cost = _pathCost(path);
        final distToTarget = _distanceToTarget(cell, target);
        if (_isBetter(
          cost: cost,
          distToTarget: distToTarget,
          cell: cell,
          bestPath: bestPath,
          bestCost: bestCost,
          bestDistToTarget: bestGoalDistToTarget,
        )) {
          bestPath = path;
          bestCost = cost;
          bestGoalDistToTarget = distToTarget;
        }
      }
    }

    if (bestPath != null) return bestPath;

    // Fallback untuk jangkauan sangat kecil (< 0.5 tile).
    return pathfinder.findPath(grid, start, targetCell);
  }

  /// Apakah pusat [cell] berada dalam [attackRange] terhadap posisi [target].
  static bool isCellInAttackRange(
    GridPoint cell,
    Combatant target,
    double attackRange,
  ) => _distanceToTarget(cell, target) <= attackRange;

  static double _distanceToTarget(GridPoint cell, Combatant target) {
    final dx = (cell.x + 0.5) - target.x;
    final dy = (cell.y + 0.5) - target.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static int _pathCost(List<GridPoint> path) {
    var total = 0;
    for (var i = 1; i < path.length; i++) {
      final dx = (path[i].x - path[i - 1].x).abs();
      final dy = (path[i].y - path[i - 1].y).abs();
      total += (dx != 0 && dy != 0) ? _diagonalCost : _straightCost;
    }
    return total;
  }

  static bool _isBetter({
    required int cost,
    required double distToTarget,
    required GridPoint cell,
    required List<GridPoint>? bestPath,
    required int? bestCost,
    required double? bestDistToTarget,
  }) {
    if (bestPath == null || bestCost == null || bestDistToTarget == null) {
      return true;
    }
    if (cost != bestCost) return cost < bestCost;
    // Tie-break deterministik: tetap dekat target, lalu (y, x).
    if ((distToTarget - bestDistToTarget).abs() > 1e-9) {
      return distToTarget < bestDistToTarget;
    }
    final bestCell = bestPath.last;
    if (cell.y != bestCell.y) return cell.y < bestCell.y;
    return cell.x < bestCell.x;
  }
}
