import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';
import '../../../domain/entities/item_definition.dart';

/// Helper terpusat untuk dekorasi border rarity pada kartu dan slot item.
class RarityBorder extends StatelessWidget {
  const RarityBorder({
    super.key,
    required this.rarity,
    required this.child,
    this.isSelected = false,
    this.isLocked = false,
    this.useGlow = false,
    this.allowTieredGlow = true,
    this.radius = AppRadius.md,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
  });

  final ItemRarity rarity;
  final Widget child;
  final bool isSelected;
  final bool isLocked;
  final bool useGlow;
  final bool allowTieredGlow;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  /// Menghasilkan [BoxDecoration] konsisten untuk kartu dan slot berbasis rarity.
  ///
  /// Mendukung tiered natural glow untuk item ber-rarity tinggi ([ItemRarity.rare],
  /// [ItemRarity.epic], [ItemRarity.legendary]) guna memperkaya visual RPG fantasy.
  static BoxDecoration decoration(
    BuildContext context, {
    required ItemRarity rarity,
    bool isSelected = false,
    bool isLocked = false,
    bool useGlow = false,
    bool allowTieredGlow = true,
    double radius = AppRadius.md,
    Color? backgroundColor,
  }) {
    final ext = EchoesTheme.of(context);
    final rarityColor = ext.colorForRarity(rarity);
    final borderColor = isSelected
        ? ext.gold
        : isLocked
        ? ext.locked.withValues(alpha: 0.45)
        : switch (rarity) {
            ItemRarity.mythical => rarityColor.withValues(alpha: 0.98),
            ItemRarity.legendary => ext.gold.withValues(alpha: 0.95),
            ItemRarity.epic => rarityColor.withValues(alpha: 0.88),
            ItemRarity.rare => rarityColor.withValues(alpha: 0.78),
            ItemRarity.uncommon => rarityColor.withValues(alpha: 0.68),
            ItemRarity.common => rarityColor.withValues(alpha: 0.52),
          };

    final borderWidth = isSelected
        ? AppBorders.accent
        : switch (rarity) {
            ItemRarity.mythical => 2.0,
            ItemRarity.legendary => 1.8,
            ItemRarity.epic => AppBorders.standard,
            _ => AppBorders.standard,
          };

    final List<BoxShadow>? shadows;
    if (isLocked) {
      shadows = null;
    } else if (isSelected) {
      shadows = AppShadows.glow(
        ext.gold,
        alpha: 0.32,
        blurRadius: 8,
        spreadRadius: 1,
      );
    } else if (useGlow || allowTieredGlow) {
      shadows = switch (rarity) {
        ItemRarity.mythical => AppShadows.glow(
          rarityColor,
          alpha: 0.36,
          blurRadius: 10,
          spreadRadius: 1.5,
        ),
        ItemRarity.legendary => AppShadows.glow(
          ext.gold,
          alpha: 0.28,
          blurRadius: 8,
          spreadRadius: 1,
        ),
        ItemRarity.epic => AppShadows.glow(
          rarityColor,
          alpha: 0.22,
          blurRadius: 6,
          spreadRadius: 0.5,
        ),
        ItemRarity.rare => AppShadows.glow(
          rarityColor,
          alpha: 0.16,
          blurRadius: 5,
          spreadRadius: 0,
        ),
        ItemRarity.uncommon =>
          useGlow
              ? AppShadows.glow(
                  rarityColor,
                  alpha: 0.12,
                  blurRadius: 4,
                  spreadRadius: 0,
                )
              : null,
        ItemRarity.common =>
          useGlow
              ? AppShadows.glow(
                  rarityColor,
                  alpha: 0.08,
                  blurRadius: 3,
                  spreadRadius: 0,
                )
              : null,
      };
    } else {
      shadows = null;
    }

    return BoxDecoration(
      color: backgroundColor ?? ext.panelBackground,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: shadows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: decoration(
        context,
        rarity: rarity,
        isSelected: isSelected,
        isLocked: isLocked,
        useGlow: useGlow,
        allowTieredGlow: allowTieredGlow,
        radius: radius,
        backgroundColor: backgroundColor,
      ),
      child: child,
    );
  }
}
