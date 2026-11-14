import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

enum SkillVfxType { slash, arcaneBurst, healPulse, critSpark }

/// Efek visual singkat untuk serangan fisik, skill aether/arcane, crit, dan heal.
/// Murni tampilan visual dan otomatis menghapus dirinya setelah [duration].
class SkillVfxComponent extends PositionComponent {
  SkillVfxComponent({
    required this.type,
    required Vector2 position,
    this.duration = 0.25,
    this.radius = 12,
    Color? color,
  }) : _color = color ?? _defaultColor(type),
       super(
         position: position,
         size: Vector2.all(radius * 2),
         anchor: Anchor.center,
         priority: 8,
       );

  factory SkillVfxComponent.slash({
    required Vector2 position,
    bool isSkill = false,
  }) => SkillVfxComponent(
    type: SkillVfxType.slash,
    position: position,
    duration: isSkill ? 0.26 : 0.16,
    radius: isSkill ? 14 : 10,
    color: isSkill ? const Color(0xFFE6BD68) : const Color(0xFFF4F7FA),
  );

  factory SkillVfxComponent.arcaneBurst({required Vector2 position}) =>
      SkillVfxComponent(
        type: SkillVfxType.arcaneBurst,
        position: position,
        duration: 0.30,
        radius: 16,
        color: const Color(0xFF65BFE8),
      );

  factory SkillVfxComponent.healPulse({required Vector2 position}) =>
      SkillVfxComponent(
        type: SkillVfxType.healPulse,
        position: position,
        duration: 0.42,
        radius: 15,
        color: const Color(0xFF66BB6A),
      );

  factory SkillVfxComponent.critSpark({required Vector2 position}) =>
      SkillVfxComponent(
        type: SkillVfxType.critSpark,
        position: position,
        duration: 0.24,
        radius: 13,
        color: const Color(0xFFFFD54F),
      );

  static Color _defaultColor(SkillVfxType type) {
    switch (type) {
      case SkillVfxType.slash:
        return const Color(0xFFF4F7FA);
      case SkillVfxType.arcaneBurst:
        return const Color(0xFF65BFE8);
      case SkillVfxType.healPulse:
        return const Color(0xFF66BB6A);
      case SkillVfxType.critSpark:
        return const Color(0xFFFFD54F);
    }
  }

  final SkillVfxType type;
  final double duration;
  final double radius;
  final Color _color;

  double _elapsed = 0;

  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;
  final Paint _fillPaint = Paint()..isAntiAlias = false;

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
    final alpha = ((1.0 - t) * 240).round().clamp(0, 255);
    final cx = size.x / 2;
    final cy = size.y / 2;

    switch (type) {
      case SkillVfxType.slash:
        _strokePaint
          ..color = _color.withAlpha(alpha)
          ..strokeWidth = 2.0 * (1.0 - t * 0.4);
        final sweep = math.pi * 0.65;
        final startAngle = -math.pi * 0.75 + (t * 0.35);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius * 0.75),
          startAngle,
          sweep,
          false,
          _strokePaint,
        );
        // Core highlight slash line
        _strokePaint.strokeWidth = 1.2;
        canvas.drawLine(
          Offset(cx - radius * 0.45, cy - radius * 0.45),
          Offset(cx + radius * 0.45, cy + radius * 0.45),
          _strokePaint,
        );
      case SkillVfxType.arcaneBurst:
        final currentR = radius * (0.25 + t * 0.75);
        _strokePaint
          ..color = _color.withAlpha(alpha)
          ..strokeWidth = 1.6;
        canvas.drawCircle(Offset(cx, cy), currentR, _strokePaint);

        _strokePaint
          ..color = const Color(0xFF9879CE).withAlpha(alpha)
          ..strokeWidth = 1.0;
        canvas.drawCircle(Offset(cx, cy), currentR * 0.55, _strokePaint);

        _fillPaint.color = const Color(0xFFF4F7FA).withAlpha(alpha);
        for (var i = 0; i < 4; i++) {
          final angle = (math.pi / 2) * i + (t * 0.6);
          final px = cx + math.cos(angle) * currentR;
          final py = cy + math.sin(angle) * currentR;
          canvas.drawRect(Rect.fromLTWH(px - 1, py - 1, 2, 2), _fillPaint);
        }
      case SkillVfxType.healPulse:
        final currentR = radius * (0.35 + t * 0.6);
        final rise = t * 6.0;
        _strokePaint
          ..color = _color.withAlpha(alpha)
          ..strokeWidth = 1.5;
        canvas.drawCircle(Offset(cx, cy - rise * 0.4), currentR, _strokePaint);

        // Simbol + kecil yang naik
        _fillPaint.color = const Color(0xFFA5D6A7).withAlpha(alpha);
        final plusY = cy - 4 - rise;
        canvas.drawRect(
          Rect.fromLTWH(cx - 2.5, plusY - 0.7, 5, 1.4),
          _fillPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(cx - 0.7, plusY - 2.5, 1.4, 5),
          _fillPaint,
        );
      case SkillVfxType.critSpark:
        final spread = radius * (0.3 + t * 0.7);
        _strokePaint
          ..color = _color.withAlpha(alpha)
          ..strokeWidth = 1.4;
        for (var i = 0; i < 4; i++) {
          final angle = (math.pi / 4) + (math.pi / 2) * i;
          final inner = spread * 0.25;
          canvas.drawLine(
            Offset(cx + math.cos(angle) * inner, cy + math.sin(angle) * inner),
            Offset(
              cx + math.cos(angle) * spread,
              cy + math.sin(angle) * spread,
            ),
            _strokePaint,
          );
        }
    }
  }
}
