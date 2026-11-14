import 'dart:math' as math;

import '../entities/grid_point.dart';

/// Menggerakkan posisi di sepanjang jalur sel-ke-sel.
///
/// Posisi dinyatakan dalam satuan tile; pusat sel (cx, cy) berada di
/// (cx + 0.5, cy + 0.5). Konversi ke piksel dilakukan di Game Layer.
class PathFollower {
  PathFollower(GridPoint start) : _x = start.x + 0.5, _y = start.y + 0.5;

  double _x;
  double _y;
  List<GridPoint> _path = const [];
  int _next = 0;

  double get x => _x;
  double get y => _y;

  bool get isMoving => _next < _path.length;

  /// Sel yang sedang ditempati.
  GridPoint get currentCell => GridPoint(_x.floor(), _y.floor());

  void setPath(List<GridPoint> path) {
    _path = path;
    _next = 0;
    // Jalur dari A* diawali sel saat ini; lewati agar tidak mundur ke tengah sel.
    if (path.isNotEmpty && path.first == currentCell) _next = 1;
  }

  /// Menempatkan ulang posisi ke pusat [cell] dan menghapus jalur sebelumnya.
  void resetTo(GridPoint cell) {
    _x = cell.x + 0.5;
    _y = cell.y + 0.5;
    _path = const [];
    _next = 0;
  }

  /// Berjalan menuju pusat [cell] secara langsung. Dipakai untuk jarak sangat
  /// dekat (misalnya berada di sel yang sama dengan target).
  void walkToCenterOf(GridPoint cell) {
    _path = [cell];
    _next = 0;
  }

  /// Maju sejauh [distance] tile di sepanjang jalur.
  void advance(double distance) {
    var remaining = distance;
    while (remaining > 0 && isMoving) {
      final target = _path[_next];
      final tx = target.x + 0.5;
      final ty = target.y + 0.5;
      final dx = tx - _x;
      final dy = ty - _y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d <= remaining) {
        _x = tx;
        _y = ty;
        remaining -= d;
        _next++;
      } else {
        final ratio = remaining / d;
        _x += dx * ratio;
        _y += dy * ratio;
        remaining = 0;
      }
    }
  }
}
