import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';

/// Identitas visual per biome dungeon agar setiap card memiliki atmosfer khas.
class BiomeStyle {
  const BiomeStyle({
    required this.label,
    required this.accentColor,
    required this.backgroundTint,
    required this.icon,
  });

  final String label;
  final Color accentColor;
  final Color backgroundTint;
  final IconData icon;

  static BiomeStyle resolve(String biome, {bool isAscension = false}) {
    if (isAscension) {
      return const BiomeStyle(
        label: 'Ascension Sanctum',
        accentColor: AppColors.arcanePurple,
        backgroundTint: Color(0xFF281D3D),
        icon: Icons.auto_awesome,
      );
    }
    switch (biome) {
      case 'forgotten_forest':
        return const BiomeStyle(
          label: 'Forgotten Forest',
          accentColor: AppColors.mossGreen,
          backgroundTint: Color(0xFF1A3127),
          icon: Icons.park_outlined,
        );
      case 'crystal_cavern':
        return const BiomeStyle(
          label: 'Crystal Cavern',
          accentColor: AppColors.aetherBlue,
          backgroundTint: Color(0xFF162C38),
          icon: Icons.diamond_outlined,
        );
      case 'ancient_crypt':
        return const BiomeStyle(
          label: 'Ancient Crypt',
          accentColor: AppColors.ancientStone,
          backgroundTint: Color(0xFF232829),
          icon: Icons.account_balance_outlined,
        );
      case 'ashen_wasteland':
        return const BiomeStyle(
          label: 'Ashen Wasteland',
          accentColor: AppColors.healthRed,
          backgroundTint: Color(0xFF331F20),
          icon: Icons.local_fire_department_outlined,
        );
      case 'aether_sanctum':
        return const BiomeStyle(
          label: 'Aether Sanctum',
          accentColor: AppColors.warmGold,
          backgroundTint: Color(0xFF262A22),
          icon: Icons.flare_outlined,
        );
      default:
        return const BiomeStyle(
          label: 'Dungeon',
          accentColor: AppColors.panelBorder,
          backgroundTint: AppColors.surfaceDark,
          icon: Icons.explore_outlined,
        );
    }
  }
}
