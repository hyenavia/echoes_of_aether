import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart'
    show FontWeight, TextDirection, TextPainter, TextSpan, TextStyle;

/// Angka damage / heal melayang yang dipicu dari event simulasi combat.
/// Murni efek visual dan tidak memengaruhi state gameplay.
class FloatingTextComponent extends PositionComponent {
  FloatingTextComponent({
    required this.text,
    required Vector2 position,
    required this.color,
    bool isBold = false,
    this.fontSize = 7,
    this.duration = 0.65,
    this.riseSpeed = 16,
  }) : _fontWeight = isBold ? FontWeight.bold : FontWeight.normal,
       super(position: position, anchor: Anchor.center, priority: 10);

  final String text;
  final Color color;
  final double fontSize;
  final FontWeight _fontWeight;
  final double duration;
  final double riseSpeed;

  double _elapsed = 0;
  int _lastAlphaBucket = -1;
  TextPainter? _painter;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    position.y -= riseSpeed * dt;
    if (_elapsed >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / duration).clamp(0.0, 1.0);
    // Kuantisasi opacity ke 8 langkah agar TextPainter tidak perlu layout ulang setiap frame.
    final bucket = ((1.0 - progress) * 7).round().clamp(0, 7);
    if (bucket != _lastAlphaBucket || _painter == null) {
      _lastAlphaBucket = bucket;
      final alpha = ((bucket / 7.0) * 255).round().clamp(0, 255);
      _painter ??= TextPainter(textDirection: TextDirection.ltr);
      _painter!
        ..text = TextSpan(
          text: text,
          style: TextStyle(
            color: color.withAlpha(alpha),
            fontSize: fontSize,
            fontWeight: _fontWeight,
          ),
        )
        ..layout();
    }
    final p = _painter!;
    p.paint(canvas, Offset(-p.width / 2, -p.height / 2));
  }

  @override
  void onRemove() {
    _painter?.dispose();
    _painter = null;
    super.onRemove();
  }
}
