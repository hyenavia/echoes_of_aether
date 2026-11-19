import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../domain/entities/combatant.dart';
import '../visuals/pixel_sprite_atlas.dart';

/// State animasi visual untuk sprite karakter dan monster.
/// Selalu diturunkan dari gameplay state & event simulasi, bukan penentu timing.
enum CombatantAnimationState { idle, walk, attack, downed }

/// Dasar tampilan untuk peserta combat. Tidak memiliki logika RPG: posisi, HP,
/// dan status dibaca dari [Combatant] milik domain dan dirender dengan pixel art
/// 16x16 nearest-neighbor dari [PixelSpriteAtlas].
///
/// - Downed (HP 0): tampil transparan dalam pose terjatuh.
/// - Invulnerable: sprite berkedip.
/// - Hit flash: kilatan putih singkat saat menerima damage.
abstract class CombatantComponent extends PositionComponent {
  CombatantComponent({
    required this.combatant,
    required this.tileSize,
    required int colorArgb,
    PixelSpriteAtlas? atlas,
    this.spriteRef,
    this.spriteTint,
  }) : _atlas = atlas ?? PixelSpriteAtlas.instance,
       _tintColorFilter = spriteTint == null
           ? null
           : ColorFilter.mode(spriteTint, BlendMode.modulate),
       super(size: Vector2.all(tileSize), anchor: Anchor.center) {
    // Gunakan parameter colorArgb hanya sebagai fallback/marker kompatibilitas.
    assert(colorArgb >= 0);
    _lastX = combatant.x;
    _syncPosition();
  }

  final Combatant combatant;
  final double tileSize;
  final PixelSpriteAtlas _atlas;
  final String? spriteRef;
  final Color? spriteTint;
  final ColorFilter? _tintColorFilter;

  ColorFilter? get spriteTintColorFilter => _tintColorFilter;

  final Paint _shadowPaint = Paint()..color = const Color(0x55000000);
  final Paint _spritePaint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  final Paint _eliteAura = Paint()
    ..color = const Color(0x99E6BD68)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _bossAuraOuter = Paint()
    ..color = const Color(0x889879CE)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  final Paint _bossAuraInner = Paint()
    ..color = const Color(0x6665BFE8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  final Paint _barBorder = Paint()..color = const Color(0xFF10141A);
  final Paint _barBackground = Paint()..color = const Color(0xFF222933);
  final Paint _barFill = Paint();
  final Paint _gleamPaint = Paint()..isAntiAlias = false;

  double _hitFlashTimer = 0;
  double _attackAnimTimer = 0;
  double _animTime = 0;
  double _lastX = 0;
  bool _facingLeft = false;

  bool get isHitFlashing => _hitFlashTimer > 0;
  bool get facingLeft => _facingLeft;

  /// Override pada subclass player agar sprite mengikuti class specialization.
  String? get spriteSpecializationId => null;

  CombatantAnimationState get animationState {
    if (!combatant.isAlive) return CombatantAnimationState.downed;
    if (_attackAnimTimer > 0) return CombatantAnimationState.attack;
    if (combatant.follower.isMoving) return CombatantAnimationState.walk;
    return CombatantAnimationState.idle;
  }

  String get activePose {
    final frame = ((_animTime ~/ 0.26) % 2);
    switch (animationState) {
      case CombatantAnimationState.downed:
        return 'downed';
      case CombatantAnimationState.attack:
        return 'attack';
      case CombatantAnimationState.walk:
        return 'walk$frame';
      case CombatantAnimationState.idle:
        return 'idle$frame';
    }
  }

  void triggerHitFlash([double duration = 0.12]) {
    _hitFlashTimer = duration;
  }

  void triggerAttackAnimation([double duration = 0.18]) {
    _attackAnimTimer = duration;
  }

  /// Arahkan sprite menghadap koordinat tile [targetTileX] (mis. saat menyerang).
  void faceToward(double targetTileX) {
    final dx = targetTileX - combatant.x;
    if (dx.abs() > 0.05) {
      _facingLeft = dx < 0;
    }
  }

  /// Sinkronkan posisi visual seketika dan bersihkan efek transient (hit
  /// flash / attack animation) setelah perpindahan ruangan.
  void resetVisualTransient() {
    _hitFlashTimer = 0;
    _attackAnimTimer = 0;
    _animTime = 0;
    _lastX = combatant.x;
    _syncPosition();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animTime += dt;
    if (_hitFlashTimer > 0) {
      _hitFlashTimer = (_hitFlashTimer - dt).clamp(0.0, double.infinity);
    }
    if (_attackAnimTimer > 0) {
      _attackAnimTimer = (_attackAnimTimer - dt).clamp(0.0, double.infinity);
    }

    final dx = combatant.x - _lastX;
    if (dx.abs() > 0.001) {
      _facingLeft = dx < 0;
      _lastX = combatant.x;
    } else if (combatant.plannedGoal != null &&
        animationState == CombatantAnimationState.walk) {
      final gx = combatant.plannedGoal!.x + 0.5 - combatant.x;
      if (gx.abs() > 0.05) {
        _facingLeft = gx < 0;
      }
    }
    _syncPosition();
  }

  void _syncPosition() {
    position.setValues(combatant.x * tileSize, combatant.y * tileSize);
  }

  int _alpha() {
    if (!combatant.isAlive) return 110;
    if (combatant.invulnerableTicks > 0) {
      return (combatant.invulnerableTicks ~/ 3).isEven ? 120 : 255;
    }
    return 255;
  }

  Color _hpBarColor() {
    if (combatant.team == Team.player) return const Color(0xFF66BB6A);
    if (combatant.isBoss) return const Color(0xFFE040FB);
    if (combatant.isElite) return const Color(0xFFE6BD68);
    return const Color(0xFFEF5350);
  }

  @override
  void render(Canvas canvas) {
    final alpha = _alpha();
    final isBoss = combatant.isBoss;
    final isElite = combatant.isElite;
    final drawScale = isBoss ? 1.28 : (isElite ? 1.1 : 1.0);
    final drawW = size.x * drawScale;
    final drawH = size.y * drawScale;
    final left = (size.x - drawW) / 2;
    final top = (size.y - drawH) / 2 - (isBoss ? 1.5 : 0);

    // Bayangan lembut di bawah kaki combatant.
    if (combatant.isAlive) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.x / 2, size.y * 0.86),
          width: drawW * 0.68,
          height: drawH * 0.22,
        ),
        _shadowPaint,
      );
    }

    // Aura visual untuk Elite & Boss agar cepat terbaca di layar.
    if (combatant.isAlive && isBoss) {
      final pulse = math.sin(_animTime * 4.5) * 1.2;
      final center = Offset(size.x / 2, size.y / 2);
      canvas.drawCircle(center, (drawW * 0.54) + pulse, _bossAuraOuter);
      canvas.drawCircle(center, (drawW * 0.42) - (pulse * 0.5), _bossAuraInner);
    } else if (combatant.isAlive && isElite) {
      final pulse = math.sin(_animTime * 3.5) * 0.6;
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        (drawW * 0.48) + pulse,
        _eliteAura,
      );
    }

    // Indikator telegraf serang elite & boss saat menyerang (gleam merah-putih)
    if (combatant.isAlive && (isBoss || isElite) && _attackAnimTimer > 0) {
      final gleamY = top - 3.0;
      final gleamX = size.x / 2;
      _gleamPaint.color = const Color(0xFFFF5252);
      canvas.drawRect(
        Rect.fromLTWH(gleamX - 1.5, gleamY - 1.5, 3, 3),
        _gleamPaint,
      );
      _gleamPaint.color = const Color(0xFFFFFFFF);
      canvas.drawRect(
        Rect.fromLTWH(gleamX - 0.5, gleamY - 0.5, 1, 1),
        _gleamPaint,
      );
    }

    final sprite = _atlas.combatantSprite(
      isPlayer: combatant.team == Team.player,
      specializationId: spriteSpecializationId,
      definitionId: combatant.definitionId,
      spriteRef: spriteRef,
      pose: activePose,
    );

    final src = Rect.fromLTWH(
      0,
      0,
      sprite.width.toDouble(),
      sprite.height.toDouble(),
    );
    final dst = Rect.fromLTWH(left, top, drawW, drawH);

    _spritePaint
      ..color = Color.fromARGB(alpha, 255, 255, 255)
      ..colorFilter = isHitFlashing
          ? const ColorFilter.mode(Color(0xCCFFFFFF), BlendMode.srcATop)
          : _tintColorFilter;

    if (_facingLeft) {
      canvas.save();
      canvas.translate(size.x / 2, 0);
      canvas.scale(-1, 1);
      canvas.translate(-size.x / 2, 0);
      canvas.drawImageRect(sprite, src, dst, _spritePaint);
      canvas.restore();
    } else {
      canvas.drawImageRect(sprite, src, dst, _spritePaint);
    }

    // Bar HP berbingkai di atas tubuh.
    final barWidth = isBoss ? size.x * 1.3 : size.x * 0.9;
    final barLeft = (size.x - barWidth) / 2;
    const barHeight = 2.0;
    final barTop = top - 3.5;
    final ratio = (combatant.hp / combatant.stats.maxHp).clamp(0.0, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(
        barLeft - 0.6,
        barTop - 0.6,
        barWidth + 1.2,
        barHeight + 1.2,
      ),
      _barBorder,
    );
    canvas.drawRect(
      Rect.fromLTWH(barLeft, barTop, barWidth, barHeight),
      _barBackground,
    );
    _barFill.color = _hpBarColor();
    canvas.drawRect(
      Rect.fromLTWH(barLeft, barTop, barWidth * ratio, barHeight),
      _barFill,
    );
    if (combatant.shield > 0) {
      final shieldRatio = (combatant.shield / combatant.stats.maxHp).clamp(
        0.0,
        1.0,
      );
      final shieldPaint = Paint()..color = const Color(0xFF4DD0E1);
      canvas.drawRect(
        Rect.fromLTWH(barLeft, barTop, barWidth * shieldRatio, barHeight),
        shieldPaint,
      );
    }
  }
}
