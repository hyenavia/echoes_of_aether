import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';
import '../../../domain/entities/equipment.dart';
import '../../../domain/entities/item_definition.dart';
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

    final slotBox = RarityBorder(
      rarity: rarity,
      isSelected: isSelected,
      isLocked: isLocked,
      useGlow: isSelected,
      radius: AppRadius.sm,
      backgroundColor: rarityColor.withValues(alpha: 0.10),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              _resolveSharedItemIcon(slot: slot, category: category),
              size: size * 0.44,
              color: isLocked ? ext.locked : rarityColor,
            ),
            if (isLocked)
              Positioned(
                top: 3,
                left: 3,
                child: Icon(Icons.lock_outline, size: 12, color: ext.locked),
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
                    color: AppColors.midnightForest.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
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
              color: tint.withValues(alpha: isEquipped ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: tint.withValues(alpha: 0.45)),
            ),
            child: Icon(
              _resolveSharedItemIcon(slot: slot),
              size: 18,
              color: tint,
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
