import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../assets/game_assets.dart';

/// Latar belakang Living Aether Camp untuk Hero Showcase dan Town/Camp Hub.
///
/// Menampilkan hutan malam gelap, tenda petualang, api unggun hangat,
/// dan kristal Aether bercahaya. Mudah diganti dengan PNG melalui
/// [GameAssetRegistry].
class CampBackdrop extends StatelessWidget {
  const CampBackdrop({super.key, this.child, this.borderRadius = AppRadius.lg});

  final Widget? child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final hasRaster = GameAssetRegistry.hasRasterAsset(
      GameAssetPaths.campBackground,
    );

    return ClipRRect(
      key: const ValueKey<String>('camp_backdrop'),
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: hasRaster
                ? Image.asset(GameAssetPaths.campBackground, fit: BoxFit.cover)
                : RepaintBoundary(
                    child: CustomPaint(painter: const _CampBackdropPainter()),
                  ),
          ),
          ?child,
        ],
      ),
    );
  }
}

/// Artwork visual untuk setiap biome dungeon (Forgotten Forest, Crystal Cavern,
/// Ancient Crypt, Ashen Wasteland, Aether Sanctum, dan Ascension Sanctum).
class BiomeArtwork extends StatelessWidget {
  const BiomeArtwork({
    super.key,
    required this.biomeId,
    this.isAscension = false,
    this.height = 96,
    this.width,
    this.borderRadius = AppRadius.md,
    this.child,
  });

  final String biomeId;
  final bool isAscension;
  final double height;
  final double? width;
  final double borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final spec = BiomeVisualSpec.resolve(biomeId, isAscension: isAscension);
    final hasRaster = GameAssetRegistry.hasRasterAsset(spec.assetPath);

    return ClipRRect(
      key: ValueKey<String>('biome_artwork_${spec.biomeId}'),
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasRaster)
              Image.asset(spec.assetPath, fit: BoxFit.cover)
            else
              RepaintBoundary(
                child: CustomPaint(painter: _BiomeArtworkPainter(spec: spec)),
              ),
            // Dark gradient vignette so overlaid badge/text stays legible
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x1A08120E), Color(0x8808120E)],
                ),
              ),
            ),
            ?child,
          ],
        ),
      ),
    );
  }
}

class _CampBackdropPainter extends CustomPainter {
  const _CampBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Enchanted twilight forest sky
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A1713),
            AppColors.midnightForest,
            Color(0xFF1A342B),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Subtle stars & Aether mist in sky
    final starPaint = Paint()
      ..color = AppColors.aetherBlue.withValues(alpha: 0.45);
    for (final pt in [
      Offset(w * 0.14, h * 0.18),
      Offset(w * 0.28, h * 0.11),
      Offset(w * 0.46, h * 0.16),
      Offset(w * 0.68, h * 0.12),
      Offset(w * 0.85, h * 0.22),
    ]) {
      canvas.drawCircle(pt, 1.4, starPaint);
    }

    // 2. Layered pine silhouettes in background
    final farTreePaint = Paint()..color = const Color(0xFF0E211B);
    for (var i = 0; i < 8; i++) {
      final tx = w * (i / 7.2);
      final treeTop = h * (0.20 + (i.isEven ? 0.05 : 0.0));
      final path = Path()
        ..moveTo(tx, treeTop)
        ..lineTo(tx - w * 0.08, h * 0.72)
        ..lineTo(tx + w * 0.08, h * 0.72)
        ..close();
      canvas.drawPath(path, farTreePaint);
    }

    // 3. Clearing floor
    final groundPath = Path()
      ..moveTo(0, h * 0.70)
      ..quadraticBezierTo(w * 0.5, h * 0.64, w, h * 0.70)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      groundPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1F3B2F), Color(0xFF11231C)],
        ).createShader(Rect.fromLTWH(0, h * 0.65, w, h * 0.35)),
    );

    // 4. Adventurer tent (left side)
    final tentBaseY = h * 0.74;
    final tentPath = Path()
      ..moveTo(w * 0.06, tentBaseY)
      ..lineTo(w * 0.18, h * 0.46)
      ..lineTo(w * 0.32, tentBaseY)
      ..close();
    canvas.drawPath(tentPath, Paint()..color = const Color(0xFF3E4D3E));
    final tentOpening = Path()
      ..moveTo(w * 0.15, tentBaseY)
      ..lineTo(w * 0.18, h * 0.55)
      ..lineTo(w * 0.22, tentBaseY)
      ..close();
    canvas.drawPath(tentOpening, Paint()..color = const Color(0xFF16241E));
    canvas.drawPath(
      tentPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.antiqueGold.withValues(alpha: 0.35),
    );

    // 5. Glowing Aether crystal spire (right side)
    final crystalCenter = Offset(w * 0.84, h * 0.62);
    canvas.drawCircle(
      crystalCenter,
      w * 0.14,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                AppColors.aetherBlue.withValues(alpha: 0.38),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: crystalCenter, radius: w * 0.14),
            ),
    );
    // Subtle rune ring and gold orbit around crystal (Aether branding accent)
    canvas.drawCircle(
      crystalCenter,
      w * 0.08,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.antiqueGold.withValues(alpha: 0.22),
    );
    canvas.drawCircle(
      crystalCenter,
      w * 0.11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = AppColors.aetherBlue.withValues(alpha: 0.18),
    );
    final spire = Path()
      ..moveTo(w * 0.84, h * 0.38)
      ..lineTo(w * 0.89, h * 0.58)
      ..lineTo(w * 0.86, h * 0.74)
      ..lineTo(w * 0.81, h * 0.74)
      ..lineTo(w * 0.79, h * 0.56)
      ..close();
    canvas.drawPath(
      spire,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB5ECFF), AppColors.aetherBlue, Color(0xFF2B6B8A)],
        ).createShader(Rect.fromLTWH(w * 0.78, h * 0.38, w * 0.12, h * 0.36)),
    );

    // 6. Warm campfire (lower-left / center-left clearing)
    final firePos = Offset(w * 0.34, h * 0.78);
    canvas.drawCircle(
      firePos,
      w * 0.12,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.campAmber.withValues(alpha: 0.38),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: firePos, radius: w * 0.12)),
    );
    // Logs
    canvas.drawLine(
      Offset(firePos.dx - 11, firePos.dy + 4),
      Offset(firePos.dx + 11, firePos.dy - 1),
      Paint()
        ..color = AppColors.earthBrown
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(firePos.dx - 10, firePos.dy - 1),
      Offset(firePos.dx + 10, firePos.dy + 4),
      Paint()
        ..color = const Color(0xFF59402E)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    // Flame
    final flame = Path()
      ..moveTo(firePos.dx - 6, firePos.dy + 2)
      ..quadraticBezierTo(
        firePos.dx - 8,
        firePos.dy - 10,
        firePos.dx,
        firePos.dy - 16,
      )
      ..quadraticBezierTo(
        firePos.dx + 8,
        firePos.dy - 10,
        firePos.dx + 6,
        firePos.dy + 2,
      )
      ..close();
    canvas.drawPath(flame, Paint()..color = AppColors.campAmber);
    final innerFlame = Path()
      ..moveTo(firePos.dx - 3, firePos.dy + 2)
      ..quadraticBezierTo(
        firePos.dx,
        firePos.dy - 10,
        firePos.dx + 3,
        firePos.dy + 2,
      )
      ..close();
    canvas.drawPath(innerFlame, Paint()..color = AppColors.antiqueGold);
  }

  @override
  bool shouldRepaint(covariant _CampBackdropPainter oldDelegate) => false;
}

class _BiomeArtworkPainter extends CustomPainter {
  const _BiomeArtworkPainter({required this.spec});

  final BiomeVisualSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sky gradient
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [spec.skyTop, spec.skyBottom],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Distant ridge
    final ridge = Path()
      ..moveTo(0, h * 0.65)
      ..lineTo(w * 0.22, h * 0.44)
      ..lineTo(w * 0.48, h * 0.58)
      ..lineTo(w * 0.74, h * 0.39)
      ..lineTo(w, h * 0.56)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      ridge,
      Paint()..color = spec.terrainColor.withValues(alpha: 0.7),
    );

    // Biome-specific signature silhouettes
    switch (spec.biomeId) {
      case 'crystal_cavern':
        _paintCrystals(canvas, w, h);
      case 'ancient_crypt':
        _paintCryptPillars(canvas, w, h);
      case 'ashen_wasteland':
        _paintVolcanicCrags(canvas, w, h);
      case 'aether_sanctum':
      case 'ascension_sanctum':
        _paintSanctumArch(canvas, w, h);
      default:
        _paintForestCanopy(canvas, w, h);
    }

    // Foreground terrain strip
    final foreground = Path()
      ..moveTo(0, h * 0.78)
      ..quadraticBezierTo(w * 0.5, h * 0.72, w, h * 0.79)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(foreground, Paint()..color = spec.terrainColor);
  }

  void _paintForestCanopy(Canvas canvas, double w, double h) {
    final treePaint = Paint()
      ..color = AppColors.midnightForest.withValues(alpha: 0.82);
    for (final x in [0.12, 0.26, 0.76, 0.90]) {
      final path = Path()
        ..moveTo(w * x, h * 0.16)
        ..lineTo(w * (x - 0.09), h * 0.82)
        ..lineTo(w * (x + 0.09), h * 0.82)
        ..close();
      canvas.drawPath(path, treePaint);
    }
    // Floating forest wisps
    final wisp = Paint()..color = spec.atmosphereColor.withValues(alpha: 0.75);
    canvas.drawCircle(Offset(w * 0.42, h * 0.44), 2.5, wisp);
    canvas.drawCircle(Offset(w * 0.58, h * 0.32), 2.0, wisp);
  }

  void _paintCrystals(Canvas canvas, double w, double h) {
    final crystalPaint = Paint()
      ..color = spec.accentColor.withValues(alpha: 0.82);
    for (final x in [0.16, 0.34, 0.78]) {
      final path = Path()
        ..moveTo(w * x, h * 0.22)
        ..lineTo(w * (x + 0.05), h * 0.50)
        ..lineTo(w * (x + 0.03), h * 0.80)
        ..lineTo(w * (x - 0.04), h * 0.80)
        ..lineTo(w * (x - 0.05), h * 0.48)
        ..close();
      canvas.drawPath(path, crystalPaint);
    }
  }

  void _paintCryptPillars(Canvas canvas, double w, double h) {
    final pillarPaint = Paint()..color = const Color(0xFF1B1729);
    for (final x in [0.15, 0.30, 0.72, 0.86]) {
      canvas.drawRect(
        Rect.fromLTWH(w * x, h * 0.24, w * 0.06, h * 0.60),
        pillarPaint,
      );
    }
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.42),
      h * 0.16,
      Paint()..color = spec.accentColor.withValues(alpha: 0.28),
    );
  }

  void _paintVolcanicCrags(Canvas canvas, double w, double h) {
    final emberPaint = Paint()
      ..color = spec.atmosphereColor.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(w * 0.28, h * 0.38), 2.2, emberPaint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.29), 1.8, emberPaint);
    canvas.drawCircle(Offset(w * 0.82, h * 0.48), 2.4, emberPaint);
  }

  void _paintSanctumArch(Canvas canvas, double w, double h) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = spec.accentColor.withValues(alpha: 0.65);
    canvas.drawCircle(Offset(w * 0.5, h * 0.45), h * 0.28, ringPaint);
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.45),
      h * 0.14,
      Paint()..color = spec.atmosphereColor.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _BiomeArtworkPainter oldDelegate) =>
      oldDelegate.spec.biomeId != spec.biomeId;
}
