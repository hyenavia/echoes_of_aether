import '../entities/grid_point.dart';
import 'navigation_grid.dart';

/// Pathfinding A* pada [NavigationGrid] (GDD 12.5).
///
/// - Hasil deterministik: urutan arah dan tie-break tetap, tanpa randomness.
/// - Biaya bilangan bulat (lurus = 10, diagonal = 14) untuk menghindari
///   masalah floating point.
/// - Gerakan diagonal tidak boleh "memotong sudut" dinding.
class AStarPathfinder {
  const AStarPathfinder({this.allowDiagonal = true});

  final bool allowDiagonal;

  static const int _straightCost = 10;
  static const int _diagonalCost = 14;
  static const int _unreached = 1 << 30;

  // Urutan tetap: N, E, S, W, lalu diagonal NE, SE, SW, NW.
  static const List<(int, int)> _directions = [
    (0, -1),
    (1, 0),
    (0, 1),
    (-1, 0),
    (1, -1),
    (1, 1),
    (-1, 1),
    (-1, -1),
  ];

  /// Mengembalikan jalur dari [start] ke [goal] (keduanya disertakan),
  /// atau `null` jika tidak ada jalur / titik awal atau tujuan tidak valid.
  List<GridPoint>? findPath(
    NavigationGrid grid,
    GridPoint start,
    GridPoint goal,
  ) {
    if (!grid.isWalkable(start.x, start.y) ||
        !grid.isWalkable(goal.x, goal.y)) {
      return null;
    }
    if (start == goal) return [start];

    final cellCount = grid.columns * grid.rows;
    final gScore = List<int>.filled(cellCount, _unreached);
    final parent = List<int>.filled(cellCount, -1);
    final closed = List<bool>.filled(cellCount, false);
    final open = _MinHeap();

    final startIndex = grid.indexOf(start.x, start.y);
    final goalIndex = grid.indexOf(goal.x, goal.y);

    gScore[startIndex] = 0;
    final startH = _heuristic(start.x, start.y, goal);
    open.push(_Entry(startH, startH, startIndex));

    final directionCount = allowDiagonal ? 8 : 4;

    while (open.isNotEmpty) {
      final current = open.pop();
      if (closed[current.index]) continue; // entri usang
      if (current.index == goalIndex) {
        return _reconstruct(grid, parent, goalIndex);
      }
      closed[current.index] = true;

      final cx = current.index % grid.columns;
      final cy = current.index ~/ grid.columns;

      for (var i = 0; i < directionCount; i++) {
        final (dx, dy) = _directions[i];
        final nx = cx + dx;
        final ny = cy + dy;
        if (!grid.isWalkable(nx, ny)) continue;

        final isDiagonal = dx != 0 && dy != 0;
        if (isDiagonal &&
            (!grid.isWalkable(cx + dx, cy) || !grid.isWalkable(cx, cy + dy))) {
          continue; // jangan memotong sudut dinding
        }

        final neighborIndex = grid.indexOf(nx, ny);
        if (closed[neighborIndex]) continue;

        final tentative =
            gScore[current.index] +
            (isDiagonal ? _diagonalCost : _straightCost);
        if (tentative < gScore[neighborIndex]) {
          gScore[neighborIndex] = tentative;
          parent[neighborIndex] = current.index;
          final h = _heuristic(nx, ny, goal);
          open.push(_Entry(tentative + h, h, neighborIndex));
        }
      }
    }
    return null;
  }

  int _heuristic(int x, int y, GridPoint goal) {
    final dx = (x - goal.x).abs();
    final dy = (y - goal.y).abs();
    if (!allowDiagonal) return _straightCost * (dx + dy); // Manhattan
    final diagonalSteps = dx < dy ? dx : dy;
    // Octile distance.
    return _straightCost * (dx + dy) -
        (2 * _straightCost - _diagonalCost) * diagonalSteps;
  }

  List<GridPoint> _reconstruct(
    NavigationGrid grid,
    List<int> parent,
    int goalIndex,
  ) {
    final path = <GridPoint>[];
    var index = goalIndex;
    while (index != -1) {
      path.add(grid.pointOf(index));
      index = parent[index];
    }
    return path.reversed.toList(growable: false);
  }
}

class _Entry {
  const _Entry(this.f, this.h, this.index);

  final int f;
  final int h;
  final int index;

  /// Urut berdasarkan f, lalu h (lebih dekat ke tujuan dulu), lalu index.
  /// Tie-break terakhir membuat hasil selalu deterministik.
  bool isBefore(_Entry other) {
    if (f != other.f) return f < other.f;
    if (h != other.h) return h < other.h;
    return index < other.index;
  }
}

/// Binary min-heap sederhana agar tidak perlu dependency tambahan
/// (aturan #8 GDD: hindari dependency yang tidak perlu).
class _MinHeap {
  final List<_Entry> _items = [];

  bool get isNotEmpty => _items.isNotEmpty;

  void push(_Entry entry) {
    _items.add(entry);
    var i = _items.length - 1;
    while (i > 0) {
      final p = (i - 1) ~/ 2;
      if (!_items[i].isBefore(_items[p])) break;
      _swap(i, p);
      i = p;
    }
  }

  _Entry pop() {
    final top = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1;
        final r = l + 1;
        var smallest = i;
        if (l < _items.length && _items[l].isBefore(_items[smallest])) {
          smallest = l;
        }
        if (r < _items.length && _items[r].isBefore(_items[smallest])) {
          smallest = r;
        }
        if (smallest == i) break;
        _swap(i, smallest);
        i = smallest;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final t = _items[a];
    _items[a] = _items[b];
    _items[b] = t;
  }
}
