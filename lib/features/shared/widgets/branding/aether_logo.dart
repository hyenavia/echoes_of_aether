import 'package:flutter/material.dart';

import '../../assets/game_assets.dart';

/// Varian logo Echoes of Aether.
enum AetherLogoVariant { primary, compact, winged, monoWhite, monoDark }

/// Widget reusable untuk menampilkan identitas logo resmi Echoes of Aether.
class AetherLogo extends StatelessWidget {
  const AetherLogo({
    super.key,
    this.variant = AetherLogoVariant.primary,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final AetherLogoVariant variant;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  String get assetPath => switch (variant) {
    AetherLogoVariant.primary => BrandingAssetPaths.logoPrimary,
    AetherLogoVariant.compact => BrandingAssetPaths.logoCompact,
    AetherLogoVariant.winged => BrandingAssetPaths.logoWinged,
    AetherLogoVariant.monoWhite => BrandingAssetPaths.logoMonoWhite,
    AetherLogoVariant.monoDark => BrandingAssetPaths.logoMonoDark,
  };

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return Text(
          'ECHOES OF AETHER',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        );
      },
    );
  }
}
