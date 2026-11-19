import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../assets/game_assets.dart';

/// Varian simbol kristal Echoes of Aether.
enum AetherSymbolVariant { mark, badge, monoWhite, monoDark }

/// Widget reusable untuk menampilkan simbol mark kristal Aether.
class AetherSymbolMark extends StatelessWidget {
  const AetherSymbolMark({
    super.key,
    this.variant = AetherSymbolVariant.mark,
    this.size = 32.0,
    this.glow = false,
  });

  final AetherSymbolVariant variant;
  final double size;
  final bool glow;

  String get assetPath => switch (variant) {
    AetherSymbolVariant.mark => BrandingAssetPaths.symbolMark,
    AetherSymbolVariant.badge => BrandingAssetPaths.symbolBadge,
    AetherSymbolVariant.monoWhite => BrandingAssetPaths.symbolMonoWhite,
    AetherSymbolVariant.monoDark => BrandingAssetPaths.symbolMonoDark,
  };

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );

    if (glow) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.aetherBlue.withValues(alpha: 0.4),
              blurRadius: size * 0.45,
              spreadRadius: size * 0.1,
            ),
          ],
        ),
        child: image,
      );
    }

    return SizedBox(width: size, height: size, child: image);
  }
}
