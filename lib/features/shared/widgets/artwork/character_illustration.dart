import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../assets/game_assets.dart';

/// Presentasi ilustrasi karakter untuk layar menu (Camp, Hero Profile,
/// Class Specialization).
///
/// Menggunakan vector fantasy illustration ber-layer (`CustomPainter`) per class
/// dan memiliki seam langsung ke `Image.asset` ketika PNG final tersedia di
/// [GameAssetRegistry]. Tidak pernah memperbesar sprite pixel art gameplay.
class CharacterIllustration extends StatelessWidget {
  const CharacterIllustration({
    super.key,
    required this.specializationId,
    this.width = 136,
    this.height = 172,
    this.showPedestal = true,
    this.showAura = true,
    this.sequence = CharacterAnimationSequence.idle,
    this.frameIndex = 0,
    this.useShowcase = false,
  });

  final String specializationId;
  final double width;
  final double height;
  final bool showPedestal;
  final bool showAura;
  final CharacterAnimationSequence sequence;
  final int frameIndex;
  final bool useShowcase;

  @override
  Widget build(BuildContext context) {
    final spec = CharacterVisualSpec.resolve(specializationId);
    final useLegacyDefault =
        !useShowcase &&
        sequence == CharacterAnimationSequence.idle &&
        frameIndex == 0;
    final spriteAsset = useShowcase
        ? spec.showcasePath
        : (useLegacyDefault
              ? 'assets/char/frames/hero_${spec.classId}_idle0.png'
              : spec.manifest.frameFor(sequence, frameIndex));

    return Semantics(
      image: true,
      label: '${spec.title} (${spec.subtitle})',
      child: SizedBox(
        key: ValueKey<String>('character_illustration_${spec.classId}'),
        width: width,
        height: height,
        child: GameAssetRegistry.hasRasterAsset(spec.assetPath)
            ? Image.asset(
                spec.assetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  if (showAura || showPedestal)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _CharacterBackdropPainter(
                            spec: spec,
                            showPedestal: showPedestal,
                            showAura: showAura,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: showPedestal ? height * 0.10 : height * 0.05,
                    top: showPedestal ? height * 0.08 : height * 0.05,
                    child: Image.asset(
                      spriteAsset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (context, error, stackTrace) {
                        if (spriteAsset != spec.portraitPath) {
                          return Image.asset(
                            spec.portraitPath,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, _, _) => RepaintBoundary(
                              child: CustomPaint(
                                size: Size(width, height),
                                painter: _CharacterIllustrationPainter(
                                  spec: spec,
                                  showPedestal: showPedestal,
                                  showAura: showAura,
                                ),
                              ),
                            ),
                          );
                        }
                        return RepaintBoundary(
                          child: CustomPaint(
                            size: Size(width, height),
                            painter: _CharacterIllustrationPainter(
                              spec: spec,
                              showPedestal: showPedestal,
                              showAura: showAura,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Ikon crest/emblem class pixel-art dengan fallback ikon yang aman.
class ClassEmblemIcon extends StatelessWidget {
  const ClassEmblemIcon({
    super.key,
    required this.specializationId,
    this.size = 24,
    this.fallbackColor,
  });

  final String specializationId;
  final double size;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final spec = CharacterVisualSpec.resolve(specializationId);
    return Image.asset(
      spec.emblemPath,
      key: ValueKey<String>('class_emblem_${spec.classId}'),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) => Icon(
        Icons.shield_outlined,
        size: size * 0.85,
        color: fallbackColor ?? spec.accentColor,
      ),
    );
  }
}

class _CharacterBackdropPainter extends CustomPainter {
  const _CharacterBackdropPainter({
    required this.spec,
    required this.showPedestal,
    required this.showAura,
  });

  final CharacterVisualSpec spec;
  final bool showPedestal;
  final bool showAura;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    if (showAura) {
      _CharacterIllustrationPainter.paintAura(canvas, size, cx, spec);
    }
    if (showPedestal) {
      _CharacterIllustrationPainter.paintPedestal(canvas, size, cx, spec);
    }
  }

  @override
  bool shouldRepaint(covariant _CharacterBackdropPainter oldDelegate) =>
      oldDelegate.spec.classId != spec.classId ||
      oldDelegate.showPedestal != showPedestal ||
      oldDelegate.showAura != showAura;
}

class _CharacterIllustrationPainter extends CustomPainter {
  const _CharacterIllustrationPainter({
    required this.spec,
    required this.showPedestal,
    required this.showAura,
  });

  final CharacterVisualSpec spec;
  final bool showPedestal;
  final bool showAura;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;

    if (showAura) {
      paintAura(canvas, size, cx, spec);
    }
    if (showPedestal) {
      paintPedestal(canvas, size, cx, spec);
    }

    switch (spec.classId) {
      case 'vanguard':
        _paintVanguard(canvas, w, h, cx);
      case 'arcanist':
        _paintArcanist(canvas, w, h, cx);
      case 'ranger':
        _paintRanger(canvas, w, h, cx);
      default:
        _paintBaseWanderer(canvas, w, h, cx);
    }
  }

  static void paintAura(
    Canvas canvas,
    Size size,
    double cx,
    CharacterVisualSpec spec,
  ) {
    final auraCenter = Offset(cx, size.height * 0.46);
    final auraRadius = math.min(size.width, size.height) * 0.48;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          spec.auraColor.withValues(alpha: 0.34),
          spec.primaryColor.withValues(alpha: 0.14),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: auraCenter, radius: auraRadius));
    canvas.drawCircle(auraCenter, auraRadius, paint);

    // Subtle floating sparks
    final sparkPaint = Paint()..color = spec.auraColor.withValues(alpha: 0.72);
    canvas.drawCircle(
      Offset(cx - size.width * 0.28, size.height * 0.28),
      2.0,
      sparkPaint,
    );
    canvas.drawCircle(
      Offset(cx + size.width * 0.30, size.height * 0.22),
      1.6,
      sparkPaint,
    );
    canvas.drawCircle(
      Offset(cx + size.width * 0.22, size.height * 0.62),
      2.1,
      sparkPaint,
    );
  }

  static void paintPedestal(
    Canvas canvas,
    Size size,
    double cx,
    CharacterVisualSpec spec,
  ) {
    final groundRect = Rect.fromCenter(
      center: Offset(cx, size.height * 0.90),
      width: size.width * 0.68,
      height: size.height * 0.10,
    );
    canvas.drawOval(
      groundRect,
      Paint()..color = AppColors.midnightForest.withValues(alpha: 0.78),
    );
    canvas.drawOval(
      groundRect.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = spec.auraColor.withValues(alpha: 0.45),
    );
  }

  void _paintBaseWanderer(Canvas canvas, double w, double h, double cx) {
    // Cloak silhouette
    final cloakPath = Path()
      ..moveTo(cx - w * 0.15, h * 0.29)
      ..lineTo(cx + w * 0.16, h * 0.29)
      ..lineTo(cx + w * 0.27, h * 0.84)
      ..quadraticBezierTo(cx, h * 0.89, cx - w * 0.27, h * 0.84)
      ..close();
    canvas.drawPath(
      cloakPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.forestGreen, AppColors.deepForest],
        ).createShader(Rect.fromLTWH(0, h * 0.28, w, h * 0.6)),
    );

    // Tunic & leather belt
    final tunicRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, h * 0.56),
        width: w * 0.25,
        height: h * 0.34,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(tunicRect, Paint()..color = const Color(0xFF284838));
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, h * 0.54),
        width: w * 0.26,
        height: h * 0.045,
      ),
      Paint()..color = AppColors.earthBrown,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, h * 0.54),
        width: w * 0.06,
        height: h * 0.05,
      ),
      Paint()..color = AppColors.antiqueGold,
    );

    // Hood & head
    _paintHeadWithHood(
      canvas,
      cx: cx,
      headY: h * 0.22,
      headR: w * 0.095,
      hoodColor: const Color(0xFF274A3B),
      trimColor: AppColors.antiqueGold,
      eyeGlow: AppColors.aetherBlue,
    );

    // Warm Aether lantern (left hand)
    final lanternCenter = Offset(cx - w * 0.26, h * 0.55);
    canvas.drawLine(
      Offset(cx - w * 0.14, h * 0.42),
      Offset(cx - w * 0.26, h * 0.50),
      Paint()
        ..color = AppColors.earthBrown
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      lanternCenter,
      w * 0.07,
      Paint()..color = AppColors.campAmber.withValues(alpha: 0.28),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: lanternCenter,
          width: w * 0.08,
          height: h * 0.08,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.campAmber,
    );

    // Traveler blade (right hand)
    _paintSword(
      canvas,
      hilt: Offset(cx + w * 0.22, h * 0.54),
      tip: Offset(cx + w * 0.34, h * 0.27),
      bladeColor: const Color(0xFFDCE6E2),
      hiltColor: AppColors.antiqueGold,
    );
  }

  void _paintVanguard(Canvas canvas, double w, double h, double cx) {
    // Crimson/gold war cape behind armor
    final capePath = Path()
      ..moveTo(cx - w * 0.19, h * 0.31)
      ..lineTo(cx + w * 0.21, h * 0.31)
      ..lineTo(cx + w * 0.31, h * 0.85)
      ..lineTo(cx - w * 0.25, h * 0.85)
      ..close();
    canvas.drawPath(capePath, Paint()..color = const Color(0xFF5D2727));

    // Heavy armored torso & tassets
    final chestPath = Path()
      ..moveTo(cx - w * 0.17, h * 0.31)
      ..lineTo(cx + w * 0.17, h * 0.31)
      ..lineTo(cx + w * 0.13, h * 0.62)
      ..lineTo(cx - w * 0.13, h * 0.62)
      ..close();
    canvas.drawPath(
      chestPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF8C9B96), Color(0xFF4C5954)],
        ).createShader(Rect.fromLTWH(cx - w * 0.2, h * 0.3, w * 0.4, h * 0.35)),
    );

    // Gold chest trim
    canvas.drawPath(
      chestPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = AppColors.antiqueGold,
    );

    // Broad pauldrons
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + side * w * 0.18, h * 0.33),
          width: w * 0.16,
          height: h * 0.09,
        ),
        Paint()..color = const Color(0xFF7B8983),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + side * w * 0.18, h * 0.33),
          width: w * 0.16,
          height: h * 0.09,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppColors.antiqueGold,
      );
    }

    // Greaves
    for (final side in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + side * w * 0.08, h * 0.75),
            width: w * 0.09,
            height: h * 0.22,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF56635E),
      );
    }

    // Crested Knight Helm
    final helmRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, h * 0.21),
        width: w * 0.20,
        height: h * 0.16,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(helmRect, Paint()..color = const Color(0xFF84928D));
    canvas.drawRRect(
      helmRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.antiqueGold,
    );
    // Helm plume
    final plume = Path()
      ..moveTo(cx - w * 0.03, h * 0.14)
      ..quadraticBezierTo(cx, h * 0.05, cx + w * 0.09, h * 0.12)
      ..close();
    canvas.drawPath(plume, Paint()..color = AppColors.emberRed);
    // Visor slit
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, h * 0.22),
        width: w * 0.13,
        height: h * 0.022,
      ),
      Paint()..color = AppColors.midnightForest,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, h * 0.22),
        width: w * 0.09,
        height: h * 0.01,
      ),
      Paint()..color = AppColors.campAmber,
    );

    // Broadsword on right
    _paintSword(
      canvas,
      hilt: Offset(cx + w * 0.24, h * 0.49),
      tip: Offset(cx + w * 0.36, h * 0.17),
      bladeColor: const Color(0xFFE7EFEA),
      hiltColor: AppColors.antiqueGold,
      bladeWidth: 5.0,
    );

    // Kite shield planted on left
    final shieldPath = Path()
      ..moveTo(cx - w * 0.32, h * 0.40)
      ..lineTo(cx - w * 0.09, h * 0.40)
      ..lineTo(cx - w * 0.09, h * 0.65)
      ..lineTo(cx - w * 0.205, h * 0.80)
      ..lineTo(cx - w * 0.32, h * 0.65)
      ..close();
    canvas.drawPath(shieldPath, Paint()..color = const Color(0xFF28433A));
    canvas.drawPath(
      shieldPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = AppColors.antiqueGold,
    );
    canvas.drawCircle(
      Offset(cx - w * 0.205, h * 0.55),
      w * 0.045,
      Paint()..color = AppColors.emberRed,
    );
  }

  void _paintArcanist(Canvas canvas, double w, double h, double cx) {
    // Flowing layered arcane robes
    final robePath = Path()
      ..moveTo(cx - w * 0.13, h * 0.29)
      ..lineTo(cx + w * 0.13, h * 0.29)
      ..lineTo(cx + w * 0.30, h * 0.86)
      ..quadraticBezierTo(cx, h * 0.90, cx - w * 0.28, h * 0.86)
      ..close();
    canvas.drawPath(
      robePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF294866), Color(0xFF2B214A)],
        ).createShader(Rect.fromLTWH(0, h * 0.28, w, h * 0.6)),
    );

    // Glowing arcane stole
    final stole = Path()
      ..moveTo(cx - w * 0.06, h * 0.31)
      ..lineTo(cx + w * 0.06, h * 0.31)
      ..lineTo(cx + w * 0.09, h * 0.80)
      ..lineTo(cx - w * 0.09, h * 0.80)
      ..close();
    canvas.drawPath(
      stole,
      Paint()..color = AppColors.arcaneViolet.withValues(alpha: 0.45),
    );
    canvas.drawPath(
      stole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.aetherBlue,
    );

    // High arcane collar + hood
    _paintHeadWithHood(
      canvas,
      cx: cx,
      headY: h * 0.21,
      headR: w * 0.095,
      hoodColor: const Color(0xFF332D5E),
      trimColor: AppColors.aetherBlue,
      eyeGlow: AppColors.aetherBlue,
    );

    // Runestaff on right
    final staffBottom = Offset(cx + w * 0.26, h * 0.85);
    final staffTop = Offset(cx + w * 0.30, h * 0.21);
    canvas.drawLine(
      staffBottom,
      staffTop,
      Paint()
        ..color = AppColors.earthBrown
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    // Crystal orb atop staff
    canvas.drawCircle(
      staffTop,
      w * 0.075,
      Paint()..color = AppColors.aetherBlue.withValues(alpha: 0.30),
    );
    final crystal = Path()
      ..moveTo(staffTop.dx, staffTop.dy - h * 0.055)
      ..lineTo(staffTop.dx + w * 0.045, staffTop.dy)
      ..lineTo(staffTop.dx, staffTop.dy + h * 0.055)
      ..lineTo(staffTop.dx - w * 0.045, staffTop.dy)
      ..close();
    canvas.drawPath(crystal, Paint()..color = AppColors.aetherBlue);

    // Floating grimoire on left
    final tomeCenter = Offset(cx - w * 0.26, h * 0.47);
    canvas.drawCircle(
      tomeCenter,
      w * 0.08,
      Paint()..color = AppColors.arcaneViolet.withValues(alpha: 0.25),
    );
    final tomeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: tomeCenter, width: w * 0.14, height: h * 0.09),
      const Radius.circular(3),
    );
    canvas.drawRRect(tomeRect, Paint()..color = AppColors.panelElevated);
    canvas.drawRRect(
      tomeRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.antiqueGold,
    );
    canvas.drawLine(
      Offset(tomeCenter.dx, tomeCenter.dy - h * 0.04),
      Offset(tomeCenter.dx, tomeCenter.dy + h * 0.04),
      Paint()
        ..color = AppColors.aetherBlue
        ..strokeWidth = 1.5,
    );
  }

  void _paintRanger(Canvas canvas, double w, double h, double cx) {
    // Quiver behind right shoulder
    canvas.save();
    canvas.translate(cx + w * 0.14, h * 0.35);
    canvas.rotate(0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.07, height: h * 0.20),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.earthBrown,
    );
    // Arrow fletchings
    for (final dx in [-4.0, 0.0, 4.0]) {
      canvas.drawLine(
        Offset(dx, -h * 0.10),
        Offset(dx, -h * 0.14),
        Paint()
          ..color = AppColors.antiqueGold
          ..strokeWidth = 1.8,
      );
    }
    canvas.restore();

    // Agile forest coat & asymmetrical mantle
    final mantle = Path()
      ..moveTo(cx - w * 0.17, h * 0.30)
      ..lineTo(cx + w * 0.15, h * 0.30)
      ..lineTo(cx + w * 0.22, h * 0.67)
      ..lineTo(cx - w * 0.24, h * 0.72)
      ..close();
    canvas.drawPath(
      mantle,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF476944), Color(0xFF213A2A)],
        ).createShader(Rect.fromLTWH(0, h * 0.28, w, h * 0.45)),
    );

    // Ranger boots / trousers
    for (final side in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + side * w * 0.08, h * 0.76),
            width: w * 0.075,
            height: h * 0.22,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF3A2F24),
      );
    }

    // Hooded ranger head
    _paintHeadWithHood(
      canvas,
      cx: cx,
      headY: h * 0.21,
      headR: w * 0.092,
      hoodColor: const Color(0xFF3E5E3E),
      trimColor: AppColors.antiqueGold,
      eyeGlow: AppColors.success,
    );

    // Recurve bow on left
    final bowTop = Offset(cx - w * 0.20, h * 0.24);
    final bowMid = Offset(cx - w * 0.34, h * 0.48);
    final bowBot = Offset(cx - w * 0.18, h * 0.72);
    final bowPath = Path()
      ..moveTo(bowTop.dx, bowTop.dy)
      ..quadraticBezierTo(bowMid.dx, bowMid.dy, bowBot.dx, bowBot.dy);
    canvas.drawPath(
      bowPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = AppColors.antiqueGold,
    );
    // Glowing bowstring
    canvas.drawLine(
      bowTop,
      Offset(cx - w * 0.13, h * 0.48),
      Paint()
        ..color = AppColors.aetherBlue
        ..strokeWidth = 1.2,
    );
    canvas.drawLine(
      Offset(cx - w * 0.13, h * 0.48),
      bowBot,
      Paint()
        ..color = AppColors.aetherBlue
        ..strokeWidth = 1.2,
    );
    // Nocked glowing arrow
    canvas.drawLine(
      Offset(cx - w * 0.13, h * 0.48),
      Offset(cx - w * 0.40, h * 0.48),
      Paint()
        ..color = AppColors.success
        ..strokeWidth = 2.0,
    );
  }

  void _paintHeadWithHood(
    Canvas canvas, {
    required double cx,
    required double headY,
    required double headR,
    required Color hoodColor,
    required Color trimColor,
    required Color eyeGlow,
  }) {
    final hoodPath = Path()
      ..moveTo(cx - headR * 1.35, headY + headR * 0.85)
      ..quadraticBezierTo(
        cx,
        headY - headR * 1.9,
        cx + headR * 1.35,
        headY + headR * 0.85,
      )
      ..close();
    canvas.drawPath(hoodPath, Paint()..color = hoodColor);
    canvas.drawPath(
      hoodPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = trimColor.withValues(alpha: 0.75),
    );
    canvas.drawCircle(
      Offset(cx, headY + headR * 0.1),
      headR * 0.82,
      Paint()..color = AppColors.midnightForest,
    );
    // Eyes
    final eyePaint = Paint()..color = eyeGlow;
    canvas.drawCircle(
      Offset(cx - headR * 0.30, headY + headR * 0.12),
      1.8,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(cx + headR * 0.30, headY + headR * 0.12),
      1.8,
      eyePaint,
    );
  }

  void _paintSword(
    Canvas canvas, {
    required Offset hilt,
    required Offset tip,
    required Color bladeColor,
    required Color hiltColor,
    double bladeWidth = 3.5,
  }) {
    canvas.drawLine(
      hilt,
      tip,
      Paint()
        ..color = bladeColor
        ..strokeWidth = bladeWidth
        ..strokeCap = StrokeCap.round,
    );
    final dir = tip - hilt;
    final len = dir.distance;
    if (len > 0) {
      final perp = Offset(-dir.dy / len, dir.dx / len) * 7;
      canvas.drawLine(
        hilt - perp,
        hilt + perp,
        Paint()
          ..color = hiltColor
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CharacterIllustrationPainter oldDelegate) =>
      oldDelegate.spec.classId != spec.classId ||
      oldDelegate.showPedestal != showPedestal ||
      oldDelegate.showAura != showAura;
}
