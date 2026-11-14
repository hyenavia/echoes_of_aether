import 'dart:ui';

import 'package:flame/components.dart';

/// Tirai transisi singkat antar-room agar perpindahan ruangan terasa mulus.
/// Murni visual dan otomatis terhapus setelah animasi selesai.
class RoomTransitionCurtain extends PositionComponent {
  RoomTransitionCurtain({
    required double worldWidth,
    required double worldHeight,
    this.duration = 0.28,
    this.fadeOut = false,
  }) : super(
         position: Vector2(-64, -64),
         size: Vector2(worldWidth + 128, worldHeight + 128),
         priority: 50,
       );

  final double duration;
  final bool fadeOut;

  double _elapsed = 0;
  final Paint _paint = Paint();

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / duration).clamp(0.0, 1.0);
    final opacity = fadeOut ? (t * 0.85) : ((1.0 - t) * 0.85);
    final alpha = (opacity * 255).round().clamp(0, 255);
    _paint.color = Color.fromARGB(alpha, 11, 11, 18);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _paint);
  }
}
