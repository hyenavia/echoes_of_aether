import 'package:flutter/material.dart';

import '../../domain/entities/item_definition.dart';

/// Token desain inti Living Aether Camp — Echoes of Aether.
abstract final class AppColors {
  // ---- Palet Utama Living Aether Camp ----
  static const Color midnightForest = Color(0xFF10251F);
  static const Color deepTeal = Color(0xFF203B30);
  static const Color antiqueGold = Color(0xFFE9C66D);
  static const Color aetherBlue = Color(0xFF69BFE5);
  static const Color arcaneViolet = Color(0xFFA88AD5);
  static const Color emberRed = Color(0xFFD96868);

  // ---- Palet Lingkungan & Sprite (GDD §14.2) ----
  static const Color forestGreen = Color(0xFF355B45);
  static const Color deepForest = Color(0xFF183028);
  static const Color mossGreen = Color(0xFF71865A);
  static const Color earthBrown = Color(0xFF795B43);
  static const Color ancientStone = Color(0xFF777B79);
  static const Color campAmber = Color(0xFFF0A25E);

  // ---- Alias Kompatibilitas Token Lama ----
  static const Color warmGold = antiqueGold;
  static const Color arcanePurple = arcaneViolet;
  static const Color healthRed = emberRed;

  // ---- Permukaan & Kontras UI RPG Gelap ----
  static const Color backgroundDark = midnightForest;
  static const Color surfaceDark = Color(0xFF162E27);
  static const Color panelDark = deepTeal;
  static const Color panelElevated = Color(0xFF27473B);
  static const Color panelBorder = Color(0xFF3F6755);
  static const Color panelInnerBorder = Color(0xFF2B4B3D);
  static const Color textPrimary = Color(0xFFF2F5EE);
  static const Color textSecondary = Color(0xFFBCCAC0);
  static const Color textMuted = Color(0xFF8CA094);

  // ---- Aksen Glow Halus ----
  static const Color aetherGlow = Color(0x3369BFE5);
  static const Color goldGlow = Color(0x33E9C66D);
  static const Color arcaneGlow = Color(0x33A88AD5);
  static const Color emberGlow = Color(0x33D96868);

  // ---- Warna Rarity (Common..Legendary) ----
  static const Color rarityCommon = Color(0xFFA8B3AE);
  static const Color rarityUncommon = Color(0xFF7FB069);
  static const Color rarityRare = aetherBlue;
  static const Color rarityEpic = arcaneViolet;
  static const Color rarityLegendary = antiqueGold;

  // ---- Semantik Status ----
  static const Color success = Color(0xFF6BBF73);
  static const Color warning = antiqueGold;
  static const Color danger = emberRed;
  static const Color locked = Color(0xFF8CA094);

  /// Sumber tunggal pemetaan warna rarity item.
  static Color colorForRarity(ItemRarity rarity) => switch (rarity) {
    ItemRarity.common => rarityCommon,
    ItemRarity.uncommon => rarityUncommon,
    ItemRarity.rare => rarityRare,
    ItemRarity.epic => rarityEpic,
    ItemRarity.legendary => rarityLegendary,
  };
}

/// Tipografi terpusat:
/// - Fantasy-inspired serif fallback untuk heading tertentu.
/// - Clean sans-serif untuk body text.
/// - Tabular figures untuk angka dan statistik gameplay.
abstract final class AppTypography {
  static const String displayFontFamily = 'serif';

  static TextStyle display(
    BuildContext context, {
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double letterSpacing = 0.5,
  }) {
    final base = Theme.of(context).textTheme.titleLarge;
    return (base ?? const TextStyle()).copyWith(
      fontFamily: displayFontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle headingSerif(
    TextStyle? base, {
    Color? color,
    double letterSpacing = 0.45,
  }) {
    return (base ?? const TextStyle()).copyWith(
      fontFamily: displayFontFamily,
      fontWeight: FontWeight.w700,
      letterSpacing: letterSpacing,
      color: color ?? base?.color ?? AppColors.textPrimary,
    );
  }

  static TextStyle numeric(
    TextStyle? base, {
    Color? color,
    FontWeight? fontWeight,
    double? fontSize,
  }) {
    return (base ?? const TextStyle()).copyWith(
      color: color ?? base?.color ?? AppColors.textPrimary,
      fontWeight: fontWeight ?? base?.fontWeight ?? FontWeight.w700,
      fontSize: fontSize ?? base?.fontSize,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
}

abstract final class AppBorders {
  static const double thin = 1.0;
  static const double standard = 1.5;
  static const double accent = 2.0;

  static BorderSide panel({Color? color, double width = standard}) =>
      BorderSide(color: color ?? AppColors.panelBorder, width: width);

  static BorderSide inner({Color? color, double width = thin}) =>
      BorderSide(color: color ?? AppColors.panelInnerBorder, width: width);
}

abstract final class AppElevation {
  static const double none = 0;
  static const double panel = 2;
  static const double card = 4;
  static const double overlay = 8;
}

abstract final class AppShadows {
  static const List<BoxShadow> panel = [
    BoxShadow(color: Color(0x5506100D), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> glow(Color color, {double alpha = 0.22}) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: 14,
      spreadRadius: 1,
    ),
  ];
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration ambient = Duration(milliseconds: 2400);
}
