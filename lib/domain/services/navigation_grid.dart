import '../entities/grid_point.dart';

/// Grid navigasi: menyimpan sel mana yang bisa dilewati.
///
/// Pathfinding membaca grid ini, bukan sprite yang dirender (GDD 12.5).
/// Grid bersifat read-only setelah dibuat. Rintangan dinamis (musuh yang
/// menghalangi, dsb.) baru dipikirkan saat dibutuhkan.
class NavigationGrid {
  NavigationGrid._(this.columns, this.rows, this._walkable);

  /// Grid kosong (semua sel bisa dilewati) dengan sel terblokir opsional.
  factory NavigationGrid.open({
    required int columns,
    required int rows,
    Iterable<GridPoint> blocked = const [],
  }) {
    if (columns <= 0 || rows <= 0) {
      throw ArgumentError('columns dan rows harus > 0 ($columns x $rows).');
    }
    final cells = List<bool>.filled(columns * rows, true);
    for (final p in blocked) {
      if (p.x >= 0 && p.x < columns && p.y >= 0 && p.y < rows) {
        cells[p.y * columns + p.x] = false;
      }
    }
    return NavigationGrid._(columns, rows, cells);
  }

  /// Membuat grid dari teks. `#` = dinding, karakter lain = lantai.
  /// Berguna untuk test dan prototipe layout ruangan.
  factory NavigationGrid.fromAscii(List<String> lines) {
    if (lines.isEmpty || lines.first.isEmpty) {
      throw ArgumentError('Grid ASCII tidak boleh kosong.');
    }
    final columns = lines.first.length;
    final cells = <bool>[];
    for (var y = 0; y < lines.length; y++) {
      if (lines[y].length != columns) {
        throw ArgumentError(
          'Baris $y memiliki panjang ${lines[y].length}, seharusnya $columns.',
        );
      }
      for (var x = 0; x < columns; x++) {
        cells.add(lines[y][x] != '#');
      }
    }
    return NavigationGrid._(columns, lines.length, cells);
  }

  final int columns;
  final int rows;
  final List<bool> _walkable;

  bool inBounds(int x, int y) => x >= 0 && x < columns && y >= 0 && y < rows;

  bool isWalkable(int x, int y) => inBounds(x, y) && _walkable[y * columns + x];

  int indexOf(int x, int y) => y * columns + x;

  GridPoint pointOf(int index) => GridPoint(index % columns, index ~/ columns);
}
