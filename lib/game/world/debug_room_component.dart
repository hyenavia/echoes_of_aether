import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../domain/entities/grid_point.dart';
import '../../domain/services/navigation_grid.dart';
import '../visuals/pixel_sprite_atlas.dart';

/// Visual tilemap room berbasis [NavigationGrid] dan [PixelSpriteAtlas]
/// Forgotten Forest dengan scaling nearest-neighbor (`FilterQuality.none`).
class DebugRoomComponent extends PositionComponent {
  DebugRoomComponent({
    required this.grid,
    required this.tileSize,
    this.markers = const [],
    this.exitUnlocked = false,
    PixelSpriteAtlas? atlas,
  }) : _atlas = atlas ?? PixelSpriteAtlas.instance,
       super(size: Vector2(grid.columns * tileSize, grid.rows * tileSize));

  final NavigationGrid grid;
  final double tileSize;
  final PixelSpriteAtlas _atlas;

  /// Titik yang diberi penanda (mis. posisi exit).
  final List<GridPoint> markers;
  bool exitUnlocked;

  double _animTime = 0;
  Picture? _staticRoomPicture;

  final Paint _wallShadow = Paint()..color = const Color(0x44000000);
  final Paint _portalAura = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  @override
  void update(double dt) {
    super.update(dt);
    _animTime += dt;
  }

  String _floorKey(int x, int y) {
    final hash = ((x * 73856093) ^ (y * 19349663)).abs() % 11;
    if (hash < 2) return 'floor2';
    if (hash < 5) return 'floor1';
    return 'floor0';
  }

  Picture _buildStaticRoomPicture() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = PixelSpriteAtlas.pixelPaint;
    const src = Rect.fromLTWH(0, 0, 16, 16);

    for (var y = 0; y < grid.rows; y++) {
      for (var x = 0; x < grid.columns; x++) {
        final key = grid.isWalkable(x, y) ? _floorKey(x, y) : 'wall_tree';
        final sprite = _atlas.tileSprite(key);
        final dst = Rect.fromLTWH(
          x * tileSize,
          y * tileSize,
          tileSize,
          tileSize,
        );
        canvas.drawImageRect(sprite, src, dst, paint);

        // Drop shadow halus di sisi selatan dinding untuk kedalaman top-down.
        if (grid.isWalkable(x, y) && y > 0 && !grid.isWalkable(x, y - 1)) {
          canvas.drawRect(
            Rect.fromLTWH(
              x * tileSize,
              y * tileSize,
              tileSize,
              tileSize * 0.16,
            ),
            _wallShadow,
          );
        }
      }
    }
    return recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    final staticPic = _staticRoomPicture ??= _buildStaticRoomPicture();
    canvas.drawPicture(staticPic);

    final paint = PixelSpriteAtlas.pixelPaint;
    const src = Rect.fromLTWH(0, 0, 16, 16);
    final exitKey = exitUnlocked ? 'exit_unlocked' : 'exit_locked';
    final exitSprite = _atlas.tileSprite(exitKey);
    final pulse = (math.sin(_animTime * 4.0) + 1) * 0.5;

    for (final m in markers) {
      final dst = Rect.fromLTWH(
        m.x * tileSize,
        m.y * tileSize,
        tileSize,
        tileSize,
      );
      canvas.drawImageRect(exitSprite, src, dst, paint);

      _portalAura.color = exitUnlocked
          ? Color.fromARGB((130 + (pulse * 110)).round(), 101, 191, 232)
          : Color.fromARGB(110, 230, 189, 104);
      canvas.drawCircle(
        Offset((m.x + 0.5) * tileSize, (m.y + 0.5) * tileSize),
        tileSize * (0.42 + (exitUnlocked ? pulse * 0.08 : 0)),
        _portalAura,
      );
    }
  }

  @override
  void onRemove() {
    _staticRoomPicture?.dispose();
    _staticRoomPicture = null;
    super.onRemove();
  }
}
