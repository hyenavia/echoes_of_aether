import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

enum SkillVfxType {
  slash,
  heavySlash,
  arcaneBurst,
  meteorFall,
  arrowShot,
  lifeSiphon,
  groundSlam,
  healPulse,
  critSpark,
  defeatBurst,
}

/// Efek visual singkat untuk serangan fisik, skill aether/arcane, crit, heal, dan death motes.
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

  factory SkillVfxComponent.heavySlash({required Vector2 position}) =>
      SkillVfxComponent(
        type: SkillVfxType.heavySlash,
        position: position,
        duration: 0.28,
        radius: 16,
        color: const Color(0xFFE6BD68),
      );

  factory SkillVfxComponent.arcaneBurst({required Vector2 position}) =>
      SkillVfxComponent(
        type: SkillVfxType.arcaneBurst,
        position: position,
        duration: 0.30,
        radius: 16,
        color: const Color(0xFF65BFE8),
      );

  factory SkillVfxComponent.meteorFall({required Vector2 position}) =>
      SkillVfxComponent(
        type: SkillVfxType.meteorFall,
        position: position,
        duration: 0.38,
        radius: 20,
        color: const Color(0xFFE6683B),
      );

  factory SkillVfxComponent.arrowShot({
    required Vector2 position,
    double angle = 0,
  }) => SkillVfxComponent(
    type: SkillVfxType.arrowShot,
    position: position,
    duration: 0.20,
    radius: 14,
    color: const Color(0xFF81C784),
  );

  factory SkillVfxComponent.lifeSiphon({required Vector2 position}) =>
      SkillVfxComponent(
        type: SkillVfxType.lifeSiphon,
        position: position,
        duration: 0.35,
        radius: 16,
        color: const Color(0xFFA88AD5),
      );

  factory SkillVfxComponent.groundSlam({required Vector2 position}) =>
      SkillVfxComponent(
        type: SkillVfxType.groundSlam,
        position: position,
        duration: 0.35,
        radius: 18,
        color: const Color(0xFFD4AF37),
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
        radius: 14,
        color: const Color(0xFFFFD54F),
      );

  factory SkillVfxComponent.defeatBurst({
    required Vector2 position,
    bool isBoss = false,
    bool isElite = false,
  }) => SkillVfxComponent(
    type: SkillVfxType.defeatBurst,
    position: position,
    duration: isBoss ? 0.55 : (isElite ? 0.45 : 0.35),
    radius: isBoss ? 22 : (isElite ? 16 : 12),
    color: isBoss
        ? const Color(0xFFA88AD5)
        : (isElite ? const Color(0xFFE6BD68) : const Color(0xFF69BFE5)),
  );

  static Color _defaultColor(SkillVfxType type) {
    switch (type) {
      case SkillVfxType.slash:
        return const Color(0xFFF4F7FA);
      case SkillVfxType.heavySlash:
        return const Color(0xFFE6BD68);
      case SkillVfxType.arcaneBurst:
        return const Color(0xFF65BFE8);
      case SkillVfxType.meteorFall:
        return const Color(0xFFE6683B);
      case SkillVfxType.arrowShot:
        return const Color(0xFF81C784);
      case SkillVfxType.lifeSiphon:
        return const Color(0xFFA88AD5);
      case SkillVfxType.groundSlam:
        return const Color(0xFFD4AF37);
      case SkillVfxType.healPulse:
        return const Color(0xFF66BB6A);
      case SkillVfxType.critSpark:
        return const Color(0xFFFFD54F);
      case SkillVfxType.defeatBurst:
        return const Color(0xFF69BFE5);
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

      case SkillVfxType.heavySlash:
        // Busur tebasan tebal emas dengan garis silang impact
        final sweep = math.pi * 0.85;
        final startAngle = -math.pi * 0.85 + (t * 0.4);
        _strokePaint
          ..color = _color.withAlpha(alpha)
          ..strokeWidth = 3.2 * (1.0 - t * 0.5);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius * 0.8),
          startAngle,
          sweep,
          false,
          _strokePaint,
        );
        // Highlight putih di tengah busur
        _strokePaint
          ..color = const Color(0xFFFFFFFF).withAlpha(alpha)
          ..strokeWidth = 1.4;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius * 0.8),
          startAngle + sweep * 0.2,
          sweep * 0.6,
          false,
          _strokePaint,
        );
        // Impact sparks
        _fillPaint.color = const Color(0xFFFFD54F).withAlpha(alpha);
        for (var i = 0; i < 4; i++) {
          final sparkAngle = (math.pi / 2) * i + (t * 0.5);
          final dist = radius * (0.3 + t * 0.6);
          final px = cx + math.cos(sparkAngle) * dist;
          final py = cy + math.sin(sparkAngle) * dist;
          canvas.drawRect(Rect.fromLTWH(px - 1, py - 1, 2, 2), _fillPaint);
        }

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

      case SkillVfxType.meteorFall:
        // Cincin ledakan magma melebar dengan inti membara dan percikan puing
        final currentR = radius * (0.2 + t * 0.8);
        _strokePaint
          ..color = const Color(0xFFD95D5D).withAlpha(alpha)
          ..strokeWidth = 2.4 * (1.0 - t * 0.4);
        canvas.drawCircle(Offset(cx, cy), currentR, _strokePaint);

        _strokePaint
          ..color = const Color(0xFFE6683B).withAlpha(alpha)
          ..strokeWidth = 1.6;
        canvas.drawCircle(Offset(cx, cy), currentR * 0.65, _strokePaint);

        // Inti putih/kuning di awal ledakan
        if (t < 0.5) {
          final coreAlpha = (((0.5 - t) / 0.5) * 255).round().clamp(0, 255);
          _fillPaint.color = const Color(0xFFFFF275).withAlpha(coreAlpha);
          canvas.drawCircle(
            Offset(cx, cy),
            radius * 0.3 * (1.0 - t),
            _fillPaint,
          );
        }

        // Puing magma memercik ke luar
        _fillPaint.color = const Color(0xFFF5A623).withAlpha(alpha);
        for (var i = 0; i < 6; i++) {
          final sparkAngle = (math.pi / 3) * i + 0.2;
          final dist = radius * (0.3 + t * 0.85);
          final px = cx + math.cos(sparkAngle) * dist;
          final py = cy + math.sin(sparkAngle) * dist;
          canvas.drawRect(Rect.fromLTWH(px - 1, py - 1, 2, 2), _fillPaint);
        }

      case SkillVfxType.arrowShot:
        // Jejak tembakan panah tajam / garis proyektil meluncur
        final advance = t * radius * 0.8;
        _strokePaint
          ..color = _color.withAlpha(alpha)
          ..strokeWidth = 2.0;
        // Garis panah utama
        canvas.drawLine(
          Offset(cx - radius * 0.6 + advance, cy),
          Offset(cx + radius * 0.6 + advance, cy),
          _strokePaint,
        );
        // Ujung mata panah diamond
        _fillPaint.color = const Color(0xFFFFFFFF).withAlpha(alpha);
        final tipX = cx + radius * 0.6 + advance;
        canvas.drawRect(Rect.fromLTWH(tipX - 1, cy - 1, 3, 3), _fillPaint);
        // Bulu panah belakang
        _strokePaint.strokeWidth = 1.2;
        final tailX = cx - radius * 0.6 + advance;
        canvas.drawLine(
          Offset(tailX, cy - 3),
          Offset(tailX + 3, cy),
          _strokePaint,
        );
        canvas.drawLine(
          Offset(tailX, cy + 3),
          Offset(tailX + 3, cy),
          _strokePaint,
        );

      case SkillVfxType.lifeSiphon:
        // Tendril energi ungu / crimson berputar menyedot ke pusat
        final currentR = radius * (1.0 - t * 0.5);
        final rot = t * math.pi * 2.5;
        _strokePaint
          ..color = _color.withAlpha(alpha)
          ..strokeWidth = 1.8;
        for (var i = 0; i < 3; i++) {
          final a0 = rot + (i * math.pi * 2 / 3);
          final p0x = cx + math.cos(a0) * currentR;
          final p0y = cy + math.sin(a0) * currentR;
          final p1x = cx + math.cos(a0 + 0.8) * (currentR * 0.4);
          final p1y = cy + math.sin(a0 + 0.8) * (currentR * 0.4);
          canvas.drawLine(Offset(p0x, p0y), Offset(p1x, p1y), _strokePaint);
        }
        // Partikel darah merah di pusat
        _fillPaint.color = const Color(0xFFD95D5D).withAlpha(alpha);
        canvas.drawCircle(
          Offset(cx, cy),
          radius * 0.25 * (1.0 - t),
          _fillPaint,
        );

      case SkillVfxType.groundSlam:
        // Gelombang kejut tanah elips melebar dengan retakan puing batu
        final currentRx = radius * (0.3 + t * 0.8);
        final currentRy = currentRx * 0.55;
        _strokePaint
          ..color = _color.withAlpha(alpha)
          ..strokeWidth = 2.2 * (1.0 - t * 0.4);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: currentRx * 2,
            height: currentRy * 2,
          ),
          _strokePaint,
        );
        // Retakan batu kecil
        _fillPaint.color = const Color(0xFF795B43).withAlpha(alpha);
        for (var i = 0; i < 5; i++) {
          final a = (math.pi / 2.5) * i + (t * 0.4);
          final px = cx + math.cos(a) * (currentRx * 0.9);
          final py = cy + math.sin(a) * (currentRy * 0.9) - (t * 4);
          canvas.drawRect(Rect.fromLTWH(px - 1.5, py - 1.5, 3, 3), _fillPaint);
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

      case SkillVfxType.defeatBurst:
        // Partikel Aether motes menyebar ke luar dan naik ke atas secara pudar
        final dist = radius * (0.2 + t * 0.9);
        final rise = t * 10.0;
        final moteCount = radius > 18 ? 12 : 8;
        for (var i = 0; i < moteCount; i++) {
          final angle = (math.pi * 2 / moteCount) * i;
          final px = cx + math.cos(angle) * dist;
          final py = cy + math.sin(angle) * (dist * 0.7) - rise;
          _fillPaint.color = (i.isEven ? _color : const Color(0xFFFFFFFF))
              .withAlpha(alpha);
          final sz = (i % 3 == 0) ? 2.5 : 1.8;
          canvas.drawRect(
            Rect.fromLTWH(px - sz / 2, py - sz / 2, sz, sz),
            _fillPaint,
          );
        }
    }
  }
}
