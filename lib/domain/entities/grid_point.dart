/// Koordinat sel pada navigation grid.
///
/// Sengaja bukan `Vector2` milik Flame: Domain Layer tidak boleh bergantung
/// pada Flame (GDD bagian 10). Konversi ke posisi dunia dilakukan di Game Layer.
class GridPoint {
  const GridPoint(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is GridPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'GridPoint($x, $y)';
}
