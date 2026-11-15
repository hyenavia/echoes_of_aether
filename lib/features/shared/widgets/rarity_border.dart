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
    this.radius = AppRadius.md,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
  });

  final ItemRarity rarity;
  final Widget child;
  final bool isSelected;
  final bool isLocked;
  final bool useGlow;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  /// Menghasilkan [BoxDecoration] konsisten untuk kartu dan slot berbasis rarity.
  static BoxDecoration decoration(
    BuildContext context, {
    required ItemRarity rarity,
    bool isSelected = false,
    bool isLocked = false,
    bool useGlow = false,
    double radius = AppRadius.md,
    Color? backgroundColor,
  }) {
    final ext = EchoesTheme.of(context);
    final rarityColor = ext.colorForRarity(rarity);
    final borderColor = isSelected
        ? ext.gold
        : isLocked
        ? ext.locked.withValues(alpha: 0.45)
        : rarityColor.withValues(alpha: 0.72);

    return BoxDecoration(
      color: backgroundColor ?? ext.panelBackground,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor,
        width: isSelected ? AppBorders.accent : AppBorders.standard,
      ),
      boxShadow: (useGlow || isSelected) && !isLocked
          ? AppShadows.glow(isSelected ? ext.gold : rarityColor, alpha: 0.20)
          : null,
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
        radius: radius,
        backgroundColor: backgroundColor,
      ),
      child: child,
    );
  }
}
