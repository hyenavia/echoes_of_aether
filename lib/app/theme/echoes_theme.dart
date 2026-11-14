import 'package:flutter/material.dart';

import '../../domain/entities/item_definition.dart';
import 'app_tokens.dart';

/// ThemeExtension khusus untuk token RPG Echoes of Aether.
@immutable
class EchoesThemeExtension extends ThemeExtension<EchoesThemeExtension> {
  const EchoesThemeExtension({
    required this.panelBackground,
    required this.panelBorder,
    required this.panelInnerBorder,
    required this.gold,
    required this.rank,
    required this.hpBar,
    required this.expBar,
    required this.locked,
    required this.success,
    required this.warning,
    required this.rarityCommon,
    required this.rarityUncommon,
    required this.rarityRare,
    required this.rarityEpic,
    required this.rarityLegendary,
  });

  final Color panelBackground;
  final Color panelBorder;
  final Color panelInnerBorder;
  final Color gold;
  final Color rank;
  final Color hpBar;
  final Color expBar;
  final Color locked;
  final Color success;
  final Color warning;
  final Color rarityCommon;
  final Color rarityUncommon;
  final Color rarityRare;
  final Color rarityEpic;
  final Color rarityLegendary;

  static const EchoesThemeExtension dark = EchoesThemeExtension(
    panelBackground: AppColors.panelDark,
    panelBorder: AppColors.panelBorder,
    panelInnerBorder: AppColors.panelInnerBorder,
    gold: AppColors.warmGold,
    rank: AppColors.arcanePurple,
    hpBar: AppColors.healthRed,
    expBar: AppColors.aetherBlue,
    locked: AppColors.locked,
    success: AppColors.success,
    warning: AppColors.warning,
    rarityCommon: AppColors.rarityCommon,
    rarityUncommon: AppColors.rarityUncommon,
    rarityRare: AppColors.rarityRare,
    rarityEpic: AppColors.rarityEpic,
    rarityLegendary: AppColors.rarityLegendary,
  );

  Color colorForRarity(ItemRarity rarity) => switch (rarity) {
    ItemRarity.common => rarityCommon,
    ItemRarity.uncommon => rarityUncommon,
    ItemRarity.rare => rarityRare,
    ItemRarity.epic => rarityEpic,
    ItemRarity.legendary => rarityLegendary,
  };

  @override
  EchoesThemeExtension copyWith({
    Color? panelBackground,
    Color? panelBorder,
    Color? panelInnerBorder,
    Color? gold,
    Color? rank,
    Color? hpBar,
    Color? expBar,
    Color? locked,
    Color? success,
    Color? warning,
    Color? rarityCommon,
    Color? rarityUncommon,
    Color? rarityRare,
    Color? rarityEpic,
    Color? rarityLegendary,
  }) {
    return EchoesThemeExtension(
      panelBackground: panelBackground ?? this.panelBackground,
      panelBorder: panelBorder ?? this.panelBorder,
      panelInnerBorder: panelInnerBorder ?? this.panelInnerBorder,
      gold: gold ?? this.gold,
      rank: rank ?? this.rank,
      hpBar: hpBar ?? this.hpBar,
      expBar: expBar ?? this.expBar,
      locked: locked ?? this.locked,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      rarityCommon: rarityCommon ?? this.rarityCommon,
      rarityUncommon: rarityUncommon ?? this.rarityUncommon,
      rarityRare: rarityRare ?? this.rarityRare,
      rarityEpic: rarityEpic ?? this.rarityEpic,
      rarityLegendary: rarityLegendary ?? this.rarityLegendary,
    );
  }

  @override
  EchoesThemeExtension lerp(
    covariant ThemeExtension<EchoesThemeExtension>? other,
    double t,
  ) {
    if (other is! EchoesThemeExtension) return this;
    return EchoesThemeExtension(
      panelBackground: Color.lerp(panelBackground, other.panelBackground, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      panelInnerBorder: Color.lerp(
        panelInnerBorder,
        other.panelInnerBorder,
        t,
      )!,
      gold: Color.lerp(gold, other.gold, t)!,
      rank: Color.lerp(rank, other.rank, t)!,
      hpBar: Color.lerp(hpBar, other.hpBar, t)!,
      expBar: Color.lerp(expBar, other.expBar, t)!,
      locked: Color.lerp(locked, other.locked, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      rarityCommon: Color.lerp(rarityCommon, other.rarityCommon, t)!,
      rarityUncommon: Color.lerp(rarityUncommon, other.rarityUncommon, t)!,
      rarityRare: Color.lerp(rarityRare, other.rarityRare, t)!,
      rarityEpic: Color.lerp(rarityEpic, other.rarityEpic, t)!,
      rarityLegendary: Color.lerp(rarityLegendary, other.rarityLegendary, t)!,
    );
  }
}

/// Pembuat [ThemeData] utama Echoes of Aether.
abstract final class EchoesTheme {
  static EchoesThemeExtension of(BuildContext context) {
    return Theme.of(context).extension<EchoesThemeExtension>() ??
        EchoesThemeExtension.dark;
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.aetherBlue,
      onPrimary: AppColors.backgroundDark,
      secondary: AppColors.warmGold,
      onSecondary: AppColors.backgroundDark,
      tertiary: AppColors.arcanePurple,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.deepForest,
      error: AppColors.healthRed,
      onError: AppColors.textPrimary,
      outline: AppColors.panelBorder,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      extensions: const [EchoesThemeExtension.dark],
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: AppColors.textPrimary,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: AppColors.textPrimary,
        ),
        titleSmall: base.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.warmGold,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.panelDark,
        elevation: AppElevation.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.panelBorder, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.panelInnerBorder,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.panelBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    );
  }
}
