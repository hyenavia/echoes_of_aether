import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';
import '../../../domain/entities/equipment.dart';
import '../../../domain/entities/item_definition.dart';
import 'locked_badge.dart';
import 'pixel_item_icon.dart';
import 'rarity_border.dart';
import 'rarity_label.dart';

/// Kartu item bersama dengan warna rarity, ikon slot/kategori, nama, stat
/// ringkas, dan dukungan state terkunci atau aksi trailing.
class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.name,
    required this.rarity,
    this.itemId,
    this.spritePath,
    this.slot,
    this.category,
    this.statsSummary,
    this.statsLines,
    this.subtitle,
    this.quantity,
    this.isLocked = false,
    this.lockedReason,
    this.isSelected = false,
    this.useRarityGlow = false,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.trailing,
    this.onTap,
  });

  final String name;
  final ItemRarity rarity;
  final String? itemId;
  final String? spritePath;
  final EquipmentSlot? slot;
  final ItemCategory? category;
  final String? statsSummary;
  final List<String>? statsLines;
  final String? subtitle;
  final int? quantity;
  final bool isLocked;
  final String? lockedReason;
  final bool isSelected;
  final bool useRarityGlow;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final Widget? trailing;
  final VoidCallback? onTap;

  IconData _resolveIcon() {
    if (slot != null) {
      return switch (slot!) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final rarityColor = ext.colorForRarity(rarity);

    final cardContent = LayoutBuilder(
      builder: (context, constraints) {
        final stackTrailingBelow =
            trailing != null && constraints.maxWidth < 300;
        final resolvedLines =
            statsLines ??
            (statsSummary != null && statsSummary!.isNotEmpty
                ? (statsSummary!.contains('\n')
                      ? statsSummary!.split('\n')
                      : (statsSummary!.contains(', ')
                            ? statsSummary!.split(', ')
                            : [statsSummary!]))
                : null);
        final bodyColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: AppSpacing.xs + 2,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  quantity != null ? '$name (x$quantity)' : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                RarityLabel(rarity: rarity, compact: true),
                if (onToggleFavorite != null)
                  InkWell(
                    onTap: onToggleFavorite,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        isFavorite ? Icons.star : Icons.star_border,
                        size: 16,
                        color: isFavorite ? ext.gold : AppColors.textMuted,
                      ),
                    ),
                  )
                else if (isFavorite)
                  Icon(Icons.star, size: 14, color: ext.gold),
              ],
            ),
            if (resolvedLines != null && resolvedLines.isNotEmpty) ...[
              const SizedBox(height: 3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final line in resolvedLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 3.5,
                            height: 3.5,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: rarityColor.withValues(alpha: 0.8),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              line.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ],
            if (isLocked) ...[
              const SizedBox(height: AppSpacing.xs),
              LockedBadge(label: lockedReason ?? 'Terkunci'),
            ],
            if (stackTrailingBelow) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          ],
        );

        final iconBg = switch (rarity) {
          ItemRarity.mythical => rarityColor.withValues(alpha: 0.22),
          ItemRarity.legendary => ext.gold.withValues(alpha: 0.18),
          ItemRarity.epic => rarityColor.withValues(alpha: 0.16),
          ItemRarity.rare => rarityColor.withValues(alpha: 0.12),
          ItemRarity.uncommon => rarityColor.withValues(alpha: 0.09),
          ItemRarity.common => rarityColor.withValues(alpha: 0.06),
        };
        final iconBorder = switch (rarity) {
          ItemRarity.mythical => rarityColor.withValues(alpha: 0.80),
          ItemRarity.legendary => ext.gold.withValues(alpha: 0.70),
          ItemRarity.epic => rarityColor.withValues(alpha: 0.60),
          _ => rarityColor.withValues(alpha: 0.45),
        };

        return Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: RarityBorder.decoration(
            context,
            rarity: rarity,
            isSelected: isSelected,
            isLocked: isLocked,
            useGlow: useRarityGlow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: iconBorder,
                    width: rarity == ItemRarity.legendary ? 1.2 : 1.0,
                  ),
                  boxShadow: rarity == ItemRarity.legendary && !isLocked
                      ? [
                          BoxShadow(
                            color: ext.gold.withValues(alpha: 0.22),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: PixelItemIcon(
                    itemId: itemId,
                    spritePath: spritePath,
                    slot: slot,
                    category: category,
                    size: 30,
                    fallbackIcon: _resolveIcon(),
                    fallbackColor: rarityColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: bodyColumn),
              if (trailing != null && !stackTrailingBelow) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        );
      },
    );

    if (onTap == null) return cardContent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: cardContent,
    );
  }
}
