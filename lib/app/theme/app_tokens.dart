import 'package:flutter/material.dart';

/// Token desain inti Echoes of Aether (GDD §14.2 + palet UI Idle RPG).
abstract final class AppColors {
  // Palet GDD §14.2
  static const Color forestGreen = Color(0xFF355B45);
  static const Color deepForest = Color(0xFF243D35);
  static const Color mossGreen = Color(0xFF71865A);
  static const Color earthBrown = Color(0xFF795B43);
  static const Color ancientStone = Color(0xFF777B79);
  static const Color aetherBlue = Color(0xFF65BFE8);
  static const Color arcanePurple = Color(0xFF9879CE);
  static const Color warmGold = Color(0xFFE6BD68);
  static const Color healthRed = Color(0xFFD95D5D);

  // Permukaan & kontras UI RPG gelap
  static const Color backgroundDark = Color(0xFF13201C);
  static const Color surfaceDark = Color(0xFF1A2C26);
  static const Color panelDark = Color(0xFF21362F);
  static const Color panelElevated = Color(0xFF274038);
  static const Color panelBorder = Color(0xFF476D59);
  static const Color panelInnerBorder = Color(0xFF2E4B3E);
  static const Color textPrimary = Color(0xFFF1F4EE);
  static const Color textSecondary = Color(0xFFB7C4BA);
  static const Color textMuted = Color(0xFF8C9A90);

  // Aksen glow halus (Aether, Gold, Arcane)
  static const Color aetherGlow = Color(0x3365BFE8);
  static const Color goldGlow = Color(0x33E6BD68);
  static const Color arcaneGlow = Color(0x339879CE);

  // Warna rarity (Common..Legendary)
  static const Color rarityCommon = Color(0xFFA8B3AE);
  static const Color rarityUncommon = Color(0xFF7FB069);
  static const Color rarityRare = aetherBlue;
  static const Color rarityEpic = arcanePurple;
  static const Color rarityLegendary = warmGold;

  // Semantik status
  static const Color success = Color(0xFF6BBF73);
  static const Color warning = warmGold;
  static const Color locked = Color(0xFF8C9A90);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

abstract final class AppRadius {
  static const double sm = 4;
  static const double md = 6;
  static const double lg = 10;
}

abstract final class AppElevation {
  static const double none = 0;
  static const double panel = 2;
  static const double overlay = 6;
}
