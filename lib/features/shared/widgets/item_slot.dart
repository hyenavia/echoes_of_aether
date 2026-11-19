import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';
import '../../../domain/entities/equipment.dart';
import '../../../domain/entities/item_definition.dart';
import 'pixel_item_icon.dart';
import 'rarity_border.dart';

IconData _resolveSharedItemIcon({EquipmentSlot? slot, ItemCategory? category}) {
  if (slot != null) {
    return switch (slot) {
      EquipmentSlot.weapon => Icons.hardware_outlined,
      EquipmentSlot.head => Icons.psychology_alt_outlined,
      EquipmentSlot.body => Icons.shield_outlined,
      EquipmentSlot.accessory => Icons.diamond_outlined,
    };
  }
  return switch (category) {
    ItemCategory.material => Icons.category_outlined,
    ItemCategory.consumable => Icons.local_drink_outlined,
    ItemCategory.questItem => Icons.auto_stories_outlined,
    _ => Icons.inventory_2_outlined,
  };
}

/// Slot item ringkas untuk grid inventori atau hadiah loot.
class ItemSlot extends StatelessWidget {
  const ItemSlot({
    super.key,
    required this.rarity,
    this.itemId,
    this.spritePath,
    this.slot,
    this.category,
    this.quantity,
    this.label,
    this.isSelected = false,
    this.isLocked = false,
    this.size = 54,
    this.onTap,
  });

  final ItemRarity rarity;
  final String? itemId;
  final String? spritePath;
  final EquipmentSlot? slot;
  final ItemCategory? category;
  final int? quantity;
  final String? label;
  final bool isSelected;
  final bool isLocked;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final rarityColor = ext.colorForRarity(rarity);

    final bgTint = isLocked
        ? ext.locked.withValues(alpha: 0.08)
        : switch (rarity) {
            ItemRarity.mythical => rarityColor.withValues(alpha: 0.22),
            ItemRarity.legendary => ext.gold.withValues(alpha: 0.18),
            ItemRarity.epic => rarityColor.withValues(alpha: 0.14),
            ItemRarity.rare => rarityColor.withValues(alpha: 0.10),
            ItemRarity.uncommon => rarityColor.withValues(alpha: 0.08),
            ItemRarity.common => rarityColor.withValues(alpha: 0.05),
          };

    final slotBox = RarityBorder(
      rarity: rarity,
      isSelected: isSelected,
      isLocked: isLocked,
      useGlow: isSelected,
      radius: AppRadius.sm,
      backgroundColor: bgTint,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PixelItemIcon(
              itemId: itemId,
              spritePath: spritePath,
              slot: slot,
              category: category,
              size: size * 0.70,
              fallbackIcon: _resolveSharedItemIcon(
                slot: slot,
                category: category,
              ),
              fallbackColor: isLocked ? ext.locked : rarityColor,
            ),
            if (isLocked)
              Positioned(
                top: 3,
                left: 3,
                child: Icon(Icons.lock_outline, size: 12, color: ext.locked),
              ),
            if ((rarity == ItemRarity.legendary ||
                    rarity == ItemRarity.mythical) &&
                !isLocked)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: ext.gold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ext.gold.withValues(alpha: 0.8),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            if (quantity != null && quantity! > 1)
              Positioned(
                right: 3,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.midnightForest.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.panelBorder.withValues(alpha: 0.65),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    'x$quantity',
                    style: AppTypography.numeric(
                      theme.textTheme.labelSmall,
                      fontSize: 10,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final widget = label == null
        ? slotBox
        : Tooltip(message: label!, child: slotBox);

    if (onTap == null) return widget;
    return Semantics(
      button: true,
      label: label ?? 'Slot Item',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: widget,
      ),
    );
  }
}

/// Slot perlengkapan karakter untuk Weapon, Head, Body, dan Accessory.
class EquipmentSlotTile extends StatelessWidget {
  const EquipmentSlotTile({
    super.key,
    required this.slot,
    required this.slotLabel,
    this.itemName,
    this.rarity,
    this.statsSummary,
    this.isSelected = false,
    this.onTap,
  });

  final EquipmentSlot slot;
  final String slotLabel;
  final String? itemName;
  final ItemRarity? rarity;
  final String? statsSummary;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final isEquipped = itemName != null && itemName!.isNotEmpty;
    final effectiveRarity = rarity ?? ItemRarity.common;
    final tint = isEquipped
        ? ext.colorForRarity(effectiveRarity)
        : AppColors.textMuted;

    final decoration = isEquipped
        ? RarityBorder.decoration(
            context,
            rarity: effectiveRarity,
            isSelected: isSelected,
            useGlow: isSelected,
          )
        : BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? ext.gold : ext.panelInnerBorder,
              width: isSelected ? AppBorders.accent : AppBorders.standard,
            ),
          );

    final tile = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: decoration,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: isEquipped ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: tint.withValues(alpha: isEquipped ? 0.58 : 0.35),
                width: isEquipped ? 1.2 : 1.0,
              ),
              boxShadow:
                  isEquipped &&
                      (effectiveRarity == ItemRarity.legendary ||
                          effectiveRarity == ItemRarity.mythical)
                  ? [
                      BoxShadow(
                        color: ext.gold.withValues(alpha: 0.20),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: PixelItemIcon(
                slot: slot,
                size: 26,
                fallbackIcon: _resolveSharedItemIcon(slot: slot),
                fallbackColor: tint,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slotLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  isEquipped ? itemName! : 'Kosong',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isEquipped ? tint : AppColors.textSecondary,
                  ),
                ),
                if (statsSummary != null && statsSummary!.isNotEmpty)
                  Text(
                    statsSummary!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isSelected ? ext.gold : AppColors.textMuted,
            ),
        ],
      ),
    );

    if (onTap == null) return tile;
    return Semantics(
      button: true,
      label: '$slotLabel ${itemName ?? 'Kosong'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: tile,
      ),
    );
  }
}
